#!/usr/bin/env bash
# firstboot/20-hyprland-caelestia.sh
#
# Installe et configure Hyprland + Caelestia.
#
# Assets attendus dans le dépôt :
#   assets/wallpapers/default.png
#   assets/gifs/session.gif
#   assets/profile/profile.png
#
# Le script doit être lancé avec l'utilisateur normal, pas avec sudo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Assets -------------------------------------------------------------------

WALLPAPER_SOURCE="$REPO_DIR/assets/wallpapers/default.png"
SESSION_GIF_SOURCE="$REPO_DIR/assets/gifs/session.gif"
PROFILE_SOURCE="$REPO_DIR/assets/profile/profile.png"

# --- Destinations -------------------------------------------------------------

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
INSTALLED_WALLPAPER="$WALLPAPER_DIR/default.png"

CAELESTIA_CONFIG_DIR="$HOME/.config/caelestia"
CAELESTIA_ASSET_DIR="$CAELESTIA_CONFIG_DIR/assets"

SHELL_CONFIG="$CAELESTIA_CONFIG_DIR/shell.json"
HYPR_VARS="$CAELESTIA_CONFIG_DIR/hypr-vars.lua"
HYPR_USER="$CAELESTIA_CONFIG_DIR/hypr-user.lua"

INSTALLED_SESSION_GIF="$CAELESTIA_ASSET_DIR/session.gif"
PROFILE_DEST="$HOME/.face"

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

# Maintient sudo actif pendant les opérations longues.
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

# --- 3. Création des dossiers -------------------------------------------------

log "Création des dossiers Caelestia…"

mkdir -p "$WALLPAPER_DIR"
mkdir -p "$CAELESTIA_CONFIG_DIR"
mkdir -p "$CAELESTIA_ASSET_DIR"

# --- 4. Installation du wallpaper --------------------------------------------

if [ -f "$WALLPAPER_SOURCE" ]; then
  log "Installation du wallpaper par défaut…"

  install -Dm644 \
    "$WALLPAPER_SOURCE" \
    "$INSTALLED_WALLPAPER"

  ok "Wallpaper installé : $INSTALLED_WALLPAPER"
else
  warn "Wallpaper introuvable : $WALLPAPER_SOURCE"
  warn "Ajoute ton image dans assets/wallpapers/default.png."
fi

# --- 5. Installation du GIF du menu d'alimentation ----------------------------

if [ -f "$SESSION_GIF_SOURCE" ]; then
  log "Installation du GIF du menu d'alimentation…"

  install -Dm644 \
    "$SESSION_GIF_SOURCE" \
    "$INSTALLED_SESSION_GIF"

  ok "GIF installé : $INSTALLED_SESSION_GIF"
else
  warn "GIF introuvable : $SESSION_GIF_SOURCE"
  warn "Ajoute ton GIF dans assets/gifs/session.gif."
fi

# --- 6. Installation de la photo de profil ------------------------------------

if [ -f "$PROFILE_SOURCE" ]; then
  log "Installation de la photo de profil…"

  # ~/.face doit être un fichier image et non un dossier.
  rm -rf "$PROFILE_DEST"

  install -Dm644 \
    "$PROFILE_SOURCE" \
    "$PROFILE_DEST"

  ok "Photo de profil installée : $PROFILE_DEST"
else
  warn "Photo de profil introuvable : $PROFILE_SOURCE"
  warn "Ajoute une image PNG dans assets/profile/profile.png."
fi

# --- 7. Configuration de shell.json -------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
  log "Installation de jq…"
  sudo pacman -S --needed --noconfirm jq
fi

log "Configuration de shell.json…"

TEMP_SHELL_CONFIG="$(mktemp)"

if [ -f "$SHELL_CONFIG" ] \
  && jq empty "$SHELL_CONFIG" >/dev/null 2>&1; then

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
  if [ -f "$SHELL_CONFIG" ]; then
    warn "$SHELL_CONFIG contient un JSON invalide."
    warn "Une nouvelle configuration minimale sera créée."
  fi

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

# --- 8. Sélection du wallpaper -----------------------------------------------

if [ -f "$INSTALLED_WALLPAPER" ]; then
  log "Sélection du wallpaper par défaut…"

  if caelestia wallpaper -f "$INSTALLED_WALLPAPER"; then
    ok "Wallpaper sélectionné."
  else
    warn "Le wallpaper ne peut pas être sélectionné maintenant."
    warn "Après ta connexion à Hyprland, exécute :"
    warn "  caelestia wallpaper -f \"$INSTALLED_WALLPAPER\""
  fi

  log "Activation du scheme dynamique…"

  if caelestia scheme set -n dynamic; then
    ok "Scheme dynamique activé."
  else
    warn "Le scheme dynamique ne peut pas être activé maintenant."
    warn "Après ta connexion à Hyprland, exécute :"
    warn "  caelestia scheme set -n dynamic"
  fi
else
  warn "Wallpaper non installé : fichier source absent."
fi

# --- 9. Configuration d'Opera et de Super + W --------------------------------

# Caelestia utilise normalement la variable "browser" pour le raccourci
# kbBrowser, correspondant par défaut à Super + W.
log "Configuration d'Opera comme navigateur par défaut…"

if [ -f "$HYPR_VARS" ]; then
  if grep -Eq '^[[:space:]]*browser[[:space:]]*=' "$HYPR_VARS"; then
    sed -i \
      -E 's/^([[:space:]]*browser[[:space:]]*=[[:space:]]*).*/\1"opera",/' \
      "$HYPR_VARS"

    ok "La variable browser est configurée sur Opera."
  elif grep -Eq '^[[:space:]]*return[[:space:]]*\{' "$HYPR_VARS"; then
    # Ajoute browser dans une configuration Lua de type :
    # return {
    #   ...
    # }
    sed -i '$i\  browser = "opera",' "$HYPR_VARS"

    ok "Opera ajouté à hypr-vars.lua."
  else
    warn "Format inconnu dans $HYPR_VARS."
    warn "Ajoute manuellement : browser = \"opera\","
  fi
else
  cat > "$HYPR_VARS" <<'EOF'
return {
  browser = "opera",
}
EOF

  ok "hypr-vars.lua créé avec Opera."
fi

# --- 10. Configuration du clavier Hyprland -----------------------------------

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

# --- 11. Installation de greetd ----------------------------------------------

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

# --- Résumé -------------------------------------------------------------------

printf '\n'
log "Installation et configuration de Caelestia terminées."

printf '\n'
printf 'Configuration :\n'
printf '  Wallpaper : %s\n' "$INSTALLED_WALLPAPER"
printf '  GIF : %s\n' "$INSTALLED_SESSION_GIF"
printf '  Photo de profil : %s\n' "$PROFILE_DEST"
printf '  Scheme : dynamic\n'
printf '  Navigateur : Opera\n'
printf '  Raccourci : Super + W\n'
printf '  Clavier : %s\n' "$KB_LAYOUT"

printf '\n'
log "Redémarre avec : sudo reboot"

warn "Dans VirtualBox, Hyprland peut ne pas démarrer à cause de l'accélération 3D limitée."