# CREOS — Interface, coffres, icônes, port et héros (brief pour ChatGPT)

> **Pour Hugo** : donne ce fichier et le dossier `sources/` (ou le zip entier) à ChatGPT et dis-lui
> « Suis le brief, commence par le lot 1 et montre-moi la planche avant de continuer ».
> Les lots sont rangés du plus utile au plus lourd : tu peux t'arrêter après n'importe lequel.
> Le lot 8 (héros) ne se lance que si tu le décides. Le reste du document est écrit pour ChatGPT.

---

You are the artist of **CREOS**, my own mobile fantasy RPG (original world). You already painted its
battle arenas, its rooms and their characters. The scenery is now beautiful, but the **interface
pieces are still old pixel art** and clash with it. Your job: repaint these pieces so that the whole
game looks like one single hand-painted game.

Work **one image at a time**, in the order of the lots. After each lot, show me a contact sheet and
wait. At the end give me one zip: `CREOS_Interface/recu/<lot folder>/<exact file name>.png`. Do not
resize or crop: I do it when I install.

## The style

- `sources/style/STYLE_1_salle.jpg`, `STYLE_2_salle.jpg`: two rooms you painted. The interface lives
  on top of images like these.
- `sources/style/STYLE_OBJETS.jpg`: two objects you painted (a display stand, a lectern). **This is
  exactly the look I want for every interface piece**: carved dark wood, polished brass with small
  teal gems, burgundy velvet, ivory parchment, clean dark outline, soft painted shading, a clear
  light from the upper left.
- `sources/style/STYLE_PERSONNAGES.jpg`: how characters look.
- Palette: burgundy `#793b49`, brass `#c6a66c`, ivory `#eee4cd`, ink `#29262e`, slate `#505e75`,
  teal `#63c8be`.
- `sources/ecrans/jeu_*.jpg`: screenshots of the game today, to see where each piece is used.
  **Never copy text from them.**
- `sources/pieces/*.png`: the current pieces, enlarged and numbered. They show the **shape, the
  proportions and the role** of each piece. Keep those; replace the pixel look with the painted one.

## Rules for every interface piece

1. **Transparent background** (PNG with alpha). No scenery, no cast shadow outside the piece.
2. **Seen exactly from the front**, no perspective, no rotation, perfectly symmetrical left/right.
3. **No text, no letters, no numbers, no icon inside** unless the piece is an icon: the game writes
   on it. The writing area stays flat and plain (one calm colour, at most a very soft texture).
4. **Stretchable pieces** (buttons, panels, ribbons, bars): all ornaments stay in the corners and at
   the ends. The middle of every edge is a simple straight border, so I can stretch the piece.
5. Same proportions as the numbered reference. One piece per image, centred, with a small margin.
6. A pressed state is the **same piece, same size**, slightly darker and pushed down 4 pixels.

---

# LOT 1 — The common kit (used on every screen)

Reference: `sources/pieces/kit_actuel.png`. Folder `recu/kit/`.

| Output file | What | Shape |
|---|---|---|
| `bouton_vert.png`, `bouton_vert_appuye.png` | Main action button: emerald green enamel plate in a brass frame, brass rivets in the 4 corners | 3:1 |
| `bouton_bois.png`, `bouton_bois_appuye.png` | Secondary button: carved dark wood plate, thin brass edge | 3:1 |
| `bouton_rouge.png`, `bouton_rouge_appuye.png` | Danger button: burgundy enamel, brass frame | 3:1 |
| `bouton_gris.png` | Disabled button: dull slate stone, tarnished frame | 3:1 |
| `fenetre.png` | Game window: ivory parchment sheet in a carved wood and brass frame, ornate corners, plain centre | square |
| `panneau.png` | Inner panel: darker parchment card with a thin brass border, plain centre | 4:3 |
| `panneau_sombre.png` | Dark panel: slate-blue lacquered board with a thin brass border, plain centre (for light text) | 4:3 |
| `ruban_titre.png` | Title ribbon: burgundy cloth banner with folded swallow-tail ends and brass tips, plain centre | 5:1 |
| `bandeau_titre.png` | Title sign for the rooms: burgundy plaque held by two brass brackets with teal gems at the ends | 7:1 |
| `croix.png`, `croix_appuye.png` | Close button: square burgundy tile with a brass X, brass frame | square |
| `retour.png`, `retour_appuye.png` | Back button: wooden arrow sign pointing left, brass tip, plain centre | 3:1 |
| `cartouche_ressource.png` | Resource counter: dark slate pill with a round brass socket on the left (an icon goes in the socket), plain centre | 3:1 |
| `barre_fond.png` | Empty progress bar: dark groove in a brass frame with rounded ends | 10:1 |
| `parchemin.png` | Wide text scroll: ivory parchment rolled on two brass rods at left and right, plain centre | 7:1 |
| `cadre_objet.png` | Item slot: square dark velvet cushion in a brass frame, empty | square |
| `infobulle.png` | Tooltip: small ivory note with a brass pin on top, plain centre | 2:1 |
| `pastille.png` | Notification dot: round glossy red gem in a thin brass ring | square |
| `cadenas.png` | Lock icon: small brass padlock | square |

---

# LOT 2 — Daily gift and monster album

References: `sources/ecrans/jeu_cadeau_du_jour.jpg`, `jeu_album.jpg`. Folder `recu/ecrans/`.

| Output file | What | Shape |
|---|---|---|
| `carte_jour.png` | Reward card: tall ivory card in a brass frame, a burgundy header strip at the top (plain, a day number is written there), large plain centre (a reward icon is drawn there), plain footer | 2:3 |
| `carte_jour_active.png` | Same card, today's card: teal glowing frame, small sparkles on the frame only | 2:3 |
| `carte_jour_prise.png` | Same card, already taken: washed-out grey parchment, tarnished frame | 2:3 |
| `carte_jour7.png` | The big 7th-day card: wider, golden frame with laurels and a crown on top, golden header strip, plain centre | 3:4 |
| `tampon_pris.png` | Wax seal stamp: round green wax seal with a simple check-mark shape pressed in it | square |
| `coffre_cadeau.png` | The 7th-day chest: closed burgundy and gold treasure chest with small wings and a star gem, three-quarter view | square |
| `album_fond.png` | Album background, **not transparent, 16:9**: a huge open bestiary book lying on a hunter's desk, seen from above; both pages blank ivory and flat (24 monster portraits are drawn on them, 4 columns × 3 rows per page); candles, claws, feathers and inkwell around the book; keep the top centre calm (title) | 16:9 |
| `album_vignette.png` | Portrait frame for one monster: small square sepia paper card with photo corners, plain centre | square |
| `album_vignette_inconnue.png` | Same frame, monster not yet seen: darker paper with a faint question-mark-like ink blot (a shape, not a letter) | square |
| `fleche_page.png` | Page arrow: brass arrow pointing right on a small wooden disc | square |

---

# LOT 3 — Hero sheet (the most visited screen)

References: `sources/ecrans/jeu_hero.jpg`, `jeu_hero_voies.jpg`, `sources/pieces/grimoire_actuel.png`,
`sources/pieces/cartes_actuelles.png`. Folder `recu/fiche_heros/`.

| Output file | What | Shape |
|---|---|---|
| `fond_loge.png` | Background, **not transparent, 16:9**: the heroes' lodge, a warm trophy hall with a fireplace, banners and weapon racks. The left 40% is a calm, softly lit stone floor and wall (the hero stands there, large). The right 60% stays darker and calm (an open book is drawn there) | 16:9 |
| `grimoire.png` | The open grimoire: large open book seen from the front, leather and brass cover edges visible around, **two blank ivory pages, flat and plain**, a ribbon bookmark hanging at the bottom. Same proportions as reference 1 | 11:10 |
| `marque_page.png`, `marque_page_actif.png` | Bookmark tab sticking out of the book: burgundy leather tab with brass tip; active version in teal and a bit longer | 2:1 |
| `carte_cadre_commun.png`, `carte_cadre_rare.png`, `carte_cadre_legendaire.png` | Tarot-like hero card frame, **only the frame, the inside fully transparent**: silver-grey, blue-and-silver, gold with gems. Same proportions as the reference cards | 3:5 |
| `carte_dos.png` | Back of the card: burgundy with a brass star pattern | 3:5 |

---

# LOT 4 — Combat interface

References: `sources/ecrans/jeu_combat.jpg`, `sources/pieces/combat_actuel.png`,
`sources/pieces/etats_actuels.png`. Folder `recu/combat/`.

| Output file | What | Shape |
|---|---|---|
| `case_attaque.png` | Attack button frame: square brass frame with rounded corners and corner studs, **inside fully transparent** (an attack picture is shown inside) | square |
| `case_attaque_grise.png` | Same frame, unavailable: dull dark iron | square |
| `case_secrete.png` | Same frame for a secret technique: teal and gold, more ornate | square |
| `cartouche_vague.png` | Wave counter: small dark slate plaque in a brass frame, plain centre | 3:1 |
| `cadre_portrait.png` | Turn-order portrait frame: thin brass square frame, inside transparent | square |
| `cadre_vie.png` | Life bar frame: thin dark groove with a brass outline, rounded ends, inside transparent | 6:1 |
| `bouton_rond.png`, `bouton_rond_actif.png` | Round button: dark slate disc in a brass ring; active version glowing gold | square |
| `cartouche_boss.png` | Boss name plate: wide dark plaque with brass horns at both ends, plain centre | 8:1 |
| `etats.png` | **One image with the 20 status icons**, on a transparent background, in a grid of 5 columns × 4 rows, one icon per cell, same order and same meaning as the numbered reference: 1 attack up, 2 attack down, 3 blind, 4 shield, 5 burn, 6 defence up, 7 defence down, 8 off-balance, 9 rooted, 10 stunned, 11 guard, 12 decoy, 13 marked, 14 wet, 15 poison, 16 taunt, 17 regeneration, 18 sealed, 19 speed up, 20 speed down. Each icon: a bold simple symbol on a small round coloured medallion with a dark outline, readable at 32 pixels | 5:4 |

---

# LOT 5 — Treasure chests

Reference: `sources/pieces/coffres_actuels.png`. Folder `recu/coffres/`. Transparent background,
three-quarter view, **closed and open versions at the same size and position**; the open one shows a
bright glow inside and no objects.

| Output files | What |
|---|---|
| `coffre_bois_ferme.png`, `coffre_bois_ouvert.png` | Common chest: plain wood with iron bands |
| `coffre_fer_ferme.png`, `coffre_fer_ouvert.png` | Rare chest: blue steel with silver bands, blue glow |
| `coffre_or_ferme.png`, `coffre_or_ouvert.png` | Epic chest: gold with rubies, golden glow |
| `coffre_serment_ferme.png`, `coffre_serment_ouvert.png` | Legendary chest: burgundy and gold with small wings and a star gem, violet-gold glow |
| `coffre_prime_ferme.png`, `coffre_prime_pret.png`, `coffre_prime_ouvert.png` | Small bounty chest: closed and dull; closed and glowing (ready); open and empty |

---

# LOT 6 — Icons

Folder `recu/icones/`. Each output is **one image with all the icons in a grid on a transparent
background, one icon per cell, in the same order as the numbered reference**. Painted little objects
with a clean dark outline, readable when small.

- `ressources.png` — reference `sources/pieces/icones_ressources.png`, grid 5 × 3: 1 summoning altar,
  2 hunting map, 3 ranking trophy, 4 oath shards (violet crystals), 5 energy (lightning bolt),
  6 gems (blue gem), 7 guild banner, 8 heroes (two hooded heads), 9 private lodge (small keep),
  10 market (mask), 11 gold (pile of coins), 12 bounties (poster with a seal), 13 rewards (gift
  chest), 14 relics (jewelled cross relic), 15 tower.
- `objets.png` — reference `sources/pieces/icones_objets.png`, grid 8 × 4, the 31 objects in the same
  order (chests, relic crystal, the 4 dungeon defences, shard, essence, ore, the 5 machine parts, the
  5 traps, rune stone, the 4 experience scrolls).
- `boutons_port.png` — reference `sources/pieces/port_boutons.png`, grid 4 columns: the round menu
  medallions of the town (same subjects, same order), each a painted emblem in a round brass frame.

---

# LOT 7 — The town square ⚠ (big job, do it last)

References: `sources/ecrans/jeu_port.jpg`, `sources/pieces/port_sol_actuel.jpg`,
`sources/pieces/port_batiments.png`. Folder `recu/port/`.

The town square is the first screen of the game and the last scenery still in pixel art. It is seen
from above, at a three-quarter angle. Heroes walk on it, in front of and behind the buildings.

- `port_sol.png` — **not transparent, 16:9**: the square **without the six buildings**: the round
  paved plaza in the centre, the paths, the lawns, the walls and towers around, the trees, the
  street lamps, the flower beds. Same layout as `port_sol_actuel.jpg`: every path and every empty
  building plot stays at the same place. Daylight, warm.
- Six buildings, each on a **transparent background**, same subject, same angle and same proportions
  as in `port_batiments.png`: `hero_lodge.png` (the heroes' lodge, big half-timbered hall),
  `hunt_table.png` (hunters' stall with a map and a skull crest), `merchant.png` (mask merchant's
  stall), `oath_lantern.png` (pavilion with the horned urn), `private_lodge.png` (small house with a
  red roof), `relics.png` (the pavilion with the violet crystal).

---

# LOT 8 — The 19 heroes ⚠ (only if I ask for it)

Folder `sources/heros/` holds the reference drawing of each hero (full body, standing). My game cuts
these drawings into body parts and animates them, so the pose must not change.

For each hero, repaint the reference in the style of `STYLE_PERSONNAGES.jpg`: **same character, same
outfit, same colours, and exactly the same pose, the same proportions and the same position in the
image** (arms, legs, weapon and cape at the same place). Only the rendering changes: richer painted
shading, cleaner outline, more detail in the materials. Transparent background, square image, as
large as you can. Save as `recu/heros/<same file name>.png`.

Start with `corbin.png` alone and stop: I test it in the game before you do the others.

---

# Checklist before each image

- Transparent background where asked? Seen from the front? Symmetrical?
- No text, no number, nothing in the writing area?
- Ornaments only in the corners and at the ends for stretchable pieces?
- Does it sit next to `STYLE_OBJETS.jpg` as if it came from the same set?

If one of these fails, redo the image before moving on.
