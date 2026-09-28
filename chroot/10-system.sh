#!/usr/bin/env bash
# chroot/10-system.sh : phase 2, exécuté DANS le nouveau système (arch-chroot)
# par install.sh. Configure : heure, langue, réseau, utilisateur, zram,
# bootloader GRUB, snapshots Btrfs (Snapper + grub-btrfs) et services.
#
# Variables attendues (fournies par install.sh) :
#   NEW_USER, NEW_HOST, TIMEZONE, LOCALE, KEYMAP

set -euo pipefail

: "${NEW_USER:?}" "${NEW_HOST:?}" "${TIMEZONE:?}" "${LOCALE:?}" "${KEYMAP:?}"

log()  { printf '\033[1;34m[chroot]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[chroot]\033[0m %s\n' "$*" >&2; }

# --- Heure, langue, clavier, nom de machine ----------------------------------
log "Heure, langue, clavier, hostname…"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

sed -i "s/^#\(${LOCALE} UTF-8\)/\1/" /etc/locale.gen
sed -i "s/^#\(en_US.UTF-8 UTF-8\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$NEW_HOST" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $NEW_HOST.localdomain $NEW_HOST
EOF

# --- pacman : couleurs, téléchargements parallèles, multilib -----------------
log "Configuration de pacman (multilib inclus, utile pour Steam)…"
sed -i -e 's/^#Color/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

# --- Utilisateur --------------------------------------------------------------
log "Création de l'utilisateur $NEW_USER…"
useradd -m -G wheel -s /bin/bash "$NEW_USER"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
passwd -l root >/dev/null   # compte root verrouillé : on passe par sudo

# --- zram (swap compressé en RAM) ---------------------------------------------
log "Configuration de zram…"
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF

# --- Snapshots Btrfs : Snapper avec un sous-volume @snapshots séparé ---------
log "Configuration de Snapper…"
if mountpoint -q /.snapshots; then umount /.snapshots; fi
rmdir /.snapshots
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount /.snapshots            # remonte @snapshots d'après /etc/fstab
chmod 750 /.snapshots

# Politique de rétention : pas de snapshots horaires, on garde les 10 derniers
# (créés par snap-pac avant/après chaque mise à jour) et 5 "importants".
sed -i \
  -e 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="no"/' \
  -e 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/' \
  -e 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/' \
  /etc/snapper/configs/root

snapper --no-dbus -c root create -d "Installation initiale" \
  || warn "Impossible de créer le snapshot initial."

# --- initramfs : permet de démarrer sur un snapshot en lecture seule ---------
log "Ajout du hook grub-btrfs-overlayfs à l'initramfs…"
if ! grep -q 'grub-btrfs-overlayfs' /etc/mkinitcpio.conf; then
  sed -i 's/^HOOKS=(\(.*\))/HOOKS=(\1 grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
fi
mkinitcpio -P

# --- Bootloader GRUB ----------------------------------------------------------
log "Installation de GRUB (UEFI)…"
# 1) Chemin de secours EFI/BOOT/BOOTX64.EFI : fonctionne partout (dont les VM)
grub-install --target=x86_64-efi --efi-directory=/efi --removable
# 2) Entrée NVRAM "Arch" dans le firmware (peut échouer selon le matériel)
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch \
  || warn "Entrée NVRAM non créée ; le démarrage passera par le chemin de secours."
grub-mkconfig -o /boot/grub/grub.cfg

# --- Services -----------------------------------------------------------------
log "Activation des services…"
systemctl enable NetworkManager.service
systemctl enable systemd-timesyncd.service
systemctl enable fstrim.timer
systemctl enable 'btrfs-scrub@-.timer'
systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfsd.service

log "Phase 2 terminée."