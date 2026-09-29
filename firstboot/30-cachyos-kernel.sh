#!/usr/bin/env bash
# firstboot/30-cachyos-kernel.sh : ajoute les dépôts CachyOS et installe le noyau
# linux-cachyos, EN GARDANT le noyau Arch "linux" comme solution de secours.
# À lancer en UTILISATEUR NORMAL, dans un terminal (des questions peuvent être posées).
#
# Méthode officielle (wiki.cachyos.org, "Optimized Repositories") : le script
# cachyos-repo.sh détecte les instructions du processeur (x86-64-v3, v4, znver4...)
# et ajoute les dépôts optimisés correspondants. Attention : il installe aussi un
# pacman modifié par CachyOS et remplace de nombreux paquets Arch par leurs
# versions optimisées.
#
# Sécurité : Snapper (snap-pac) prend un snapshot avant chaque transaction pacman,
# et le noyau "linux" reste disponible dans le menu GRUB (Advanced options).

set -euo pipefail

log()  { printf '\033[1;34m[cachyos]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[cachyos]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[cachyos]\033[0m %s\n' "$*" >&2; exit 1; }

KERNEL_PKG="linux-cachyos"
KERNEL_IMG="/boot/vmlinuz-linux-cachyos"

[ "$(id -u)" -ne 0 ] || die "Ne lance pas ce script en root : utilise ton utilisateur normal."
curl -fsS --max-time 10 -o /dev/null https://mirror.cachyos.org || die "mirror.cachyos.org injoignable (Internet ?)."

sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE_PID=$!
tmp="$(mktemp -d)"
trap 'kill "$KEEPALIVE_PID" 2>/dev/null || true; rm -rf "$tmp"' EXIT

# --- 1. Protéger quickshell-git (Caelestia) ----------------------------------
# Le dépôt CachyOS peut proposer sa propre version de quickshell-git, et un
# signalement d'utilisateurs indique qu'elle peut être incompatible avec Caelestia.
# On fige donc le paquet AVANT d'ajouter les dépôts (retire "quickshell-git" de
# IgnorePkg dans /etc/pacman.conf si tu veux le laisser se mettre à jour).
if pacman -Qq quickshell-git >/dev/null 2>&1; then
  if grep -Eq '^IgnorePkg.*quickshell-git' /etc/pacman.conf; then
    log "quickshell-git est déjà figé dans /etc/pacman.conf."
  elif grep -q '^IgnorePkg' /etc/pacman.conf; then
    log "Ajout de quickshell-git à IgnorePkg…"
    sudo sed -i '/^IgnorePkg/ s/$/ quickshell-git/' /etc/pacman.conf
  else
    log "Ajout de quickshell-git à IgnorePkg…"
    sudo sed -i 's/^#IgnorePkg.*/IgnorePkg = quickshell-git/' /etc/pacman.conf
  fi
fi

# --- 2. Dépôts CachyOS --------------------------------------------------------
if grep -q '^\[cachyos' /etc/pacman.conf; then
  log "Les dépôts CachyOS sont déjà configurés."
else
  log "Téléchargement du script officiel cachyos-repo…"
  curl -fsSL https://mirror.cachyos.org/cachyos-repo.tar.xz -o "$tmp/cachyos-repo.tar.xz"
  tar -xf "$tmp/cachyos-repo.tar.xz" -C "$tmp"
  script="$(find "$tmp" -name cachyos-repo.sh | head -n1)"
  [ -n "$script" ] || die "cachyos-repo.sh introuvable dans l'archive."

  log "Lancement de cachyos-repo.sh (il peut poser des questions)…"
  ( cd "$(dirname "$script")" && sudo bash ./cachyos-repo.sh )
fi

# --- 3. Noyau CachyOS ---------------------------------------------------------
log "Installation de $KERNEL_PKG et de ses en-têtes…"
sudo pacman -S --needed "$KERNEL_PKG" "${KERNEL_PKG}-headers"

[ -f "$KERNEL_IMG" ] || die "$KERNEL_IMG introuvable après l'installation : le noyau n'est pas en place."

# --- 4. GRUB : le noyau CachyOS en premier, "linux" en secours ---------------
# GRUB_TOP_LEVEL place ce noyau en tête du menu ; le noyau "linux" reste dans
# "Advanced options for Arch Linux".
log "Configuration de GRUB…"
if grep -q '^GRUB_TOP_LEVEL=' /etc/default/grub; then
  sudo sed -i "s|^GRUB_TOP_LEVEL=.*|GRUB_TOP_LEVEL=\"$KERNEL_IMG\"|" /etc/default/grub
else
  printf 'GRUB_TOP_LEVEL="%s"\n' "$KERNEL_IMG" | sudo tee -a /etc/default/grub >/dev/null
fi
sudo grub-mkconfig -o /boot/grub/grub.cfg

log "Terminé. Redémarre : sudo reboot"
log "Vérification après redémarrage : 'uname -r' doit contenir « cachyos »."
warn "Si le système ne démarre pas : menu GRUB > Advanced options > noyau 'linux' (secours)."