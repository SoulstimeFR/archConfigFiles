# archConfigFiles

Réinstallation automatisée d'**Arch Linux** (noyau CachyOS, Hyprland + Caelestia) depuis l'ISO Arch, en quelques commandes.

Le but : quand le système se corrompt, repartir d'une base propre et retrouver son environnement rapidement, sans tout refaire à la main.

> **Attention : `install.sh` EFFACE TOUT LE DISQUE choisi.** Fais une sauvegarde de tes données avant de le lancer. UEFI uniquement (pas de BIOS legacy).

---

## Démarrage rapide

### 1. Avant de commencer

- Télécharge l'ISO Arch (archlinux.org/download) et mets-la sur une clé USB.
- Dans le BIOS : **désactive Secure Boot** et démarre en **UEFI** sur la clé.
- Aie une connexion Internet : câble Ethernet (le plus simple) ou Wi-Fi.
  Wi-Fi depuis l'ISO : `iwctl`, puis `station wlan0 connect "NOM_DU_RESEAU"` (`station list` donne le vrai nom de la carte).
- Garde ce README sur un autre appareil (téléphone) : c'est ton mode d'emploi si la machine est hors service.

### 2. Installation depuis l'ISO

```bash
curl -fsSL https://raw.githubusercontent.com/SoulstimeFR/archConfigFiles/main/bootstrap.sh | bash
```

Le script pose quelques questions :

1. Le **disque à effacer** (il faut retaper son chemin pour confirmer, par exemple `/dev/nvme0n1`).
2. Le **nom de la machine**, ton **nom d'utilisateur** et ton **mot de passe**.
3. Si tu es en Wi-Fi : le **mot de passe du Wi-Fi**, pour que le système installé s'y reconnecte tout seul.

Puis retire la clé USB et redémarre : `reboot`.

### 3. Après le redémarrage (en console, avec ton utilisateur)

Le dépôt a été copié dans `~/arch-setup`. Si ce n'est pas le cas :
`git clone https://github.com/SoulstimeFR/archConfigFiles.git ~/arch-setup`

Si tu n'as pas de réseau, connecte-toi avec `nmtui` (menu texte) ou `nmcli device wifi connect "NOM" --ask`.

```bash
bash ~/arch-setup/firstboot/20-hyprland-caelestia.sh
bash ~/arch-setup/firstboot/30-cachyos-kernel.sh
sudo reboot
```

Au redémarrage, l'écran de connexion (greetd) apparaît, puis Hyprland avec Caelestia.

---

## Réponses aux questions posées pendant l'installation

### `caelestia install` (script 20)

Les questions viennent de Caelestia, pas du script. Réponses à donner :

| Question | Réponse |
|---|---|
| Appuyer sur Entrée pour continuer | Entrée |
| Applications optionnelles (Spotify, Discord...) | Aucune : Entrée (elles sont gérées à part) |
| Quel shell ? | `caelestia-shell` (le premier choix, la version stable) |
| Quelle CLI ? | `caelestia-cli` |
| Fournisseur de `papirus-folders` | Le premier de la liste |
| Fournisseur de `qtengine` | Le premier de la liste |
| Confirmations pacman/paru | `O` (oui) ou Entrée. Sur un système en anglais ce sera `Y` |

### `cachyos-repo.sh` (script 30)

Le script officiel de CachyOS peut poser des questions de confirmation : accepte. Il installe les dépôts CachyOS optimisés pour le processeur, ce qui remplace beaucoup de paquets Arch (plus de 500 paquets, environ 1,2 Go).

Si tu vois des erreurs `404` sur des paquets : ce sont des miroirs CachyOS en retard. Relance `sudo pacman -Syyu`, ou change l'ordre des miroirs dans `/etc/pacman.d/cachyos-v3-mirrorlist`, ou attends un peu.

---

## Ce que fait l'installation

### Disque et système de base (`install.sh` + `chroot/10-system.sh`)

- **Partitions** : ESP FAT32 de 1 Go montée sur `/efi`, le reste en **Btrfs**.
- **Sous-volumes Btrfs** : `@` (racine), `@home`, `@log`, `@pkg` (cache pacman), `@snapshots`. `/home` est séparé de la racine : un retour en arrière du système ne touche pas tes fichiers.
- **Bootloader** : GRUB (UEFI) avec `grub-btrfs`, qui ajoute les snapshots au menu de démarrage.
- **Snapshots** : Snapper avec `snap-pac`, un snapshot avant et après chaque transaction pacman. Pas de snapshots horaires ; on garde les 10 derniers (5 « importants »).
- **Mémoire** : zram (pas de partition de swap).
- **Utilisateur** : groupe `wheel` avec `sudo`. Le compte **root est verrouillé**.
- **Réseau** : NetworkManager. Le Wi-Fi utilisé pendant l'installation est copié.
- **Pacman** : couleurs, téléchargements parallèles, dépôt `multilib` activé (utile pour Steam).
- **Langue et clavier par défaut** : système en anglais (`en_US.UTF-8`), clavier de la console en `fr`, fuseau `Europe/Paris`. Modifiables en haut de `install.sh`.

### Bureau (`firstboot/20-hyprland-caelestia.sh`)

- Installe `paru` (compilé depuis les sources, voir plus bas).
- Installe la CLI Caelestia (AUR) puis lance `caelestia install` (Hyprland, shell, dotfiles).
- Installe **greetd + tuigreet** comme écran de connexion (les dotfiles Caelestia n'en fournissent pas).
- Règle la disposition du clavier dans Hyprland (par défaut, celle de la console) dans `~/.config/caelestia/hypr-user.lua`.

### Noyau (`firstboot/30-cachyos-kernel.sh`)

- Fige `quickshell-git` (`IgnorePkg`) pour que le dépôt CachyOS ne le remplace pas : sa version peut être incompatible avec Caelestia.
- Ajoute les dépôts CachyOS (script officiel) et installe `linux-cachyos` + ses en-têtes.
- Place le noyau CachyOS en tête du menu GRUB. Le noyau Arch `linux` reste disponible dans « Advanced options » comme secours.

---

## Structure du dépôt

```
archConfigFiles/
├── bootstrap.sh                     # point d'entrée depuis l'ISO (curl | bash)
├── install.sh                       # phase 1 : disque, Btrfs, pacstrap, chroot
├── chroot/
│   └── 10-system.sh                 # phase 2 : langue, utilisateur, GRUB, Snapper, services
├── firstboot/
│   ├── 10-paru.sh                   # helper AUR
│   ├── 20-hyprland-caelestia.sh     # Hyprland, Caelestia, greetd, clavier
│   └── 30-cachyos-kernel.sh         # noyau CachyOS
├── .gitattributes                   # force les fins de ligne LF
└── README.md
```

Les scripts sont découpés selon **où** ils s'exécutent :

1. **Live (ISO)** : `bootstrap.sh`, `install.sh` (opérations sur le disque).
2. **Chroot** : `chroot/` (configuration du système fraîchement installé, avant son premier démarrage).
3. **Premier démarrage, en utilisateur normal** : `firstboot/` (l'AUR et les dotfiles ne peuvent pas être installés en root).

---

## Personnalisation

### Variables de `install.sh` et `bootstrap.sh`

À placer devant `bash` dans la commande `curl`, par exemple :
`curl -fsSL <url> | KEYMAP=fr bash`

| Variable | Rôle |
|---|---|
| `DISK` | Disque cible (évite la question) |
| `NEW_USER`, `NEW_HOST`, `PASSWORD` | Réponses aux questions (pour automatiser) |
| `TIMEZONE`, `LOCALE`, `KEYMAP` | Fuseau, langue, clavier de la console |
| `ASSUME_YES=1` | Supprime la confirmation d'effacement et la copie du Wi-Fi. **À réserver aux tests en machine virtuelle.** |
| `REPO_URL`, `REPO_BRANCH`, `TARGET_DIR` | Autre dépôt, branche ou dossier (bootstrap) |
| `FORCE=1` | Autorise `bootstrap.sh` hors de l'ISO (bootstrap) |
| `KB_LAYOUT` | Disposition du clavier dans Hyprland (script 20) |

### Config Caelestia / Hyprland

Ne modifie **jamais** `~/.config/hypr/` : les mises à jour de Caelestia l'écraseraient. Les changements personnels vont dans :

- `~/.config/caelestia/hypr-user.lua` : moniteurs, raccourcis, règles de fenêtres, tout ce qui n'est pas géré par Caelestia (syntaxe Lua de Hyprland 0.55+).
- `~/.config/caelestia/hypr-vars.lua` : valeurs par défaut gérées par Caelestia (applications, etc.).
- `~/.config/caelestia/shell.json` : comportement du shell.

Mise à jour de Caelestia : `caelestia update`.

---

## Snapshots et retour en arrière

```bash
sudo snapper -c root list          # liste des snapshots
btrfs subvolume list /             # sous-volumes
```

Si une mise à jour casse le système : au démarrage, dans le menu GRUB, ouvre le sous-menu des snapshots et démarre sur le dernier bon.

**Limite actuelle** : démarrer sur un snapshot te donne un système qui marche, mais en lecture seule avec une couche temporaire. Ce n'est **pas une restauration définitive**. Une procédure de restauration permanente reste à écrire (voir « À faire »).

Un snapshot n'est pas une sauvegarde : il est sur le même disque. Sauvegarde `/home` ailleurs.

---

## Tester en machine virtuelle

Réglages VirtualBox qui ont fonctionné :

- **EFI activé**, disque sur contrôleur **NVMe**, réseau NAT.
- **Disque de 60 Go minimum** : à 20 Go, l'installation du bureau sature le disque (« no space left on device »).
- **8 Go de RAM** si possible (compiler des paquets Qt sur 4 Go est risqué), 4 CPU.
- Prendre un **instantané** de la VM vierge et un autre après l'installation de base pour itérer vite.
- Le copier-coller n'existe pas sur l'ISO : active SSH (`passwd`, `systemctl start sshd`, redirection du port hôte 2222 vers 22 dans VirtualBox) et connecte-toi avec `ssh -p 2222 root@127.0.0.1`.

La VM valide l'installateur, Btrfs, GRUB, paru, l'installation de Caelestia et le noyau. **Elle ne valide pas le rendu du bureau** : Hyprland et le shell Caelestia dépendent de l'accélération graphique et échouent souvent sous VirtualBox (erreurs EGL).

---

## Choix techniques et pièges connus

- **Pas d'`archinstall`** : script maison basé sur `pacstrap`. Le format JSON d'`archinstall` change d'une version à l'autre et ne permettait pas de contrôler finement la disposition Btrfs.
- **`paru` compilé, pas `paru-bin`** : le binaire précompilé est lié à une version précise de `libalpm` et casse quand pacman est plus récent (`libalpm.so.15: cannot open shared object file`).
- **Fins de ligne LF obligatoires** : les scripts écrits sous Windows en CRLF plantent sur Linux. C'est le rôle du `.gitattributes`.
- **Clavier** : `loadkeys` ne marche que sur une vraie console (TTY), pas dans un terminal sous Hyprland. Dans Hyprland, la disposition est un réglage du compositeur (`hypr-user.lua`). Si les raccourcis avec chiffres (Super+1...) ne marchent plus en AZERTY, c'est un piège connu de Hyprland (il faut des codes de touches).
- **Compte root verrouillé** : pour réparer depuis l'ISO, monte le disque Btrfs et utilise `arch-chroot`.

---

## État de validation

| Élément | État |
|---|---|
| Installation de base (Btrfs, GRUB, Snapper) | Validé en VM et sur le G5 KF |
| `paru`, Caelestia, greetd | Validé sur le G5 KF |
| Noyau CachyOS | Installé sur le G5 KF |
| Copie du Wi-Fi vers le système installé | Non validé |
| Langue par défaut en anglais | Non validé |
| Clavier AZERTY automatique dans Hyprland | Non validé |
| Test complet de bout en bout depuis un disque vierge | À refaire avec tous les changements |

---

## À faire

- Profil matériel du G5 KF (NVIDIA / Optimus, Bluetooth, thermique) dans un dossier `machines/`.
- Liste d'applications (`packages/apps.txt`) et script `firstboot/40-apps.sh`.
- Lanceur unique `firstboot/run.sh` qui enchaîne tous les scripts.
- Dotfiles personnels (chezmoi) : suivre `~/.config/caelestia/`, jamais `~/.config/hypr/`.
- Script de restauration définitive d'un snapshot (`rollback`).
- Activer `bluetooth.service`.
- Automatiser les questions de `caelestia install` (options de la CLI à étudier).
- Sauvegarde régulière de `/home` (restic ou borg).

---

## Sécurité

- **Aucun secret** (mots de passe, clés SSH, tokens) dans ce dépôt public, ni dans l'historique Git : un secret supprimé reste lisible dans les anciens commits.
- Le mot de passe du Wi-Fi n'est demandé qu'à l'installation ; il est écrit dans un fichier réservé à root sur le système installé, comme le fait NetworkManager.
