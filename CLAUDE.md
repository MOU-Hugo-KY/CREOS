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
  équipe de chasse (7 max : 2 devant, 3 au milieu, 2 à l'arrière), objets, étoiles par donjon. Règles pures et testées dans
  `scripts/core/progression.gd`, chiffres dans `data/progression.json`. Les tests et l'outil de
  capture appellent `PlayerData.use_memory_only()` pour ne jamais toucher la vraie sauvegarde.
- Autoload `GameSettings` (`scripts/core/game_settings.gd`) : volumes Général / Musique / Effets
  (bus audio du même nom), enregistrés dans `user://settings.cfg`. Bouton SON en jeu.
- **Tout le jeu est en 2D dessinée.** Animations en pièces détachées livrées par ChatGPT, importées
  par `python tools/import_creos_packs.py [D:/dev/CREOS_sources]` (sources hors du dépôt) en
  « clips » JSON compacts : chaque image = liste de commandes de dessin (pièce PNG + position,
  rotation, transparence ; traits ; anneaux), origine (0, 0) = point au sol de l'acteur.
  `scripts/anim/clip_player.gd` (`ClipPlayer`, Node2D) les joue partout (combat, hub, Loge, Lanterne).
  - Héros (19) : `assets/anim/heroes/` — clips `<id>_idle/_walk/_hurt/_death/_relic`, attaques
    `<id>_0/_1/_2` (base, compétence, ultime), techniques secrètes `<id>_3/_4/_5` (une par voie),
    `quatuor_0..3` ; `fiches/` (dessin complet) et `portraits/` (têtes, découpées automatiquement).
  - Ennemis (152, 10 mondes) : `assets/anim/enemies/rNN/` — `<id>_idle/_walk/_attack/_hurt/_death`,
    `_skill` pour les boss. Ils regardent à gauche.
  - Décors de combat : `assets/decors/mondeNN/` (fond1-3, sol, premier plan, ambiance1-3.json lue
    par `scripts/battle/ambience.gd`). Cadre 1280 × 720, pieds vers y = 590.
    Les 30 arènes jouées sont peintes (ChatGPT) : `areneN.png` en 1920 × 1080 (N = 1 entrée, 2 profondeur,
    3 boss) + `areneN.json` ; prompts et images de référence dans `docs/pour_chatgpt/decors/`.
  - Reliques : `assets/relics/`.
  - `python tools/render_clip.py` dessine un clip en image (vérifier sans Godot) ;
    `python tools/make_attack_icons_from_clips.py` refait les icônes d'attaque ;
    `python tools/build_game_data.py` régénère heroes/monsters/dungeons/regions/relics.json depuis la
    fiche de combat (`CREOS_Donnees_Combat.json`) et la table des effets en tête du script.

## Architecture (à respecter)
- `scripts/combat/` = **logique pure** (RefCounted, aucun nœud, aucun affichage), **déterministe**
  avec une graine aléatoire. `BattleEngine.step(delta)` fait avancer le combat ;
  `drain_events()` renvoie les événements (`turn`, `attack` avec son `slot` 0/1/2, `damage`,
  `heal`, `shield`, `status`, `death`, `wave_start`, `victory`, `defeat`).
  **Tour par tour** : quand la jauge d'un héros est pleine (hors Auto), le moteur se fige
  (`awaiting_uid`) jusqu'à `request_attack(uid, slot)`.
- `scripts/hub/` = **Port-Franc**, le hub (scène de démarrage `scenes/hub/hub.tscn`, `hub_scene.gd`). La place est
  en pixel art vue de dessus (`hub_pixel.gd`, `HubPixel`, carte 1280 × 720 décrite par `assets/hub_px/hub_layout.json`) :
  sol, bâtiments et objets triés par leur pied, effets animés (cristal, flammes, bannières), lumières, cycle jour/nuit
  (aube, jour, crépuscule, nuit, d'après l'heure réelle ou le bouton « Jour / nuit »), héros de l'équipe qui se
  promènent ; toucher un bâtiment ouvre son service. `hub_fx.gd` (`HubFx`) ajoute les effets pixelfx de la place
  (`data/pixelfx_hub.json` : papillons, oiseaux, feux follets, et effets plein écran lucioles / rayons / averse, dont
  la bande de sol est coupée par `crop_bottom`). `hub_hud.gd` = l'interface (ruban du haut, boutons du bas, écrans).
  Bâtiments et actions : `data/hub.json` (l'Échoppe des masques est le Marchand). Profil de départ : `data/player_start.json`.
- **Interface** : `scripts/ui/ui_kit.gd` (`UiKit`) = le style commun, d'après la maquette
  `docs/maquette_interfaces/` (ivoire #eee4cd cerclé d'encre #29262e avec ombre dure, bordeaux
  #793b49, laiton #c6a66c, ardoise #505e75, turquoise #63c8be ; police Fredoka ; boutons en relief) ; `UiWindow` = fenêtre de jeu avec ruban
  de titre et croix. Tout nouvel écran les utilise. Écrans du hub : Loge des héros (`HeroesScreen` :
  les 19 héros, ceux à recruter grisés ; fiche avec Force, amélioration contre de l'or, onglets
  Techniques / Voies / Relique / Échos, règles dans `Progression`), Table des chasses
  (`CampaignScreen` : 10 mondes × 8 niveaux, un niveau s'ouvre quand le précédent est gagné, puis
  `HuntPrepScreen`), Marchand (`ShopScreen`, offres dans `hub.json`), Reliques et quatuors
  (`RelicsScreen`), Profil (clic sur le profil en haut à gauche), Primes du jour (`QuestsScreen`, règles pures dans `scripts/core/quests.gd`,
  données dans `data/quests.json`, événements notés par `PlayerData.record_event()`), Loge,
  Lanterne des Serments (invocations en gemmes seulement, `data/summon.json` ; les fragments de relique ne servent
  qu'aux reliques), Cadeau du jour (`LoginScreen`, 7 cases, `data/login.json`, s'ouvre seul au port), Album des
  monstres (`AlbumScreen`, depuis le Profil ; `state.album`, 50 gemmes tous les 10 monstres). Pastilles rouges sur
  les boutons du port (`hub_hud.gd`, `_refresh_pack_hud`).
- **Sauvegarde** : écriture sûre (fichier `.tmp` puis renommage, copie `user://save.bak.json` rechargée si la
  sauvegarde est abîmée) ; `_deep_merge` garde les nouvelles clés des sous-parties de `DEEP_KEYS`.
- **Difficulté de la campagne** : `data/difficulty.json` (multiplicateur par niveau) écrit par
  `godot --headless --path . --script res://tools/calibrate_difficulty.gd` (courbe continue : niveau de héros visé
  1 au début → 58 au boss final, ~6/10 victoires). À relancer après un changement d'équilibrage.
- **Images** : illustrations (ui, décors, héros et ennemis en pièces) importées en WebP avec perte (qualité 0.85),
  pixel art (hub_px, anim/pixel, pixelfx) sans perte.
- **Progression (fiche de combat)** : niveaux 1-60 ; **Échos** = doublons du même héros (seuils
  1/3/6/9/12, bonus surtout sur la statistique principale, `progression.json` "echoes") ;
  **reliques** à 5 paliers (fragments `relique_<héros>` gagnés en campagne + `materiaux_relique`) ;
  3 voies d'Héritage par héros (une active). **Combos d'équipe** : quatuors (`data/relics.json` "quartets"),
  duos et trios (`data/combos.json` "combos") ; si les membres sont dans l'équipe et ont chacun lancé leur
  ultime, un bouton par combo prêt (une fois par combat chacun). **Synergies** (`combos.json` "synergies") :
  bonus permanents selon le nombre de héros du même élément ou de la même classe. Au-delà de 4 héros,
  `GameData.dungeon_waves_for()` grossit les vagues (jusqu'à 8 ennemis, boss plus solide).
- **Effets pixelfx du hub** : `data/pixelfx_hub.json` (papillons et oiseaux le jour, feux follets et chauve-souris la nuit, effets plein écran tirés au sort : lucioles la nuit, rayons à l'aube, averse rare), avec `when` (dawn/day/dusk/night), `drift`, `wander`, `glow` ; joués par `scripts/hub/hub_fx.gd` (`HubFx`, enfant de `HubPixel`, suit `set_hour`), planches exportées par `node tools/export_pixelfx.mjs --data=data/pixelfx_hub.json`. Capture : `--weather=rain`.
- `scripts/battle/` = **affichage**, en 2D : lit les événements et anime. Ne met jamais de règle de
  jeu ici. `battle_scene.gd` (chef d'orchestre, formation en losange), `battle_stage.gd` (décor du
  monde), `unit_view.gd` (un personnage : ClipPlayer, ombre, cible, nombres), `battle_fx.gd`
  (secousses, éclats), `battle_audio.gd` (sons), `ui/` (interface, bouton du quatuor, écran de fin).
  Les instants d'impact (`hit_times`) viennent des repères des clips.
  Décor vivant des arènes : `data/pixelfx_arenas.json` (par monde, effets pixelfx en boucle : météo, bestioles,
  braseros ; `pos` dans le cadre 1280 × 720, `k` échelle entière, `z` -25 derrière les combattants, 16 pour la
  météo légère), posés par `BattleStage._spawn_arena_fx()` ; exporter avec `node tools/export_pixelfx.mjs --data=data/pixelfx_arenas.json`.
- **Mise en beauté du combat** : `scripts/battle/stage_grade.gd` (`StageGrade` : vignette, bas d'écran assombri, lueur du
  monde, rayons de lumière sur les arènes peintes ; `StageGrade.disc()` = disque flou partagé pour les ombres et poussières).
  Arène peinte (image plus large que 1280) : `BattleStage.painted`, pas d'effets pixelfx par-dessus, poussières douces.
  Combattants à 3 pixels d'écran par pixel de dessin (`TOP_SCALE`), entrée en scène en courant (`UnitView.enter`).
  Changement de scène : autoload `Transition` (`scripts/core/transition.gd`, iris d'encre cerclé de laiton), `Transition.go(chemin)`.
  Boutons `UiKit.button` : écrasement sous le doigt (`UiKit.juice`).
- **Salles peintes** (échoppe, reliquaire, Lanterne, profil, primes…) : fonds 1920 × 1080 peints par ChatGPT, posés à la
  place des anciens. Personnages des salles, nid et Esprits : livrés en poses fixes puis transformés en planches animées
  par `python tools/bake_salles_peintes.py <dossier recu> . <anciennes pièces>` (respiration, pose d'action, apparition),
  jouées par `MageRoom.Sheet` (clés `columns` = grille, `smooth` = lissé, `scale` ; en français `colonnes`, `lisse`,
  `echelle` dans `jardin_esprits.json`). Le même script pose la stèle dans sa salle (`stele_eveil.png` s'allume par-dessus),
  redécoupe le comptoir de l'échoppe et recale les niches du reliquaire (`ecrans.json`, 3 rangées de 7).
- **Ma Loge** (bâtiment « Loge privée » du hub, `PrivateLodgeScreen`) : le donjon du joueur. Trois salles
  (`data/lodge.json` : défenseurs et pièges par salle, mises), règles pures dans `scripts/core/lodge.gd`
  (`Lodge`), état dans la sauvegarde (`state.lodge_dungeon`, la clé `lodge` est le nom de la loge).
  Défenses construites contre de l'or (`defenses` : tour du mage, mur qui provoque, baliste, autel), unités
  « structure » sans clip (image d'objet du hub). Pièges = consommables gagnés à la Lanterne (objets `piege_<id>`).
  Une équipe n'attaque qu'un donjon de Force moyenne au moins égale à la sienne. Combat : une vague par
  salle, des héros en défense (camp ennemi, retournés), pièges déclenchés à l'entrée
  (`BattleEngine.setup(..., traps)`, événement `trap`). Rivaux du jour générés en attendant le jeu en ligne.
- **Les données vont dans `data/*.json`** (héros, monstres, donjons, régions), pas dans le code.
  Un nouveau héros = une entrée JSON (+ un modèle 3D), sans toucher au moteur si ses effets existent.
- **Effets pixelfx** (`PixelFx`, `scripts/battle/pixel_fx.gd`) : héros dans `data/pixelfx.json` ("attacks", plus "statuses" = boucles d'état aux pieds et "deaths" = mort selon l'élément) ; monstres par règles dans `data/pixelfx_monsters.json` (famille / magie / distance / compétence de boss, palette selon l'élément, exceptions "ids" ; planches : `python tools/pixelfx_monsters_export.py`) ; interface (fin de combat, invocation, montée de niveau) dans `data/pixelfx_ui.json`, joué par `PixelFx.ui_play` (planches : `node tools/export_pixelfx.mjs --data=data/pixelfx_ui.json`).
- Icônes d'attaque : `assets/ui/attacks/<id>.png`, tirées des clips par
  `python tools/make_attack_icons_from_clips.py`.
- **3 attaques par héros** dans `"attacks"` : [0] base, [1] à recharge (`"cooldown"`),
  [2] ultime (`"energy"`). Chaque attaque : `id`, `name`, `description`, `anim`, `hit_time`,
  `target`, `effects`. Les monstres peuvent n'en avoir qu'une (sans `effects` = dégâts ×1).
  Options : `hit_times` (plusieurs coups), `fx` (effet visuel), `dash: false` (ne court pas).
  Un effet peut avoir sa propre `target` (ex. foudre qui se propage à `all_enemies`).
- Une attaque a un `"clip"` (son animation) et `hit_times` (instants d'impact du clip).
- Effets d'attaque supportés : `damage` (`stat` atk/mag/def/hp, `bonus_if` un état), `heal`, `shield`,
  `taunt`, `stun`, `dot` (brûlure/poison), `cleanse`, `status` (marque, mouille, desequilibre,
  aveugle, scelle, enracine, leurre, garde…), `buff` (± stat pendant une durée), `regen`, `gauge`,
  `lifesteal`. Tout effet peut avoir `if_status` (+ `consume`). Durées en secondes (« 2 tours » ≈ 4 s).
  Cibles : `single_enemy`, `all_enemies`, `lowest_hp_enemy`, `random_enemy` (chaque coup au hasard),
  `two_enemies`, `all_allies`, `lowest_hp_ally`, `self`.

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
Si tu changes l'équilibrage (stats, formules), regarde la ligne « victoires : X/20 » des tests et
`godot --headless --path . --script res://tools/balance_report.gd` (toute la campagne).

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
