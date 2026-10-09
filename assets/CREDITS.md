# Crédits des assets

## Tout le jeu en 2D dessinée (créé pour CREOS par Hugo avec ChatGPT)

Illustrations, pièces détachées et animations créées spécialement pour CREOS (images générées
avec l'outil de génération d'images de ChatGPT, d'après les briefs de `docs/pour_chatgpt/`).
Importées et allégées par `tools/import_creos_packs.py` (sources dans `D:/dev/CREOS_sources`).

| Dossier | Contenu | Pack d'origine |
|---|---|---|
| `anim/heroes/` | 19 héros : pièces, 213 clips (attaques, techniques secrètes, quatuors, repos, marche, touché, mort, reliques), sons | CREOS_Pack_Animations_Reliques_V2 |
| `anim/heroes/fiches/`, `portraits/` | fiches des 19 héros (portraits découpés automatiquement) | CREOS_5_Nouveaux_Heros_2D, CREOS_7_Nouveaux_Heros_2D_Lot2, CREOS_Quatuor_Murim_2D, lot des 4 premiers héros |
| `anim/enemies/rNN/` | 152 ennemis des 10 mondes de l'acte I (repos, marche, attaque, touché, mort, compétence des boss), sons | CREOS_Ennemis_Region1_Animes, CREOS_MondeNN_Partie1/2 |
| `decors/mondeNN/` | 30 décors de combat (fond, sol, premier plan) + ambiances animées | CREOS_Decors_MondeNN, CREOS_Ambiances_Animees |
| `relics/` | 19 reliques (sprites et icônes) | CREOS_Pack_Animations_Reliques_V2 |
| `hub2d/port/` | Port-Franc en 2D : calques, bâtiments, survols, animations | Port_Franc_Full_2D_Lot1 |
| `npcs2d/marchand_masques/` | le marchand de masques en pièces | Brumenoire_Et_Marchand_2D |

Les sons des packs sont des bruitages synthétisés originaux (convertis en OGG). `scripts/battle/ambience.gd`
et `ambience.gdshader` viennent du pack « Ambiances animées » (créé pour CREOS).

## Icônes (`assets/ui/attacks/`, `assets/ui/hub/`)

Icônes d'attaques tirées de l'image d'impact de chaque clip par `tools/make_attack_icons_from_clips.py` ;
icônes du hub et des monnaies dessinées par `tools/make_hub_icons.py` (pièces d'or, diamant,
énergie, parchemin, coffre, œil, trophée, bouclier, créés par nous) ou reprises des dessins du port.

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
- Coffres et Esprits : pack ChatGPT « CREOS_Coffres_Esprits » (pixel art créé pour le projet).
- Arcanes de la Loge (cartes de tarot, grimoire, icônes de statistiques, illustrations) : pack ChatGPT « CREOS_Arcanes » (pixel art créé pour le projet).
- Les trois invocateurs, salles du Mage runique, du Mécanicien et du Druide (décors, personnages animés, cercles runiques, rouages, effets) : pack ChatGPT « CREOS_Invocateurs » (pixel art créé pour le projet).
