#!/usr/bin/env bash
# firstboot/10-paru.sh : installe paru, un assistant pour l'AUR.
# À lancer en UTILISATEUR NORMAL (makepkg refuse de tourner en root).
#
# On utilise "paru-bin" (binaire précompilé) plutôt que "paru" : pas besoin de
# compiler du Rust, l'installation est beaucoup plus rapide.

set -euo pipefail

log() { printf '\033[1;34m[paru]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[paru]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Ne lance pas ce script en root : utilise ton utilisateur normal."

if command -v paru >/dev/null 2>&1; then
  log "paru est déjà installé, rien à faire."
  exit 0
fi

sudo -v

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "Téléchargement de paru-bin depuis l'AUR…"
git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"

log "Compilation et installation du paquet…"
cd "$tmp/paru-bin"
makepkg -si --noconfirm

log "paru installé : $(paru --version | head -n1)"