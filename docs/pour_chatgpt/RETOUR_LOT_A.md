# Retour sur la palette et le lot A (testé dans Blender 5.2.2 et dans le jeu)

## Ce qui marche (à garder)
- Le générateur tourne sans erreur dans Blender 5.2.2 ; rendus Cycles OK.
- Squelette KayKit réutilisé, 84 animations, clips sur place, palette partagée, aucune image dans
  les GLB : l'import dans Godot marche du premier coup et les animations jouent.
- Les 15 attaques sont lisibles sur les planches (anticipation, impact, retour) et respectent
  les instants d'impact. Les couleurs des héros sont les bonnes.

## Ce qui ne va pas (capture du jeu jointe : `essai_heros_lotA.png`, à comparer avec
## `essai_style_kaykit.png`, le style visé)
1. **Proportions** : nos héros sont **plus petits et plus maigres** que les squelettes KayKit
   à côté d'eux, avec une **petite tête**. Le style visé est chibi : tête ≈ 40 % de la hauteur,
   gros mains et pieds, membres épais, silhouette trapue. Dans le jeu, nos héros doivent être au
   moins **aussi grands et aussi massifs que les squelettes** (`Skeleton_Mage.glb` fourni).
2. **Construction en boîtes** : corps, bras et jambes sont des blocs séparés et facettés ; on voit
   les jointures. KayKit utilise des volumes **arrondis et continus** (ombrage lisse, biseaux,
   peu de facettes visibles). Solution la plus sûre : **partir du maillage du corps de
   `Barbarian.glb`** (CC0, poids de peau déjà parfaits) comme base, le remodeler (tête plus grosse,
   carrure propre à chaque héros) et **ajouter nos pièces** (coiffures, barbes, casques, armures,
   manteaux, armes) en volumes arrondis, chacune bien pondérée.
3. **Visages** : trop petits et plats. Yeux plus grands et plus expressifs, nez et sourcils
   simples mais marqués, comme KayKit.
4. **Torvald** : le torse nu se lit comme une **poitrine féminine**. Faire des pectoraux plats et
   carrés de colosse, ou un gilet de fourrure ouvert, avec une barbe tressée plus volumineuse qui
   descend sur le torse.
5. **Malgrave** : les plaques ressemblent à des **cubes**. Faire des plaques d'armure bombées,
   à pointes, avec un vrai casque de chevalier (visière fendue, yeux violets émissifs), et un
   **cœur de fumée violette** plus visible entre les plaques.
6. **Kaïto** : le masque rouge cache tout le bas du visage comme un bloc ; faire un vrai menpō
   (demi-masque à moustache) et des épaulières (sode) plus larges.
7. **Vesprin** et **Orage** : bien reconnaissables, mais même problème de proportions. Bec de
   Vesprin plus long et courbé, réservoir dorsal bien visible ; Orage plus massif (moine-boxeur).

## Demande
Une **v2 du lot A** avec ces corrections : mêmes noms de fichiers, mêmes os, mêmes noms
d'animations et mêmes instants d'impact. Ajoute une planche « héros à côté de `Skeleton_Mage`
et de `Barbarian` » à la même échelle pour vérifier les proportions avant livraison.
