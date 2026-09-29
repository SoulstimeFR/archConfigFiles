#!/usr/bin/env bash
# install.sh : phase 1, à lancer depuis l'ISO Arch (via bootstrap.sh).
#
# Ce qu'il fait :
#   1. choisit et efface le disque cible (avec confirmation explicite)
#   2. crée une partition ESP (FAT32) + une partition Btrfs avec sous-volumes
#   3. installe le système de base avec pacstrap
#   4. génère fstab, copie ce dépôt dans le nouveau système
#   5. lance chroot/10-system.sh dans le nouveau système (phase 2)
#
# UEFI uniquement. Le log complet est écrit dans /root/install.log.
#
# Variables optionnelles pour automatiser (utile pour tester en VM) :
#   DISK=/dev/nvme0n1 NEW_USER=toi NEW_HOST=archbox PASSWORD=... ASSUME_YES=1
#   TIMEZONE, LOCALE, KEYMAP

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG=/root/install.log
exec > >(tee -a "$LOG") 2>&1

# --- Configuration ------------------------------------------------------------
TIMEZONE="${TIMEZONE:-Europe/Paris}"
LOCALE="${LOCALE:-fr_FR.UTF-8}"
KEYMAP="${KEYMAP:-fr}"
NEW_HOST="${NEW_HOST:-}"
NEW_USER="${NEW_USER:-}"
PASSWORD="${PASSWORD:-}"
DISK="${DISK:-}"
ASSUME_YES="${ASSUME_YES:-0}"

ESP_SIZE="1GiB"
BTRFS_OPTS="noatime,compress=zstd:3,discard=async"
SUBVOLUMES=(@ @home @log @pkg @snapshots)

# --- Affichage ----------------------------------------------------------------
log()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'printf "\n\033[1;31m[install] ERREUR ligne %s. Voir %s\033[0m\n" "$LINENO" "$LOG" >&2' ERR

# Les questions passent directement par le terminal (/dev/tty) : elles restent
# visibles même si la sortie est redirigée vers le fichier de log.
say() { printf '%s\n' "$*" >/dev/tty; }

ask() { # ask VARIABLE "Question" ["valeur par défaut"]
  local var="$1" question="$2" default="${3:-}" answer
  [ -n "${!var:-}" ] && return 0
  if [ -n "$default" ]; then
    printf '%s [%s] : ' "$question" "$default" >/dev/tty
  else
    printf '%s : ' "$question" >/dev/tty
  fi
  read -r answer </dev/tty
  printf -v "$var" '%s' "${answer:-$default}"
}

ask_password() {
  [ -n "$PASSWORD" ] && return 0
  local p1 p2
  while true; do
    printf 'Mot de passe pour %s : ' "$NEW_USER" >/dev/tty
    read -rs p1 </dev/tty; printf '\n' >/dev/tty
    printf 'Confirme le mot de passe : ' >/dev/tty
    read -rs p2 </dev/tty; printf '\n' >/dev/tty
    if [ -n "$p1" ] && [ "$p1" = "$p2" ]; then
      PASSWORD="$p1"
      return 0
    fi
    say "Mots de passe vides ou différents, recommence."
  done
}

# Nom d'une partition : /dev/nvme0n1 -> /dev/nvme0n1p1, /dev/sda -> /dev/sda1
part() {
  case "$1" in
    *[0-9]) printf '%sp%s' "$1" "$2" ;;
    *)      printf '%s%s'  "$1" "$2" ;;
  esac
}

# --- 1. Vérifications ---------------------------------------------------------
preflight() {
  [ "$(id -u)" -eq 0 ] || die "À lancer en root."
  [ -f /sys/firmware/efi/fw_platform_size ] \
    || die "Démarrage UEFI requis (ce script n'installe pas en BIOS/legacy)."
  curl -fsS --max-time 10 -o /dev/null https://archlinux.org \
    || die "Pas d'accès à Internet."
  timedatectl set-ntp true || warn "Synchronisation de l'heure impossible."
  sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
}

# --- 2. Choix du disque -------------------------------------------------------
choose_disk() {
  if [ -z "$DISK" ]; then
    local live_disk="" src name
    local -a candidates=()
    if src="$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null)" && [ -n "$src" ]; then
      live_disk="$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1 || true)"
    fi
    while read -r name; do
      [ -n "$live_disk" ] && [ "$name" = "/dev/$live_disk" ] && continue
      candidates+=("$name")
    done < <(lsblk -dpno NAME -e 7,11)   # exclut loop et lecteurs optiques

    [ "${#candidates[@]}" -gt 0 ] || die "Aucun disque candidat trouvé."
    say ""
    say "Disques disponibles (la clé USB de l'ISO est exclue) :"
    lsblk -dpo NAME,SIZE,MODEL,TRAN "${candidates[@]}" >/dev/tty
    say ""
    local default=""
    [ "${#candidates[@]}" -eq 1 ] && default="${candidates[0]}"
    ask DISK "Disque à EFFACER COMPLÈTEMENT" "$default"
  fi

  [ -b "$DISK" ] || die "'$DISK' n'est pas un disque valide."

  if [ "$ASSUME_YES" != "1" ]; then
    say ""
    lsblk "$DISK" >/dev/tty
    say ""
    printf 'TOUT le contenu de %s sera détruit. Retape le chemin du disque pour confirmer : ' "$DISK" >/dev/tty
    local confirm
    read -r confirm </dev/tty
    [ "$confirm" = "$DISK" ] || die "Confirmation incorrecte, abandon (rien n'a été modifié)."
  fi
}

# --- 3. Informations sur le futur système ------------------------------------
gather_info() {
  ask NEW_HOST "Nom de la machine (hostname)" "archbox"
  ask NEW_USER "Nom d'utilisateur"
  [ -n "$NEW_USER" ] || die "Nom d'utilisateur obligatoire."
  case "$NEW_USER" in
    *[!a-z0-9_-]*|[0-9-]*) die "Nom d'utilisateur invalide (minuscules, chiffres, _ et - ; pas de chiffre en premier)." ;;
  esac
  ask_password
}

# --- 4. Partitionnement et formatage -----------------------------------------
partition_and_format() {
  log "Partitionnement de $DISK…"
  umount -R /mnt 2>/dev/null || true
  swapoff -a 2>/dev/null || true

  wipefs -af "$DISK"
  sgdisk --zap-all "$DISK"
  sgdisk -n "1:0:+${ESP_SIZE}" -t 1:ef00 -c 1:ESP "$DISK"
  sgdisk -n "2:0:0"            -t 2:8300 -c 2:archroot "$DISK"
  partprobe "$DISK"
  udevadm settle

  ESP="$(part "$DISK" 1)"
  ROOT="$(part "$DISK" 2)"

  log "Formatage : $ESP (FAT32) et $ROOT (Btrfs)…"
  mkfs.fat -F32 -n ESP "$ESP"
  mkfs.btrfs -f -L archroot "$ROOT"

  log "Création des sous-volumes Btrfs…"
  mount "$ROOT" /mnt
  local sv
  for sv in "${SUBVOLUMES[@]}"; do
    btrfs subvolume create "/mnt/$sv"
  done
  umount /mnt

  log "Montage…"
  mount -o "${BTRFS_OPTS},subvol=@" "$ROOT" /mnt
  mkdir -p /mnt/efi /mnt/home /mnt/var/log /mnt/var/cache/pacman/pkg /mnt/.snapshots
  mount -o "${BTRFS_OPTS},subvol=@home"      "$ROOT" /mnt/home
  mount -o "${BTRFS_OPTS},subvol=@log"       "$ROOT" /mnt/var/log
  mount -o "${BTRFS_OPTS},subvol=@pkg"       "$ROOT" /mnt/var/cache/pacman/pkg
  mount -o "${BTRFS_OPTS},subvol=@snapshots" "$ROOT" /mnt/.snapshots
  mount -o fmask=0077,dmask=0077 "$ESP" /mnt/efi
}

# --- 5. Système de base -------------------------------------------------------
install_base() {
  log "Mise à jour du trousseau de clés de l'ISO…"
  pacman -Sy --noconfirm archlinux-keyring

  local -a ucode=()
  if grep -q GenuineIntel /proc/cpuinfo; then
    ucode=(intel-ucode)
  elif grep -q AuthenticAMD /proc/cpuinfo; then
    ucode=(amd-ucode)
  fi

  local -a pkgs=(
    base linux linux-headers linux-firmware sof-firmware "${ucode[@]}"
    mkinitcpio iptables            # les nommer évite les questions "quel fournisseur ?"
    base-devel btrfs-progs
    grub efibootmgr grub-btrfs inotify-tools
    snapper snap-pac
    networkmanager sudo git nano zram-generator
  )

  log "Installation du système de base (pacstrap)… ça peut prendre un moment."
  pacstrap -K /mnt "${pkgs[@]}" --noconfirm

  log "Génération de fstab…"
  genfstab -U /mnt > /mnt/etc/fstab
  # Retire subvolid=... : il rendrait fstab dépendant d'un numéro de sous-volume
  # précis et casserait la restauration d'un snapshot.
  sed -i -E 's/subvolid=[0-9]+,?//; s/,,/,/; s/,([[:space:]])/\1/' /mnt/etc/fstab

  log "Copie du dépôt dans le nouveau système…"
  mkdir -p /mnt/root/arch-setup
  cp -a "$SCRIPT_DIR/." /mnt/root/arch-setup/
}

# --- 6. Phase 2 : configuration dans le chroot -------------------------------
configure_in_chroot() {
  local script=/root/arch-setup/chroot/10-system.sh
  [ -f "/mnt$script" ] || die "$script introuvable dans le dépôt."

  log "Configuration du système (chroot)…"
  arch-chroot /mnt env \
    NEW_USER="$NEW_USER" NEW_HOST="$NEW_HOST" \
    TIMEZONE="$TIMEZONE" LOCALE="$LOCALE" KEYMAP="$KEYMAP" \
    bash "$script"

  log "Définition du mot de passe de $NEW_USER…"
  printf '%s:%s\n' "$NEW_USER" "$PASSWORD" | arch-chroot /mnt chpasswd

  # Copie du dépôt dans le home de l'utilisateur : les scripts firstboot/ doivent
  # être lancés en utilisateur normal, qui n'a pas accès à /root.
  log "Copie du dépôt dans /home/$NEW_USER/arch-setup…"
  cp -a /mnt/root/arch-setup "/mnt/home/$NEW_USER/arch-setup"
  arch-chroot /mnt chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/arch-setup"
}

# --- 6b. Wi-Fi : reprend la connexion utilisée pendant l'installation --------
# Le Wi-Fi configuré avec iwctl sur l'ISO n'est pas conservé : sans cette étape,
# le système installé démarre sans connaître le réseau. On crée donc un profil
# NetworkManager pour le Wi-Fi actuellement utilisé (le mot de passe est demandé).
copy_wifi_profile() {
  [ "$ASSUME_YES" = "1" ] && return 0

  local iface ssid pass uuid file
  iface="$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')"
  [ -n "$iface" ] || return 0
  ssid="$(iw dev "$iface" link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p')"
  [ -n "$ssid" ] || return 0   # connecté par câble : rien à copier

  say ""
  say "Le Wi-Fi « $ssid » est utilisé pendant l'installation."
  printf 'Mot de passe de ce Wi-Fi (vide = ne pas le copier) : ' >/dev/tty
  read -rs pass </dev/tty
  printf '\n' >/dev/tty
  [ -n "$pass" ] || return 0

  uuid="$(cat /proc/sys/kernel/random/uuid)"
  file="/mnt/etc/NetworkManager/system-connections/${ssid//\//_}.nmconnection"
  mkdir -p "$(dirname "$file")"
  (
    umask 077
    cat > "$file" <<EOF
[connection]
id=$ssid
uuid=$uuid
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$pass

[ipv4]
method=auto

[ipv6]
method=auto
EOF
  )
  chmod 600 "$file"
  log "Connexion Wi-Fi « $ssid » copiée dans le nouveau système."
}

# --- 7. Fin -------------------------------------------------------------------
finish() {
  cp "$LOG" /mnt/root/install.log 2>/dev/null || true
  sync
  umount -R /mnt
  log "Installation terminée."
  say ""
  say "  -> Retire la clé USB, puis redémarre avec : reboot"
  say "  -> Le journal de l'installation est dans /root/install.log du nouveau système."
  say ""
}

main() {
  preflight
  choose_disk
  gather_info
  partition_and_format
  install_base
  configure_in_chroot
  copy_wifi_profile
  finish
}

main "$@"