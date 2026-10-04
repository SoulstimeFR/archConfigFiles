#!/usr/bin/env bash
# firstboot/40-drivers.sh : détecte le matériel et installe les pilotes adaptés.
# À lancer en UTILISATEUR NORMAL, APRÈS 30-cachyos-kernel.sh (il fournit "chwd").
#
# 1. Pilotes libres de base (Mesa, Vulkan, accélération vidéo) selon le GPU détecté.
# 2. "chwd -a" (CachyOS Hardware Detection) : détecte le matériel et installe le bon
#    profil de pilotes, y compris NVIDIA et les portables hybrides (PRIME).
# 3. Portable : gestion de l'énergie (et thermald sur Intel). Bluetooth : activation.
#
# Ignoré dans une machine virtuelle. Les étapes sont tolérantes : un échec est signalé
# mais n'interrompt pas les suivantes.
#
# Sécurité : snap-pac prend un snapshot Snapper avant et après chaque transaction
# pacman. En cas d'écran noir au redémarrage : menu GRUB > snapshots, ou
# Advanced options > noyau "linux".

set -euo pipefail

log()  { printf '\033[1;34m[drivers]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[drivers]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[drivers]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Ne lance pas ce script en root : utilise ton utilisateur normal."

# --- Machine virtuelle : rien à faire ----------------------------------------
virt="$(systemd-detect-virt 2>/dev/null || true)"
if [ -n "$virt" ] && [ "$virt" != "none" ]; then
  warn "Machine virtuelle détectée ($virt) : installation des pilotes matériels ignorée."
  exit 0
fi

curl -fsS --max-time 10 -o /dev/null https://archlinux.org || die "Pas d'accès à Internet."

sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE_PID=$!
trap 'kill "$KEEPALIVE_PID" 2>/dev/null || true' EXIT

# --- lspci (paquet pciutils) : absent d'une installation Arch minimale -------------
sudo pacman -S --needed --noconfirm pciutils || die "Impossible d'installer pciutils."

# --- Outils nécessaires à la détection ------------------------------------------
# pciutils fournit lspci : sans lui, la détection ne verrait aucun GPU en silence.
if ! command -v lspci >/dev/null 2>&1; then
  log "Installation de pciutils (lspci)…"
  sudo pacman -S --needed --noconfirm pciutils
fi
command -v lspci >/dev/null 2>&1 || die "lspci introuvable : impossible de détecter le matériel."

# chwd vient du dépôt CachyOS et n'est PAS installé par cachyos-repo.sh.
if ! command -v chwd >/dev/null 2>&1 && grep -q '^\[cachyos' /etc/pacman.conf; then
  log "Installation de chwd (dépôt CachyOS)…"
  sudo pacman -S --needed --noconfirm chwd \
    || warn "Installation de chwd impossible (dépôts CachyOS en cours de synchronisation ?)."
fi

# --- Détection des cartes graphiques ------------------------------------------
gpus="$(lspci -nn | grep -Ei 'vga|3d|display' || true)"
log "Cartes graphiques détectées :"
printf '%s\n' "$gpus"
[ -n "$gpus" ] || warn "Aucune carte graphique détectée par lspci : détection impossible."
has() { printf '%s' "$gpus" | grep -qiE "$1"; }

# --- 1. Pilotes libres de base (Mesa, Vulkan, vidéo) ---------------------------
pkgs=(mesa vulkan-icd-loader lib32-mesa lib32-vulkan-icd-loader)
if has 'intel'; then
  pkgs+=(vulkan-intel lib32-vulkan-intel intel-media-driver)
fi
if has 'amd|advanced micro devices|\[ati\]'; then
  pkgs+=(vulkan-radeon lib32-vulkan-radeon)
fi

log "Installation des pilotes libres : ${pkgs[*]}"
sudo pacman -S --needed --noconfirm "${pkgs[@]}" \
  || warn "Installation partielle (miroirs ?). Réessaie plus tard : sudo pacman -Syu"

# --- 2. Pilotes propriétaires / hybrides avec chwd -----------------------------
chwd_ok=0
# chwd n'est pas installé d'office avec les dépôts ni avec le noyau CachyOS.
if ! command -v chwd >/dev/null 2>&1 && pacman -Si chwd >/dev/null 2>&1; then
  log "Installation de chwd (dépôt CachyOS)…"
  sudo pacman -S --needed --noconfirm chwd || warn "Installation de chwd impossible."
fi
if command -v chwd >/dev/null 2>&1; then
  log "Configuration automatique du matériel avec chwd (peut poser des questions)…"
  if sudo chwd -a; then
    chwd_ok=1
  else
    warn "chwd a échoué. Cause fréquente : dépôts CachyOS en cours de synchronisation"
    warn "(versions de paquets NVIDIA incohérentes). Réessaie plus tard :"
    warn "  sudo pacman -Syyu && sudo chwd -a"
  fi
elif has 'nvidia'; then
  warn "GPU NVIDIA détecté mais chwd est absent : lance d'abord firstboot/30-cachyos-kernel.sh."
fi

if [ "$chwd_ok" = "1" ]; then
  log "Reconstruction de l'initramfs et du menu GRUB…"
  sudo mkinitcpio -P
  sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# Vérification : chwd peut se terminer sans erreur sans rien installer (aucun profil
# ne correspond au matériel, par exemple à cause du type de châssis du portable).
if has 'nvidia' && ! pacman -Q nvidia-utils >/dev/null 2>&1; then
  warn "GPU NVIDIA détecté, mais aucun pilote NVIDIA n'est installé (nvidia-utils absent)."
  warn "Profils que chwd propose pour ce matériel :"
  { sudo chwd --list 2>&1 || true; } | sed 's/^/    /' >&2
  warn "Type de châssis (DMI) : $(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo inconnu)"
  warn "Copie ces informations pour choisir le bon profil à la main."
fi

# --- 3. Portable : énergie et température --------------------------------------
if compgen -G '/sys/class/power_supply/BAT*' >/dev/null; then
  log "Portable détecté : gestion de l'énergie…"
  sudo pacman -S --needed --noconfirm power-profiles-daemon brightnessctl \
    || warn "Installation de power-profiles-daemon impossible."
  sudo systemctl enable power-profiles-daemon.service \
    || warn "Activation de power-profiles-daemon impossible."

  if grep -q GenuineIntel /proc/cpuinfo; then
    sudo pacman -S --needed --noconfirm thermald || warn "Installation de thermald impossible."
    sudo systemctl enable thermald.service || warn "Activation de thermald impossible."
  fi
fi

# --- 4. Bluetooth ---------------------------------------------------------------
if compgen -G '/sys/class/bluetooth/hci*' >/dev/null; then
  if pacman -Q bluez >/dev/null 2>&1; then
    log "Bluetooth détecté : activation du service…"
    sudo systemctl enable --now bluetooth.service || warn "Activation de bluetooth impossible."
  else
    warn "Contrôleur Bluetooth détecté mais le paquet bluez est absent."
  fi
fi

log "Terminé. Redémarre : sudo reboot"
if has 'nvidia'; then
  log "Après redémarrage : 'nvidia-smi' doit lister ta carte NVIDIA."
  log "Portable hybride : lance une application sur la NVIDIA avec 'prime-run <commande>'."
fi