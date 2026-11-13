# Refonte des 19 héros

Les 19 héros jouables ont une nouvelle apparence, avec silhouettes, matières et accessoires
propres à chacun. Les dessins sont créés pour CREOS avec le générateur d'images de ChatGPT,
à partir des sprites d'origine. Leurs identités et leurs règles de combat sont conservées.

- 19 attaques de base de **16 poses** chacune.
- Neuf mouvements redessinés par héros : repos, marche, attaque de base, seconde attaque,
  ultime, compétence, esquive, coup reçu et mort.
- Les autres mouvements ont 7 ou 8 poses propres à leur planche ; la mort de Jin Seok en a 16.
- Même apparence dans le combat, les portraits, les cartes et les promeneurs du port.
- Les anciennes animations sont conservées dans `sheet.json` sous les noms `*_original`.

Quelques signatures : Corbin et son manteau de plumes, Aegis et son équipement solaire,
Brume et ses coraux, Kharok et son ambre, Braise et sa forge portative, Nacre et ses ailes
lunaires, Sylve et ses champignons, Calx et ses cloches, les talismans de Saffran et les
silhouettes martiales distinctes de Mei Lian, Jin Seok, Yun Tao et Tang Su.
La direction détaillée de chaque héros est conservée dans `data/hero_redesigns.json`.

## Technique

Les PNG sont conservés intacts et joués en atlas. Les découpes tiennent compte de la grille
réellement produite (7 ou 8 colonnes, 9 rangées), au lieu de supposer une grille uniforme.
Les archives ne sont pas chargées en mémoire pendant le jeu ; elles restent disponibles
à la demande pour diagnostic (`original_animation`).
Les attaques de base utilisent chacune une autre planche de 4 × 4 poses.
Les ancres, échelles et limites opaques sont décrites par pose. Le cadrage des portraits et
cartes utilise ces limites pour ignorer les pixels presque transparents en bordure.

Le port réutilise les nouveaux repos et marches de trois quarts. Les déplacements vers la
gauche sont retournés ; il n'y a pas encore de nouvelles vues dessinées de dos pour le haut.
Les techniques secrètes continuent d'utiliser les correspondances existantes vers les
compétences et ultimes. Aucun changement des dégâts, statistiques ou repères de combat.

Pour réimporter les planches présentes dans le dépôt :

```bash
python tools/import_hero_redesigns.py data/hero_redesigns.json
godot --headless --path . --import
```

Dépendances de l'outil : Pillow et NumPy. Le manifeste conserve les découpes et directions
artistiques ; une réimportation ne supprime pas les animations d'origine.

## Vérification

```bash
godot --headless --path . --script res://tests/test_hero_redesigns.gd
godot --headless --path . --script res://tests/test_pixel_atlas.gd
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/smoke_battle.gd --fixed-fps 60
godot --headless --path . --script res://tests/smoke_hub.gd --fixed-fps 60
```

Contrôle des textures et régions des 19 héros, portraits, tailles, repères d'impact, ainsi que
rendu des repos, attaques et morts. La chute de Jin Seok a été refaite sur une planche séparée
après identification d'une mauvaise découpe. Contrôle effectué sous Godot 4.6.3, avec rendu
OpenGL Compatibility ; le projet cible 4.7. Validation sur téléphone encore nécessaire.
Les messages de ressources conservées à la fermeture et de callbacks supprimés dans certains
combats existaient déjà avant cette refonte.

Cette passe concerne les 19 héros jouables. Les 152 monstres et boss gardent leurs dessins.
