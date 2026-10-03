# CREOS — passage du jeu entier en 2D dessinée

Nos personnages sont maintenant des **dessins 2D** animés en marionnettes (Corbin, Aegis, Brume,
Orage, les 5 ennemis de Brumenoire et le marchand de masques : fiches jointes). Le décor 3D ne va
pas avec leur style : **tout le jeu passe en 2D dessinée**, avec de la **perspective** (plans
étagés, profondeur, parallaxe) et des **animations**. Ce brief remplace tous les briefs Blender
et 3D précédents. Il me faut des **images**, pas de scripts. Je monte tout dans le jeu (Godot)
moi-même : découpage, parallaxe, animations, interface.

Jointes : les fiches de nos personnages (`corbin_fiche.png`, `aegis_fiche.png`,
`brume_fiche.png`, `orage_fiche.png`, `vel_zareth_fiche.png`, `marchand_fiche.png`), la planche de
style (`style_reference.jpg`, **style seulement**, ne recopie aucun personnage) et deux captures du
jeu actuel (`actuel_port.png`, `actuel_combat.png`) pour la disposition. Ne copie rien de Dungeon
Boss ni d'aucun autre jeu.

---

## 1. Le style (le même pour tout)

- **Le même trait que nos personnages** : contour noir épais et régulier, aplats de couleur avec
  une ombre franche par couleur, peu de détails mais bien choisis, et pas de rendu 3D ni de
  textures photo. Les décors peuvent avoir **un peu plus de nuances** que les personnages
  (dégradés doux dans le ciel et l'eau, brume), mais leurs objets gardent le contour encré.
- **Lisibilité d'abord** : les personnages doivent toujours ressortir du fond. Le fond est donc
  **moins contrasté et légèrement désaturé**, avec des contours plus fins que ceux des
  personnages ; plus c'est loin, plus c'est clair et bleuté (perspective aérienne).
- Palette générale : ivoire `#eee4cd`, encre `#29262e`, bordeaux `#793b49`, laiton `#c6a66c`,
  ardoise `#505e75`, mousse `#5f6b3a`, magie turquoise `#63c8be` (héros) et violette `#9b5de5`
  (Morvath et ses serviteurs).
- Ambiance « fantasy occulte mignonne » : chaleureux au port, inquiétant mais pas gore au marais.

## 2. Règles techniques communes

- **PNG à fond transparent** pour tout ce qui est un calque, un objet ou un effet. Pas d'ombre
  portée cuite sur le sol pour les objets séparés : le jeu ajoute les ombres.
- Écran de jeu : **paysage 1920 × 1080**. Les décors sont livrés **en calques séparés**
  (ciel, lointain, plan moyen, sol, premier plan) **à la même taille**, empilables tels quels.
- **Un fichier `Layout.json` par scène** : pour chaque objet séparé, son nom de fichier, sa
  position (x, y du **point au sol**, en pixels de l'image de la scène), son calque et s'il est
  cliquable. Exemple : `{"file": "Loge_Des_Heros.png", "x": 520, "y": 610, "layer": "mid",
  "click": "loge_des_heros"}`.
- **Animations en planches de sprites** : images de même taille alignées horizontalement,
  8 à 12 images par boucle, avec le nombre d'images et les images par seconde dans le nom
  (`Fumee_Cheminee_8f_10fps.png`). Les boucles doivent revenir parfaitement au début.
- Échelle de référence : un héros mesure **240 px de haut** dans une scène 1920 × 1080 au premier
  plan. Tout est dessiné à cette échelle (une porte fait environ 300 px de haut).
- Livraison : **un ZIP par lot**, avec un `LIRE_MOI.md` qui liste chaque fichier.

---

## LOT 1 : le port de Port-Franc (le hub), en priorité

Le joueur voit la ville de face, un peu en hauteur, comme une **scène de théâtre en plans
étagés**. La scène fait **3840 × 1080** (deux écrans de large) : le joueur la fait glisser
horizontalement et les calques bougent à des vitesses différentes (parallaxe).

**Composition, de gauche à droite** : le Marché et les maisons de l'herboriste à gauche ; au centre
la grande place pavée avec la **Lanterne des serments** ; la Loge des héros et Ma loge sur une
terrasse derrière, avec un escalier au milieu ; à droite la Table des chasses, puis le quai, la
mer, les bateaux et un phare au loin. Au fond, les toits de la ville en terrasses, les remparts,
et à l'horizon le continent (voir plus bas).

**Calques** (3840 × 1080 chacun, transparents sauf le ciel) :
1. `Port_Ciel.png` : ciel de fin d'après-midi doré et rose, quelques nuages.
2. `Port_Horizon.png` : le continent lointain en silhouettes claires et bleutées (forêt de
   Sylvecroc, marais de Brumenoire, la **Tour de Morvath** noire avec une lueur violette au
   centre, volcans de Cendrefer, falaises de Sel-Brisé, île flottante des Dragons), et la mer.
3. `Port_Ville_Fond.png` : toits en terrasses, remparts, arbres.
4. `Port_Place.png` : la place pavée, le sol, l'escalier, le quai et l'eau proche. C'est là que
   marchent les personnages (bande de sol entre y = 620 et y = 1000).
5. `Port_Premier_Plan.png` : quelques éléments devant (feuillages, tonneaux, lanternes,
   cordages) sur les bords gauche et droit uniquement, pour encadrer sans cacher la place.

**Bâtiments et objets séparés** (PNG transparents, posés par `Layout.json`, cliquables) :
`Loge_Des_Heros.png`, `Ma_Loge.png`, `Marche.png`, `Table_Des_Chasses.png`,
`Lanterne_Des_Serments.png` (avec son cœur violet séparé : `Lanterne_Coeur.png`),
`Echoppe_Des_Masques.png`, `Tour_De_Morvath.png` (lointaine, cliquable). Chaque bâtiment :
façade de trois quarts, porte visible, enseigne qui dit sa fonction **sans texte**, fenêtres
chaudes.

**Animations du port** (planches de sprites) : fumée des cheminées, drapeaux et fanions au vent,
flammes des lanternes, eau du port qui scintille, bateau qui tangue, mouettes qui volent, cœur
de la Lanterne qui pulse, feuillage qui bouge. Plus une **version éclairée** de chaque bâtiment
cliquable (`Loge_Des_Heros_Survol.png` : contour doré lumineux) pour quand on le touche.

## LOT 2 : l'arène de combat du Marais de Brumenoire

Une scène **1920 × 1080**, vue de trois quarts légèrement en hauteur, comme une **scène de
combat de RPG** : les héros à gauche, les ennemis à droite, sur un sol bien lisible.

- **Zone de combat** : bande de sol dégagée entre y = 560 (fond) et y = 940 (devant) sur toute
  la largeur. Les personnages s'y placent : plus haut = plus loin = un peu plus petits.
- **Calques** : `Marais_Ciel.png` (ciel nocturne vert-gris brumeux), `Marais_Fond.png` (ruines
  du temple englouti, arbres morts tordus, eau sombre), `Marais_Sol.png` (sol de pierre et de
  vase, flaques, roseaux), `Marais_Premier_Plan.png` (roseaux, racines, chaînes rouillées et
  crânes moussus **uniquement sur les bords**).
- **Animations** : brume qui glisse (calque semi-transparent qui se répète horizontalement),
  feux follets verts, eau qui ondule, lucioles.
- Une **variante boss** (`Marais_Boss_*.png`) : même lieu, plus sombre, avec un autel de Vel'Zareth
  et des cristaux violets au fond.

## LOT 3 : les effets des attaques (sprites)

Effets dessinés dans le même style, planches de 8 à 12 images, fond transparent, environ
512 × 512 par image, centrés sur le point d'impact :
`Effet_Entaille` (coup de lame), `Effet_Impact_Marteau` (choc et poussière), `Effet_Toupie`
(tourbillon de lames), `Effet_Eclair` (éclair qui tombe du ciel), `Effet_Poing_Foudre`,
`Effet_Eclat_Glace` (projectile + éclat), `Effet_Vague_Soin` (vague turquoise douce),
`Effet_Bouclier` (dôme doré qui apparaît), `Effet_Brume_Maudite` (nuage vert-violet),
`Effet_Trait_Ombre` (projectile violet + impact), `Effet_Nova_Ombre` (anneau violet qui
s'étend), `Effet_Etourdi` (étoiles qui tournent, en boucle), `Effet_Poison` (bulles, en boucle),
`Effet_Mort_Ennemi` (dissolution en fumée violette), `Effet_Niveau` (rayon doré pour les
montées de niveau).

## LOT 4 : la Lanterne des serments (écran d'invocation)

Une scène 1920 × 1080 : la grande Lanterne vue de près, de nuit, au-dessus d'un cercle de pierre
gravé de runes, avec des voiles qui flottent. Calques : fond, cercle de runes (blanc neutre : le
jeu le colore selon la rareté), Lanterne, voiles. Animations : voiles qui ondulent, runes qui
s'allument une à une (12 images), **rayon de révélation** (colonne de lumière blanche,
10 images) et silhouettes floues qui passent derrière les voiles.

## LOT 5 : la carte du continent

Une carte 2D illustrée de CREOS, **3840 × 2160**, comme une vieille carte peinte : Port-Franc
au sud au bord de la mer, la forêt de Sylvecroc, le Marais de Brumenoire, les Côtes de Sel-Brisé,
les Pics de Cendrefer, l'Île des Dragons qui flotte, et la Citadelle de Morvath au centre. Les
**noms des lieux ne sont pas écrits** : le jeu les affiche. Fournis aussi les **pastilles de
donjon** (PNG séparés : verrouillé, ouvert, terminé avec 1 à 3 étoiles) et un chemin en
pointillés qui relie les lieux (`Carte_Chemins.png`).

## LOT 6 : l'interface (icônes et cadres)

Dans le même style encré, fond transparent :
- **Icônes des bâtiments et menus** (256 × 256) : Table des chasses, Loge des héros, Lanterne des
  serments, Marché, Ma loge, Échoppe des masques, Primes, Récompenses, Corruption, Classement,
  Guilde, Tour, Profil, Paramètres, Son.
- **Monnaies et objets** (128 × 128) : or, gemmes, énergie, fragments de relique, essence d'ombre,
  fragments de héros (une icône générique), coffre fermé et ouvert.
- **Icônes des 12 attaques de nos héros** (256 × 256, dans un médaillon rond) : Entaille du
  corbeau, Danse des lames, Pique du corbeau (Corbin) ; Marteau du rempart, Bouclier solaire,
  Impact du bastion (Aegis) ; Éclat lunaire, Marée apaisante, Malédiction de brume (Brume) ;
  Paume foudroyante, Pas du tonnerre, Sentence céleste (Orage).
- **Cadres** : un cadre de fenêtre en parchemin ivoire cerclé d'encre, découpable en 9 parties
  (coins + bords + centre, 96 px de bord), un ruban de titre bordeaux, un bouton rond et un bouton
  long (normal / appuyé), une barre de vie (cadre + remplissage) et un cadre de portrait rond.

## Ordre de livraison

1. **Lot 1, le port** (c'est l'écran qu'on voit le plus).
2. **Lot 2, l'arène du marais** et **lot 3, les effets**.
3. Lot 6 (interface), puis lot 4 (invocation), puis lot 5 (carte).

Signale clairement ce qui n'est pas parfaitement raccord (calques qui ne se superposent pas au
pixel, animations qui ne bouclent pas) : je vérifie tout dans le jeu et je te renvoie des
captures.
