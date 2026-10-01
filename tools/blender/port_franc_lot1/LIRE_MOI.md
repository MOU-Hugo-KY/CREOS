# CREOS — Port-Franc, lot 1

Ce pack contient le **générateur Blender**, pas des GLB déjà cuits. Blender n'est pas installé dans l'environnement où ce script a été écrit. La syntaxe Python et les budgets de géométrie ont été vérifiés ; **l'exécution bpy, la cuisson Cycles, le rendu et l'import Godot restent à vérifier sur votre ordinateur**. Les aperçus fournis montrent la géométrie exacte avec des couleurs simples ; ils ne sont pas des rendus Blender et ne montrent pas les textures finales.

## Lancer sur Windows

1. Décompresser le ZIP dans un dossier local.
2. Double-cliquer sur `Lancer_Port_Franc.bat`. Le lanceur recherche `blender.exe` dans `D:\Blender`, puis dans `C:\Program Files\Blender Foundation` si le chemin par défaut est absent.
3. Attendre le message `TERMINE`. La cuisson est exécutée sur CPU, sans addon ni téléchargement. Le temps dépend de votre ordinateur.
4. Ouvrir `Port_Franc_Lot1_Genere/`. En cas d'erreur, transmettre `Execution_Blender.log` : aucune réussite de cuisson ne doit être déduite des aperçus fournis.

Pour indiquer explicitement l'exécutable, depuis PowerShell ouvert dans le dossier du pack :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Lancer_Port_Franc.ps1 -BlenderPath "D:\Blender\blender.exe"
```

Ou directement avec Blender :

```powershell
& "D:\Blender\blender.exe" --background --python-exit-code 1 --python .\build_port_franc.py
```

Le script vise l'API Blender 5.2. Cette compatibilité n'a pas été vérifiée par une exécution réelle ici. Le lanceur ouvre une scène neuve dans un processus en arrière-plan. Il ne modifie pas un projet Blender ouvert. Une nouvelle exécution écrase uniquement les sorties portant les mêmes noms dans son dossier de génération.

## Contenu produit à l'exécution

- `GLB/` : onze modèles séparés, textures intégrées.
- `LOD/` : onze versions `_LOD1`, par décimation du modèle déjà texturé. Le script vérifie une réduction effective du nombre de triangles ; la lisibilité reste à contrôler visuellement.
- `textures/` : `Atlas_Batiments_BaseColor.png`, `Atlas_Batiments_Normal.png`, `Atlas_Batiments_ORM.png` en 2048² par défaut.
- `previews/` : onze rendus Cycles, puis une vue à la caméra du jeu.
- `Layout_Lot1.json` : positions, rotations, échelles, pivots des nœuds spéciaux et boîtes cliquables des cinq éléments principaux.
- `Manifest.json` : statistiques tirées des GLB réellement exportés, dimensions, matériaux et LOD.
- `Validation.json` : contrôles de structure glTF et budgets. L'import Godot est marqué non testé.
- `Port_Franc_Lot1.blend` : scène de contrôle et matériaux exportables.

Le lot 1 comprend la Loge des héros, Ma loge, le Marché, la Table des chasses, l'Autel des Reliques, et six maisons : boulangerie, forge, taverne, pêcheur, herboriste, cartographe. Les enseignes utilisent des emblèmes géométriques, sans texte illisible ni nom emprunté.

## Matériaux, cuisson et atlas

Le style est stylisé, sans atlas pixel ni filtrage nearest. La couleur utilise des variations procédurales douces ; les toits comportent un motif de tuiles, les matériaux un relief léger et les silhouettes de toiture de vraies tuiles de bordure. Il s'agit de textures procédurales évoquant une peinture stylisée, **pas de textures peintes manuellement par un artiste**.

Les onze modèles partagent un atlas 4 × 3 cellules. Les UV de chaque modèle occupent une cellule distincte. Les objets spéciaux disposent d'une bande réservée dans cette cellule. Les bâtiments sont éloignés les uns des autres pendant la cuisson pour éviter une AO provenant d'autres bâtiments superposés.

Cycles cuit :

| Carte | Contenu |
|---|---|
| BaseColor | Couleurs seules, sans éclairage direct ni indirect |
| Normal | Normales tangentes et relief procédural |
| ORM R | Occlusion ambiante des formes, y compris contacts entre pièces |
| ORM G | Rugosité |
| ORM B | Métal, principalement ferronneries |

**Trois images intégrées par GLB**, et non une seule image : le cahier des charges demandait simultanément une texture et trois cartes. Cette décision conserve les trois cartes PBR. Les fenêtres et lanternes emploient `Emissif_Fenetres` ; runes et cristal emploient `Emissif_Cristaux`. Le soleil doré sert uniquement aux rendus et n'est pas cuit dans les couleurs. Les textures sont intégrées à chaque fichier ; pour réduire la mémoire dans Godot, réutiliser les mêmes ressources de texture/matériau après import au lieu de charger onze copies distinctes.

Une seconde couche `UV2` est déroulée indépendamment, sans chevauchement de ses îlots au sein de chaque mesh. Des UV2 de meshes différents peuvent utiliser le même domaine 0–1 : Godot effectue le packing des instances pour la lightmap. Le script ne cuit pas de lightmap.

Sources techniques : [export glTF Blender](https://docs.staging.blender.org/manual/en/latest/addons/scene_gltf2.html), [cuisson Cycles](https://docs.staging.blender.org/manual/en/latest/render/cycles/baking.html). Le canal d'occlusion est raccordé au groupe `glTF Material Output`, entrée `Occlusion`.

## Repère et disposition

La géométrie est écrite en coordonnées de jeu, puis convertie vers Blender : `(x, y, z)` du jeu devient `(x, -z, y)` dans Blender. L'export glTF utilise +Y up. Les façades regardent +Z ; 1 unité = 1 m ; les portes font 2,9 m. L'origine est au centre de la fondation et à hauteur du sol. Les accessoires de façade peuvent dépasser l'empreinte de fondation ; le manifeste indique les dimensions complètes.

Les fichiers de bâtiment sont exportés à l'origine. **Appliquer les positions du layout une seule fois** lors de leur placement. Ne pas replacer une seconde fois des géométries qui seront exportées en coordonnées mondiales dans les prochains lots.

La vue d'ensemble du lot 1 utilise `(0,11,21)` → `(0,5,-10)`, champ vertical 42°. Le sol neutre de contrôle n'est pas exporté. Les maisons prévues sur les terrasses sont déjà à leur hauteur cible : les terrasses elles-mêmes arrivent au lot 2. Le lot 1 ne doit donc pas être jugé comme une ville complète.

## Nœuds et éléments à ajouter dans le jeu

- `Cristal` : nœud distinct de l'autel, pivot à `(0,2.28,0)`. Rotation Y et flottement à ajouter dans Godot.
- `Drapeau_*` : pièces distinctes, couleur de sommet R progressive vers le bord libre. Ajouter le mouvement dans le shader ou l'animation du jeu.
- `Fumee_*` : attaches en haut des cheminées, sans particules incluses.
- `Lumiere_*` : attaches pour les lampes. L'émission ne remplace pas une lampe réelle.
- `Eau_*` : surfaces et jets à venir au lot 3 ; le lot 1 livre le bassin sans eau animée.
- `Vegetation_*` : végétation générale et intensité du vent à venir au lot 2 ; les petites jardinières du lot 1 sont intégrées aux maisons.

Ajouter côté jeu : collisions simples, navigation, eau, vent, fumée, éclairage, brume et interactions. LOD1 est livré en fichier séparé ; la sélection selon la distance reste à configurer dans Godot. Les boîtes cliquables du layout servent aux interactions, pas aux collisions de déplacement.

Le **Quai des Égarés**, convenu pour les invocations, reste prévu à proximité du port. Il ne fait pas partie de ce lot de bâtiments et aucune cinématique d'invocation n'est incluse ici.

## Pour Claude

1. Lancer le générateur dans le Blender local avec `--python-exit-code 1` et conserver le journal.
2. Ne pas annoncer les GLB comme validés avant la réussite de cuisson/export et inspection de `Manifest.json`.
3. Vérifier une façade +Z, les portes à l'échelle des héros de 2,6 m, les UV2, le canal AO et les trois cartes intégrées.
4. Importer les cinq bâtiments principaux et les six maisons depuis `GLB/`, appliquer `Layout_Lot1.json`.
5. Résoudre les nœuds exacts `Cristal`, `Drapeau_*`, `Fumee_*`, `Lumiere_*` ; leurs noms exportés sont normalisés depuis les propriétés source pour retirer les suffixes internes Blender.
6. Partager les textures importées, activer l'éclairage adapté au rendu mobile et contrôler le coût des transparences/émissifs.
7. Contrôler visuellement les LOD ; les reliefs et les détails fins peuvent perdre en lisibilité après décimation.
8. Continuer avec le lot 2 (terrain/végétation), puis le lot 3 (eau/accessoires) et le lot 4 (horizon/scène finale).

## Vérification réalisée dans ce pack

`Audit_Geometrie.json` contient les statistiques calculées sans Blender : 27 636 triangles au total, maximum 3 590 par élément. Les variantes géométriques simplifiées auditées sont indicatives ; les LOD réellement exportés sont obtenus par décimation Blender et leurs statistiques sont calculées à l'exécution. La syntaxe des modules Python a été compilée. Les coordonnées, indices, budgets, nœuds et hauteurs minimales ont été contrôlés. Aucun test réel de bpy ou de Godot n'a été exécuté.

Mode de vérification sans Blender : `python build_port_franc.py --audit`.

Paramètres en tête de `build_port_franc.py` : graine, densité végétale réservée au lot 2, résolution de texture, échantillons de cuisson/rendu et ratio LOD. Pour un essai plus rapide dans Blender : ajouter `-- --texture-size 512 --no-previews` à la commande. Cet essai génère des fichiers à basse résolution ; relancer en 2048 pour la livraison finale.
