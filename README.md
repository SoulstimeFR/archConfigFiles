# archConfigFiles

Installation automatisée d'un environnement **Arch Linux + CachyOS + Hyprland + Caelestia**.

Ce dépôt permet de réinstaller rapidement un système complet depuis l'ISO officielle d'Arch Linux, avec :

- partitionnement automatique en UEFI ;
- système de fichiers Btrfs avec sous-volumes ;
- snapshots Snapper ;
- noyau CachyOS ;
- détection automatique des pilotes ;
- Hyprland et Caelestia ;
- wallpaper et thème dynamique personnalisés ;
- applications quotidiennes installées automatiquement.

> ⚠️ **Attention : l'installation efface entièrement le disque choisi.**  
> Vérifie soigneusement le disque sélectionné et sauvegarde tes données avant de commencer.

---

## Sommaire

- [Fonctionnement général](#fonctionnement-général)
- [Prérequis](#prérequis)
- [Installation complète](#installation-complète)
- [Scripts disponibles](#scripts-disponibles)
- [Applications installées](#applications-installées)
- [Personnalisation Caelestia](#personnalisation-caelestia)
- [Après l'installation](#après-linstallation)
- [Tests et vérifications](#tests-et-vérifications)
- [Structure du dépôt](#structure-du-dépôt)
- [Dépannage](#dépannage)
- [Tester dans une machine virtuelle](#tester-dans-une-machine-virtuelle)
- [Limites connues](#limites-connues)
- [Sécurité](#sécurité)

---

## Fonctionnement général

L'installation est divisée en plusieurs phases :

```text
ISO Arch Linux
    │
    ├── bootstrap.sh
    │       Clone ou met à jour le dépôt
    │
    ├── install.sh
    │       Efface le disque, partitionne et installe Arch
    │
    ├── chroot/10-system.sh
    │       Configure le système installé
    │
    └── Premier démarrage
            │
            ├── 10-paru.sh
            ├── 20-hyprland-caelestia.sh
            ├── 30-cachyos-kernel.sh
            ├── Redémarrage sur CachyOS
            ├── 40-drivers.sh
            └── 50-apps.sh
```

Les scripts `firstboot/` doivent être lancés avec l'utilisateur normal créé pendant l'installation. Ils ne doivent pas être lancés avec `sudo` ou directement en root.

---

## Prérequis

### Matériel

- ordinateur compatible UEFI ;
- disque interne à effacer ;
- au moins 60 Go d'espace disque recommandé ;
- connexion Internet ;
- carte graphique compatible Linux.

### ISO

Télécharge l'ISO officielle d'Arch Linux, puis démarre dessus en mode **UEFI**.

Dans le BIOS :

- désactive Secure Boot si nécessaire ;
- démarre sur la clé USB Arch ;
- vérifie que tu es bien en mode UEFI.

Vérifie le mode de démarrage :

```bash
test -d /sys/firmware/efi && echo "UEFI OK" || echo "Mode BIOS/legacy"
```

Le script ne fonctionne pas en mode BIOS/legacy.

---

## Installation complète

Depuis l'ISO Arch Linux, connecte-toi à Internet.

### Connexion Ethernet

Aucune configuration particulière n'est généralement nécessaire.

### Connexion Wi-Fi

Lance :

```bash
iwctl
```

Puis, dans `iwctl` :

```text
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "NOM_DU_WIFI"
exit
```

Le nom de l'interface peut être différent de `wlan0`. Utilise `station list` pour le connaître.

Vérifie ensuite la connexion :

```bash
ping -c 3 archlinux.org
```

### Lancer l'installation

```bash
curl -fsSL https://raw.githubusercontent.com/SoulstimeFR/archConfigFiles/main/bootstrap.sh | bash
```

Le script va demander :

1. le disque à effacer ;
2. le nom de la machine ;
3. le nom de l'utilisateur ;
4. le mot de passe utilisateur ;
5. le mot de passe Wi-Fi si une connexion Wi-Fi est détectée.

Le disque choisi sera entièrement effacé.

Pour confirmer le disque, le chemin devra être retapé exactement, par exemple :

```text
/dev/nvme0n1
```

À la fin :

```bash
reboot
```

Retire la clé USB avant le redémarrage.

---

## Installation automatisée pour une machine virtuelle

Les variables suivantes peuvent être utilisées pour automatiser l'installation :

```bash
DISK=/dev/sda \
NEW_USER=user \
NEW_HOST=archbox \
PASSWORD='mot-de-passe' \
ASSUME_YES=1 \
curl -fsSL https://raw.githubusercontent.com/SoulstimeFR/archConfigFiles/main/bootstrap.sh | bash
```

> ⚠️ `ASSUME_YES=1` supprime certaines confirmations dangereuses.  
> Utilise cette option uniquement dans une machine virtuelle ou un environnement de test.

Autres variables disponibles :

| Variable | Description |
|---|---|
| `DISK` | Disque cible à effacer |
| `NEW_USER` | Nom du nouvel utilisateur |
| `NEW_HOST` | Nom de la machine |
| `PASSWORD` | Mot de passe utilisateur |
| `TIMEZONE` | Fuseau horaire, par défaut `Europe/Paris` |
| `LOCALE` | Locale, par défaut `en_US.UTF-8` |
| `KEYMAP` | Clavier console, par défaut `fr` |
| `ASSUME_YES` | Ignore certaines confirmations |
| `REPO_URL` | URL alternative du dépôt |
| `REPO_BRANCH` | Branche à utiliser |
| `TARGET_DIR` | Dossier temporaire du dépôt |
| `FORCE` | Autorise le lancement hors ISO Arch |

Exemple avec une autre disposition clavier :

```bash
KEYMAP=us curl -fsSL \
  https://raw.githubusercontent.com/SoulstimeFR/archConfigFiles/main/bootstrap.sh \
  | bash
```

---

## Scripts disponibles

### `bootstrap.sh`

Point d'entrée depuis l'ISO Arch.

Il :

- vérifie que le script est lancé en root ;
- vérifie l'environnement ISO Arch ;
- configure temporairement le clavier ;
- vérifie Internet ;
- installe Git si nécessaire ;
- clone ou met à jour le dépôt ;
- lance `install.sh`.

Commande :

```bash
curl -fsSL https://raw.githubusercontent.com/SoulstimeFR/archConfigFiles/main/bootstrap.sh | bash
```

---

### `install.sh`

Phase principale d'installation.

Il :

- vérifie le mode UEFI ;
- demande le disque cible ;
- efface le disque ;
- crée une partition EFI ;
- crée une partition Btrfs ;
- crée les sous-volumes Btrfs ;
- installe le système de base avec `pacstrap` ;
- génère `fstab` ;
- copie le dépôt dans le nouveau système ;
- lance la phase chroot ;
- copie le profil Wi-Fi utilisé pendant l'installation.

Le partitionnement créé est :

```text
Partition 1 : EFI FAT32, environ 1 Gio, montée sur /efi
Partition 2 : Btrfs, utilisée pour le système
```

Sous-volumes Btrfs :

```text
@             → /
@home         → /home
@log          → /var/log
@pkg          → /var/cache/pacman/pkg
@snapshots    → /.snapshots
```

Options de montage principales :

```text
noatime,compress=zstd:3,discard=async
```

Un journal complet est conservé dans :

```text
/root/install.log
```

---

### `chroot/10-system.sh`

Configure le système depuis `arch-chroot`.

Il configure :

- fuseau horaire ;
- locale ;
- clavier console ;
- hostname ;
- utilisateur ;
- sudo ;
- verrouillage du compte root ;
- zram ;
- Snapper ;
- Snap-pac ;
- GRUB ;
- grub-btrfs ;
- NetworkManager ;
- services système.

Le compte root est verrouillé après la création de l'utilisateur. Les opérations administratives se font avec `sudo`.

---

### `firstboot/10-paru.sh`

Installe `paru`, l'assistant AUR.

`paru` est compilé depuis les sources plutôt que d'utiliser `paru-bin`.

Cela évite les problèmes de compatibilité avec les versions récentes de `libalpm` et de `pacman`.

Lancer manuellement :

```bash
bash ~/arch-setup/firstboot/10-paru.sh
```

---

### `firstboot/20-hyprland-caelestia.sh`

Installe et configure :

- `caelestia-cli` ;
- Hyprland ;
- Caelestia ;
- `greetd` ;
- `tuigreet` ;
- configuration du clavier Hyprland ;
- wallpaper personnalisé ;
- thème dynamique ;
- GIF du menu d'alimentation.

Lancer :

```bash
bash ~/arch-setup/firstboot/20-hyprland-caelestia.sh
```

Après l'installation :

```bash
sudo reboot
```

---

### `firstboot/30-cachyos-kernel.sh`

Ajoute les dépôts CachyOS et installe :

```text
linux-cachyos
linux-cachyos-headers
```

Le noyau Arch `linux` est conservé comme solution de secours jusqu'à l'exécution de `40-drivers.sh`.

Lancer :

```bash
bash ~/arch-setup/firstboot/30-cachyos-kernel.sh
```

Redémarrer ensuite :

```bash
sudo reboot
```

Vérifier le noyau actif :

```bash
uname -r
```

Le résultat doit contenir :

```text
cachyos
```

---

### `firstboot/40-drivers.sh`

Détecte le matériel et installe les pilotes adaptés.

Le script :

- ignore les machines virtuelles ;
- installe `pciutils` si nécessaire ;
- détecte les cartes graphiques avec `lspci` ;
- installe Mesa et Vulkan ;
- installe les pilotes Intel ou AMD ;
- utilise `chwd` pour la détection CachyOS ;
- configure les cartes NVIDIA ;
- configure les portables hybrides ;
- installe `power-profiles-daemon` ;
- installe `brightnessctl` ;
- installe `thermald` sur les portables Intel ;
- active Bluetooth si un contrôleur est détecté ;
- supprime le noyau Arch lorsque CachyOS est actif ;
- reconstruit l'initramfs et GRUB.

Lancer après avoir redémarré sur CachyOS :

```bash
bash ~/arch-setup/firstboot/40-drivers.sh
```

Puis redémarrer :

```bash
sudo reboot
```

Pour une carte NVIDIA :

```bash
nvidia-smi
```

Pour un portable hybride :

```bash
prime-run <commande>
```

Exemple :

```bash
prime-run glxinfo | grep "OpenGL renderer"
```

---

### `firstboot/50-apps.sh`

Installe automatiquement les applications quotidiennes.

Le script utilise :

- `pacman` pour les paquets officiels ;
- `paru` pour les paquets AUR ;
- `npm` ou le paquet Arch correspondant pour les outils JavaScript.

Le script ne possède pas de checklist interactive : toutes les applications prises en charge sont installées automatiquement.

Lancer :

```bash
bash ~/arch-setup/firstboot/50-apps.sh
```

---

## Applications installées

### Paquets officiels

Le script installe notamment :

- Steam ;
- PHP ;
- extensions PHP ;
- Python ;
- `pip` ;
- `virtualenv` ;
- Git ;
- Docker Engine ;
- Docker Compose ;
- Docker Buildx ;
- Java ;
- Kotlin ;
- Composer ;
- DBeaver ;
- MariaDB ;
- LibreOffice ;
- Mermaid CLI ;
- `mpv` ;
- `fzf` ;
- `yt-dlp`.

### Paquets AUR

Le script installe notamment :

- Opera ;
- JetBrains Toolbox ;
- Obsidian ;
- Spotify ;
- Discord ;
- GitHub Desktop ;
- VSCodium ;
- Bitwarden ;
- ani-cli ;
- Symfony CLI ;
- HyprMod.

### Applications non installées automatiquement

#### Docker Desktop

Docker Engine est installé par défaut.

Docker Desktop n'est pas installé en parallèle afin d'éviter les conflits entre plusieurs moteurs Docker.

#### Claude Desktop

Claude Desktop n'est pas installé automatiquement car aucun paquet Arch fiable n'est imposé par le script.

Une installation manuelle pourra être ajoutée ultérieurement si une méthode Linux/Arch stable est retenue.

---

## Configuration de Docker

Après l'installation de Docker Engine, le script :

- active `docker.service` ;
- démarre le service ;
- ajoute l'utilisateur au groupe `docker`.

Déconnecte-toi puis reconnecte-toi pour appliquer le changement de groupe.

Vérifie ensuite :

```bash
docker --version
systemctl status docker.service
```

Teste Docker :

```bash
docker run hello-world
```

Si la commande refuse l'accès au socket Docker, vérifie le groupe :

```bash
groups
```

Tu peux temporairement appliquer le groupe sans te déconnecter :

```bash
newgrp docker
```

---

## Personnalisation Caelestia

### Wallpaper

Ajoute le wallpaper dans le dépôt :

```text
assets/wallpapers/default.jpg
```

Lors de l'exécution de `20-hyprland-caelestia.sh`, il est copié vers :

```text
~/Pictures/Wallpapers/default.jpg
```

Le dossier est créé automatiquement s'il n'existe pas.

Le script tente également d'appliquer le wallpaper avec :

```bash
caelestia wallpaper -f "$HOME/Pictures/Wallpapers/default.jpg"
```

Si cette commande ne fonctionne pas avant le premier lancement de Hyprland, exécute-la après la connexion :

```bash
caelestia wallpaper -f "$HOME/Pictures/Wallpapers/default.jpg"
```

---

### Scheme dynamique

Le script tente d'activer le scheme dynamique :

```bash
caelestia scheme set -n dynamic
```

Si nécessaire, exécute cette commande après la première connexion à Hyprland :

```bash
caelestia scheme set -n dynamic
```

---

### GIF du menu d'alimentation

Ajoute ton GIF dans le dépôt :

```text
assets/gifs/session.gif
```

Il est copié vers :

```text
~/.config/caelestia/assets/session.gif
```

Le fichier de configuration suivant est créé ou mis à jour :

```text
~/.config/caelestia/shell.json
```

La configuration contient :

```json
{
  "paths": {
    "wallpaperDir": "/home/USER/Pictures/Wallpapers",
    "sessionGif": "/home/USER/.config/caelestia/assets/session.gif"
  }
}
```

Vérifie la configuration avec :

```bash
jq '.paths' ~/.config/caelestia/shell.json
```

Après une modification du GIF, redémarre la session Hyprland ou recharge Caelestia.

---

### Clavier Hyprland

La disposition est ajoutée dans :

```text
~/.config/caelestia/hypr-user.lua
```

Le script récupère la valeur définie dans :

```text
/etc/vconsole.conf
```

Tu peux forcer une disposition particulière avec :

```bash
KB_LAYOUT=fr bash ~/arch-setup/firstboot/20-hyprland-caelestia.sh
```

Exemples :

```bash
KB_LAYOUT=fr
KB_LAYOUT=us
KB_LAYOUT=de
```

---

## Après l'installation

Après le premier démarrage, les scripts doivent être lancés dans cet ordre :

```bash
bash ~/arch-setup/firstboot/20-hyprland-caelestia.sh
bash ~/arch-setup/firstboot/30-cachyos-kernel.sh
sudo reboot
```

Après le redémarrage sur CachyOS :

```bash
bash ~/arch-setup/firstboot/40-drivers.sh
sudo reboot
```

Puis installe les applications :

```bash
bash ~/arch-setup/firstboot/50-apps.sh
sudo reboot
```

Ordre complet :

```text
20-hyprland-caelestia.sh
        ↓
30-cachyos-kernel.sh
        ↓
Redémarrage sur linux-cachyos
        ↓
40-drivers.sh
        ↓
Redémarrage
        ↓
50-apps.sh
        ↓
Redémarrage recommandé
```

---

## Tests et vérifications

### Vérifier la syntaxe des scripts

```bash
bash -n bootstrap.sh
bash -n install.sh
bash -n chroot/10-system.sh
bash -n firstboot/10-paru.sh
bash -n firstboot/20-hyprland-caelestia.sh
bash -n firstboot/30-cachyos-kernel.sh
bash -n firstboot/40-drivers.sh
bash -n firstboot/50-apps.sh
```

### Vérifier le noyau

```bash
uname -r
```

Résultat attendu :

```text
linux-cachyos
```

ou une version contenant :

```text
cachyos
```

### Vérifier la carte graphique

```bash
lspci -k | grep -EA3 'VGA|3D|Display'
```

Pour NVIDIA :

```bash
nvidia-smi
```

### Vérifier Bluetooth

```bash
systemctl status bluetooth.service
bluetoothctl
```

Dans `bluetoothctl` :

```text
power on
agent on
default-agent
scan on
devices
```

Les adresses du type `44:01:A7:...` sont des adresses Bluetooth normales.

### Vérifier le réseau

```bash
systemctl status NetworkManager.service
nmcli device status
```

### Vérifier Caelestia

```bash
ls -l ~/Pictures/Wallpapers
ls -l ~/.config/caelestia/assets
jq '.paths' ~/.config/caelestia/shell.json
```

### Vérifier les applications

```bash
git --version
python --version
php --version
java --version
kotlinc -version
composer --version
docker --version
mmdc --version
```

---

## Structure du dépôt

```text
archConfigFiles/
├── assets/
│   ├── gifs/
│   │   └── session.gif
│   └── wallpapers/
│       └── default.jpg
│
├── bootstrap.sh
│   Point d'entrée depuis l'ISO Arch
│
├── install.sh
│   Partitionnement et installation du système de base
│
├── chroot/
│   └── 10-system.sh
│       Configuration du système depuis arch-chroot
│
├── firstboot/
│   ├── 10-paru.sh
│   │   Installation de paru
│   │
│   ├── 20-hyprland-caelestia.sh
│   │   Installation de Hyprland, Caelestia et greetd
│   │
│   ├── 30-cachyos-kernel.sh
│   │   Installation du noyau CachyOS
│   │
│   ├── 40-drivers.sh
│   │   Détection et installation des pilotes
│   │
│   └── 50-apps.sh
│       Installation automatique des applications
│
├── .gitattributes
└── README.md
```

---

## Dépannage

### Le dépôt ne se clone pas

Vérifie Internet :

```bash
curl -I https://github.com
```

Puis relance :

```bash
curl -fsSL https://raw.githubusercontent.com/SoulstimeFR/archConfigFiles/main/bootstrap.sh | bash
```

### `paru` échoue

Vérifie que le script est lancé avec l'utilisateur normal :

```bash
id -u
```

La sortie ne doit pas être :

```text
0
```

Relance :

```bash
bash ~/arch-setup/firstboot/10-paru.sh
```

### Le noyau CachyOS n'est pas actif

Vérifie :

```bash
uname -r
```

Si le résultat ne contient pas `cachyos` :

1. redémarre ;
2. ouvre le menu GRUB ;
3. sélectionne le noyau `linux-cachyos`.

Puis relance :

```bash
bash ~/arch-setup/firstboot/40-drivers.sh
```

### Écran noir après l'installation des pilotes

Depuis GRUB :

```text
Advanced options
```

Sélectionne temporairement le noyau Arch `linux` s'il est encore présent.

Une fois le système démarré, vérifie :

```bash
nvidia-smi
journalctl -b -p err
```

### Le wallpaper n'est pas appliqué

Vérifie que le fichier existe :

```bash
ls -lh ~/Pictures/Wallpapers/default.jpg
```

Puis exécute :

```bash
caelestia wallpaper -f ~/Pictures/Wallpapers/default.jpg
caelestia scheme set -n dynamic
```

### Le GIF du menu d'alimentation n'est pas affiché

Vérifie :

```bash
ls -lh ~/.config/caelestia/assets/session.gif
jq '.paths.sessionGif' ~/.config/caelestia/shell.json
```

Le chemin doit être absolu et pointer vers un fichier existant.

### Une application AUR échoue

Relance son installation seule :

```bash
paru -S <nom-du-paquet>
```

Exemples :

```bash
paru -S opera
paru -S obsidian
paru -S hyprmod
paru -S ani-cli
```

Les paquets AUR peuvent temporairement échouer à cause :

- d'une mise à jour de pacman ;
- d'une dépendance manquante ;
- d'un paquet AUR abandonné ;
- d'un miroir indisponible ;
- d'un changement du nom du paquet.

---

## Tester dans une machine virtuelle

Réglages recommandés :

- UEFI activé ;
- disque virtuel d'au moins 60 Go ;
- 4 CPU ;
- 8 Go de RAM si possible ;
- réseau NAT ;
- accélération 3D activée si disponible.

La machine virtuelle permet de valider :

- le partitionnement ;
- Btrfs ;
- GRUB ;
- Snapper ;
- NetworkManager ;
- paru ;
- Caelestia ;
- le noyau CachyOS ;
- l'installation des applications.

Elle ne permet pas toujours de valider correctement :

- les pilotes NVIDIA ;
- PRIME ;
- le rendu Hyprland ;
- l'accélération graphique ;
- le comportement réel d'un portable.

---

## Limites connues

- L'installation efface entièrement le disque choisi.
- L'installation est prévue pour UEFI uniquement.
- Les pilotes propriétaires dépendent du matériel détecté.
- Les paquets AUR peuvent changer ou devenir indisponibles.
- Docker Engine est installé par défaut ; Docker Desktop n'est pas installé en parallèle.
- Claude Desktop n'est pas installé automatiquement.
- MariaDB est utilisé comme serveur compatible avec l'écosystème MySQL.
- Le service MariaDB n'est pas initialisé automatiquement.
- Le wallpaper et le scheme Caelestia peuvent nécessiter une application manuelle après la première connexion à Hyprland.
- Le matériel NVIDIA/Optimus doit être validé sur la machine réelle.
- Un snapshot Btrfs n'est pas une sauvegarde : il reste sur le même disque.
- Les fichiers personnels de `/home` doivent être sauvegardés séparément.

---

## Snapshots et restauration

Lister les snapshots :

```bash
sudo snapper -c root list
```

Voir les sous-volumes Btrfs :

```bash
sudo btrfs subvolume list /
```

Les snapshots sont créés automatiquement par `snap-pac` avant et après les transactions `pacman`.

En cas de problème :

1. redémarre ;
2. ouvre le menu GRUB ;
3. ouvre le sous-menu des snapshots ;
4. démarre sur un snapshot fonctionnel.

> Démarrer sur un snapshot ne constitue pas une restauration définitive.  
> Il s'agit d'un démarrage temporaire en lecture seule avec une couche overlay.

---

## Personnalisation de l'installation

### Changer le fuseau horaire

```bash
TIMEZONE=Europe/Paris
```

### Changer la locale

```bash
LOCALE=en_US.UTF-8
```

### Changer le clavier console

```bash
KEYMAP=fr
```

### Changer l'utilisateur et le hostname

```bash
NEW_USER=user
NEW_HOST=archbox
```

Ces valeurs peuvent être fournies avant le lancement de `bootstrap.sh` ou saisies interactivement par `install.sh`.

---

## Sécurité

Ne stocke jamais dans ce dépôt :

- mots de passe ;
- clés SSH privées ;
- tokens ;
- clés API ;
- fichiers `.env` ;
- sauvegardes de comptes ;
- mots de passe Wi-Fi en clair.

Le mot de passe Wi-Fi demandé pendant l'installation est écrit dans un profil NetworkManager protégé par les permissions système.

Vérifie toujours le contenu des scripts avant d'utiliser une commande du type :

```bash
curl ... | bash
```

Pour une installation plus sûre, clone d'abord le dépôt :

```bash
git clone https://github.com/SoulstimeFR/archConfigFiles.git ~/arch-setup
cd ~/arch-setup
less bootstrap.sh
```

---

## État du projet

| Élément | État |
|---|---|
| Installation UEFI | Implémentée |
| Partitionnement Btrfs | Implémenté |
| Sous-volumes Btrfs | Implémenté |
| Snapper et snap-pac | Implémenté |
| GRUB et grub-btrfs | Implémenté |
| NetworkManager | Implémenté |
| zram | Implémenté |
| paru | Implémenté |
| Hyprland et Caelestia | Implémenté |
| Wallpaper personnalisé | Implémenté |
| Scheme dynamique Caelestia | Implémenté |
| GIF du menu d'alimentation | Implémenté |
| Noyau CachyOS | Implémenté |
| Détection des pilotes | Implémentée |
| Bluetooth | Implémenté |
| Installation des applications | Implémentée |
| Docker Engine | Implémenté |
| Docker Desktop | Non installé automatiquement |
| Claude Desktop | Non installé automatiquement |
| Test complet sur machine réelle | À valider |

---

## Licence

Aucune licence spécifique n'est actuellement déclarée pour ce dépôt.