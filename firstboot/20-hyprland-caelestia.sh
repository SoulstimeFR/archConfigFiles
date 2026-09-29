#!/usr/bin/env bash
# firstboot/20-hyprland-caelestia.sh : installe Hyprland + Caelestia.
# À lancer en UTILISATEUR NORMAL, dans un terminal (des questions peuvent être posées).
#
# Méthode officielle Caelestia (README du dépôt caelestia-dots/caelestia) :
#   paru -S caelestia-cli && caelestia install
# La CLI installe Hyprland, le shell (quickshell), les dépendances et les dotfiles.
#
# Ensuite on ajoute un gestionnaire de connexion (greetd + tuigreet), car les
# dotfiles Caelestia n'en fournissent pas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m[caelestia]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[caelestia]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[caelestia]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Ne lance pas ce script en root : utilise ton utilisateur normal."

curl -fsS --max-time 10 -o /dev/null https://archlinux.org \
  || die "Pas d'accès à Internet."

# Demande le mot de passe sudo une fois, puis le garde actif pendant le script
# (les compilations AUR peuvent durer plus longtemps que la validité de sudo).
sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE_PID=$!
trap 'kill "$KEEPALIVE_PID" 2>/dev/null || true' EXIT

# --- 1. paru (AUR) ------------------------------------------------------------
bash "$SCRIPT_DIR/10-paru.sh"

# --- 2. Caelestia : CLI puis installation des dotfiles ------------------------
log "Installation de la CLI Caelestia (AUR)…"
paru -S --needed --noconfirm caelestia-cli

log "Lancement de 'caelestia install' (répond aux questions éventuelles)…"
caelestia install

# --- 3. Gestionnaire de connexion : greetd + tuigreet -------------------------
log "Installation de greetd + tuigreet…"
sudo pacman -S --needed --noconfirm greetd greetd-tuigreet

# Hyprland récent se lance de préférence via "start-hyprland" s'il existe.
launcher="Hyprland"
if command -v start-hyprland >/dev/null 2>&1; then
  launcher="start-hyprland"
fi

log "Configuration de greetd (lancement de $launcher)…"
sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd $launcher"
user = "greeter"
EOF

sudo systemctl enable greetd.service

log "Terminé. Redémarre pour arriver sur l'écran de connexion : sudo reboot"
warn "Dans VirtualBox, Hyprland peut ne pas démarrer (accélération 3D limitée) : ce n'est pas forcément une erreur de script."