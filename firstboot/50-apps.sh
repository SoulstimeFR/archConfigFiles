#!/usr/bin/env bash

# firstboot/50-apps.sh : installe automatiquement les applications quotidiennes.
# À lancer en UTILISATEUR NORMAL, après 40-drivers.sh.
#
# Méthodes utilisées :
# - pacman : paquets officiels Arch/CachyOS
# - paru   : paquets AUR
# - npm    : Mermaid CLI
#
# Certaines applications peuvent être absentes ou changer de nom dans l'AUR.
# Le script continue malgré les erreurs et affiche un résumé à la fin.

set -uo pipefail

log()  { printf '\033[1;34m[apps]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[apps]\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m[apps]\033[0m %s\n' "$*"; }

if [ "$(id -u)" -eq 0 ]; then
  printf '\033[1;31m[apps]\033[0m Ne lance pas ce script en root : utilise ton utilisateur normal.\n' >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

declare -a INSTALLED=()
declare -a FAILED=()
declare -a SKIPPED=()

record_success() {
  INSTALLED+=("$1")
}

record_failure() {
  FAILED+=("$1")
}

record_skipped() {
  SKIPPED+=("$1")
}

install_official() {
  local name="$1"
  shift
  local -a packages=("$@")

  log "Installation officielle : $name"
  if sudo pacman -S --needed --noconfirm "${packages[@]}"; then
    record_success "$name"
  else
    warn "Échec de l'installation officielle : $name"
    record_failure "$name"
  fi
}

install_aur() {
  local name="$1"
  shift
  local -a packages=("$@")

  if ! command -v paru >/dev/null 2>&1; then
    warn "paru est absent : impossible d'installer $name."
    record_failure "$name"
    return 1
  fi

  log "Installation AUR : $name"
  if paru -S --needed --noconfirm "${packages[@]}"; then
    record_success "$name"
  else
    warn "Échec de l'installation AUR : $name"
    record_failure "$name"
  fi
}

install_npm() {
  local name="$1"
  shift
  local -a packages=("$@")

  log "Installation npm : $name"

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm est absent : installation de nodejs et npm…"
    if ! sudo pacman -S --needed --noconfirm nodejs npm; then
      warn "Impossible d'installer nodejs/npm."
      record_failure "$name"
      return 1
    fi
  fi

  if npm install --global "${packages[@]}"; then
    record_success "$name"
  else
    warn "Échec de l'installation npm : $name"
    record_failure "$name"
  fi
}

log "Mise à jour du système avant l'installation des applications…"
if ! sudo pacman -Syu --noconfirm; then
  warn "La mise à jour complète a échoué. Les installations vont quand même continuer."
fi

# -------------------------------------------------------------------------------
# Paquets officiels Arch/CachyOS
# -------------------------------------------------------------------------------

install_official "Steam" steam

install_official "PHP" php php-gd php-intl php-sqlite php-pgsql php-apache

install_official "Python" python python-pip python-virtualenv

install_official "Git" git

install_official "Docker Engine" docker docker-compose docker-buildx

install_official "Java" jdk-openjdk

install_official "Kotlin" kotlin

install_official "Composer" composer

install_official "DBeaver" dbeaver

# MariaDB fournit un serveur compatible avec l'écosystème MySQL.
install_official "MariaDB / serveur compatible MySQL" mariadb

install_official "LibreOffice" libreoffice-fresh libreoffice-fresh-fr

install_official "Dépendances ani-cli" mpv fzf yt-dlp
install_aur "ani-cli" ani-cli

# Symfony CLI est généralement disponible dans l'AUR plutôt que dans les dépôts
# officiels selon l'état courant des dépôts.
install_aur "Symfony CLI" symfony-cli

# -------------------------------------------------------------------------------
# Paquets AUR
# -------------------------------------------------------------------------------

install_aur "Opera" opera

install_aur "JetBrains Toolbox" jetbrains-toolbox

install_aur "Obsidian" obsidian

install_aur "Spotify" spotify

install_aur "Discord" discord

install_aur "GitHub Desktop" github-desktop-bin

install_aur "VSCodium" vscodium-bin

install_aur "Bitwarden Desktop" bitwarden

# -------------------------------------------------------------------------------
# Docker
# -------------------------------------------------------------------------------

log "Configuration de Docker Engine…"

if pacman -Q docker >/dev/null 2>&1; then
  if sudo systemctl enable --now docker.service; then
    ok "Docker Engine activé."
  else
    warn "Docker Engine installé mais impossible à démarrer."
    record_failure "Activation de Docker Engine"
  fi

  if sudo usermod -aG docker "$USER"; then
    ok "Utilisateur $USER ajouté au groupe docker."
    warn "Déconnecte-toi puis reconnecte-toi pour appliquer le groupe docker."
  else
    warn "Impossible d'ajouter $USER au groupe docker."
    record_failure "Groupe docker"
  fi
fi

# Docker Desktop n'est pas installé en parallèle de Docker Engine.
# Cela évite d'introduire des conflits ou deux moteurs concurrents.
warn "Docker Desktop n'est pas installé automatiquement : Docker Engine est utilisé à la place."
record_skipped "Docker Desktop"

# -------------------------------------------------------------------------------
# Mermaid CLI
# -------------------------------------------------------------------------------

install_official "Mermaid CLI" mermaid-cli

# -------------------------------------------------------------------------------
# Claude Desktop
# -------------------------------------------------------------------------------

# Aucun paquet Arch fiable n'est imposé ici.
# Une installation manuelle spécifique pourra être ajoutée plus tard.
warn "Claude Desktop n'est pas installé automatiquement : paquet Linux/Arch non défini."
record_skipped "Claude Desktop"

# -------------------------------------------------------------------------------
# Initialisation facultative de MariaDB
# -------------------------------------------------------------------------------

if pacman -Q mariadb >/dev/null 2>&1; then
  log "MariaDB est installé."
  warn "Le service MariaDB n'est pas initialisé ni démarré automatiquement."
  warn "Pour l'initialiser plus tard : sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql"
  warn "Puis : sudo systemctl enable --now mariadb.service"
fi

# -------------------------------------------------------------------------------
# Vérifications finales
# -------------------------------------------------------------------------------

printf '\n'
log "Installation des applications terminée."

printf '\n\033[1;32mInstallés ou déjà présents :\033[0m\n'
if [ "${#INSTALLED[@]}" -eq 0 ]; then
  printf '  Aucun\n'
else
  printf '  - %s\n' "${INSTALLED[@]}"
fi

printf '\n\033[1;33mIgnorés volontairement :\033[0m\n'
if [ "${#SKIPPED[@]}" -eq 0 ]; then
  printf '  Aucun\n'
else
  printf '  - %s\n' "${SKIPPED[@]}"
fi

printf '\n\033[1;31mÉchecs :\033[0m\n'
if [ "${#FAILED[@]}" -eq 0 ]; then
  printf '  Aucun\n'
else
  printf '  - %s\n' "${FAILED[@]}"
fi

printf '\n'
warn "Si Docker a été installé, déconnecte-toi puis reconnecte-toi."
warn "Un redémarrage est recommandé après l'installation des applications."