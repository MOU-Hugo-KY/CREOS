# CREOS — instructions pour Claude

Jeu mobile RPG « chasseurs de héros » inspiré de *Dungeon Boss* (2015), avec un univers 100 % original.
L'utilisateur (Hugo) parle français : **réponds en français**, simplement, sans jargon inutile.

## À lire d'abord
- `docs/GDD.md` : l'univers (CREOS, Morvath le Mage Noir, régions, héros, rareté, combat).
- `docs/ROADMAP.md` : ce qui est fait et la prochaine étape (coche les cases au fur et à mesure).

## Stack
- **Godot 4.7** (GDScript, rendu « Mobile »), paysage 1920×1080, cible Android/iOS.
- Autoload `GameData` (`scripts/core/game_data.gd`) charge `data/*.json`.
- Autoload `PlayerData` (`scripts/core/player_data.gd`) : **la sauvegarde** (`user://save.json`) :
  or, gemmes, énergie (se recharge avec le temps), niveau de la loge, héros possédés (niveau, XP),
  équipe de chasse (4 max), objets, étoiles par donjon. Règles pures et testées dans
  `scripts/core/progression.gd`, chiffres dans `data/progression.json`. Les tests et l'outil de
  capture appellent `PlayerData.use_memory_only()` pour ne jamais toucher la vraie sauvegarde.
- Autoload `GameSettings` (`scripts/core/game_settings.gd`) : volumes Général / Musique / Effets
  (bus audio du même nom), enregistrés dans `user://settings.cfg`. Bouton SON en jeu.
- Héros : **nos modèles chibi** dans `assets/heroes/` (7 clips chacun : `Idle`, `Walk`, `Hit`,
  `Death`, `Attack_01…03`). Monstres et décor : packs **KayKit (CC0)** dans `assets/kaykit/`.

## Architecture (à respecter)
- `scripts/combat/` = **logique pure** (RefCounted, aucun nœud, aucun affichage), **déterministe**
  avec une graine aléatoire. `BattleEngine.step(delta)` fait avancer le combat ;
  `drain_events()` renvoie les événements (`turn`, `attack` avec son `slot` 0/1/2, `damage`,
  `heal`, `shield`, `status`, `death`, `wave_start`, `victory`, `defeat`).
  **Tour par tour** : quand la jauge d'un héros est pleine (hors Auto), le moteur se fige
  (`awaiting_uid`) jusqu'à `request_attack(uid, slot)`.
- `scripts/hub/` = **Port-Franc**, le hub (scène de démarrage) : décor en blocs (`port_franc.gd`,
  `blocks.gd`), bâtiments cliquables, héros qui se promènent, interface. Bâtiments, boutons et
  actions décrits dans `data/hub.json` ; profil de départ dans `data/player_start.json`.
- `scripts/battle/` = **affichage** : lit les événements et anime. Ne met jamais de règle de jeu ici.
  `battle_scene.gd` (chef d'orchestre), `unit_view.gd` (un personnage), `marsh_level.gd` (décor),
  `battle_fx.gd` (effets), `battle_audio.gd` (sons), `ui/` (interface et écran de fin).
  Le moteur applique les dégâts tout de suite ; l'affichage les montre à l'instant `hit_time`.
- **Les données vont dans `data/*.json`** (héros, monstres, donjons, régions), pas dans le code.
  Un nouveau héros = une entrée JSON (+ un modèle 3D), sans toucher au moteur si ses effets existent.
- Icônes d'attaque : `assets/ui/attacks/<id>.png`, dessinées par `python tools/make_attack_icons.py`
  (une fonction par attaque ; en ajouter une pour chaque nouvelle attaque de héros).
- **3 attaques par héros** dans `"attacks"` : [0] base, [1] à recharge (`"cooldown"`),
  [2] ultime (`"energy"`). Chaque attaque : `id`, `name`, `description`, `anim`, `hit_time`,
  `target`, `effects`. Les monstres peuvent n'en avoir qu'une (sans `effects` = dégâts ×1).
  Options : `hit_times` (plusieurs coups), `fx` (effet visuel), `dash: false` (ne court pas).
  Un effet peut avoir sa propre `target` (ex. foudre qui se propage à `all_enemies`).
- Héros : nos modèles chibi dans `assets/heroes/<nom>/` (`.glb` + `integration.json` d'origine).
  `"anims"` donne les noms des clips repos/course/touché/mort, `"portrait"` le cadrage.
- Effets d'attaque supportés : `damage`, `heal`, `shield`, `taunt`, `stun`, `dot`, `cleanse`.
  Cibles : `single_enemy`, `all_enemies`, `lowest_hp_enemy`, `all_allies`, `lowest_hp_ally`, `self`.

## Commandes
```bash
godot --headless --path . --import                              # (ré)importer les assets
godot --headless --path . --script res://tests/run_tests.gd     # tests du moteur de combat
godot --headless --path . --script res://tests/smoke_battle.gd  # la scène de combat va jusqu'au bout
godot --headless --path . --script res://tests/smoke_hub.gd     # le hub se charge et mène au combat
godot --path .                                                  # lancer le jeu
godot --path . --resolution 1280x720 --script res://tools/screenshot.gd  # capture -> docs/
#   options après `--` : --scene=res://scenes/hub/hub.tscn --shots=200,600 --auto --end --out=…
```
Sous Windows, `godot` = le chemin de l'exécutable installé par `tools/setup-windows.ps1`.

**Avant chaque commit** : lance les trois tests ci-dessus, ils doivent passer.
Si tu changes l'équilibrage (stats, formules), regarde la ligne « victoires : X/20 » des tests.

## Outils MCP prévus (installés par `tools/setup-*.ps1|sh`)
- `godot` (Coding-Solo/godot-mcp) : lancer l'éditeur ou le jeu, lire les erreurs de debug.
- `blender` (mcp-for-blender) : modéliser et retoucher les héros, exporter en `.glb`.
- Connecteur **Higgsfield** (compte claude.ai, s'il est disponible) : `generate_image` pour les
  concepts de héros, puis `generate_3d` (image → `.glb`).

## Règles du projet
- **Ne jamais copier** de nom, de personnage, d'image ou de texte de Dungeon Boss (propriété de
  Netflix/Boss Fight). On reprend seulement les **mécaniques**.
- **Pas de pay-to-win** : tout héros doit pouvoir s'obtenir en jouant (voir GDD §6).
- Les assets ajoutés doivent être sous **licence libre (CC0 / CC-BY)** ou créés par nous ; note la
  source dans `assets/CREDITS.md`.
- Code et commentaires en français, noms de variables en anglais.
- Les fichiers `.import` sont commités ; le dossier `.godot/` ne l'est pas.
