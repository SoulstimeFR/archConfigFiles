#!/usr/bin/env bash
# bootstrap.sh : point d'entrée à lancer depuis l'ISO Arch (environnement live).
#
# Il ne fait que préparer le terrain : vérifications, réseau, git, clonage du
# dépôt, puis il passe la main à install.sh.
#
# Usage depuis l'ISO :
#   curl -fsSL https://raw.githubusercontent.com/TON-PSEUDO/arch-setup/main/bootstrap.sh | bash
#
# Variables optionnelles (à placer devant "bash") :
#   REPO_URL, REPO_BRANCH, TARGET_DIR, KEYMAP, FORCE
#   ex : curl -fsSL <url> | KEYMAP=fr bash

set -euo pipefail

# --- Configuration ------------------------------------------------------------
REPO_URL="${REPO_URL:-https://github.com/SoulstimeFR/archConfigFiles.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
TARGET_DIR="${TARGET_DIR:-/root/arch-setup}"
KEYMAP="${KEYMAP:-fr}"      # ex : fr, us, de-latin1 (vide = ne rien changer)
FORCE="${FORCE:-0}"       # 1 = autorise l'exécution hors de l'ISO live

# --- Affichage ----------------------------------------------------------------
log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Vérifications préalables -------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "À lancer en root (c'est le cas par défaut sur l'ISO Arch)."

if [ ! -d /run/archiso ] && [ "$FORCE" != "1" ]; then
  die "Ce script est prévu pour l'ISO Arch (live). Relance avec FORCE=1 pour l'exécuter ailleurs."
fi

case "$REPO_URL" in
  *TON-PSEUDO*) die "Édite REPO_URL dans ce script, ou passe REPO_URL=... devant bash." ;;
esac

# --- Clavier (optionnel) ------------------------------------------------------
if [ -n "$KEYMAP" ]; then
  log "Disposition du clavier : $KEYMAP"
  loadkeys "$KEYMAP" || warn "Impossible de charger la disposition '$KEYMAP', on continue."
fi

# --- Réseau -------------------------------------------------------------------
log "Vérification de la connexion Internet…"
if ! curl -fsS --max-time 10 -o /dev/null https://archlinux.org; then
  die "Pas d'accès à Internet.
  - Câble : vérifie le branchement.
  - Wi-Fi : lance 'iwctl', puis : station wlan0 connect \"NOM_DU_RESEAU\"
    (utilise 'station list' pour voir le nom réel de ta carte Wi-Fi).
  Puis relance ce script."
fi

# Horloge à l'heure (évite des erreurs de certificats et de signatures)
timedatectl set-ntp true || warn "Synchronisation de l'heure impossible, on continue."

# --- Git ----------------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  log "Installation de git…"
  pacman -Sy --noconfirm --needed archlinux-keyring git
fi

# --- Récupération du dépôt ----------------------------------------------------
if [ -d "$TARGET_DIR/.git" ]; then
  log "Dépôt déjà présent, mise à jour…"
  git -C "$TARGET_DIR" fetch --depth 1 origin "$REPO_BRANCH"
  git -C "$TARGET_DIR" reset --hard "origin/$REPO_BRANCH"
else
  log "Clonage de $REPO_URL (branche $REPO_BRANCH)…"
  git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TARGET_DIR"
fi

[ -f "$TARGET_DIR/install.sh" ] || die "install.sh introuvable dans $TARGET_DIR."
chmod +x "$TARGET_DIR/install.sh"

# --- Passage à install.sh -----------------------------------------------------
# Quand ce script est lancé via "curl | bash", son entrée standard est le script
# lui-même. On reconnecte donc install.sh au clavier (/dev/tty) pour qu'il puisse
# poser des questions à l'utilisateur.
log "Lancement de install.sh"
cd "$TARGET_DIR"
exec bash "$TARGET_DIR/install.sh" "$@" </dev/tty