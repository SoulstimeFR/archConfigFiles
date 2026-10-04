#!/usr/bin/env bash
# firstboot/50-apps.sh : checklist interactive d'applications à installer.
# À lancer en UTILISATEUR NORMAL : les changements système passent par sudo.
#
# Notes de mapping (conservatrices) :
# - Officiel pacman : paquets Arch standards (ex: docker, libreoffice-fresh, vscodium).
# - AUR via paru : Opera, Spotify, JetBrains Toolbox, GitHub Desktop…
# - npm : Mermaid CLI (@mermaid-js/mermaid-cli), avec nodejs/npm installés au besoin.
# - Éléments « expérimental/incertain » : Claude Desktop et Docker Desktop (AUR non officiel,
#   disponibilité variable). Le script vérifie l'existence du paquet avant installation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m[apps]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[apps]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[apps]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Ne lance pas ce script en root : utilise ton utilisateur normal."
[ -t 0 ] || die "Terminal interactif requis (TTY)."

curl -fsS --max-time 10 -o /dev/null https://archlinux.org || die "Pas d'accès à Internet."

sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE_PID=$!
trap 'kill "$KEEPALIVE_PID" 2>/dev/null || true' EXIT

declare -a APP_IDS=(
  opera steam jetbrains_toolbox obsidian php python spotify discord git github_desktop
  claude_desktop docker_engine docker_desktop java kotlin composer symfony_cli
  mermaid_cli dbeaver mariadb libreoffice vscodium ani_cli bitwarden
)

declare -A APP_LABEL APP_METHOD APP_PACMAN APP_AUR APP_NPM APP_NOTE

# Officiel pacman
APP_LABEL[steam]="Steam"
APP_METHOD[steam]="pacman"
APP_PACMAN[steam]="steam"

APP_LABEL[obsidian]="Obsidian"
APP_METHOD[obsidian]="pacman"
APP_PACMAN[obsidian]="obsidian"

APP_LABEL[php]="PHP"
APP_METHOD[php]="pacman"
APP_PACMAN[php]="php"

APP_LABEL[python]="Python"
APP_METHOD[python]="pacman"
APP_PACMAN[python]="python"

APP_LABEL[discord]="Discord"
APP_METHOD[discord]="pacman"
APP_PACMAN[discord]="discord"

APP_LABEL[git]="Git"
APP_METHOD[git]="pacman"
APP_PACMAN[git]="git"

APP_LABEL[docker_engine]="Docker Engine"
APP_METHOD[docker_engine]="pacman"
APP_PACMAN[docker_engine]="docker"
APP_NOTE[docker_engine]="Active le service + ajoute l'utilisateur au groupe docker (reconnexion requise)."

APP_LABEL[java]="Java (OpenJDK)"
APP_METHOD[java]="pacman"
APP_PACMAN[java]="jdk-openjdk"

APP_LABEL[kotlin]="Kotlin"
APP_METHOD[kotlin]="pacman"
APP_PACMAN[kotlin]="kotlin"

APP_LABEL[composer]="Composer"
APP_METHOD[composer]="pacman"
APP_PACMAN[composer]="composer"

APP_LABEL[dbeaver]="DBeaver"
APP_METHOD[dbeaver]="pacman"
APP_PACMAN[dbeaver]="dbeaver"

APP_LABEL[mariadb]="MariaDB (serveur MySQL compatible)"
APP_METHOD[mariadb]="pacman"
APP_PACMAN[mariadb]="mariadb"

APP_LABEL[libreoffice]="LibreOffice"
APP_METHOD[libreoffice]="pacman"
APP_PACMAN[libreoffice]="libreoffice-fresh"

APP_LABEL[vscodium]="VSCodium"
APP_METHOD[vscodium]="pacman"
APP_PACMAN[vscodium]="vscodium"

APP_LABEL[bitwarden]="Bitwarden Desktop"
APP_METHOD[bitwarden]="pacman"
APP_PACMAN[bitwarden]="bitwarden"

# AUR (paru)
APP_LABEL[opera]="Opera"
APP_METHOD[opera]="aur"
APP_AUR[opera]="opera"

APP_LABEL[jetbrains_toolbox]="JetBrains Toolbox"
APP_METHOD[jetbrains_toolbox]="aur"
APP_AUR[jetbrains_toolbox]="jetbrains-toolbox"

APP_LABEL[spotify]="Spotify"
APP_METHOD[spotify]="aur"
APP_AUR[spotify]="spotify"

APP_LABEL[github_desktop]="GitHub Desktop"
APP_METHOD[github_desktop]="aur"
APP_AUR[github_desktop]="github-desktop-bin"
APP_NOTE[github_desktop]="Paquet AUR non officiel (binaire)."

APP_LABEL[symfony_cli]="Symfony CLI"
APP_METHOD[symfony_cli]="aur"
APP_AUR[symfony_cli]="symfony-cli-bin"

APP_LABEL[ani_cli]="ani-cli"
APP_METHOD[ani_cli]="aur"
APP_AUR[ani_cli]="ani-cli"

# npm
APP_LABEL[mermaid_cli]="Mermaid CLI"
APP_METHOD[mermaid_cli]="npm"
APP_NPM[mermaid_cli]="@mermaid-js/mermaid-cli"
APP_NOTE[mermaid_cli]="Nécessite nodejs + npm (installés automatiquement si sélectionné)."

# Expérimental / disponibilité variable
APP_LABEL[claude_desktop]="Claude Desktop"
APP_METHOD[claude_desktop]="experimental_claude"
APP_NOTE[claude_desktop]="Expérimental : paquet AUR non officiel et potentiellement indisponible."

APP_LABEL[docker_desktop]="Docker Desktop"
APP_METHOD[docker_desktop]="experimental_docker_desktop"
APP_NOTE[docker_desktop]="Expérimental : AUR, peut entrer en conflit avec Docker Engine."

ensure_dialog_or_fallback() {
  if command -v dialog >/dev/null 2>&1; then
    return 0
  fi

  warn "'dialog' est absent. Tentative d'installation via pacman…"
  if sudo pacman -S --needed --noconfirm dialog; then
    return 0
  fi

  warn "Installation de 'dialog' impossible. Bascule sur un menu texte simplifié."
  return 1
}

choose_with_dialog() {
  local tmp
  local -a options=()
  tmp="$(mktemp)"

  for id in "${APP_IDS[@]}"; do
    local note="${APP_NOTE[$id]:-}"
    local method="${APP_METHOD[$id]}"
    local desc="${APP_LABEL[$id]} [$method]"
    if [ -n "$note" ]; then
      desc+=" - $note"
    fi
    options+=("$id" "$desc" off)
  done

  dialog --clear \
    --backtitle "archConfigFiles • firstboot/50-apps.sh" \
    --title "Sélection des applications" \
    --checklist "Sélectionne les applications à installer (ESPACE = cocher, ENTRÉE = valider)." \
    24 120 16 \
    "${options[@]}" 2>"$tmp" || {
      rm -f "$tmp"
      die "Sélection annulée."
    }

  tr -d '"' <"$tmp" | tr '\n' ' '
  rm -f "$tmp"
}

choose_with_fallback() {
  local i=1
  local -a index_to_id=()

  echo
  echo "Checklist (fallback texte)"
  echo "--------------------------"
  for id in "${APP_IDS[@]}"; do
    printf "%2d) %s [%s]" "$i" "${APP_LABEL[$id]}" "${APP_METHOD[$id]}"
    if [ -n "${APP_NOTE[$id]:-}" ]; then
      printf " — %s" "${APP_NOTE[$id]}"
    fi
    printf "\n"
    index_to_id[$i]="$id"
    i=$((i + 1))
  done
  echo
  echo "Entre les numéros à installer (ex: 1 4 7), ou laisse vide pour annuler."

  local input token
  read -r -p "> " input
  [ -n "${input// /}" ] || die "Aucune application sélectionnée."

  local -a selected=()
  for token in $input; do
    if [[ "$token" =~ ^[0-9]+$ ]] && [ "$token" -ge 1 ] && [ "$token" -lt "$i" ]; then
      selected+=("${index_to_id[$token]}")
    else
      warn "Entrée ignorée (invalide) : $token"
    fi
  done

  [ "${#selected[@]}" -gt 0 ] || die "Aucune sélection valide."
  printf '%s ' "${selected[@]}"
}

ensure_paru() {
  if command -v paru >/dev/null 2>&1 && paru --version >/dev/null 2>&1; then
    return 0
  fi

  warn "paru est requis pour les paquets AUR."
  if [ -x "$SCRIPT_DIR/10-paru.sh" ]; then
    bash "$SCRIPT_DIR/10-paru.sh"
  elif [ -f "$SCRIPT_DIR/10-paru.sh" ]; then
    bash "$SCRIPT_DIR/10-paru.sh"
  else
    return 1
  fi

  command -v paru >/dev/null 2>&1 && paru --version >/dev/null 2>&1
}

ensure_node_npm() {
  command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1 && return 0
  log "Installation de nodejs + npm (requis pour Mermaid CLI)…"
  sudo pacman -S --needed --noconfirm nodejs npm
}

install_pacman_app() {
  local id="$1"
  local -a pkgs=()
  read -r -a pkgs <<<"${APP_PACMAN[$id]}"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

install_aur_app() {
  local id="$1"
  local pkg="${APP_AUR[$id]}"

  ensure_paru || return 1
  paru -Si "$pkg" >/dev/null 2>&1 || {
    warn "Paquet AUR introuvable : $pkg"
    return 1
  }
  paru -S --needed --noconfirm "$pkg"
}

install_npm_app() {
  local id="$1"
  local pkg="${APP_NPM[$id]}"

  ensure_node_npm || return 1
  sudo npm install -g "$pkg"
}

install_claude_desktop_experimental() {
  ensure_paru || return 1

  local found=""
  local candidate
  for candidate in claude-desktop-bin claude-desktop; do
    if paru -Si "$candidate" >/dev/null 2>&1; then
      found="$candidate"
      break
    fi
  done

  if [ -z "$found" ]; then
    warn "Claude Desktop non installé : aucun paquet AUR connu (claude-desktop-bin/claude-desktop) n'est disponible."
    return 1
  fi

  warn "Installation expérimentale de Claude Desktop via AUR ($found), non officielle."
  paru -S --needed --noconfirm "$found"
}

install_docker_desktop_experimental() {
  ensure_paru || return 1

  local pkg="docker-desktop"
  paru -Si "$pkg" >/dev/null 2>&1 || {
    warn "Docker Desktop non installé : paquet AUR introuvable ($pkg)."
    return 1
  }

  warn "Docker Desktop est expérimental et peut entrer en conflit avec Docker Engine."
  paru -S --needed --noconfirm "$pkg"
}

post_install_docker_engine() {
  log "Activation du service docker…"
  if ! sudo systemctl enable --now docker.service; then
    warn "Impossible d'activer docker.service automatiquement."
    return 1
  fi

  if id -nG "$USER" | grep -qw docker; then
    log "L'utilisateur $USER est déjà dans le groupe docker."
  else
    log "Ajout de $USER au groupe docker…"
    sudo usermod -aG docker "$USER" || {
      warn "Impossible d'ajouter $USER au groupe docker."
      return 1
    }
    warn "Reconnexion nécessaire (logout/login) pour utiliser Docker sans sudo."
  fi

  return 0
}

resolve_docker_conflict() {
  local -n selected_ref=$1

  if [ -n "${selected_ref[docker_engine]:-}" ] && [ -n "${selected_ref[docker_desktop]:-}" ]; then
    warn "Docker Engine et Docker Desktop ont été sélectionnés ensemble : conflit potentiel."
    echo "Choisis une option :"
    echo "  1) Garder Docker Engine, retirer Docker Desktop"
    echo "  2) Garder Docker Desktop, retirer Docker Engine"
    echo "  3) Garder les deux (non recommandé)"
    local choice
    read -r -p "Ton choix [1/2/3, défaut=1] : " choice
    case "${choice:-1}" in
      2)
        unset 'selected_ref[docker_engine]'
        ;;
      3)
        warn "Tu gardes les deux : le script continue, mais la cohabitation n'est pas recommandée."
        ;;
      *)
        unset 'selected_ref[docker_desktop]'
        ;;
    esac
  fi
}

main() {
  local use_dialog=0 raw_choices
  if ensure_dialog_or_fallback; then
    use_dialog=1
  fi

  if [ "$use_dialog" -eq 1 ]; then
    raw_choices="$(choose_with_dialog)"
  else
    raw_choices="$(choose_with_fallback)"
  fi

  local -a selected_ids=()
  # shellcheck disable=SC2206
  selected_ids=($raw_choices)
  [ "${#selected_ids[@]}" -gt 0 ] || die "Aucune application sélectionnée."

  declare -A selected_map=()
  local id
  for id in "${selected_ids[@]}"; do
    selected_map["$id"]=1
  done

  resolve_docker_conflict selected_map

  local -a successes=() failures=() warnings=()

  for id in "${APP_IDS[@]}"; do
    [ -n "${selected_map[$id]:-}" ] || continue

    log "Installation : ${APP_LABEL[$id]} (${APP_METHOD[$id]})"
    case "${APP_METHOD[$id]}" in
      pacman)
        if install_pacman_app "$id"; then
          successes+=("${APP_LABEL[$id]}")
        else
          failures+=("${APP_LABEL[$id]}")
        fi
        ;;
      aur)
        if install_aur_app "$id"; then
          successes+=("${APP_LABEL[$id]}")
        else
          failures+=("${APP_LABEL[$id]}")
        fi
        ;;
      npm)
        if install_npm_app "$id"; then
          successes+=("${APP_LABEL[$id]}")
        else
          failures+=("${APP_LABEL[$id]}")
        fi
        ;;
      experimental_claude)
        if install_claude_desktop_experimental; then
          successes+=("${APP_LABEL[$id]}")
        else
          failures+=("${APP_LABEL[$id]} (expérimental)")
        fi
        ;;
      experimental_docker_desktop)
        if install_docker_desktop_experimental; then
          successes+=("${APP_LABEL[$id]}")
        else
          failures+=("${APP_LABEL[$id]} (expérimental)")
        fi
        ;;
      *)
        warn "Méthode inconnue pour $id"
        failures+=("${APP_LABEL[$id]} (méthode inconnue)")
        ;;
    esac

    if [ "$id" = "docker_engine" ] && [ -n "${selected_map[docker_engine]:-}" ]; then
      if post_install_docker_engine; then
        warnings+=("Docker Engine : service activé. Reconnexion requise si ajout au groupe docker.")
      else
        warnings+=("Docker Engine : installation OK mais post-configuration incomplète (service/groupe).")
      fi
    fi
  done

  echo
  log "Résumé de l'installation"
  echo "-------------------------"
  echo "Succès (${#successes[@]}):"
  if [ "${#successes[@]}" -eq 0 ]; then
    echo "  - Aucun"
  else
    printf '  - %s\n' "${successes[@]}"
  fi

  echo "Échecs (${#failures[@]}):"
  if [ "${#failures[@]}" -eq 0 ]; then
    echo "  - Aucun"
  else
    printf '  - %s\n' "${failures[@]}"
  fi

  if [ "${#warnings[@]}" -gt 0 ]; then
    echo "Infos / actions manuelles :"
    printf '  - %s\n' "${warnings[@]}"
  fi

  if [ "${#failures[@]}" -gt 0 ]; then
    warn "Certaines applications n'ont pas été installées. Corrige puis relance le script si besoin."
    exit 1
  fi

  log "Terminé."
}

main "$@"
