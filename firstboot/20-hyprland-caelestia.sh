#!/usr/bin/env bash
# firstboot/20-hyprland-caelestia.sh
#
# Installe Hyprland + Caelestia et applique la configuration personnelle :
#   - wallpaper par défaut ;
#   - scheme dynamique ;
#   - GIF personnalisé du menu d'alimentation ;
#   - Opera comme navigateur par défaut ;
#   - SUPER + W pour lancer Opera ;
#   - disposition clavier ;
#   - greetd + tuigreet.
#
# Assets attendus dans le dépôt :
#   assets/wallpapers/default.png
#   assets/gifs/session.gif
#
# À lancer avec un utilisateur normal, pas avec sudo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Fichiers sources dans le dépôt -------------------------------------------

WALLPAPER_SOURCE="$REPO_DIR/assets/wallpapers/default.png"
SESSION_GIF_SOURCE="$REPO_DIR/assets/gifs/session.gif"

# --- Chemins de destination ---------------------------------------------------

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
INSTALLED_WALLPAPER="$WALLPAPER_DIR/default.png"

CAELESTIA_CONFIG_DIR="$HOME/.config/caelestia"
SHELL_CONFIG="$CAELESTIA_CONFIG_DIR/shell.json"
HYPR_VARS="$CAELESTIA_CONFIG_DIR/hypr-vars.lua"
HYPR_USER="$CAELESTIA_CONFIG_DIR/hypr-user.lua"

CAELESTIA_ASSET_DIR="$CAELESTIA_CONFIG_DIR/assets"
INSTALLED_SESSION_GIF="$CAELESTIA_ASSET_DIR/session.gif"

# --- Fonctions ----------------------------------------------------------------

log() {
  printf '\033[1;34m[caelestia]\033[0m %s\n' "$*"
}

ok() {
  printf '\033[1;32m[caelestia]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[caelestia]\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31m[caelestia]\033[0m %s\n' "$*" >&2
  exit 1
}

# --- Vérifications ------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
  die "Ne lance pas ce script en root : utilise ton utilisateur normal."
fi

if ! command -v curl >/dev/null 2>&1; then
  die "curl est requis pour continuer."
fi

curl -fsS --max-time 10 -o /dev/null https://archlinux.org \
  || die "Pas d'accès à Internet."

# Demande le mot de passe sudo une fois.
sudo -v

# Maintient sudo actif pendant les compilations AUR.
(
  while true; do
    sudo -n true
    sleep 50
    kill -0 "$$" 2>/dev/null || exit
  done
) &

KEEPALIVE_PID=$!

cleanup() {
  kill "$KEEPALIVE_PID" 2>/dev/null || true
}

trap cleanup EXIT

# --- 1. Installation de paru -------------------------------------------------

log "Installation ou vérification de paru…"
bash "$SCRIPT_DIR/10-paru.sh"

if ! command -v paru >/dev/null 2>&1; then
  die "paru est introuvable après l'exécution de 10-paru.sh."
fi

# --- 2. Installation de Caelestia --------------------------------------------

log "Installation de la CLI Caelestia depuis l'AUR…"
paru -S --needed --noconfirm caelestia-cli

if ! command -v caelestia >/dev/null 2>&1; then
  die "La commande caelestia est introuvable après son installation."
fi

log "Lancement de caelestia install…"
caelestia install

# --- 3. Préparation des dossiers Caelestia ------------------------------------

log "Création des dossiers Caelestia…"

mkdir -p "$WALLPAPER_DIR"
mkdir -p "$CAELESTIA_CONFIG_DIR"
mkdir -p "$CAELESTIA_ASSET_DIR"

# --- 4. Installation du wallpaper --------------------------------------------

if [ -f "$WALLPAPER_SOURCE" ]; then
  log "Copie du wallpaper par défaut…"

  install -Dm644 \
    "$WALLPAPER_SOURCE" \
    "$INSTALLED_WALLPAPER"

  ok "Wallpaper installé : $INSTALLED_WALLPAPER"
else
  warn "Wallpaper introuvable : $WALLPAPER_SOURCE"
  warn "Ajoute une image à assets/wallpapers/default.png."
fi

# --- 5. Installation du GIF du menu d'alimentation ----------------------------

if [ -f "$SESSION_GIF_SOURCE" ]; then
  log "Copie du GIF du menu d'alimentation…"

  install -Dm644 \
    "$SESSION_GIF_SOURCE" \
    "$INSTALLED_SESSION_GIF"

  ok "GIF installé : $INSTALLED_SESSION_GIF"
else
  warn "GIF introuvable : $SESSION_GIF_SOURCE"
  warn "Ajoute un GIF à assets/gifs/session.gif."
fi

# --- 6. Configuration de shell.json -------------------------------------------

# shell.json n'est pas forcément créé par Caelestia.
# jq permet de conserver les autres options existantes.
if ! command -v jq >/dev/null 2>&1; then
  log "Installation de jq…"
  sudo pacman -S --needed --noconfirm jq
fi

log "Configuration de shell.json…"

TEMP_SHELL_CONFIG="$(mktemp)"

if [ -f "$SHELL_CONFIG" ]; then
  if ! jq empty "$SHELL_CONFIG" >/dev/null 2>&1; then
    warn "$SHELL_CONFIG contient un JSON invalide."
    warn "Une nouvelle configuration minimale sera créée."
    rm -f "$SHELL_CONFIG"
  fi
fi

if [ -f "$SHELL_CONFIG" ]; then
  jq \
    --arg wallpaper_dir "$WALLPAPER_DIR" \
    --arg session_gif "$INSTALLED_SESSION_GIF" \
    '
      .paths = ((.paths // {}) + {
        wallpaperDir: $wallpaper_dir,
        sessionGif: $session_gif
      })
    ' \
    "$SHELL_CONFIG" > "$TEMP_SHELL_CONFIG"
else
  jq -n \
    --arg wallpaper_dir "$WALLPAPER_DIR" \
    --arg session_gif "$INSTALLED_SESSION_GIF" \
    '
      {
        paths: {
          wallpaperDir: $wallpaper_dir,
          sessionGif: $session_gif
        }
      }
    ' > "$TEMP_SHELL_CONFIG"
fi

install -Dm644 "$TEMP_SHELL_CONFIG" "$SHELL_CONFIG"
rm -f "$TEMP_SHELL_CONFIG"

ok "shell.json configuré."

# --- 7. Sélection du wallpaper et du scheme dynamique ------------------------

if [ -f "$INSTALLED_WALLPAPER" ]; then
  log "Sélection du wallpaper par défaut…"

  if caelestia wallpaper -f "$INSTALLED_WALLPAPER"; then
    ok "Wallpaper sélectionné."
  else
    warn "Le wallpaper n'a pas pu être sélectionné pendant l'installation."
    warn "Si nécessaire, lance cette commande après ta connexion à Hyprland :"
    warn "  caelestia wallpaper -f \"$INSTALLED_WALLPAPER\""
  fi

  log "Activation du scheme dynamique…"

  if caelestia scheme set -n dynamic; then
    ok "Scheme dynamique activé."
  else
    warn "Le scheme dynamique n'a pas pu être activé pendant l'installation."
    warn "Si nécessaire, lance cette commande après ta connexion à Hyprland :"
    warn "  caelestia scheme set -n dynamic"
  fi
fi

# --- 8. Configuration d'Opera et de SUPER + W -------------------------------

# La configuration Lua moderne de Caelestia utilise :
#
#   return {
#     browser = "opera",
#   }
#
# Le raccourci SUPER + W utilise déjà la variable kbBrowser par défaut.
# On modifie donc uniquement browser.

log "Configuration d'Opera comme navigateur par défaut…"

if [ -f "$HYPR_VARS" ]; then
  if grep -Eq '^[[:space:]]*browser[[:space:]]*=' "$HYPR_VARS"; then
    sed -i \
      -E 's/^([[:space:]]*browser[[:space:]]*=[[:space:]]*).*/\1"opera",/' \
      "$HYPR_VARS"

    ok "Navigateur par défaut configuré sur Opera."
  elif grep -Eq '^[[:space:]]*return[[:space:]]*\{' "$HYPR_VARS"; then
    # Ajoute browser juste avant la dernière accolade fermante.
    sed -i '$i\  browser = "opera",' "$HYPR_VARS"
    ok "Opera ajouté à hypr-vars.lua."
  else
    warn "Format inattendu dans $HYPR_VARS."
    warn "Ajoute manuellement : browser = \"opera\","
  fi
else
  cat > "$HYPR_VARS" <<'EOF'
return {
  browser = "opera",
}
EOF

  ok "hypr-vars.lua créé avec Opera comme navigateur par défaut."
fi

# Vérifie que le raccourci SUPER + W reste configuré.
# Si une configuration utilisateur existe déjà, on ne l'écrase pas.
if grep -Eq '^[[:space:]]*kbBrowser[[:space:]]*=' "$HYPR_VARS" 2>/dev/null; then
  log "Le raccourci kbBrowser existant est conservé."
fi

# --- 9. Configuration du clavier dans Hyprland -------------------------------

# Caelestia démarre généralement en clavier US.
# On reprend le KEYMAP de /etc/vconsole.conf, sauf si KB_LAYOUT est fourni.

KEYMAP_FROM_CONSOLE="$(
  sed -n 's/^KEYMAP=//p' /etc/vconsole.conf 2>/dev/null \
    | head -n1 \
    || true
)"

KB_LAYOUT="${KB_LAYOUT:-${KEYMAP_FROM_CONSOLE%%-*}}"
KB_LAYOUT="${KB_LAYOUT:-fr}"

mkdir -p "$(dirname "$HYPR_USER")"

if ! grep -q 'arch-setup: keyboard' "$HYPR_USER" 2>/dev/null; then
  log "Configuration du clavier Hyprland : $KB_LAYOUT"

  cat >> "$HYPR_USER" <<EOF

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
  log "Configuration du clavier déjà présente."
fi

# --- 10. Installation et configuration de greetd ----------------------------

log "Installation de greetd et tuigreet…"
sudo pacman -S --needed --noconfirm greetd greetd-tuigreet

LAUNCHER="Hyprland"

if command -v start-hyprland >/dev/null 2>&1; then
  LAUNCHER="start-hyprland"
fi

log "Configuration de greetd avec le lanceur : $LAUNCHER"

sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd $LAUNCHER"
user = "greeter"
EOF

sudo systemctl enable greetd.service

# --- Fin ----------------------------------------------------------------------

log "Installation de Caelestia terminée."

printf '\n'
printf 'Configuration appliquée :\n'
printf '  Wallpaper : %s\n' "$INSTALLED_WALLPAPER"
printf '  GIF menu alimentation : %s\n' "$INSTALLED_SESSION_GIF"
printf '  Scheme : dynamic\n'
printf '  Navigateur : Opera\n'
printf '  Raccourci navigateur : SUPER + W\n'
printf '  Clavier : %s\n' "$KB_LAYOUT"

printf '\n'
log "Redémarre avec : sudo reboot"

warn "Dans VirtualBox, Hyprland peut ne pas démarrer à cause de l'accélération 3D limitée."
warn "Si le wallpaper ou le scheme n'est pas appliqué après le redémarrage, exécute :"
warn "  caelestia wallpaper -f \"$INSTALLED_WALLPAPER\""
warn "  caelestia scheme set -n dynamic"