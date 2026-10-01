# Port-Franc — FULL 2D — Lot 1

30 PNG : 5 calques, 9 objets indépendants, 7 états de survol, 8 bandes d’animation et 1 aperçu de direction artistique. Aucun décor 3D. Tous les fichiers sont vérifiés par décodage intégral avant archivage.

Calques et aperçu : 3840 × 1080. Objets : 1024 × 1024, cœur : 512 × 512. Animations : bandes horizontales, cases 512 × 512. Nombre de cases et fréquence dans le nom et Manifest.json.

Layout.json propose des positions et tailles d’affichage, à régler dans Godot. x/y correspond au point d’ancrage inférieur des objets ; les calques utilisent leur coin supérieur gauche. Le cœur de la lanterne possède son propre point de placement. Les coordonnées sont indicatives et ne constituent pas une scène Godot montée.

## Limites à vérifier

- Les calques ont été dessinés séparément : raccords, perspective et chevauchements nécessitent un ajustement. L’aperçu est une référence dessinée, pas une capture des calques assemblés.
- Les panoramas sont rééchantillonnés en 3840 × 1080 ; ce n’est pas leur résolution native. Cet export modifie leur rapport de proportions.
- Les états de survol peuvent varier légèrement en silhouette et alignement : transition à vérifier avant emploi.
- Boucles et pivots non validés dans Godot : quelques images peuvent dériver. Aucun fondu ni animation parfaitement raccordée n’est garanti.
- Le bateau utilise six vues orientées à gauche en aller-retour (10 cases). Les deux vues inversées ont été exclues.
- Eau_Port représente des reflets stylisés assez marqués. Contrôler opacité, échelle et raccord à l’eau du décor.
- Certains objets comportent des ombres et détails plus riches que les aplats des héros. Vérifier aussi les franges de transparence, nuages superposés et lisibilité à la taille mobile.
- Ajuster les bâtiments pour des portes proches de 300 px face à des héros de 240 px.

## Inventaire
- Port_Ciel.png
- Port_Horizon.png
- Port_Ville_Fond.png
- Port_Place.png
- Port_Premier_Plan.png
- Port_Apercu_Reference.png
- Loge_Des_Heros.png
- Ma_Loge.png
- Marche.png
- Table_Des_Chasses.png
- Echoppe_Des_Masques.png
- Lanterne_Des_Serments.png
- Lanterne_Coeur.png
- Tour_De_Morvath.png
- Bateau_De_Peche.png
- Loge_Des_Heros_Survol.png
- Ma_Loge_Survol.png
- Marche_Survol.png
- Table_Des_Chasses_Survol.png
- Echoppe_Des_Masques_Survol.png
- Lanterne_Des_Serments_Survol.png
- Tour_De_Morvath_Survol.png
- Fumee_Cheminee_8f_10fps.png
- Fanion_8f_10fps.png
- Flamme_Lanterne_8f_12fps.png
- Eau_Port_8f_10fps.png
- Mouette_8f_10fps.png
- Feuillage_8f_8fps.png
- Bateau_Tangue_10f_8fps.png
- Lanterne_Pulse_8f_10fps.png

Lots suivants non inclus : arène des marais, effets de combat, interfaces, invocation, carte du monde.
