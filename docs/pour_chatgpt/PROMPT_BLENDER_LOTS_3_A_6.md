# CREOS — Port-Franc : brief complet Blender, lots 1 v3, 3, 4, 5 et 6

Tu as déjà livré les lots 1, 1 v2 et 2 (générateur Python pour Blender). Ils ont été **exécutés
dans Blender 5.2.2 sur mon PC** puis intégrés dans le jeu (Godot 4.7, rendu Mobile). Ce brief
donne le retour sur ce qui a été intégré et la liste de **tout ce qu'il reste à faire**. Lis-le en
entier avant de commencer, puis livre **un seul ZIP** avec le même type de générateur.

Captures du jeu jointes : `v2_1_vue_camera_jeu.png`, `v2_2_gros_plan_facade_loge.png`,
`v2_3_gros_plan_mur_cote_toit.png`.

---

## 0. Le jeu, en bref

- **CREOS**, RPG mobile en paysage (1920×1080) : on recrute des héros, on forme une équipe de 4
  et on part chasser dans des donjons. Univers médiéval-fantastique original, ton chaleureux.
- **Port-Franc** est la ville-hub des chasseurs, un port au soleil couchant. Le joueur la voit
  d'une **seule caméra fixe** (avec un léger glissement latéral) : position `(0, 11, 21)`,
  regarde `(0, 5, -10)`, champ vertical 42°. Tout ce qui compte doit être beau **depuis là**.
- Direction artistique : **héros en pixels (chibi voxel)** sur un **décor propre, stylisé,
  peint à la main**, dans l'esprit des villages de jeux mobiles « cosy » haut de gamme. Couleurs
  chaudes et saturées mais pas criardes, formes lisibles, beaucoup de petits détails de vie.
  Pas de réalisme photo, pas de textures de pixels.
- Ne copie **aucun** nom, bâtiment ou visuel de Dungeon Boss ni d'un autre jeu.

## 1. Conventions techniques (inchangées, à respecter strictement)

- Godot : **Y-up, mètres, façade vers +Z**. Conversion Blender (Z-up) : `(x,y,z)` → `(x,-z,y)`.
- Origine des bâtiments et accessoires **au sol**, au centre de l'emprise. Décors de terrain et
  horizon : **coordonnées du monde**, posés en `(0,0,0)`.
- **GLB sans images intégrées.** Textures **partagées** une seule fois dans `textures/`,
  en familles d'atlas : `BaseColor` (sRGB), `Normal` (OpenGL, Y+), `ORM` (R = AO, G = rugosité,
  B = métal). Les noms des matériaux glTF servent de clés (ex. `Atlas_Batiments`,
  `Emissif_Fenetres`). Aucun soleil ni ombre portée dans la couleur cuite.
- Deux couches d'UV : `UVMap` (atlas) et `UV2` (lightmap, îlots sans chevauchement).
- `COLOR_0.r` = poids du vent (0 au pied, 1 en haut) pour tout ce qui bouge ; ne jamais s'en
  servir comme couleur.
- Nœuds vides nommés pour la vie ajoutée par le jeu : `Fumee_*` (fumée), `Lumiere_*` (lampe
  chaude), `Drapeau_*` (pivot d'un drapeau qui ondule), `Cristal` (tourne et flotte). Nouveaux
  préfixes possibles : `Eau_*` (surface d'eau, voir lot 3), `Vent_*` (objet qui se balance),
  `Etincelles_*` (particules magiques), `Camera_*` (point de vue, voir lot 6).
- Budget : **80 000 triangles visibles** pour tout le hub (lots 1, 2, 3, 4 ensemble), maximum
  6 000 par bâtiment, + un LOD1 à ~60 %. Le lot 6 a son propre budget (scène séparée).
- Lancement : `blender --background --python-exit-code 1 --python build_port_franc.py -- --lot <n>`,
  avec `--lot all` pour tout. Une relance d'un lot ne doit **pas** effacer les autres lots.
- Garde les diagnostics (`Diagnostics_Atlas_*.json`, `Diagnostic_UV_*.png`, `Validation.json`)
  et les rendus de contrôle dans `previews/`, plus le rendu depuis la caméra du jeu.

## 2. Retour sur ce qui est intégré (lots 1 v2 et 2)

Points forts : formes, colombages, fenêtres, gouttières et jardinières des murs latéraux,
terrasses, escaliers, remparts, quai, arbres et herbe avec vent. Tout s'importe sans erreur.

Problèmes à corriger :
1. **Atlas des bâtiments occupé à 11,96 % seulement** (voir le diagnostic). Les îlots sont
   minuscules et presque tout l'atlas est vide. En jeu, crépi, bois et tuiles sont donc **flous et
   lisses** : la matière cuite ne se voit pas.
2. **Fenêtres** : la couleur de base des vitres est un jaune saturé plein. Il faut une vitre
   sombre bleu-vert avec un reflet clair et des croisillons ; c'est l'émission qui fait la lumière.
3. **Toutes les maisons ont le même crépi crème** : les rangées se ressemblent trop.
4. Les **murs de soutènement** des terrasses sont un motif de briques régulier et monotone sur
   60 m.
5. **Peu d'accessoires** : la place et les bords paraissent vides par rapport à un village vivant.
6. Rien à l'horizon côté mer, et le canal n'a pas d'eau.

---

## 3. Lot 1 v3 : bâtiments (mêmes noms, positions et pivots)

Les 11 modèles restent : `Loge_Des_Heros`, `Ma_Loge`, `Marche`, `Table_Des_Chasses`,
`Autel_Des_Reliques`, `Maison_Boulangerie`, `Maison_Forge`, `Maison_Taverne`, `Maison_Pecheur`,
`Maison_Herboriste`, `Maison_Cartographe`.

1. **Densité de texels homogène et atlas rempli.** Mets à l'échelle les îlots de façon à
   **occuper au moins 70 %** de l'atlas 2048² (mesuré, pas annoncé). Vise ~**200 px par mètre**
   sur les grandes faces (murs, toits, portes) et réduis l'échelle des petites pièces cachées
   (dessous, faces arrière contre un mur). Si 2048² ne suffit pas : passe à **deux atlas**
   (`Atlas_Batiments_A` et `_B`, mêmes trois cartes chacun) plutôt que de réduire la densité.
   Arrête la génération si l'occupation est inférieure à 60 %.
2. **Des teintes de crépi différentes par maison**, avec une variante de toit :
   - Loge des héros : crépi crème chaud, toit ardoise bleue, bannières bleu et or ;
   - Ma loge : crépi ocre clair, toit tuiles rouges, bannière du joueur ;
   - Taverne : crépi rose pâle, toit tuiles brunes, enseigne chope ;
   - Boulangerie : crépi jaune beurre, toit orange, enseigne pain, cheminée qui fume ;
   - Forge : moellons de pierre grise en bas, bois sombre en haut, toit ardoise, enseigne enclume ;
   - Pêcheur : bardage de planches bleu délavé, toit vert de gris, filets et flotteurs ;
   - Herboriste : crépi vert sauge, toit de chaume, plantes grimpantes ;
   - Cartographe : crépi bleu ciel, toit ardoise, longue-vue au balcon.
   Toutes les maisons gardent le même atlas : les teintes sont des zones différentes de l'atlas.
3. **Matière lisible à la distance de la caméra (10 à 30 m)** : pierres d'angle bien dessinées,
   tuiles qui se lisent une par une (avec des tuiles plus claires ou plus sombres au hasard),
   veinage et planches sur les portes, joints sombres. **Contraste net** entre les matières, avec
   une petite **usure plus claire sur les arêtes**. Évite les bruits fins qui deviennent une
   bouillie grise en petit.
4. **Fenêtres** : vitres sombres comme dit plus haut. Sépare le matériau `Emissif_Fenetres`
   (vitre seule) des cadres (`Atlas_Batiments`). Ajoute des **rideaux** et des pots de fleurs
   variés.
5. **Plus de vie sur les façades** : enseignes en fer forgé qui pendent (nœud `Vent_*`), lanternes
   murales (`Lumiere_*`), auvents en toile, escaliers extérieurs en bois, balcons, cordes à
   linge, lierre, tonneaux et caisses contre les murs. Silhouettes de toit variées : lucarnes,
   cheminées de formes différentes, girouettes.
6. Garde les **mêmes noms de nœuds spéciaux** et les mêmes positions des portes (porte de 2,9 m
   de haut).

## 4. Lot 2 v2 : petites corrections du terrain

- **Murs de soutènement** : moellons irréguliers de tailles variées, pierres plus grosses en bas,
  lignes de mousse et de coulures, quelques pierres saillantes. Ajoute des **contreforts** tous
  les 6 à 8 m, des **pots de fleurs**, des **plantes qui retombent** du haut du mur et 2 ou
  3 **niches avec une petite statue ou une lanterne**.
- **Escaliers** : rampe en pierre avec des **lanternes sur les piliers**, marches usées au
  milieu, pots de fleurs sur les côtés.
- **Remparts** : variation des pierres, bannières bleu et or le long des créneaux (`Drapeau_*`),
  porte principale avec herse en bois relevée et deux braseros (`Lumiere_*`).
- **Sol de la place** : pavés plus grands et contrastés, avec un **motif décoratif** (rosace
  de pavés en cercle autour de l'Autel), bordures en pierre plus claires, plaques d'herbe et de
  mousse entre les pavés sur les bords, pas au centre.
- Plus de **verdure** : haies, rosiers, lierre sur les remparts, petites fleurs le long des murs
  (densité réglable, centre de la place et chemins toujours libres).

## 5. Lot 3 : l'eau et la vie du port

Toutes les surfaces d'eau sont des **meshes plats séparés**, nommés `Eau_*`. Le jeu leur met son
propre shader animé : ne cuis pas d'eau dans un atlas, donne seulement la forme, UV0 en mètres/8
et `COLOR_0.r` = profondeur (0 au bord, 1 au large) pour la couleur et l'écume.

1. **Mer** (`Eau_Mer`) : au-delà du quai, de x = 16 vers l'est et le sud. Ne la fais pas
   descendre sous `y = -0.5`. Ajoute une **bande d'écume** le long du quai et des rochers
   (`Eau_Ecume`, un ruban).
2. **Canal** (`Eau_Canal`) dans le lit déjà réservé (x = 12,5, largeur 1,8 m), avec **2 petits
   ponts** en pierre en arc pour traverser, une **petite cascade** à l'endroit où il descend de la
   terrasse 1 vers la place (mesh `Eau_Cascade` avec UV verticaux pour un défilement), et
   un **bassin** au pied.
3. **Fontaine de l'Autel** : remplir la vasque de `Eau_Fontaine` et ajouter 4 petits jets
   (nœuds `Eau_Jet_1..4` pour des particules).
4. **Port** (côté droit, x = 16 à 30, z = +5 à -30) :
   - grand **ponton en bois** sur pilotis avec lampes, bittes d'amarrage et cordages ;
   - 2 **bateaux de pêche** différents et **un voilier** de chasseurs plus grand avec voile
     repliée (pivots `Vent_*` pour le roulis) ;
   - **grue en bois** avec poulie et filet de caisses, **casiers à homards**, filets qui sèchent,
     barils, rames, bouées ;
   - un **phare** sur un rocher au loin (x ≈ 45, z ≈ -40), avec `Lumiere_Phare`.
5. **Accessoires de la place** (fichiers séparés pour pouvoir les placer, origine au sol) :
   `Banc`, `Puits`, `Charrette`, `Lanterne_Sur_Pied`, `Panneau_Direction` (flèches vers les
   régions), `Etal_Fruits`, `Etal_Poissons`, `Tonneaux_Pile`, `Caisses_Pile`, `Sacs_Grain`,
   `Pots_Fleurs`, `Statue_Fondateur` (une chasseuse avec un arc, sur un socle), `Guirlande`
   (cordelette avec fanions entre deux points, nœud `Vent_*`), `Panneau_Avis`. Livre-les dans
   un atlas commun `Atlas_Accessoires`.
6. **Rochers** de la côte et pied des remparts : 5 variantes de taille réutilisables.

## 6. Lot 4 : l'horizon et le continent

On voit le continent de CREOS au fond (au-delà de z = -60) et la mer à droite. Aujourd'hui ce
sont des formes simples faites dans le jeu. Remplace-les par **6 silhouettes de régions**,
lisibles en un coup d'œil, à plat de couleur avec un dégradé de brume (perspective aérienne :
plus c'est loin, plus c'est clair et bleuté). Chaque région est un GLB séparé, en coordonnées
du monde, budget **1 500 triangles chacune** :

| Fichier | Région | Position (x, z) | Lecture attendue |
|---|---|---|---|
| `Horizon_Sylvecroc` | Forêt de Sylvecroc (nature) | (-190, -235) | collines couvertes d'arbres géants vert profond |
| `Horizon_Brumenoire` | Marais de Brumenoire (ombre) | (-95, -255) | marais bas, arbres morts, ruines, brume violette |
| `Horizon_Citadelle` | Citadelle de Morvath | (-10, -290) | piton rocheux noir, tour fine de 40 m, nuage sombre |
| `Horizon_Cendrefer` | Pics de Cendrefer (feu) | (85, -270) | volcans et pics, coulées de lave (matériau `Emissif_Lave`) |
| `Horizon_Sel_Brise` | Côtes de Sel-Brisé (eau) | (200, -190) | falaises blanches, arches de roche, vagues |
| `Horizon_Drakonis` | Île des Dragons | (150, y = 40, -240) | île flottante avec cascades qui tombent dans le vide |

Ajoute `Horizon_Collines` : une bande continue de collines basses qui relie les régions (pas de
trou, pas de bord visible depuis la caméra en glissant de ±8 m), et `Horizon_Iles` : 3 ou
4 petites îles côté mer. Pas de détail fin : ce sont des silhouettes, mais des **silhouettes
élégantes** (lignes de crête variées, pas de cônes réguliers).

## 7. Lot 5 : le Sanctuaire des Reliques (invocations)

Dans le jeu, l'**Autel des Reliques** sert à **invoquer des héros** avec des fragments. Quand le
joueur clique dessus, on passe à une scène rapprochée : la **cérémonie d'invocation**. Je veux un
GLB séparé, `Sanctuaire_Invocation.glb`, budget 25 000 triangles, vu par une caméra fixe
(nœud `Camera_Invocation`, 16:9, le héros invoqué au centre à environ 6 m).

Contenu :
- une **plateforme circulaire** de 6 m de diamètre en pierre claire, avec un **cercle de runes**
  gravé (runes dans un matériau séparé `Emissif_Runes`, que le jeu allumera dans la couleur de
  la rareté) ;
- au centre, un **socle** bas où apparaît le héros (nœud `Point_Heros`, au sol) ;
- **4 piliers** autour, chacun avec un **cristal flottant** (`Cristal_1..4`) et un nœud
  `Etincelles_*` ;
- derrière, une **grande arche** en pierre et métal doré (5 m de haut) qui encadre le héros, avec
  un **voile magique** (mesh plat séparé `Portail_Voile`, UV 0-1, que le jeu animera) ;
- un **fond** semi-fermé : murs d'un temple ancien en ruine, colonnes cassées, lierre, bannières,
  ciel nocturne visible par le toit ouvert ; des **coffres et piles de fragments** (petits cristaux
  violets) sur les côtés ;
- 3 nœuds `Lumiere_*` placés pour éclairer le héros de face, de côté et en contre-jour.

Le jeu colore runes, voile, cristaux et lumières selon la rareté du héros obtenu : gris (Commun),
bleu (Rare), violet (Épique), or (Légendaire), rouge (Mythique), blanc nacré irisé (Relique
Ancienne). Les matériaux de ces éléments doivent donc être **neutres et clairs** (blanc cassé),
sans teinte cuite.

## 8. Lot 6 : intérieur de la Loge des héros

Quand le joueur ouvre la Loge des héros, on montre la liste et un héros en grand. Livre
`Loge_Interieur.glb` (budget 20 000 triangles, caméra `Camera_Loge`, héros au nœud `Point_Heros`
à 4 m de la caméra, à gauche du centre pour laisser la droite à l'interface) : une salle
chaleureuse en bois avec cheminée (`Fumee_*`, `Lumiere_Cheminee`), râteliers d'armes,
trophées de chasse (crâne de bête, écaille de dragon, sans gore), carte du continent au mur,
tapis, bougies (`Lumiere_*`), grande fenêtre sur le port au crépuscule.

## 9. Livraison et contrôle

- Un ZIP avec `build_port_franc.py`, `modules/`, `Lancer_*.bat` (un par lot, plus un pour tout),
  `LIRE_MOI.md`, les aperçus géométriques, et le **layout JSON** de tout ce qui est placé
  (positions, rotations, nœuds spéciaux, boîtes cliquables).
- Pour chaque lot : rendu Cycles depuis la caméra du jeu (`0,11,21` → `0,5,-10`, 42°), rendu
  rapproché de chaque modèle, diagnostics d'atlas (**occupation mesurée**), et `Validation.json`
  (triangles, images dans les GLB = 0, chevauchements UV = 0).
- Signale clairement ce que tu n'as **pas pu tester** ; je lance tout sur mon PC et je te renvoie
  des captures du jeu.
- Ordre de priorité si tu dois découper : **1 v3 → 3 → 5 → 4 → 2 v2 → 6**.
