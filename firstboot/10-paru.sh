#!/usr/bin/env bash
# firstboot/10-paru.sh : installe paru, un assistant pour l'AUR.
# À lancer en UTILISATEUR NORMAL (makepkg refuse de tourner en root).
#
# On compile "paru" depuis les sources (et pas "paru-bin") : le binaire précompilé
# est lié à une version précise de libalpm (la bibliothèque de pacman) et se casse
# dès que pacman est plus récent ("libalpm.so.15: cannot open shared object file").
# Compiler soi-même garantit la compatibilité, au prix de quelques minutes de
# compilation Rust.

set -euo pipefail

log() { printf '\033[1;34m[paru]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[paru]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Ne lance pas ce script en root : utilise ton utilisateur normal."

# "paru --version" échoue si la bibliothèque libalpm ne correspond pas : on teste
# donc le fonctionnement réel, pas seulement la présence de la commande.
if command -v paru >/dev/null 2>&1 && paru --version >/dev/null 2>&1; then
  log "paru est déjà installé et fonctionnel, rien à faire."
  exit 0
fi

sudo -v

# Retire une éventuelle version précompilée cassée (le paquet -debug dépend du
# paquet principal, on les retire ensemble).
old=()
for p in paru-bin paru-bin-debug; do
  if pacman -Q "$p" >/dev/null 2>&1; then old+=("$p"); fi
done
if [ "${#old[@]}" -gt 0 ]; then
  log "Retrait de : ${old[*]} (incompatible avec la version de pacman installée)…"
  sudo pacman -Rns --noconfirm "${old[@]}"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "Téléchargement de paru depuis l'AUR…"
git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"

log "Compilation et installation (Rust, compte plusieurs minutes)…"
cd "$tmp/paru"
makepkg -si --noconfirm

paru --version >/dev/null 2>&1 || die "paru est installé mais ne démarre pas."
log "paru installé : $(paru --version | head -n1)"