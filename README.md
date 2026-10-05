# archConfigFiles

Installation automatisée d'un environnement **Arch Linux + CachyOS + Hyprland + Caelestia**.

Ce dépôt permet d'installer rapidement un système Arch Linux complet avec :

- installation en mode UEFI ;
- partitionnement automatique en Btrfs ;
- sous-volumes Btrfs ;
- snapshots Snapper ;
- noyau CachyOS ;
- détection automatique des pilotes ;
- Hyprland et Caelestia ;
- wallpaper personnalisé ;
- scheme dynamique ;
- GIF personnalisé du menu d'alimentation ;
- photo de profil Caelestia ;
- Opera associé au raccourci `Super + W` ;
- installation automatique des applications quotidiennes ;
- HyprMod.

> ⚠️ **Attention : l'installation efface entièrement le disque sélectionné.**
>
> Sauvegarde tes fichiers importants et vérifie soigneusement le disque avant de continuer.

---

## Sommaire

- [Fonctionnement général](#fonctionnement-général)
- [Prérequis](#prérequis)
- [Installation depuis l'ISO Arch](#installation-depuis-liso-arch)
- [Étapes après le premier démarrage](#étapes-après-le-premier-démarrage)
- [Scripts disponibles](#scripts-disponibles)
- [Personnalisation de Caelestia](#personnalisation-de-caelestia)
- [Applications installées](#applications-installées)
- [Vérifications](#vérifications)
- [Structure du dépôt](#structure-du-dépôt)
- [Dépannage](#dépannage)
- [Tester dans une machine virtuelle](#tester-dans-une-machine-virtuelle)
- [Sécurité](#sécurité)

---

## Fonctionnement général

L'installation est divisée en deux phases.

### Phase 1 : depuis l'ISO Arch

```text
bootstrap.sh
    │
    └── install.sh
            │
            ├── efface le disque choisi ;
            ├── crée les partitions EFI et Btrfs ;
            ├── installe le système de base ;
            ├── configure le système dans chroot ;
            └── copie le dépôt dans /home/UTILISATEUR/arch-setup
```

### Phase 2 : après le premier démarrage

Les scripts `firstboot` doivent être lancés manuellement, un par un :

```text
20-hyprland-caelestia.sh
        │
        └── redémarrage

30-cachyos-kernel.sh
        │
        └── redémarrage

40-drivers.sh
        │
        └── redémarrage

50-apps.sh
        │
        └── redémarrage recommandé
```

Les scripts `firstboot` doivent être lancés avec l'utilisateur normal créé pendant l'installation.

> Ne lance pas ces scripts avec `sudo` et ne les lance pas directement en root.

---

## Prérequis

- ISO officielle d'Arch Linux ;
- démarrage en mode **UEFI** ;
- connexion Internet ;
- disque cible à effacer ;
- environ 60 Go d'espace disque recommandés ;
- carte graphique compatible Linux.

Vérifie que l'ISO a démarré en mode UEFI :

```bash
test -d /sys/firmware/efi \
  && echo "UEFI OK" \
  || echo "Mode BIOS/legacy"
```

Le script d'installation ne prend pas en charge le mode BIOS/legacy.

---

## Installation depuis l'ISO Arch

### Connexion Ethernet

Avec une connexion Ethernet, aucune configuration particulière n'est généralement nécessaire.

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

Le nom de l'interface peut être différent de `wlan0`. Utilise `station list` ou `device list` pour connaître le nom correct.

Teste ensuite la connexion :

```bash
ping -c 3 archlinux.org
```

### Lancer l'installation

Depuis l'ISO Arch :

```bash
curl -fsSL \
  https://raw.githubusercontent.com/SoulstimeFR/archConfigFiles/main/bootstrap.sh \
  | bash
```

Le script demande notamment :

1. le disque à effacer ;
2. le nom de la machine ;
3. le nom de l'utilisateur ;
4. le mot de passe utilisateur ;
5. le mot de passe Wi-Fi si une connexion Wi-Fi est détectée.

Le disque sélectionné sera entièrement effacé.

Pour confirmer le disque, tu dois retaper son chemin exactement, par exemple :

```text
/dev/nvme0n1
```

À la fin de l'installation :

```bash
reboot
```

Retire la clé USB avant le redémarrage.

Le journal complet de l'installation est conservé dans :

```text
/root/install.log
```

---

## Installation automatisée dans une machine virtuelle

Pour automatiser une installation de test :

```bash
DISK=/dev/sda \
NEW_USER=user \
NEW_HOST=archbox \
PASSWORD='mot-de-passe' \
ASSUME_YES=1 \
curl -fsSL \
  https://raw.githubusercontent.com/SoulstimeFR/archConfigFiles/main/bootstrap.sh \
  | bash
```

> ⚠️ Utilise `ASSUME_YES=1` uniquement dans une machine virtuelle ou sur un disque de test.

Variables disponibles :

| Variable | Valeur par défaut | Description |
|---|---|---|
| `DISK` | interactive | Disque à effacer |
| `NEW_USER` | interactive | Nom du nouvel utilisateur |
| `NEW_HOST` | `archbox` | Nom de la machine |
| `PASSWORD` | interactive | Mot de passe utilisateur |
| `TIMEZONE` | `Europe/Paris` | Fuseau horaire |
| `LOCALE` | `en_US.UTF-8` | Locale système |
| `KEYMAP` | `fr` | Disposition du clavier console |
| `ASSUME_YES` | `0` | Ignore certaines confirmations |
| `REPO_URL` | dépôt GitHub | URL du dépôt à cloner |
| `REPO_BRANCH` | `main` | Branche utilisée |
| `TARGET_DIR` | `/root/arch-setup` | Dossier temporaire du dépôt |
| `FORCE` | `0` | Autorise le lancement hors ISO Arch |

---

## Étapes après le premier démarrage

Les scripts `firstboot` doivent être exécutés **un par un**, dans l'ordre indiqué, avec l'utilisateur normal créé pendant l'installation.

> Ne lance pas ces scripts avec `sudo` et ne les lance pas directement en root.

### Étape 1 : installer Hyprland et Caelestia

```bash
bash ~/arch-setup/firstboot/20-hyprland-caelestia.sh
```

Ce script configure :

- `paru` ;
- Caelestia ;
- Hyprland ;
- `greetd` ;
- `tuigreet` ;
- le wallpaper personnalisé ;
- le scheme dynamique ;
- le GIF du menu d'alimentation ;
- la photo de profil ;
- Opera pour `Super + W` ;
- le clavier Hyprland.

Ne redémarre pas encore après cette étape.

---

### Étape 2 : installer le noyau CachyOS

Toujours dans la même session, lance ensuite :

```bash
bash ~/arch-setup/firstboot/30-cachyos-kernel.sh
```

Ce script :

- ajoute les dépôts CachyOS ;
- installe `linux-cachyos` ;
- installe les headers du noyau ;
- configure GRUB ;
- conserve temporairement le noyau Arch comme solution de secours.

Une fois le script terminé, redémarre :

```bash
sudo reboot
```

Après le redémarrage, vérifie le noyau actif :

```bash
uname -r
```

La sortie doit contenir :

```text
cachyos
```

Ne continue pas si le noyau CachyOS n'est pas actif.

---

### Étape 3 : installer les pilotes matériels

Après avoir redémarré sur le noyau CachyOS :

```bash
bash ~/arch-setup/firstboot/40-drivers.sh
```

Ce script détecte et configure notamment :

- les cartes graphiques Intel, AMD et NVIDIA ;
- les portables hybrides ;
- Mesa et Vulkan ;
- la gestion de l'énergie ;
- Bluetooth ;
- les pilotes matériels adaptés.

Redémarre ensuite :

```bash
sudo reboot
```

---

### Étape 4 : installer les applications

Après le redémarrage :

```bash
bash ~/arch-setup/firstboot/50-apps.sh
```

Ce script installe les applications officielles et les paquets AUR configurés dans le dépôt.

Un redémarrage est recommandé à la fin :

```bash
sudo reboot
```

---

### Ordre complet

```text
1. bash ~/arch-setup/firstboot/20-hyprland-caelestia.sh
2. bash ~/arch-setup/firstboot/30-cachyos-kernel.sh
3. sudo reboot

4. Vérifier que uname -r contient « cachyos »
5. bash ~/arch-setup/firstboot/40-drivers.sh
6. sudo reboot

7. bash ~/arch-setup/firstboot/50-apps.sh
8. sudo reboot
```

---

## Scripts disponibles

### `bootstrap.sh`

Point d'entrée depuis l'ISO Arch.

Il :

- vérifie que le script est lancé en root ;
- vérifie que l'environnement ISO Arch est utilisé ;
- configure temporairement le clavier ;
- vérifie Internet ;
- installe Git si nécessaire ;
- clone ou met à jour le dépôt ;
- lance `install.sh`.

---

### `install.sh`

Effectue l'installation principale du système.

Il :

- vérifie le mode UEFI ;
- demande le disque cible ;
- efface le disque ;
- crée une partition EFI ;
- crée une partition Btrfs ;
- crée les sous-volumes Btrfs ;
- installe le système avec `pacstrap` ;
- génère `fstab` ;
- copie le dépôt dans le nouveau système ;
- lance la configuration chroot ;
- copie éventuellement le profil Wi-Fi utilisé pendant l'installation.

Partitionnement créé :

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

---

### `chroot/10-system.sh`

Configure le système depuis `arch-chroot`.

Il configure :

- le fuseau horaire ;
- la locale ;
- le clavier console ;
- le hostname ;
- l'utilisateur ;
- sudo ;
- zram ;
- Snapper ;
- snap-pac ;
- GRUB ;
- grub-btrfs ;
- NetworkManager ;
- les services système.

---

### `firstboot/10-paru.sh`

Compile et installe `paru` depuis l'AUR.

Ce script est normalement appelé automatiquement au début de :

```bash
firstboot/20-hyprland-caelestia.sh
```

---

### `firstboot/20-hyprland-caelestia.sh`

Installe et configure :

- Caelestia ;
- Hyprland ;
- `greetd` ;
- `tuigreet` ;
- le wallpaper ;
- le scheme dynamique ;
- le GIF du menu d'alimentation ;
- la photo de profil ;
- Opera pour `Super + W` ;
- le clavier Hyprland.

---

### `firstboot/30-cachyos-kernel.sh`

Ajoute les dépôts CachyOS et installe :

```text
linux-cachyos
linux-cachyos-headers
```

Le noyau Arch reste disponible temporairement comme solution de secours.

---

### `firstboot/40-drivers.sh`

Détecte le matériel et installe les pilotes adaptés.

Le script ignore automatiquement les machines virtuelles.

Pour NVIDIA :

```bash
nvidia-smi
```

Pour lancer une application sur le GPU NVIDIA d'un portable hybride :

```bash
prime-run <commande>
```

---

### `firstboot/50-apps.sh`

Installe automatiquement les applications configurées avec :

- `pacman` pour les paquets officiels ;
- `paru` pour les paquets AUR.

Le script ne possède pas de checklist interactive. Il affiche un résumé des paquets :

- installés ;
- ignorés volontairement ;
- échoués.

---

## Personnalisation de Caelestia

Les assets utilisés par le script sont :

```text
assets/
├── gifs/
│   └── session.gif
├── profile/
│   └── profile.png
└── wallpapers/
    └── default.png
```

---

### Wallpaper

Le fichier source doit être :

```text
assets/wallpapers/default.png
```

Il est copié vers :

```text
~/Pictures/Wallpapers/default.png
```

Le script tente ensuite de l'appliquer avec :

```bash
caelestia wallpaper -f "$HOME/Pictures/Wallpapers/default.png"
```

Si le wallpaper ne peut pas être appliqué pendant l'installation, exécute la commande après ta connexion à Hyprland :

```bash
caelestia wallpaper -f "$HOME/Pictures/Wallpapers/default.png"
```

---

### Scheme dynamique

Le script tente d'activer le scheme :

```bash
caelestia scheme set -n dynamic
```

Tu peux réexécuter cette commande après la connexion à Hyprland si nécessaire.

---

### GIF du menu d'alimentation

Le fichier source doit être :

```text
assets/gifs/session.gif
```

Il est copié vers :

```text
~/.config/caelestia/assets/session.gif
```

Le fichier de configuration est :

```text
~/.config/caelestia/shell.json
```

Il contient notamment :

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

---

### Photo de profil

Le fichier source doit être :

```text
assets/profile/profile.png
```

Une image PNG carrée est recommandée.

Le script l'installe ici :

```text
~/.face
```

Vérifie l'image avec :

```bash
file ~/.face
ls -lh ~/.face
```

Si la photo n'est pas affichée, déconnecte-toi puis reconnecte-toi à Hyprland.

---

### Opera et `Super + W`

Opera est installé par `50-apps.sh` avec le paquet AUR :

```text
opera
```

Le script Caelestia configure le navigateur dans :

```text
~/.config/caelestia/hypr-vars.lua
```

La configuration attendue est :

```lua
browser = "opera",
```

Vérifie-la avec :

```bash
grep -n "browser" ~/.config/caelestia/hypr-vars.lua
```

Après la connexion à Hyprland :

```text
Super + W
```

doit lancer Opera.

---

### Clavier Hyprland

La configuration utilisateur est ajoutée dans :

```text
~/.config/caelestia/hypr-user.lua
```

La disposition est récupérée depuis :

```text
/etc/vconsole.conf
```

Pour forcer une disposition :

```bash
KB_LAYOUT=fr \
bash ~/arch-setup/firstboot/20-hyprland-caelestia.sh
```

Exemples :

```bash
KB_LAYOUT=fr
KB_LAYOUT=us
KB_LAYOUT=de
```

---

## Applications installées

### Paquets officiels

Le script installe notamment :

- Steam ;
- PHP ;
- extensions PHP ;
- Python ;
- pip ;
- virtualenv ;
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

---

## Configuration de Docker

Le script :

- installe Docker Engine ;
- active `docker.service` ;
- démarre Docker ;
- ajoute l'utilisateur au groupe `docker`.

Déconnecte-toi puis reconnecte-toi après l'installation pour appliquer le groupe.

Vérifie Docker :

```bash
docker --version
systemctl status docker.service
```

Teste le fonctionnement :

```bash
docker run hello-world
```

Si nécessaire :

```bash
newgrp docker
```

---

## Vérifications

### Vérifier la syntaxe des scripts

Depuis la racine du dépôt :

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

### Vérifier les assets

```bash
test -f assets/wallpapers/default.png \
  && echo "Wallpaper OK"

test -f assets/gifs/session.gif \
  && echo "GIF OK"

test -f assets/profile/profile.png \
  && echo "Photo de profil OK"
```

### Vérifier Caelestia

```bash
ls -lh ~/Pictures/Wallpapers/default.png
ls -lh ~/.config/caelestia/assets/session.gif
ls -lh ~/.face
jq '.paths' ~/.config/caelestia/shell.json
```

### Vérifier Opera

```bash
command -v opera
grep -n "browser" ~/.config/caelestia/hypr-vars.lua
```

### Vérifier le noyau

```bash
uname -r
```

La sortie doit contenir :

```text
cachyos
```

### Vérifier les pilotes graphiques

```bash
lspci -k | grep -EA3 'VGA|3D|Display'
```

Pour NVIDIA :

```bash
nvidia-smi
```

### Vérifier Bluetooth

```bash
systemctl is-active bluetooth.service
```

Puis :

```bash
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

Les adresses comme `44:01:A7:...` sont des adresses Bluetooth normales.

### Vérifier le réseau

```bash
systemctl is-active NetworkManager.service
nmcli device status
```

---

## Structure du dépôt

```text
archConfigFiles/
├── assets/
│   ├── gifs/
│   │   └── session.gif
│   ├── profile/
│   │   └── profile.png
│   └── wallpapers/
│       └── default.png
│
├── bootstrap.sh
├── install.sh
│
├── chroot/
│   └── 10-system.sh
│
├── firstboot/
│   ├── 10-paru.sh
│   ├── 20-hyprland-caelestia.sh
│   ├── 30-cachyos-kernel.sh
│   ├── 40-drivers.sh
│   └── 50-apps.sh
│
├── .gitattributes
└── README.md
```

---

## Dépannage

### Le wallpaper n'est pas installé

Vérifie le fichier source :

```bash
ls -lh assets/wallpapers/default.png
```

Après l'installation :

```bash
ls -lh ~/Pictures/Wallpapers/default.png
```

Pour l'appliquer manuellement :

```bash
caelestia wallpaper -f ~/Pictures/Wallpapers/default.png
```

---

### Le scheme dynamique n'est pas activé

```bash
caelestia scheme set -n dynamic
```

---

### Le GIF n'est pas affiché

Vérifie :

```bash
ls -lh ~/.config/caelestia/assets/session.gif
jq '.paths.sessionGif' ~/.config/caelestia/shell.json
```

Le chemin doit être absolu et pointer vers un fichier existant.

---

### La photo de profil n'est pas affichée

Vérifie :

```bash
file ~/.face
ls -lh ~/.face
```

Si nécessaire, reconnecte-toi à Hyprland.

---

### `Super + W` ne lance pas Opera

Vérifie qu'Opera est installé :

```bash
command -v opera
```

Vérifie la configuration Caelestia :

```bash
grep -n "browser" ~/.config/caelestia/hypr-vars.lua
```

La ligne attendue est :

```lua
browser = "opera",
```

---

### `paru` échoue

Vérifie que le script n'est pas lancé en root :

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

---

### Le noyau CachyOS n'est pas actif

Vérifie :

```bash
uname -r
```

Si `cachyos` n'apparaît pas :

1. redémarre ;
2. ouvre le menu GRUB ;
3. sélectionne `linux-cachyos`.

---

### Un paquet AUR échoue

Relance le paquet individuellement :

```bash
paru -S <nom-du-paquet>
```

Exemples :

```bash
paru -S opera
paru -S hyprmod
paru -S obsidian
```

Les paquets AUR peuvent échouer temporairement à cause :

- d'une mise à jour de pacman ;
- d'une dépendance manquante ;
- d'un paquet AUR abandonné ;
- d'un miroir indisponible ;
- d'un changement du nom du paquet.

---

### Écran noir après l'installation d'un pilote

Depuis GRUB, démarre temporairement sur le noyau Arch dans :

```text
Advanced options
```

Puis consulte :

```bash
journalctl -b -p err
```

Pour NVIDIA :

```bash
nvidia-smi
```

---

## Tester dans une machine virtuelle

Réglages recommandés :

- UEFI activé ;
- disque virtuel d'au moins 60 Go ;
- 4 CPU ;
- 8 Go de RAM si possible ;
- réseau NAT ;
- accélération 3D activée si disponible.

Une machine virtuelle permet de tester :

- le partitionnement ;
- Btrfs ;
- GRUB ;
- Snapper ;
- NetworkManager ;
- paru ;
- Caelestia ;
- l'installation des applications.

Les éléments suivants doivent être validés sur la machine réelle :

- pilotes NVIDIA ;
- PRIME ;
- accélération graphique ;
- comportement de Hyprland ;
- Bluetooth matériel ;
- gestion de l'énergie d'un portable.

---

## Snapshots Btrfs

Lister les snapshots :

```bash
sudo snapper -c root list
```

Voir les sous-volumes :

```bash
sudo btrfs subvolume list /
```

Les transactions pacman peuvent être protégées par `snap-pac`.

> Un snapshot Btrfs n'est pas une sauvegarde. Il reste sur le même disque physique.

---

## Sécurité

Ne stocke jamais dans ce dépôt :

- mots de passe ;
- clés SSH privées ;
- tokens ;
- clés API ;
- fichiers `.env` ;
- mots de passe Wi-Fi ;
- sauvegardes personnelles.

Vérifie toujours le disque ciblé avant d'exécuter l'installation.

Pour inspecter le dépôt avant l'installation :

```bash
git clone https://github.com/SoulstimeFR/archConfigFiles.git ~/arch-setup
cd ~/arch-setup
less bootstrap.sh
```

L'installation efface entièrement le disque sélectionné. Utilise toujours un disque de test pour tes premiers essais.