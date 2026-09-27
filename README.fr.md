# Randomizer et navigateur de jeux pour MiSTer FPGA

*[English](README.md) · [Español](README.es.md) · Français · [Polski](README.pl.md) · [Svenska](README.sv.md)*

Deux outils qui partagent un petit serveur web sur la MiSTer, tous deux
conçus pour être utilisés depuis un téléphone :

**La page des seeds** : un générateur de seeds et un tracker sans spoiler
pour *A Link to the Past Randomizer* et *SMZ3* (Super Metroid + ALTTP
combinés). La carte montre où vous êtes passé et, c'est tout l'intérêt,
ce que vous pouvez réellement atteindre avec ce que vous avez sur vous. La
logique d'accès est **celle d'Archipelago**, le même ensemble de règles
qui a généré la seed.

**Le navigateur de jeux** : tous les jeux de votre MiSTer sous forme de
liste sur votre téléphone. Touchez un jeu et la MiSTer change de core et
le lance. Les systèmes qui n'ont que quelques jeux sont regroupés derrière
une seule tuile pour que la page d'accueil reste lisible.

> **Aucune ROM n'est incluse, et aucune ne peut l'être.** Le navigateur
> affiche ce qui se trouve déjà sur votre propre carte SD ; si vous n'y
> avez aucun jeu, la liste est vide. Il en va de même pour les ROM de base
> utilisées pour générer les seeds : ce doivent être vos propres dumps.
> Voir *Vos propres ROM* plus bas.


<p align="center">
  <img src="docs/seed-page.png" alt="La page des seeds avec deux parties côte à côte" width="900">
</p>

<p align="center">
  <img src="docs/map-light-world.png" alt="La carte du Monde de la Lumière avec les compteurs de donjons" width="440">
  <img src="docs/map-zebes.png" alt="La carte de Zebes avec les emplacements ramassés" width="440">
</p>

<p align="center">
  <em>Vert : accessible maintenant, rouge : bloqué, gris : terminé. Les
  pastilles comptent les coffres restants dans chaque donjon. Les boss sont
  des losanges, qui deviennent gris dès qu'ils tombent. Affiché ici en
  suédois ; l'anglais, l'espagnol, le français et le polonais sont aussi
  inclus.</em>
</p>

<p align="center">
  <img src="docs/item-grid.png" alt="Une carte ALTTPR et une carte SMZ3 côte à côte, chacune avec sa grille d'objets" width="900">
</p>

<p align="center">
  <em>Ce que vous avez ramassé, allumé une fois trouvé, avec la quantité
  dans le coin ; une carte SMZ3 montre les deux jeux. Les icônes de
  l'image sont la copie personnelle du joueur ; voir
  <a href="#ce-qui-nest-pas-inclus">Ce qui n'est pas inclus</a>.</em>
</p>

<p align="center">
  <img src="docs/leaderboard-smz3.png" alt="Le classement SMZ3 : cinq seeds terminées classées par temps total, avec les temps Zelda et Metroid de chacune" width="900">
  <img src="docs/leaderboard-alttpr.png" alt="Le classement ALTTPR avec une seed terminée" width="900">
</p>

<p align="center">
  <em>Un classement par jeu, la seed terminée la plus rapide en premier.
  SMZ3 affiche le temps de chaque moitié à côté du total, les mêmes temps
  que ceux du générique de fin. « ≈ » signale un temps lu après coup dans
  la sauvegarde plutôt qu'à l'arrivée.</em>
</p>

<p align="center">
  <img src="docs/game-browser.png" alt="Le navigateur de jeux avec tous les systèmes de la carte" width="900">
</p>

---

## Ce dont vous avez besoin

**Deux machines, pas plus :**

1. Une **MiSTer FPGA** sur votre réseau.
2. Un serveur **Home Assistant** : *Home Assistant OS* ou *Supervised*.
   C'est une exigence stricte : HA Container et HA Core ne peuvent pas
   installer de modules complémentaires, et la logique en est un.

### Vos propres ROM

Le navigateur de jeux n'a besoin de rien : il affiche les jeux que vous
avez déjà dans `/media/fat/games/`.

**La génération de seeds** a besoin de deux dumps sans en-tête, que vous
devez posséder et avoir dumpés vous-même :

```
alttp.smc   1 048 576 octets   md5 03a63945398191337e896e5771f77173
sm.smc      3 145 728 octets   md5 21f3e98df4780ee1c667b84e57d88675
```

(Zelda 3 japonais 1.0 et Super Metroid JU respectivement.) L'installateur
les cherche parmi vos propres ROM SNES, y compris dans des fichiers `.zip`
et même s'ils ont un en-tête de 512 octets ; en général, vous n'avez donc
rien à faire.

---

## Installation

Les deux moitiés sont indépendantes et peuvent être installées dans
n'importe quel ordre. Commencez tout de même par Home Assistant :
l'installateur de la MiSTer pourra alors vérifier que la logique répond
avant d'annoncer qu'il a terminé.

### 1. Home Assistant

1. **Paramètres → Modules complémentaires → Boutique des modules complémentaires**
2. Menu en haut à droite → **Dépôts** → collez :
   ```
   https://github.com/frystien-png/mister-randomizer
   ```
3. Fermez la fenêtre, trouvez **SMZ3 and ALTTPR logic** → **Installer**
4. Onglet **Configuration** → saisissez l'adresse IP de la MiSTer → **Enregistrer**
5. **Démarrer**

La première compilation prend quelques minutes : c'est à ce moment
qu'Archipelago est téléchargé et allégé.

*Sans GitHub :* copiez le dossier `smz3-logic/` dans `/addons/` de Home
Assistant (via le module Samba ou SSH), choisissez **Rechercher des mises
à jour** dans le menu de la boutique, et il apparaît sous **Modules
complémentaires locaux**.

### 2. MiSTer

Placez **un seul fichier** dans `/media/fat/Scripts/` sur la carte SD ; il
télécharge le reste lui-même :

```
https://raw.githubusercontent.com/frystien-png/mister-randomizer/main/mister/Randomizer_install.sh
```

Lancez ensuite **Scripts → Randomizer_install** depuis le menu de la
MiSTer.

*Sans internet sur la MiSTer :* placez `randomizer-payload.tar.gz` à côté
du script, il sera utilisé à la place du téléchargement.

L'installateur trouve Home Assistant tout seul, dépose les fichiers, vous
demande la langue souhaitée, crée les entrées du menu, configure le
démarrage automatique et lance le serveur. Vous pouvez le relancer à tout
moment : vos notes, vos repères sur la carte et vos temps d'arrivée ne
sont pas touchés, et une installation existante n'est pas écrasée.

---

## Langue

Les pages sont traduites au moment où elles sont servies. L'anglais est la
langue par défaut ; l'installateur pose la question et le choix est
enregistré dans `.mistergames/randomizer.conf` :

```
MISTER_LANG="fr"
```

Modifiez cette ligne et redémarrez la MiSTer pour changer de langue ;
inutile de réinstaller.

| Code | Langue |
|---|---|
| `en` | English *(la langue source, et celle par défaut)* |
| `es` | Español |
| `fr` | Français |
| `pl` | Polski |
| `sv` | Svenska |

### Ajouter votre propre langue

Tout ce qu'il faut se trouve déjà sur la MiSTer, dans
`/media/fat/Scripts/.mistergames/lang/` :

1. Copiez `TEMPLATE.json` vers `<code>.json`, par exemple `de.json`.
2. Mettez dans `__name` le nom de la langue dans cette langue (`"Deutsch"`).
3. Traduisez la partie **droite** de chaque ligne. La partie gauche est le
   texte source anglais et ne doit jamais être modifiée : c'est la clé
   recherchée dans la page.
4. Ce que vous laissez de côté reste simplement en anglais, donc une
   traduction à moitié faite est parfaitement utilisable.
5. Relancez l'installateur et choisissez votre langue dans le menu : il
   liste tous les fichiers présents dans le dossier.

Deux outils se trouvent à côté des fichiers de langue :

```
python3 lang_check.py          vérifie tous les fichiers de langue
python3 lang_extract.py        régénère le modèle à partir des pages
```

C'est `lang_check.py` qu'il vaut la peine de lancer. Il indique quelle
part du modèle vous avez couverte, et il échoue sur les deux erreurs qui
cassent vraiment quelque chose : une clé absente des pages (presque
toujours une faute de frappe ; un espace final manquant suffit) et une clé
également utilisée comme classe CSS ou nom de fichier, ce qui traduirait
la mécanique de la page au lieu de son texte.

Les noms d'objets de Zelda (Arc, Grappin, Perle de lune) sont traduits
dans toutes les langues. Ceux de Super Metroid (Morph Ball, Screw Attack,
missiles) restent **en anglais partout** : le jeu lui-même n'a jamais été
traduit, et les joueurs connaissent ces noms en anglais, quelle que soit
leur langue.

Les traductions peuvent contenir des apostrophes et des guillemets
(`l'écran`, `¿Qué?`) : ils sont échappés selon l'endroit où ils
atterrissent.

---

## Utilisation

| | |
|---|---|
| **Navigateur de jeux** | `http://<ip-de-la-mister>:8182/` |
| **Page des seeds** | `http://<ip-de-la-mister>:8182/seeds` |
| **Retour au menu** | le bouton `⏏ Menu` dans l'en-tête, visible pendant qu'un jeu tourne |
| **Nouvelle seed ALTTPR** | menu de la MiSTer → Scripts → `ALTTPR_new_seed` |
| **Nouvelle seed SMZ3** | menu de la MiSTer → Scripts → `SMZ3_new_seed` |

Ajoutez les deux pages à Home Assistant sous forme de cartes **page web**
avec l'adresse de la MiSTer, et vous pourrez les ouvrir depuis votre
téléphone.

Les jeux dans des archives `.zip` fonctionnent comme les fichiers isolés :
le lanceur résout le chemin à l'intérieur de l'archive, ce qu'exige un
MGL. Une collection qui mélange les deux ne pose aucun problème.

Le navigateur réindexe les dossiers de jeux toutes les quinze minutes, et
immédiatement si vous appelez `http://<ip-de-la-mister>:8182/api/rescan`.
Les nouveaux jeux apparaissent d'eux-mêmes, sans redémarrage.

---

## Lecture en direct (SNI)

L'installateur propose de configurer **SNI**, qui permet au serveur de
lire directement la mémoire du jeu. La carte se met alors à jour **pendant
que vous jouez**, et pas seulement quand vous ouvrez le menu OSD.

Cela repose sur une prise en charge qui existe déjà dans le core SNES
officiel de MiSTer (depuis mars 2026) et dans le programme principal
(depuis avril). Ce qui manque, c'est le démon
[`snid`](https://github.com/NobodyNada/snid), que l'installateur télécharge
et vérifie avec une somme de contrôle connue.

**Une étape à faire vous-même, une seule fois :** lancez un jeu SNES,
ouvrez le menu OSD et choisissez **UART MODE → SNI**. Le mode est envoyé
au core par le menu, pas par un fichier, on ne peut donc pas le faire à
votre place. Le choix est enregistré par core et restauré automatiquement
ensuite.

Vérifiez que cela fonctionne avec `curl http://<mister>:8182/api/smz3` :
le champ `live` doit valoir `true` pour la seed en cours.

⚠️ Sur une MiSTer déjà ancienne, le fichier système `/usr/sbin/uartmode`
peut être trop vieux et ne pas connaître le mode SNI. L'installateur le
détecte et demande avant de toucher à quoi que ce soit ; l'original est
conservé sous le nom `uartmode.original` sur la carte SD. Une future mise
à jour du firmware peut écraser la modification : relancez simplement
l'installateur.

Si vous passez SNI, rien d'autre ne change ; la sauvegarde reste la
source.

---

## À savoir d'emblée

**Sans SNI, la sauvegarde n'est écrite que lorsque vous ouvrez le menu
OSD.** C'est à ce moment-là que la MiSTer écrit la mémoire de sauvegarde
du jeu sur la carte SD, pas en continu. Le tracker ne peut donc rien voir
de ce que vous avez fait depuis la dernière ouverture du menu. Une
habitude à prendre : **ouvrez et fermez l'OSD après avoir sauvegardé.**

Pour la même raison : **ne lancez pas un nouveau jeu depuis le navigateur
en pleine partie** sans avoir ouvert l'OSD auparavant. Le changement de
core est immédiat et tout ce qui suit la dernière écriture est perdu ;
cela vaut pour tous les jeux, pas seulement les seeds du randomizer. Ce
n'est pas corrigeable par logiciel : `/dev/MiSTer_cmd` ne comprend que
`load_core` et quelques commandes vidéo et audio, sans moyen d'ouvrir le
menu ni de demander une sauvegarde.

**Donnez des adresses fixes aux deux machines** dans votre routeur. Si
l'une change d'IP, elles ne se trouvent plus, et cela se voit à une carte
qui ne se met plus à jour, pas à un message d'erreur.

---

## En cas de problème

| Symptôme | Cause probable |
|---|---|
| La page ne répond pas du tout | Le serveur ne tourne pas. Relancez `Randomizer_install`. |
| Un jeu démarre mais l'écran reste noir | Presque toujours les réglages vidéo de la MiSTer elle-même, pas ceci. Un `video_mode` fixe combiné à `vsync_adjust=1` sort du 50 Hz pour les jeux PAL, et beaucoup de téléviseurs refusent ce mode : le jeu tourne, vous ne le voyez simplement pas. Regardez le dossier des sauvegardes : si `saves/<core>/<jeu>.eep` ou `.sra` est apparu, la ROM a bien été chargée. Corrigez avec `vsync_adjust=0` dans `MiSTer.ini`. |
| La carte s'affiche mais les points n'ont pas de couleur | Le module complémentaire ne répond pas. Vérifiez son journal et `mister_ip`. |
| La carte ne se met pas à jour après avoir joué | Vous n'avez pas ouvert l'OSD. La sauvegarde n'a pas été écrite. |
| Des parties de la page sont en anglais | Ce fichier de langue ne traduit pas encore ces textes ; ils restent en anglais. Lancez `lang_check.py`. |
| « Mauvaise ROM » pour le bon jeu | Vous avez un autre dump. Comparez le md5 avec la liste ci-dessus. |
| Rien ne se passe après le redémarrage de la MiSTer | `user-startup.sh` ne doit pas s'appeler `_user-startup.sh`. |
| Le téléchargement échoue sur la MiSTer | Liste de certificats obsolète. Lancez **Scripts → update_all** une fois, ou placez `randomizer-payload.tar.gz` à côté du script. |

Journal sur la MiSTer : `/tmp/mistergames.log`.
Service de logique : `curl http://<home-assistant>:8183/health`.

**Toujours bloqué, ou une idée ?** Posez la question dans
[Discussions](https://github.com/frystien-png/mister-randomizer/discussions).
Questions, demandes et « voici comment j'ai monté le mien » sont les
bienvenus ; pas besoin d'ouvrir une issue.

---

## Ce qui n'est *pas* inclus

**Aucune ROM, aucune image disque, rien de protégé par le droit
d'auteur.** Le paquet ne contient que du code et des tables de données.
C'est garanti par `check_payload.sh`, qui s'exécute à chaque compilation
et refuse d'empaqueter tout ce qui ressemble à une ROM. Vous pouvez le
lancer vous-même sur le fichier téléchargé :

```
./check_payload.sh randomizer-payload.tar.gz
```

Il rejette les extensions de ROM, tout ce qui se trouve dans
`randomizer/base/` sauf la note, les fichiers de plus de 400 K, les
binaires de type inconnu, les secrets et tout état utilisateur non vide.
Il refuse aussi les **informations réseau privées** (adresses RFC 1918,
adresses MAC, noms de partages, jetons et clés) afin que le réseau
domestique de personne ne fuite avec une version.

Également hors du paquet : l'état du core envoyé à Home Assistant
(`ha_push.py`) et le montage NAS des disques PS1/Saturn (`nas_mount.sh`).
Le navigateur affiche tout ce qui est monté sous `/media/fat/games/`, donc
votre propre montage réseau fonctionne, mais sa mise en place vous
revient.

Si vous avez déjà votre propre `page.py`, l'installateur n'y touche pas et
dépose le sien à côté sous le nom `page.py.new`.

**Pas d'icônes d'objets.** Chaque carte de seed contient une grille de ce
que vous avez ramassé, disposée comme dans les trackers de la communauté.
Les icônes sont les graphismes des jeux eux-mêmes et ne peuvent donc pas
être fournies ; sans elles, chaque case affiche un mot court et la grille
fonctionne de la même façon. Pour avoir des images, placez des PNG en
32×32 dans un dossier `items/` à côté de la page des seeds (dans Home
Assistant, `/config/www/items/`). Les noms de fichiers sont ceux que
demandent `invZelda`/`invMetroid` dans `seedpage.py` : `bow1.png`,
`sword3.png`, `sm-Morph.png`, etc.

---

## Licence et remerciements

Ce projet est sous **licence MIT** ; voir [LICENSE](LICENSE). Utilisez-le,
modifiez-le, redistribuez-le ; conservez la mention de copyright et
n'attendez aucune garantie.

Il repose sur le travail d'autres personnes :

| | |
|---|---|
| [Archipelago](https://github.com/ArchipelagoMW/Archipelago) (MIT) | la logique d'accès elle-même. Le module complémentaire la fige sur un commit précis et répond avec ses règles, pas avec les nôtres. |
| [hutchch/ALTTPR-Tracker](https://github.com/hutchch/ALTTPR-Tracker) (MIT) | la table des coffres qui associe chaque emplacement d'ALTTP à son indicateur exact en SRAM, et la façon de gérer le choix du médaillon. |
| [TotalSMZ3](https://github.com/tewtal/SMZ3Randomizer) | la logique de SMZ3 et la structure de ROM que suit la version combinée. |
| [pyz3r](https://github.com/tcprescott/pyz3r) (Apache-2.0) | trois fichiers intégrés pour appliquer les patchs ALTTPR. Modifié : aiohttp remplacé par urllib, car la MiSTer n'a pas pip. La licence et le NOTICE sont fournis dans le paquet. |
| [bps](https://pypi.org/project/bps/) (WTFPL) | application de patchs BPS intégrée. COPYING est fourni dans le paquet. |
| [snid](https://github.com/NobodyNada/snid) par NobodyNada | le démon qui rend possible la lecture en direct de la mémoire SNES. Téléchargé à la demande, jamais inclus. |
| alttpr.com et samus.link | la génération des seeds et les sprites. Seules des données de patch sont échangées ; aucune ROM n'est jamais envoyée. |
| Les captures d'écran | Les cartes sous les points sont les illustrations des jeux eux-mêmes (© Nintendo) ; la carte de Zebes est l'œuvre de Falcon Zero. Elles illustrent le tracker ; aucune donnée de jeu n'est fournie avec ce projet. |

**Aucune donnée de jeu d'aucune sorte n'est incluse** ; voir la section
*Ce qui n'est pas inclus* ci-dessus.

## Pour qui veut bâtir là-dessus

```
├── repository.yaml          doit être à la racine - HA le cherche là
├── smz3-logic/              le module complémentaire lui-même
│   ├── config.yaml          options, ports, architectures
│   ├── Dockerfile           télécharge et allège Archipelago
│   └── logic/               reachd.py, smz3_logic.py, alttp_locmap.py
├── mister/
│   ├── Randomizer_install.sh
│   └── randomizer-payload.tar.gz
├── build_payload.sh         reconstruit le paquet depuis une MiSTer en marche
└── check_payload.sh         le garde-fou : pas de ROM, pas de secrets, pas d'infos réseau local
```

La MiSTer fait foi pour le paquet : le code y vit, et `build_payload.sh`
le rapatrie en laissant de côté tout ce qui est personnel : ROM, mots de
passe, notes privées. Il refuse de s'exécuter sans adresse :

```
./build_payload.sh 192.168.1.50
echo 192.168.1.50 > .mister-ip     # ignoré par git, mémorisé pour la prochaine fois
```

Rien n'est empaqueté tant que le garde-fou ne s'est pas prononcé. S'il
trouve quelque chose, la compilation s'arrête et le tarball existant reste
intact.

L'installateur peut être testé sans toucher à une installation réelle :

```
FAT=/tmp/prov ./Randomizer_install.sh
```

Rien de ce qui tourne n'est touché, et tout atterrit sous `/tmp/prov`.
