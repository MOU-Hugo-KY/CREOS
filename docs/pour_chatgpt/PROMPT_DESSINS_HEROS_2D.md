# CREOS — dessins des héros en 2D (pour le générateur d'images de ChatGPT)

On change de méthode : les personnages ne sont plus modélisés en 3D. Ce sont des **dessins 2D**
animés comme des marionnettes (comme *Cult of the Lamb*), dans un décor en 3D. Il me faut des
**dessins**, pas de scripts Blender.

La référence de style est la planche jointe (`style_reference.jpg`). Elle sert **seulement pour le
style** : ne recopie aucun de ses personnages. Les nôtres sont originaux.

## Le style (à respecter sur toutes les images)

- Fantasy occulte mignonne : personnages **chibi trapus**, grosse tête ou gros couvre-chef
  (≈ 45 % de la hauteur), corps en forme de cloche, **petites jambes noires courtes**, mains
  simples.
- **Trait noir épais et régulier** autour de chaque forme, traits intérieurs plus fins.
- Couleurs **en aplats** avec une seule ombre franche par couleur, pas de dégradé ni de texture,
  et pas de fond.
- Palette : bordeaux poussiéreux, ivoire, vert mousse, charbon, cuir brun, gris ardoise, laiton.
  Magie en vert spectral, turquoise ou violet.
- Visages simples ou **masques** expressifs, gros accessoires lisibles de loin (armes, bâtons,
  boucliers, cornes, capuches).

## Les 5 héros

| Nom | Rôle | À dessiner |
|---|---|---|
| **Corbin** | lame agile, ombre | capuche bordeaux pointue, **long masque de corbeau** ivoire, cape en lambeaux, deux lames courbes, fioles à la ceinture |
| **Aegis** | gardien, lumière | casque fendu sombre avec visière en T, **très grand bouclier** laiton et ardoise, marteau de guerre, épaulières rondes |
| **Brume** | sorcière des marées, eau | grande capuche ardoise, **visage noir avec deux yeux turquoise lumineux**, bâton tordu avec un orbe turquoise, coquillages et algues sur la robe |
| **Ronce** | braconnier, nature | chapeau vert à plume, capuchon, col en fourrure, **arbalète**, trophées pendus (crocs, petit crâne), carquois |
| **Belhor** | brute, feu | **masque de crâne de bélier** à deux grosses cornes enroulées, fourrure sombre, braises orange, **deux haches** |

## Ce qu'il faut pour CHAQUE héros (2 images)

### Image 1 : la fiche du personnage
- Le personnage **entier**, de trois quarts, **tourné vers la droite**, debout, au repos, son arme
  en main.
- **Fond transparent** (PNG), image carrée 1024 × 1024, personnage centré, pieds en bas de l'image
  (marge de 40 px).

### Image 2 : les pièces détachées (pour l'animer)
Le **même** personnage, **même taille, même angle, même trait**, découpé en pièces séparées et
posées les unes à côté des autres avec de l'espace entre elles, sur **fond transparent**,
image 2048 × 1024 :
1. **Tête** : tête complète avec capuche, chapeau, casque, cornes ou masque, coupée au cou.
2. **Corps** : torse, robe ou manteau, jambes et bras arrière, **sans** la tête et **sans** le bras
   avant.
3. **Bras avant** : épaule, bras, main **et l'arme qu'il tient** (pour Aegis : le bras qui tient
   le marteau ; son bouclier reste sur le corps).
4. **Cape arrière** (si le personnage en a une) : le morceau de cape ou de manteau qui flotte
   derrière.

Les pièces doivent pouvoir se **recoller exactement** pour reformer l'image 1 : prolonge un peu
chaque pièce sous la jointure (cou, épaule) pour qu'il n'y ait pas de trou quand elle bouge.

## Ensuite (après validation des héros)
Même méthode pour : les monstres de Brumenoire (serviteur squelette, guerrier squelette, rôdeur
squelette, acolyte de Morvath), le boss **Vel'Zareth la Liche**, le **marchand de masques** du
port. Les monstres sont **tournés vers la gauche**.

**Commence par Corbin seul** (images 1 et 2) : je l'anime dans le jeu pour valider la méthode
avant de faire les autres.
