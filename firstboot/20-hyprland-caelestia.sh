#!/usr/bin/env bash
# firstboot/20-hyprland-caelestia.sh : installe Hyprland + Caelestia.
# À lancer en UTILISATEUR NORMAL, dans un terminal.
#
# Assets attendus dans le dépôt :
#   assets/wallpapers/default.jpg
#   assets/gifs/session.gif
#
# Le script :
#   - installe Caelestia ;
#   - crée ~/Pictures/Wallpapers ;
#   - installe et sélectionne le wallpaper par défaut ;
#   - active le scheme dynamique ;
#   - installe le GIF du menu d'alimentation ;
#   - configure le clavier Hyprland ;
#   - installe et configure greetd + tuigreet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WALLPAPER_SOURCE="$REPO_DIR/assets/wallpapers/default.jpg"
SESSION_GIF_SOURCE="$REPO_DIR/assets/gifs/session.gif"

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
INSTALLED_WALLPAPER="$WALLPAPER_DIR/default.jpg"

CAELESTIA_CONFIG_DIR="$HOME/.config/caelestia"
CAELESTIA_ASSET_DIR="$CAELESTIA_CONFIG_DIR/assets"
SHELL_CONFIG="$CAELESTIA_CONFIG_DIR/shell.json"
INSTALLED_SESSION_GIF="$CAELESTIA_ASSET_DIR/session.gif"

log()  { printf '\033[1;34m[caelestia]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[caelestia]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[caelestia]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[caelestia]\033[0m %s\n' "$*" >&2; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
  die "Ne lance pas ce script en root : utilise ton utilisateur normal."
fi

curl -fsS --max-time 10 -o /dev/null https://archlinux.org \
  || die "Pas d'accès à Internet."

# Demande le mot de passe sudo une fois, puis garde sudo actif pendant le script.
sudo -v

(
  while true; do
    sudo -n true
    sleep 50
    kill -0 "$$" 2>/dev/null || exit
  done
) &

KEEPALIVE_PID=$!
trap 'kill "$KEEPALIVE_PID" 2>/dev/null || true' EXIT

# --- 1. paru ------------------------------------------------------------------
log "Installation ou vérification de paru…"
bash "$SCRIPT_DIR/10-paru.sh"

# --- 2. Caelestia -------------------------------------------------------------
log "Installation de la CLI Caelestia depuis l'AUR…"
paru -S --needed --noconfirm caelestia-cli

if ! command -v caelestia >/dev/null 2>&1; then
  die "La commande caelestia est introuvable après son installation."
fi

log "Lancement de caelestia install…"
caelestia install

# --- 2a. Wallpaper ------------------------------------------------------------
log "Création du dossier des wallpapers…"
mkdir -p "$WALLPAPER_DIR"

if [ -f "$WALLPAPER_SOURCE" ]; then
  log "Installation du wallpaper par défaut…"

  install -Dm644 \
    "$WALLPAPER_SOURCE" \
    "$INSTALLED_WALLPAPER"

  ok "Wallpaper copié vers : $INSTALLED_WALLPAPER"

  log "Configuration du dossier des wallpapers dans shell.json…"

  if ! command -v jq >/dev/null 2>&1; then
    log "Installation de jq…"
    sudo pacman -S --needed --noconfirm jq
  fi

  mkdir -p "$CAELESTIA_CONFIG_DIR"

  tmp_config="$(mktemp)"

  if [ -f "$SHELL_CONFIG" ]; then
    if jq \
      --arg wallpaper_dir "$WALLPAPER_DIR" \
      '
        .paths = ((.paths // {}) + {
          wallpaperDir: $wallpaper_dir
        })
      ' \
      "$SHELL_CONFIG" > "$tmp_config"; then
      install -Dm644 "$tmp_config" "$SHELL_CONFIG"
      ok "Dossier des wallpapers configuré."
    else
      warn "shell.json contient un JSON invalide : dossier non configuré."
    fi
  else
    jq -n \
      --arg wallpaper_dir "$WALLPAPER_DIR" \
      '
        {
          paths: {
            wallpaperDir: $wallpaper_dir
          }
        }
      ' > "$tmp_config"

    install -Dm644 "$tmp_config" "$SHELL_CONFIG"
    ok "shell.json créé avec le dossier des wallpapers."
  fi

  rm -f "$tmp_config"

  # Cette commande peut ne fonctionner qu'après le démarrage de la session
  # Hyprland/Caelestia. L'échec n'interrompt donc pas l'installation.
  log "Sélection du wallpaper par défaut…"
  if caelestia wallpaper -f "$INSTALLED_WALLPAPER"; then
    ok "Wallpaper par défaut sélectionné."
  else
    warn "Impossible de sélectionner le wallpaper maintenant."
    warn "Après ta connexion à Hyprland, lance :"
    warn "  caelestia wallpaper -f \"$INSTALLED_WALLPAPER\""
  fi

  log "Activation du scheme dynamique…"
  if caelestia scheme set -n dynamic; then
    ok "Scheme dynamique activé."
  else
    warn "Impossible d'activer le scheme dynamique maintenant."
    warn "Après ta connexion à Hyprland, lance :"
    warn "  caelestia scheme set -n dynamic"
  fi
else
  warn "Wallpaper introuvable : $WALLPAPER_SOURCE"
  warn "Ajoute ton image à ce chemin dans le dépôt."
fi

# --- 2b. GIF du menu d'alimentation -------------------------------------------
if [ -f "$SESSION_GIF_SOURCE" ]; then
  log "Installation du GIF du menu d'alimentation…"

  mkdir -p "$CAELESTIA_ASSET_DIR"

  install -Dm644 \
    "$SESSION_GIF_SOURCE" \
    "$INSTALLED_SESSION_GIF"

  ok "GIF copié vers : $INSTALLED_SESSION_GIF"

  if ! command -v jq >/dev/null 2>&1; then
    log "Installation de jq…"
    sudo pacman -S --needed --noconfirm jq
  fi

  mkdir -p "$CAELESTIA_CONFIG_DIR"

  tmp_config="$(mktemp)"

  if [ -f "$SHELL_CONFIG" ]; then
    if jq \
      --arg session_gif "$INSTALLED_SESSION_GIF" \
      --arg wallpaper_dir "$WALLPAPER_DIR" \
      '
        .paths = ((.paths // {}) + {
          sessionGif: $session_gif,
          wallpaperDir: $wallpaper_dir
        })
      ' \
      "$SHELL_CONFIG" > "$tmp_config"; then
      install -Dm644 "$tmp_config" "$SHELL_CONFIG"
      ok "GIF du menu d'alimentation configuré."
    else
      warn "shell.json contient un JSON invalide : GIF non configuré."
    fi
  else
    jq -n \
      --arg session_gif "$INSTALLED_SESSION_GIF" \
      --arg wallpaper_dir "$WALLPAPER_DIR" \
      '
        {
          paths: {
            sessionGif: $session_gif,
            wallpaperDir: $wallpaper_dir
          }
        }
      ' > "$tmp_config"

    install -Dm644 "$tmp_config" "$SHELL_CONFIG"
    ok "shell.json créé avec le GIF du menu d'alimentation."
  fi

  rm -f "$tmp_config"
else
  warn "GIF du menu d'alimentation introuvable : $SESSION_GIF_SOURCE"
  warn "Ajoute ton GIF à ce chemin dans le dépôt."
fi

# --- 2c. Disposition du clavier dans Hyprland -------------------------------
# Caelestia démarre généralement avec la disposition us.
# On utilise KEYMAP de /etc/vconsole.conf, sauf si KB_LAYOUT est fourni.
km="$(
  sed -n 's/^KEYMAP=//p' /etc/vconsole.conf 2>/dev/null \
    | head -n1 \
    || true
)"

KB_LAYOUT="${KB_LAYOUT:-${km%%-*}}"
KB_LAYOUT="${KB_LAYOUT:-fr}"

USER_LUA="$CAELESTIA_CONFIG_DIR/hypr-user.lua"

mkdir -p "$(dirname "$USER_LUA")"

if ! grep -q 'arch-setup: keyboard' "$USER_LUA" 2>/dev/null; then
  log "Configuration du clavier Hyprland : $KB_LAYOUT"

  cat >> "$USER_LUA" <<EOF

-- arch-setup: keyboard
-- Ajouté par firstboot/20-hyprland-caelestia.sh
hl.config({
  input = {
    kb_layout = "$KB_LAYOUT",
  },
})
EOF

  ok "Disposition clavier configurée."
else
  log "Configuration du clavier déjà présente : aucune modification."
fi

# --- 3. Gestionnaire de connexion : greetd + tuigreet -----------------------
log "Installation de greetd et tuigreet…"
sudo pacman -S --needed --noconfirm greetd greetd-tuigreet

launcher="Hyprland"

if command -v start-hyprland >/dev/null 2>&1; then
  launcher="start-hyprland"
fi

log "Configuration de greetd avec le lanceur : $launcher"

sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd $launcher"
user = "greeter"
EOF

sudo systemctl enable greetd.service

log "Installation Caelestia terminée."
log "Le wallpaper attendu est : $INSTALLED_WALLPAPER"
log "Le GIF du menu d'alimentation attendu est : $INSTALLED_SESSION_GIF"
log "Redémarre avec : sudo reboot"

warn "Dans VirtualBox, Hyprland peut ne pas démarrer à cause de l'accélération 3D limitée."