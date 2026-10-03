# CREOS — brief complet Blender : tout le jeu dans un seul style 3D

Ce brief **remplace tous les précédents**. On change de direction artistique : héros, monstres, hub,
animations, tout passe dans **un seul style 3D**, celui des personnages KayKit (CC0) déjà utilisés
pour nos monstres. Lis tout avant de commencer. Tu écris des **générateurs Python pour Blender**
(comme pour les lots précédents) ; je les lance moi-même sur mon PC (Blender 5.2.2, Windows) et je
te renvoie des captures du jeu.

Fichiers fournis avec ce message :
- `Barbarian.glb` (KayKit Character Pack: Adventurers 1.0, CC0) : **squelette de référence** et
  76 animations génériques ;
- `Skeleton_Mage.glb` (KayKit Skeletons, CC0) : un monstre actuel, pour le style ;
- `essai_style_kaykit.png` : capture du combat avec des personnages KayKit (le style visé) ;
- `apercu_cinq_heros.png` : nos 5 héros actuels en pixels, **à refaire dans le nouveau style** ;
- captures du hub actuel (`v2_*.png`).

---

## 0. Le jeu

- **CREOS** : RPG mobile en paysage (1920×1080), Godot 4.7 (rendu Mobile). On recrute des héros,
  on forme une équipe de 4, on chasse dans des donjons en combat **tour par tour à jauges**.
  Univers médiéval-fantastique **original** et chaleureux. Ne copie **aucun** nom, personnage ou
  visuel de Dungeon Boss ou d'un autre jeu. On reprend seulement le **style** KayKit, pas ses
  personnages.
- Le méchant : **Morvath le Mage Noir**, dans sa citadelle au centre du continent.
- **Port-Franc** : la ville-hub des chasseurs, un port au soleil couchant.

## 1. Le style (le plus important)

Le style KayKit, appliqué à **tout** :
- **Formes trapues et arrondies**, très lisibles en petit : grosses têtes (environ 1/3 de la
  hauteur), mains et pieds épais, armes surdimensionnées. Angles **biseautés** (bevel de 1 ou
  2 segments), ombrage lisse avec des arêtes vives là où il faut.
- **Couleurs en aplats** issues d'une **palette** : une seule petite texture PNG de cases de
  couleur, avec un **léger dégradé vertical dans chaque case** (plus clair en haut). Chaque face
  pointe en UV sur la case de sa couleur. **Pas** de texture détaillée, de bruit ou de normal map.
  Rugosité unique ~0,8, métal 0 (sauf le métal des armes : case dédiée + matériau `Metal`
  rugosité 0,4).
- Peu de triangles mais des **silhouettes riches** : accessoires, sacoches, ceintures, plumes,
  rivets en volume (pas en texture).
- Les **couleurs racontent** : élément du héros (feu rouge-orange, eau bleu, nature vert, lumière
  or-jaune, ombre violet), rareté (gris, bleu, violet, or, rouge, blanc nacré).
- Aucune lumière ni ombre cuite dans les couleurs : c'est le jeu qui éclaire.

**Palette partagée** : `textures/Palette_CREOS.png`, 512×512, cases de 32×32 (256 couleurs),
organisée par familles (peaux, cheveux, cuirs, tissus, métaux, pierres, bois, toits, végétation,
eau, couleurs d'éléments, couleurs émissives). Livre un `Palette_CREOS.json` qui nomme chaque
case. **Tous les modèles du jeu utilisent cette palette**, plus une seconde image
`Palette_CREOS_Emission.png` (même grille, noire sauf les cases lumineuses : yeux, runes, cristaux,
fenêtres, lave, magie).

## 2. Conventions techniques (strictes)

- Godot : **Y-up, mètres, face avant vers +Z**. Conversion Blender (Z-up) : `(x,y,z)` → `(x,-z,y)`.
  Origine des modèles **au sol**, au centre de l'emprise.
- **GLB sans images intégrées** : les deux PNG de palette existent une seule fois dans `textures/`.
  Matériaux nommés `Palette` (opaque), `Palette_Emission` (avec émission), `Metal`,
  `Palette_Alpha` (découpe alpha, pour les feuillages et les tissus déchirés). Le jeu leur applique
  les textures par leur nom.
- **Pas de déplacement racine dans les animations** (« in place ») : le jeu déplace lui-même le
  personnage vers sa cible. Le personnage regarde vers +Z.
- Noms ASCII, sans accents ni espaces. Une **relance** d'un lot ne doit pas effacer les autres.
- Lancement : `blender --background --python-exit-code 1 --python build_creos.py -- --lot <A|B|C|D|E|all>`
  avec l'option `--kaykit <dossier>` qui pointe sur les GLB KayKit fournis.
- Chaque lot produit : les GLB, `previews/` (rendus Cycles de chaque modèle et planches), un
  `Manifest.json` (fichiers, triangles, dimensions, animations avec leur durée), un
  `Validation.json` (images dans les GLB = 0, budgets respectés, animations présentes) et un
  `LIRE_MOI.md`. Arrête le script avec un message clair si une vérification échoue.

---

## LOT A : les 5 héros, avec toutes leurs animations

### A.1 Squelette et animations génériques

- Importe `Barbarian.glb` et réutilise **son armature telle quelle** (41 os : `root`, `hips`,
  `spine`, `chest`, `head`, `upperarm.l/r`, `lowerarm.l/r`, `wrist.l/r`, `hand.l/r`,
  `handslot.l/r`, `upperleg.l/r`, `lowerleg.l/r`, `foot.l/r`, `toes.l/r` + contrôleurs IK). Mêmes
  noms, mêmes repos : les **76 animations KayKit** (Idle, Running_A, Hit_A, Death_A, Cheer,
  Block, Dodge, Spellcast_*, 1H_/2H_/Dualwield_Melee_*, Throw…) doivent marcher sur nos héros
  sans retouche. Garde-les toutes dans chaque GLB.
- Le **corps de base** peut partir du gabarit KayKit (même taille, mêmes proportions), mais
  chaque héros doit avoir **sa propre silhouette** : tête, coiffure, armure, vêtements et armes à
  nous. Peau : poids lisses sur les os (aucune pièce qui se déchire en animation, vérifie sur
  toutes les animations). Pièces rigides (casques, épaulières, armes) attachées à un seul os.
- Armes : nœuds séparés, enfants de `handslot.r` / `handslot.l`, nommés `Arme_D` / `Arme_G`.
- Points d'attache vides pour les effets du jeu : `FX_Arme_D` (bout de l'arme principale),
  `FX_Main_G`, `FX_Main_D`, `FX_Tete`, `FX_Torse`, `FX_Sol`.
- Budget : **6 000 triangles** par héros, armes comprises.

### A.2 Les héros

| Fichier | Héros | Look à garder (voir `apercu_cinq_heros.png`) |
|---|---|---|
| `Hero_Torvald.glb` | **Torvald Barbe-Rouge**, gardien, feu, Épique | colosse, grosse **barbe rousse tressée**, crête de cheveux rouges, bandeau bleu à rivets, torse nu musclé, épaulière en fourrure, pagne de cuir, bottes en fourrure, **deux haches** |
| `Hero_Kaito.glb` | **Kaïto le Ronin**, lame, eau, Épique | armure de samouraï **bleu nuit à laçages or**, casque à **cornes dorées en V**, masque rouge, **katana et wakizashi** |
| `Hero_Vesprin.glb` | **Docteur Vesprin**, traqueur, nature, Épique | **docteur-peste** : masque à long bec, lunettes rondes vertes lumineuses, chapeau, long manteau vert, sangles, fioles vertes à la ceinture, **réservoir dorsal** relié par un tuyau à un pulvérisateur |
| `Hero_Orage.glb` | **Frère Orage**, arcaniste, lumière, Épique | **moine** chauve, sourcils marqués, tunique bleu nuit, ceinture **or** à longs pans, brassards à **symboles d'éclair**, poings nus |
| `Hero_Malgrave.glb` | **Sire Malgrave**, gardien, ombre, Légendaire | **chevalier possédé** : armure noire à pointes **dont les pièces flottent** autour d'un corps de **fumée violette** (fentes et yeux violets émissifs), **masse** et **chaîne** spectrale |

### A.3 Animations propres à chaque héros (3 attaques + base)

Chaque héros a **ses propres animations** en plus des 76 génériques : `Idle_Hero` (repos
caractéristique, en boucle), `Run_Hero` (course, en boucle), `Hit_Hero`, `Death_Hero`,
`Victory_Hero` (célébration en boucle), et **ses 3 attaques** ci-dessous.

Règles pour les attaques :
- Sur place, face à +Z. Anticipation lisible (appel), **impact** net, retour au repos.
- L'**instant d'impact** est important : le jeu affiche les dégâts à ce moment-là. Respecte les
  instants demandés (± 0,05 s) et note les instants réels dans `Manifest.json`
  (`"hit_times": [...]` pour chaque attaque).
- Durée : attaque de base 0,9 à 1,3 s, attaque à recharge 1,2 à 1,7 s, ultime 1,6 à 2,2 s.
- Pas d'effet visuel dans l'animation : les éclairs, poisons et ondes sont faits par le jeu aux
  points `FX_*`. Pour les projectiles (fiole), l'objet lancé disparaît au moment du lancer
  (`Fiole` caché par une clé de visibilité ou échelle 0).

| Héros | Nom de l'animation | Attaque | Impact(s) | Ce qu'on doit voir |
|---|---|---|---|---|
| Torvald | `Attack_01_Coup_de_Hache` | base, un ennemi | 0,53 s | grand coup de hache en diagonale, de haut en bas |
| Torvald | `Attack_02_Tourbillon_Furieux` | recharge, tous | 0,70 et 1,20 s | deux tours complets sur lui-même, haches tendues |
| Torvald | `Attack_03_Ecrasement_Berserk` | ultime, tous | 1,09 s | saut, les deux haches levées, écrasement au sol, rugissement |
| Kaïto | `Attack_01_Double_Entaille` | base, un ennemi | 0,38 et 0,68 s | coup de katana puis coup de wakizashi |
| Kaïto | `Attack_02_Coupe_Tournoyante` | recharge, tous | 0,60 s | coupe circulaire basse, lames à l'horizontale |
| Kaïto | `Attack_03_Frappe_Plongeante` | ultime, un ennemi | 0,92 s | bond très haut et plongée, les deux lames vers le bas |
| Vesprin | `Attack_01_Fiole_Explosive` | base, un ennemi | 0,72 s (lancer à ~0,45 s) | prend une fiole à la ceinture et la lance en cloche |
| Vesprin | `Attack_02_Flaque_Toxique` | recharge, un ennemi | 0,68 s | vise avec le pulvérisateur et arrose le sol devant |
| Vesprin | `Attack_03_Explosion_Reservoir` | ultime, tous | 1,05 s | ouvre la vanne du réservoir, se cambre, jet de gaz tout autour |
| Orage | `Attack_01_Paume_Foudroyante` | base, un ennemi | 0,41 s | coup de paume ouverte, rapide |
| Orage | `Attack_02_Pas_Du_Tonnerre` | recharge, un ennemi | 0,55 s | élan éclair puis coup de pied sauté |
| Orage | `Attack_03_Sentence_Celeste` | ultime, un ennemi (à distance) | 1,04 s | prière, bras levés vers le ciel, puis bras abaissé vers l'ennemi |
| Malgrave | `Attack_01_Masse_Maudite` | base, un ennemi | 0,64 s | coup de masse lourd de haut en bas |
| Malgrave | `Attack_02_Chaines_Spectrales` | recharge, à distance | 0,82 s | lance la chaîne en avant puis la tire vers lui |
| Malgrave | `Attack_03_Onde_Du_Tombeau` | ultime, tous (sur place) | 1,08 s | lève la masse, les pièces d'armure s'écartent, frappe le sol |

Pour Malgrave, les pièces d'armure flottent : anime-les avec leurs propres os (enfants des os
KayKit, nommés `Flotte_*`) sur une **oscillation douce en boucle** dans toutes ses animations.

### A.4 Portraits et planches

- `Portrait_<Hero>.png` 512×512 : buste de face légèrement de trois quarts, fond transparent,
  éclairage doux (le jeu l'affiche dans un cercle).
- Planche de contrôle : les 5 héros côte à côte, puis une planche par héros avec 8 images clés de
  chaque attaque (dont l'image de l'impact).

---

## LOT B : monstres et boss de Brumenoire (premier donjon)

Même squelette KayKit pour les monstres de taille humaine (les animations génériques suffisent
pour eux, plus une attaque propre). Le premier donjon, le **Marais de Brumenoire** (élément
ombre), contient :

| Fichier | Monstre | Look |
|---|---|---|
| `Monstre_Serviteur_Squelette.glb` | Serviteur squelette | squelette maigre, haillons, épée rouillée |
| `Monstre_Guerrier_Squelette.glb` | Guerrier squelette | casque cabossé, bouclier rond, hache |
| `Monstre_Rodeur_Squelette.glb` | Rôdeur squelette | capuche rouge sombre, deux dagues |
| `Monstre_Acolyte_Noir.glb` | Acolyte de Morvath | robe violette à capuche, masque d'os, bâton à cristal |
| `Boss_Vel_Zareth.glb` | **Vel'Zareth la Liche** (boss, 1,5× plus grande) | liche couronnée, robe en lambeaux qui flotte, mains squelettiques, bâton à crâne, flammes violettes dans les orbites, phylactère qui flotte devant elle |

Animations propres : `Attack_01` pour chaque monstre ; pour Vel'Zareth, 3 attaques (`Attack_01`
projectile d'ombre, `Attack_02` invocation (bras levés), `Attack_03` nova d'ombre (lévitation
puis onde)) + `Idle_Boss` en lévitation, `Hit_Boss`, `Death_Boss` (s'effondre en poussière).
Note les instants d'impact dans le manifeste. Budget : 5 000 triangles, 9 000 pour le boss.

**Lot B2 (après le reste)** : les boss des autres régions, même principe : Grondebête (ours-titan
corrompu, Sylvecroc, nature), Mère-Abysse (kraken, Sel-Brisé, eau), Ignorak (golem de lave,
Cendrefer, feu), Aethryss (dragonne ancestrale, Île des Dragons), Morvath le Mage Noir.

---

## LOT C : Port-Franc, le hub (tout refaire dans le style)

Le joueur voit la ville d'une **caméra fixe** : position `(0, 11, 21)`, regarde `(0, 5, -10)`,
champ vertical 42°, avec un glissement latéral de ±7 m. Tout doit être beau **depuis là**.
Garde le plan actuel (fichier `Layout_Lots_1v2_2.json` des lots précédents) : place ovale de
26 × 18 m centrée en `(0,0,-3)`, terrasses à y = 2,4 m (z de −16 à −30) et 4,8 m (z de −30 à −44),
escaliers centraux, remparts au fond, port et mer à droite (x > 14), canal à x = 12,5.

Budget total visible : **90 000 triangles**. Chaque bâtiment : 5 000 maximum.

### C.1 Bâtiments cliquables (mêmes noms, mêmes positions, porte de 2,9 m)
`Loge_Des_Heros` (−8,5 ; 0 ; −11 ; rotation 14°), `Ma_Loge` (8,5 ; 0 ; −11 ; −14°),
`Marche` (−10 ; 0 ; −0,5), `Table_Des_Chasses` (8,8 ; 0 ; 0,8),
`Autel_Des_Reliques` (0 ; 0 ; −3 : fontaine ronde avec 4 piliers et le **Cristal** violet qui
flotte au centre). Nœuds de vie : `Fumee_*`, `Lumiere_*`, `Drapeau_*`, `Cristal`.

### C.2 Maisons (crépis et toits tous différents)
Taverne (rose pâle, tuiles brunes, enseigne chope), Boulangerie (jaune beurre, toit orange,
cheminée qui fume), Forge (pierre grise, ardoise, enclume dehors, foyer rougeoyant
`Palette_Emission`), Pêcheur (planches bleu délavé, toit vert de gris, filets), Herboriste
(vert sauge, chaume, plantes grimpantes), Cartographe (bleu ciel, ardoise, longue-vue au balcon),
plus 4 maisons simples de remplissage. Fenêtres : **vitre sombre** + case émissive chaude
(`Palette_Emission`). Façades vivantes : enseignes qui pendent, auvents, balcons, jardinières,
cordes à linge, tonneaux, lierre.

### C.3 Terrain, eau, verdure
- Pavés en **volumes** (grosses dalles arrondies, pas de texture), rosace autour de l'Autel,
  bordures, herbe entre les pavés sur les bords. Murs de soutènement en **grosses pierres
  arrondies**, contreforts, niches avec lanternes, plantes qui retombent.
- Végétation dans le style : arbres à **boules de feuillage** arrondies, buissons, fleurs, herbes
  (`Palette_Alpha` pour les herbes), avec `COLOR_0.r` = poids du vent (0 au pied, 1 en haut).
- Eau : meshes plats séparés `Eau_Mer`, `Eau_Canal`, `Eau_Fontaine`, `Eau_Cascade` (le jeu y met
  son shader animé), 2 petits ponts sur le canal, cascade à la descente de la terrasse.

### C.4 Port et accessoires
Ponton sur pilotis, 2 bateaux de pêche + 1 voilier, grue en bois, casiers, filets, barils, phare
sur un rocher au loin (x ≈ 45, z ≈ −40). Accessoires séparés (origine au sol) : `Banc`, `Puits`,
`Charrette`, `Lanterne_Sur_Pied`, `Panneau_Direction`, `Etal_Fruits`, `Etal_Poissons`,
`Tonneaux_Pile`, `Caisses_Pile`, `Sacs_Grain`, `Pots_Fleurs`, `Statue_Fondateur` (une chasseuse
avec un arc), `Guirlande`, `Panneau_Avis`.

### C.5 Animations du hub (dans les GLB)
- `Anim_Drapeau` : chaque drapeau et bannière ondule en boucle (2 ou 3 os).
- `Anim_Porte` : porte qui s'ouvre puis se referme (Loge des héros, Ma loge), jouée au clic.
- `Anim_Grue` : la grue du port balance son filet en boucle.
- `Anim_Moulin` : ajoute un **petit moulin à vent** sur la terrasse 2, ailes qui tournent.
- `Anim_Bateau` : roulis léger en boucle ; `Anim_Voile` : la voile qui se gonfle.
- `Anim_Enseigne` : les enseignes qui se balancent ; `Anim_Cristal` : rotation du Cristal.

### C.6 Habitants (PNJ du hub)
Sur le squelette KayKit, budget 3 000 triangles chacun : une marchande, un pêcheur avec sa
canne, un forgeron, une herboriste, deux enfants qui jouent, un garde des remparts, plus un
**chat** et un **chien** (squelettes simples à eux). Animations en boucle : `Idle`, `Walk`,
et une activité (`Travail` : vendre, pêcher, marteler, arroser, jouer à chat, monter la garde ;
le chat dort, le chien remue la queue).

### C.7 Horizon (au-delà de z = −60)
Six silhouettes de régions dans le même style (formes rondes, dégradés de brume vers le
bleu-mauve plus c'est loin), 1 500 triangles chacune, en coordonnées du monde :
Sylvecroc (−190, −235) forêt d'arbres géants ; Brumenoire (−95, −255) marais et arbres morts ;
Citadelle de Morvath (−10, −290) piton noir avec **tour fine de 40 m** ; Cendrefer (85, −270)
volcans avec lave émissive ; Sel-Brisé (200, −190) falaises blanches et arches ; Île des Dragons
(150, y = 40, −240) île flottante avec cascades. Plus `Horizon_Collines` (bande continue, sans
trou) et `Horizon_Iles` (3 ou 4 îlots côté mer).

---

## LOT D : écrans 3D

- `Sanctuaire_Invocation.glb` (20 000 triangles) : la cérémonie d'invocation de l'Autel.
  Plateforme ronde de 6 m avec un **cercle de runes** (matériau `Runes`, blanc neutre : le jeu
  le colore selon la rareté), socle central (nœud `Point_Heros`), 4 piliers avec un cristal
  flottant chacun (`Cristal_1..4`), grande arche derrière avec un voile (`Portail_Voile`, plan à
  UV 0-1), fond de temple ancien en ruine sous un ciel de nuit, coffres et tas de fragments
  violets. Caméra `Camera_Invocation` (héros au centre, à 6 m). Animations : `Anim_Cristaux`
  (les 4 cristaux tournent et flottent), `Anim_Ouverture` (l'arche s'illumine, les piliers se
  soulèvent un peu, 1,5 s).
- `Loge_Interieur.glb` (20 000 triangles) : salle chaleureuse en bois, cheminée, râteliers
  d'armes, trophées de chasse (sans gore), carte du continent au mur, bougies, fenêtre sur le
  port. Nœud `Point_Heros` à 4 m de `Camera_Loge`, à gauche du centre.

## LOT E : arène de combat de Brumenoire

Une arène de combat du marais, vue par la caméra de combat : position `(0, 8,6, 13,2)`,
inclinaison −27°, champ vertical 48°. Zone de combat dégagée de 16 × 8 m centrée en (0,0,0) :
héros à gauche (x de −7 à −2), ennemis à droite (x de 2 à 7). Autour : eau stagnante (`Eau_Marais`),
ruines d'un temple englouti, arbres morts tordus, roseaux, lanternes de feu follet (émissif vert),
brume (nœuds `Brume_*`). Budget 30 000 triangles. Rendu depuis la caméra de combat.

---

## Livraison et ordre de priorité

1. **Palette + lot A** (les héros et leurs animations) : c'est le plus important.
2. Lot B (Brumenoire), puis lot E (l'arène).
3. Lot C (le hub), en commençant par C.1 et C.2.
4. Lot D, puis lot B2.

Un seul ZIP par livraison, avec un lanceur `.bat` par lot et un pour tout. Signale clairement ce
que tu n'as pas pu tester (Blender et Godot ne tournent pas chez toi) : je lance tout, je vérifie
dans le jeu et je te renvoie des captures.
