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
- Héros : **dessins 2D animés en marionnettes** (style « fantasy occulte » encrée, comme Cult of the
  Lamb) dans `assets/heroes2d/<id>/` : pièces PNG (head, body, arm_front, arm_back, cape),
  `fiche.png` (dessin complet, sert au portrait) et `puppet.json` (pivots, points d'accroche,
  `pixel_size`, cadrage du portrait). `scripts/battle/puppet_2d.gd` (`Puppet2D`) les assemble et
  anime tout par code ; le champ `"anim"` d'une attaque est un mouvement : punch, kick, slam, spin,
  cast, cast_sky, throw, slash, stab, shoot, pull. Héros actuels : Corbin, Aegis, Brume, Orage.
  Ennemis du marais (`assets/monsters2d/`) et marchand de masques (`assets/npcs2d/`) : même
  système (`"puppet"` dans `monsters.json`, dessinés tournés vers la droite ; `"float"` = lévitation).
  `python tools/compose_puppet.py <dossier> [hauteur_m] [sortie.png]` recolle les pièces pour
  vérifier les points d'attache et donne le `pixel_size`. Décor : packs **KayKit (CC0)** dans
  `assets/kaykit/`.

## Architecture (à respecter)
- `scripts/combat/` = **logique pure** (RefCounted, aucun nœud, aucun affichage), **déterministe**
  avec une graine aléatoire. `BattleEngine.step(delta)` fait avancer le combat ;
  `drain_events()` renvoie les événements (`turn`, `attack` avec son `slot` 0/1/2, `damage`,
  `heal`, `shield`, `status`, `death`, `wave_start`, `victory`, `defeat`).
  **Tour par tour** : quand la jauge d'un héros est pleine (hors Auto), le moteur se fige
  (`awaiting_uid`) jusqu'à `request_attack(uid, slot)`.
- `scripts/hub/` = **Port-Franc**, le hub (scène de démarrage) : `port_franc.gd` place nos modèles
  GLB de `assets/hub/` (en mètres, origine au sol, façade +Z ; tailles dans `manifest.json`),
  bâtiments cliquables, héros qui se promènent, interface, Loge des héros. Direction artistique :
  **héros en pixels, décor propre** (les textures pixel des bâtiments sont lissées en aplats au
  chargement) ; le continent à l'horizon est dans `continent_backdrop.gd`. Bâtiments, boutons et
  actions décrits dans `data/hub.json` ; profil de départ dans `data/player_start.json`.
- **Direction artistique (octobre 2026)** : tout le jeu passe dans **le style des personnages KayKit**
  (formes trapues et arrondies, biseaux, couleurs en aplats d'une palette partagée, pas de
  texture détaillée). Les héros seront refaits sur le **squelette KayKit** (mêmes 41 os) pour
  profiter de ses 76 animations, plus 3 attaques animées par héros. Le brief complet pour
  ChatGPT/Blender est dans `docs/pour_chatgpt/PROMPT_BLENDER_COMPLET.md`. En attendant, les
  héros en pixels et le hub actuel restent en place.
- **Interface** : `scripts/ui/ui_kit.gd` (`UiKit`) = le style commun, d'après la maquette
  `docs/maquette_interfaces/` (ivoire #eee4cd cerclé d'encre #29262e avec ombre dure, bordeaux
  #793b49, laiton #c6a66c, ardoise #505e75, turquoise #63c8be ; police Fredoka ; boutons en relief) ; `UiWindow` = fenêtre de jeu avec ruban
  de titre et croix. Tout nouvel écran les utilise. Écrans du hub : Loge des héros (`HeroesScreen` :
  collection filtrable, fiche avec Force, amélioration contre de l'or, étoiles/évolution avec les
  fragments du héros, règles dans `Progression`), Profil (clic sur le profil en haut à gauche), Primes du jour (`QuestsScreen`, règles pures dans `scripts/core/quests.gd`,
  données dans `data/quests.json`, événements notés par `PlayerData.record_event()`), Loge,
  Autel des Reliques (invocations, `data/summon.json`).
- **Port-Franc en 2D** (`scripts/hub/port_franc_2d.gd`, images dans `assets/hub2d/port/`) : un
  « théâtre » de calques posés à différentes distances de la caméra (parallaxe en glissant),
  bâtiments cliquables avec leur image de survol, animations en planches de sprites
  (`Nom_8f_10fps.png`), héros marionnettes qui se promènent. Ordre de dessin explicite
  (`render_priority`) : fond < place < objets triés par leur point au sol < premier plan.
  L'ancien port 3D (`port_franc.gd`) ne sert plus que si ces images sont absentes.
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
