# CREOS — dessins des ennemis du premier donjon : le Marais de Brumenoire

Même méthode que pour nos héros Corbin, Aegis, Brume et Orage : des **dessins 2D** animés comme
des marionnettes dans le jeu. Les fiches de nos héros sont jointes (`corbin_fiche.png`,
`brume_fiche.png`) : **même style, même trait, même échelle**, pour que héros et ennemis aient
l'air du même jeu. La planche `style_reference.jpg` sert seulement de référence de style ; ne
recopie aucun de ses personnages.

## Le lieu et l'histoire

Le **Marais de Brumenoire** : brouillard épais, eau stagnante vert-noir, ruines d'un temple
englouti, arbres morts. Il est tenu par **Vel'Zareth la Liche**, lieutenante de **Morvath le Mage
Noir**. Ses morts-vivants sont les anciens habitants du marais, relevés par sa magie. Les ennemis
doivent faire **un peu peur mais rester mignons** : pas de gore, ni de sang, ni d'organes.

## Le style (identique aux héros)

- Chibi trapu, **grosse tête** (≈ 45 % de la hauteur), corps compact, petites jambes.
- **Trait noir épais et régulier**, aplats de couleur avec une seule ombre franche, sans dégradé
  ni texture.
- Palette des ennemis : **os ivoire jauni**, tissus **charbon** et **gris-vert de vase**, métal
  rouillé, algues et mousse vert sombre. Leur magie est **violette** (couleur de Morvath), avec
  une touche de **vert spectral** pour les yeux. Les yeux brillent dans les orbites.
- Chaque ennemi a **une silhouette différente**, reconnaissable en tout petit, même en ombre
  chinoise.
- Ils sont tous **tournés vers la GAUCHE** (ils font face aux héros, qui regardent à droite).

## Les 5 ennemis

### 1. Serviteur squelette (le plus faible, il vient en nombre)
- **Rôle en combat** : chair à canon rapide, griffe au corps à corps.
- **Look** : petit squelette **maigre et voûté**, haillons de tissu gris en lambeaux à la taille,
  **une seule griffe d'os** allongée à la place d'une main, mâchoire pendante, crâne fendu, deux
  points verts dans les orbites, quelques algues accrochées aux côtes.
- **Attitude** : penché en avant, prêt à bondir.
- Taille : **la plus petite** (environ 85 % d'un héros).

### 2. Guerrier squelette (le costaud)
- **Rôle en combat** : encaisse les coups, frappe fort.
- **Look** : squelette **large d'épaules**, **casque rouillé cabossé** à cornes cassées,
  **grand bouclier rond en bois pourri** cerclé de fer (avec un symbole violet de Morvath peint
  dessus), **hache rouillée** ébréchée, cotte de mailles déchirée, cape charbon effilochée.
- **Attitude** : campé, bouclier en avant.
- Taille : comme un héros, mais **plus massif**.

### 3. Rôdeur squelette (rapide et sournois, élément eau)
- **Rôle en combat** : attaque à distance en lançant des lames.
- **Look** : squelette fin à **capuche rouge sombre délavée** qui cache le haut du crâne (on voit
  seulement la mâchoire et deux yeux verts), **foulard** sur le bas du visage, **ceinture de
  couteaux** en travers du torse, un couteau courbe dans chaque main, pieds dans l'eau avec des
  gouttes et des coquillages.
- **Attitude** : accroupi, un couteau levé, prêt à lancer.
- Taille : comme un héros.

### 4. Acolyte de Morvath (le mage du culte)
- **Rôle en combat** : lance des traits d'ombre violets.
- **Look** : humanoïde caché sous une **grande robe à capuche violet-noir**, **masque d'os
  blanc** sans bouche avec deux yeux violets brillants, **symbole de Morvath** (œil fendu ou
  tour) brodé en laiton sur la poitrine, **bâton** surmonté d'un **cristal violet** qui flotte,
  chaînettes et petits crânes à la ceinture, bas de robe en lambeaux qui traîne dans la vase.
- **Attitude** : bâton levé, l'autre main ouverte avec une petite flamme violette.
- Taille : comme un héros, un peu plus grand grâce à la capuche pointue.

### 5. Vel'Zareth la Liche (le BOSS)
- **Rôle en combat** : boss du donjon. Rayon d'ombre, toucher glacial (sur le héros le plus
  faible) et **Nova nécrotique** (explosion violette sur toute l'équipe).
- **Look** :
  - **liche squelettique féminine**, **couronne** de laiton noircie à pointes ;
  - longs **cheveux spectraux violets** qui flottent comme sous l'eau ;
  - **robe royale en lambeaux** violet profond et charbon, col haut ;
  - **mains squelettiques** très longues, l'une tenant un **bâton** surmonté d'un **crâne
    cornu** ;
  - un **phylactère** (petite fiole-relique lumineuse violette) qui flotte devant sa poitrine ;
  - flammes violettes dans les orbites, **pas de jambes** : le bas de la robe se dissout en
    brume.
- **Attitude** : elle **lévite**, bras écartés, dominante mais toujours « chibi ».
- Taille : **1,6 fois** un héros. Elle doit se reconnaître immédiatement comme le boss.

## Ce qu'il faut pour CHAQUE ennemi (2 images, comme pour les héros)

### Image 1 : la fiche
- L'ennemi **entier**, de trois quarts, **tourné vers la gauche**, dans sa pose de repos.
- **Fond transparent** (PNG), image carrée 1024 × 1024, personnage centré, pieds en bas de l'image
  (marge de 40 px). Pour Vel'Zareth : 1536 × 1536.

### Image 2 : les pièces détachées
Le **même** ennemi, **même taille, même angle, même trait**, découpé en pièces séparées, posées
avec de l'espace entre elles, sur **fond transparent**, image 2048 × 1024 :
1. **Tête** (avec capuche, casque, couronne ou cheveux), coupée au cou ;
2. **Corps** (torse, bassin, jambes, bras arrière), **sans** la tête et **sans** le bras avant ;
3. **Bras avant avec son arme** (griffe, hache, couteau, bâton) ;
4. **Pièce en plus** si l'ennemi en a une :
   - bouclier (Guerrier) ;
   - cape ou bas de robe flottant (Acolyte, Vel'Zareth) ;
   - phylactère (Vel'Zareth : pièce séparée qui flottera seule).

Prolonge un peu chaque pièce sous la jointure (cou, épaule) pour qu'il n'y ait pas de trou quand
elle bouge.

## Livraison

Un ZIP par ennemi, nommé `<Nom>_2D.zip` (par exemple `Serviteur_Squelette_2D.zip`), avec
`<Nom>_Fiche.png` et `<Nom>_Pieces.png`. Commence par le **Serviteur squelette** et
**Vel'Zareth** (le plus simple et le plus important), puis les trois autres.
