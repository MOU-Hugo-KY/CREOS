# Charte « pixel art sobre » (refonte, novembre 2026)

Décision de Hugo : le style actuel est trop doré, trop chargé, « trop de pixels partout ».
On refait tout (fonds compris) en **pixel art sobre** : gros pixels nets, peu de couleurs, beaucoup de calme.

## 1. Les règles

1. **Une seule chose importante par zone.** Le fond se tait, l'interface parle, le personnage brille.
2. **Gros pixels.** Fonds dessinés en 480 × 270 (ou 640 × 360), agrandis ×4 / ×3 sans lissage. Jamais de détail
   plus fin qu'un pixel à cette taille : pas de dorures ciselées, pas de motifs dans les motifs.
3. **Palette courte.** 5 à 6 couleurs par écran au plus, + la couleur d'accent de l'écran.
4. **Fonds calmes.** Peu de contraste, couleurs désaturées, grands aplats ; le centre de l'écran (là où va
   l'interface) est le plus vide.
5. **Or rare.** L'or ne sert qu'à signaler la récompense ou le légendaire. Jamais en bordure de cadre ni sur les boutons ordinaires.
6. **Cadres fins.** Bordure de 1 pixel d'art (= 4 px à l'écran) en encre, + 1 pixel de lumière en haut. Pas d'ornements aux coins.
7. **Lisible au doigt.** Boutons d'au moins 96 px de haut (en 1920 × 1080), texte d'au moins 24 px, noms d'au moins 22 px.

## 2. La palette commune

| Rôle | Couleur |
|---|---|
| Encre (contours, texte sur clair) | `#1c1b24` |
| Nuit (panneaux sombres) | `#2b2d3a` |
| Ardoise (boutons secondaires) | `#4a5468` |
| Pierre (bordures, éléments éteints) | `#7d8597` |
| Ivoire (panneaux clairs) | `#e9e0c9` |
| Turquoise (action principale, magie) | `#4fb3a5` |
| Bordeaux (danger, titres) | `#9c3f4a` |
| Or (récompense seulement) | `#d8b25a` |

Chaque monde du combat garde **une** couleur d'accent (Brumenoire = vert d'eau, etc.).

## 3. Ce que je refais moi-même, en code (sans images)

Cadres de fenêtre, boutons (normal / appuyé / grisé), rubans de titre, onglets, barres (vie, énergie, XP),
cartouches de monnaie, bulles, info-bulles, pastilles d'étoiles. Ils sont dessinés à l'échelle ×4 dans `UiKit`, d'après la
palette ci-dessus. Ils remplacent les pièces dorées des packs `assets/ui/finitions/*` (cadres, `bandeau_titre`, `retour`,
`bouton_*`, `cartouche_monnaie`, `parchemin`).

## 4. Les fonds à refaire (images à générer)

Format demandé pour chacun : **PNG 480 × 270, pixel art, sans texte, sans interface, sans personnage**
(sauf indication), palette de 12 couleurs au plus, centre dégagé.

Début commun de chaque demande (à coller avant la description) :

> Pixel art background, 480x270 pixels, chunky readable pixels, limited muted palette (max 12 colors),
> calm low-contrast composition, large flat areas, no gold ornaments, no text, no UI, no characters,
> the center third of the image is mostly empty and dark so a menu can sit on top. Style: cozy, minimal, modern pixel art.

| # | Écran | Fichier actuel | Description à ajouter |
|---|---|---|---|
| 1 | Port-Franc (hub) | `hub_px/backgrounds/hub_ground.png` | Vue de dessus d'une petite place de port : pavés unis, quelques arbres ronds, eau calme en bas. (Les bâtiments restent des images à part, à refaire ensuite dans le même style.) |
| 2 | Loge des héros | `ui/ecrans/fiche_heros/…` | Salle de pierre simple, deux fenêtres, une bibliothèque sombre. Bleu nuit. |
| 3 | Table des chasses (pièce) | `finitions/table_chasses/salle_cartographe.png` | Table en bois vue de haut, bougie unique. Brun doux. |
| 4 | Carte du monde | `finitions/table_chasses/carte_monde.png` | Carte sur parchemin uni, 10 régions simples (une couleur chacune), chemins pointillés, sans cadre doré. |
| 5 | Préparation de chasse | `finitions/preparation_chasse/campement.png` | Clairière de nuit, sol de terre uni au centre, un feu de camp à gauche. |
| 6 | Échoppe des masques | `ui/echoppe/echoppe/echoppe_fond.png` | Petite boutique, étagères simples, 3 masques. Bordeaux sourd. |
| 7 | Reliquaire | `ui/echoppe/reliquaire/reliquaire_fond.png` | Crypte simple, mur de niches en grille régulière, lumière froide. |
| 8 | Table des quatuors | `ui/echoppe/quatuors/table_quatuors_fond.png` | Table ronde de pierre vue de haut. |
| 9 | Lanterne (hall) | `finitions/hall_objets/hall_invocateurs.png` | Trois arches simples, chacune d'une couleur (violet, orange, vert), sol uni. |
| 10 | Salle du Mage | `ui/invocateurs/mage/salle_mage.png` | Observatoire, un grand cercle de runes au sol, violet. |
| 11 | Salle du Mécanicien | `ui/invocateurs/mecanicien/salle_mecanicien.png` | Atelier, deux engrenages, établi, orange. |
| 12 | Jardin des Esprits | `ui/invocateurs/jardin/jardin_esprits.png` | Jardin de nuit, un nid au centre, vert d'eau. |
| 13 | Stèle | `ui/invocateurs/stele/salle_stele.png` | Stèle de pierre seule, lumière bleue. |
| 14 | Druide | `ui/invocateurs/druide/salle_druide.png` | Sanctuaire de racines, vert. |
| 15 | Primes du jour | `finitions/primes/tableau_primes.png` | Mur de taverne avec un grand panneau de liège vide. |
| 16 | Profil | `finitions/profil/bureau_chasseur.png` | Bureau avec étagère à trophées vide (niches régulières). |
| 17 | Ma Loge (donjon) | `finitions/ma_loge/loge_coupe.png` | Coupe d'un donjon : 3 salles côte à côte, murs unis. |
| 18 | Paramètres | `finitions/parametres/boite_musique.png` | Fond uni bleu nuit avec une boîte à musique simple. |
| 19 | Chargement | `finitions/popups/chargement.png` | Silhouette du port au crépuscule, très simple. |
| 20 | Victoire / défaite | `finitions/combat/victoire_fond.png`, `defaite_fond.png` | Ciel clair avec rayons / ciel gris avec pluie, rien d'autre. |
| 21–30 | Arènes des 10 mondes | `decors/mondeNN/` (fond1-3, sol, premier plan) | Arène en 3 couches : ciel uni, une silhouette de paysage, sol plat au premier tiers bas. Une couleur d'accent par monde. |

Ordre conseillé : 1 (hub) et 21 (arène du monde 1) d'abord, pour valider le style sur les deux écrans
les plus vus, puis le reste.

## 5. Les cartes de héros et les icônes

Les cartes de tarot (`ui/arcanes/`) et les icônes suivent la même règle : cadre fin à 1 pixel, fond uni de la
couleur de l'élément, pas de dorure (l'or seulement pour la rareté Légendaire).
