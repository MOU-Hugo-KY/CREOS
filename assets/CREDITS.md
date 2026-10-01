# Crédits des assets

## Héros (`assets/heroes/`)

Modèles 3D chibi originaux créés pour CREOS (fournis par Hugo) : Barbare, Ronin, Alchimiste de la
peste, Moine des éclairs, Chevalier possédé (en réserve, pas encore jouable). Version « prises
d'armes corrigées » : les armes suivent les os `held_weapon_L` / `held_weapon_R`. Chaque dossier garde le `integration.json` d'origine (clips, instants
d'impact) et un `apercu.png`.

## Icônes (`assets/ui/attacks/`, `assets/ui/hub/`)

Dessinées pour CREOS par `tools/make_attack_icons.py` et `tools/make_ui_icons.py` (pixel art
32 × 32, créé par nous).

## Port-Franc, lot 1 du générateur Blender (`assets/hub/lot1/`)

11 bâtiments générés par `tools/blender/port_franc_lot1/build_port_franc.py` (script écrit pour
CREOS, lancé avec Blender 5.2) : Loge des héros, Ma loge, Marché, Table des chasses, Autel des
Reliques, et 6 maisons à thème (boulangerie, forge, taverne, pêcheur, herboriste, cartographe).
Textures cuites par Cycles dans un atlas partagé (`textures/`, BaseColor, Normal, ORM) ; les GLB
sont livrés sans leurs images (`tools/blender/strip_glb_images.py`), le jeu applique l'atlas.

## Décor de Port-Franc (`assets/hub/`)

15 modèles GLB originaux créés pour CREOS (fournis par Hugo) : Loge des héros, Ma loge, 3 maisons,
Marché, Table des chasses, Autel des Reliques (nœud `Cristal` animé par le jeu), Tour de Morvath
(40 m), ponton, bateau, lampadaire, arbre, tonneau, caisses. `manifest.json` donne les tailles ;
aperçus dans `apercus/`. Le sol (dalles KayKit), la mer, les remparts et les montagnes sont
ajoutés par `scripts/hub/port_franc.gd`.

## Monstres et décor

| Dossier | Pack | Auteur | Licence | Source |
|---|---|---|---|---|
| `kaykit/dungeon` | KayKit Dungeon Remastered 1.0 | Kay Lousberg | CC0 | https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 |
| `kaykit/adventurers` | KayKit Character Pack: Adventurers 1.0 | Kay Lousberg | CC0 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 |
| `kaykit/skeletons` | KayKit Character Pack: Skeletons 1.0 | Kay Lousberg | CC0 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 |
| `kaykit/prototype` | KayKit Prototype Bits 1.0 | Kay Lousberg | CC0 | https://github.com/KayKit-Game-Assets/KayKit-Prototype-Bits-1.0 |

Seuls les fichiers glTF/GLB et leurs textures ont été copiés (sans les versions FBX/OBJ).
CC0 = domaine public : utilisation libre, même commerciale. Créditer reste une bonne pratique.

## Sons et musiques (`assets/audio/`)

| Fichier(s) | Pack / morceau | Auteur | Licence | Source |
|---|---|---|---|---|
| `sfx/swing_*`, `sfx/throw` | RPG Audio | Kenney | CC0 | https://kenney.nl/assets/rpg-audio |
| `sfx/hit_*`, `sfx/hit_heavy_*`, `sfx/death_*` | Impact Sounds | Kenney | CC0 | https://kenney.nl/assets/impact-sounds |
| `sfx/heal`, `sfx/shield`, `sfx/ui_*` | Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds |
| `sfx/magic_*`, `sfx/ultimate_impact` | Sci-fi Sounds | Kenney | CC0 | https://kenney.nl/assets/sci-fi-sounds |
| `sfx/wave_start`, `music/victory`, `music/defeat` | Music Jingles | Kenney | CC0 | https://kenney.nl/assets/music-jingles |
| `music/battle_loop.ogg` | Determined Pursuit (epic orchestra loop) | Emma_MA | CC0 | https://opengameart.org/content/determined-pursuit-epic-orchestra-loop |
| `music/boss_loop.ogg` | Dark Shrine Loop | qubodup | CC0 | https://opengameart.org/content/dark-shrine-loop |
| `music/town_loop.ogg` | Town Theme RPG | cynicmusic | CC0 | https://opengameart.org/content/town-theme-rpg |

Les fichiers ont été renommés pour le jeu (le nom d'origine est dans le pack). `battle_loop.ogg` a été
converti de WAV en OGG (ffmpeg, qualité 4).

## Police

| Dossier | Police | Auteur | Licence | Source |
|---|---|---|---|---|
| `fonts/Fredoka.ttf` | Fredoka (variable) | The Fredoka Project Authors | SIL OFL 1.1 (`fonts/OFL.txt`) | https://github.com/google/fonts/tree/main/ofl/fredoka |
