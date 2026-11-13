# CREOS — Salles, personnages et objets des salles (brief pour ChatGPT)

> **Pour Hugo** : donne ce fichier et le dossier `sources/` (ou le zip entier) à ChatGPT, et dis-lui
> « Suis le brief, commence par le lot 1 ». Il range les images dans `recu/` et te rend un zip, comme
> pour les arènes. Le reste du document est écrit pour ChatGPT.

---

You are the background and character artist of **CREOS**, my own mobile fantasy RPG (original world,
not based on any existing game). You already painted its 30 battle arenas. Now you repaint the
**rooms** of the home town (shop, reliquary, summoning halls…), the **characters who live in these
rooms** and a few **big objects**. Everything is in the `sources/` folder.

Work **one image at a time**, in the order of the lots. After each lot, show me a contact sheet.
At the end, give me one zip: `CREOS_Salles/recu/…` with the exact file names below, plus the contact
sheets. Do not resize or crop your images: I do it when I install them.

## The style (same for everything)

- `sources/style/STYLE_1_exterieur.jpg`, `STYLE_2_interieur.jpg`, `STYLE_3_interieur.jpg`: three of
  the arenas you painted. **This is the target style for every room**: hand-painted fantasy
  illustration, rich warm colours, soft painterly shading, clean readable shapes, strong light
  sources, lots of small storytelling details. Not pixel art, not photorealistic, not a 3D render.
- `sources/style/STYLE_PERSONNAGES.jpg`: how characters look in this game. **This is the target style
  for every character and creature**: cute stocky proportions (about 2.5 heads tall), big head, clean
  dark outline, painted shading, bright readable colours.
- House colours of the town: burgundy red, brass gold, ivory, dark wood, slate blue, teal glow.
- Never: text, letters, numbers, logos, watermark, frame, border, interface elements.
- Banners and emblems use invented abstract shapes only.

---

# LOT 1 — The 15 rooms

For each room you have two images in `sources/salles/`:

- `fond_NN_name.jpg` — the **current background**. Its composition is the plan to follow.
- `jeu_NN_name.jpg` — the **same room in the game**, with the interface, cards and characters drawn
  on top. Use it only to understand what the game covers. **Never copy anything of the interface,
  the text, the cards, the icons or the characters from it.**

Rules for every room:

1. **Same camera, same framing, same layout.** Every important object stays at the same place with
   the same size and outline, because my interface is positioned precisely over the image.
2. **Areas the game draws on stay calm and plain** (they are listed for each room): no decoration,
   no strong contrast, no small bright details there.
3. **Everything else must become clearly better than the original**: more depth (a real foreground,
   middle and background), a clear main light source with a warm glow and soft shadows, richer
   materials (wood, brass, velvet, stone, glass), more charm and story in the props. Think
   "illustration of a premium mobile game", not "tileset".
4. **No characters and no creatures** in the rooms (they are separate images, lot 2).
5. Wide landscape image, **16:9**, as large as you can.

Save as `recu/salles/<output name>.png`.

### 1. Mask merchant's shop — output `echoppe_fond.png`
Sources: `fond_01_echoppe`, `jeu_01_echoppe`.
Keep: the wooden counter in the lower left with its front panel at the same place; the shelves of
potions, jars and hanging white masks in the upper left; the red curtains; the wooden floor and the
red carpet in the bottom left. **Calm areas:** the large dark-wood wall filling the right two thirds
(a display stand full of items is drawn on it); the space just behind the counter, from the counter
top up to head height (the merchant stands there); the carpet corner at the bottom left (a speech
bubble).
Make it better: a cosy cabinet of curiosities at night. Warm lantern light pooling on the counter,
more varied masks (fox, moon, owl, laughing, crying) hanging at different depths, glass jars catching
the light, a small window with a moonlit street behind the shelves, dust motes in the light.

### 2. Council round table — output `table_quatuors_fond.png`
Sources: `fond_02_table_quatuors`, `jeu_02_table_quatuors`.
Keep: the big oval table seen from above, in the centre, same size; its **empty, light parchment
top** (crests and portraits are drawn on it: keep it empty, only a very faint map drawing); the four
red chairs at the same places; the stained-glass windows, banners and chandeliers at the top.
**Calm areas:** the whole table top; the strip of floor under the table at the bottom (a text scroll).
Make it better: a solemn war-council hall. Coloured light from the stained glass falling across the
floor, candle glow from the chandeliers, carved gold rim on the table, deeper perspective in the room.

### 3. Reliquary crypt ⚠ — output `reliquaire_fond.png`
Sources: `fond_03_reliquaire`, `jeu_03_reliquaire`.
Keep EXACTLY: the stone wall with **3 rows of 7 arched niches** (21 niches) at the same positions and
the same size, all **empty and dark inside** (a relic is drawn in each one, with a name above it:
leave a little plain stone above every niche); the tall plain stone panel between two pillars on the
right (a lectern is drawn in front of it); the gothic pillars, candle stands and banners on both
sides; the reflective floor. Do not add, remove, resize or shift any niche.
Make it better: a sacred vault. Each niche framed by finely carved stone, soft candlelight washing
the wall from both sides, a faint golden haze, worn mosaic floor with reflections.

### 4. Summoners' hall — output `hall_invocateurs.png`
Sources: `fond_04_hall_lanterne`, `jeu_04_hall_lanterne`.
Keep: the three tall arches at the same places and size, each one a magical window on another place
(left: a violet arcane observatory under a nebula; centre: an orange clockwork forge with giant
gears; right: a teal moonlit garden with a waterfall); the pillars with banners and lanterns between
them; the polished floor with a round emblem. **Calm areas:** the floor strip under each arch (three
buttons) and the top centre (title).
Make it better: the three views must feel alive and deep, each with its own coloured light spilling
out onto the pillars and the floor in front of it. Stronger contrast between the dark hall and the
three bright worlds.

### 5. Dungeon cross-section ⚠ — output `loge_coupe.png`
Sources: `fond_05_mon_donjon`, `jeu_05_mon_donjon`.
Keep EXACTLY: the cutaway view of a stone dungeon with **three rooms side by side** in the upper half
(left: an entrance hall with a staircase; middle: a gallery with two statues in alcoves; right: a
treasure room with shelves), separated by pillars, same positions and sizes; a clear flat floor in
each room (defenders and traps are placed on it). **The whole lower 40% of the image stays a very
dark, almost empty band of rock** (the interface is drawn there).
Make it better: each room gets its own mood and light (cold blue hall, warm candle-lit gallery,
golden treasure glow), real thickness in the walls and vaults, roots and rock around the cutaway.

### 6. Music box (settings) — output `boite_musique.png`
Sources: `fond_06_parametres`, `jeu_06_parametres`.
Keep: the large open music box at the same place and size; its lid holding the brass cylinder and
comb; its inside lined with **empty red velvet** (three sliders are drawn on the velvet: keep it flat
and plain); the desk around it with candles, books, a globe and a lantern; the night window top left.
Make it better: jewel-like gold ornaments on the box, deep velvet, warm candlelight with soft bokeh,
tiny gears visible in the mechanism.

### 7. Hunters' camp — output `campement.png`
Sources: `fond_07_campement`, `jeu_07_campement`.
Keep: the wide **empty dirt clearing** in the centre (the heroes stand there in formation); the red
tents and weapon racks on the left; the canvas shelter with a map table on the right; the **stone
fire ring in the lower left, unlit and empty** (the game draws the flames); the forest and the
distant lit city under a night sky. **Calm areas:** the clearing; the bottom quarter of the image (a
drawer of hero portraits); the middle right (a small scroll).
Make it better: a warm camp against a cool blue night. Lanterns on poles, glow on the tent canvas,
fireflies, a starry sky, depth in the forest with mist between the trunks.

### 8. Bounty board — output `tableau_primes.png`
Sources: `fond_08_primes`, `jeu_08_primes`.
Keep: the large **empty wooden notice board** in the centre under its red drape (four posters are
drawn on it: plain planks only); the long wooden counter along the bottom (a progress bar and four
small chests sit on it: keep its top edge and front plain); the window with the moon and a distant
castle on the left; the weapon rack, shelves and mugs on the right; the antler banners.
Make it better: a cosy hunters' tavern. Honey-coloured lantern light, visible wood grain and iron
nails, a fireplace glow from the side, trophies and old posters pinned around (not on) the board.

### 9. Hunter's study (profile) ⚠ — output `bureau_chasseur.png`
Sources: `fond_09_profil`, `jeu_09_profil`.
Keep EXACTLY: the tall wooden display cabinet on the right with **4 columns × 3 rows of softly lit
empty alcoves** (12 alcoves, same positions and size; a trophy is drawn in each); the plain strip
under the cabinet (a line of text). Keep the night window, the desk with its chair, the bookshelves
and the rug on the left. **Calm areas:** the wall and desk area between the window and the cabinet
(a portrait medallion and six stat plates are drawn there).
Make it better: a lived-in study. Each alcove lit by its own small warm lamp, polished dark wood,
moonlight through the window mixing with lamp light, maps and hunting souvenirs on the wall.

### 10. Cartographer's table (world map) ⚠ — output `carte_monde.png`
Sources: `fond_10_carte_monde`, `jeu_10_carte_monde`.
Keep EXACTLY: the big pale parchment on the table, same position and size, and the **10 small island
maps** drawn on it in 2 rows of 5, each at the same position, same size and same outline. Themes, top
row left to right: sunny coast, mushroom forest, earthen burrows, red raider camps, pale stone
quarries. Bottom row: teal sunken necropolis, snowy forest outposts, high rocky peaks, volcanic
dragon temple, dark violet citadel. Keep the right side of the parchment plain (an info scroll is
drawn there) and the globe, candles, books and scrolls around the table. No names or labels.
Make it better: each island a tiny painted jewel with its own colour, readable at a glance; candle
light on the parchment, brass instruments, inked sea monsters and compass roses in the empty sea.

### 11. Spirit garden — output `jardin_sans_nid.png`
Sources: `fond_11_jardin`, `jeu_11_jardin`.
Keep: the moonlit garden terrace with its flagstone floor; the big tree with hanging lanterns, the
small waterfall and pond on the left; the balustrade with the night view of a distant city; the
white crystals on the right. **Calm areas:** the centre of the floor (an animated flower nest is
drawn there, and a character stands to its left); the **right fifth of the image, very dark and
plain** (a text panel); the bottom strip (buttons).
Make it better: an enchanted night garden. Moonbeams through the branches, glowing flowers, lanterns
with soft halos, mist over the pond, bioluminescent plants in blue and violet.

### 12. Mage's hall — output `salle_mage.png`
Sources: `fond_12_salle_mage`, `jeu_12_salle_mage`.
Keep: the tall stained-glass window with a star in the centre and the two smaller ones beside it;
the bookshelves, lecterns, armillary spheres and candles on both sides; the **round stepped dais with
a golden star on the floor, lower centre, same place and size, its top clear** (the summoning
happens on it). **Calm areas:** the floor to the left of the dais (the mage stands there); the right
fifth (a text panel); the bottom strip (buttons).
Make it better: a grand arcane library. Coloured light from the windows falling on the dais, floating
dust in the beams, gold inlays glowing in the floor, books and scrolls piled with character.

### 13. Clockwork workshop — output `salle_mecanicien.png`
Sources: `fond_13_salle_mecanicien`, `jeu_13_salle_mecanicien`.
Keep: the giant gear with a teal crystal in the centre of the back wall; the brass pipes and glowing
teal tubes; the blueprints; the workbenches on both sides; the **low rectangular brass platform on
the floor, lower centre, same place and size, its top clear** (objects appear on it). **Calm areas:**
the floor to the left of the platform (the mechanic stands there); the right fifth (a text panel);
the bottom strip (buttons).
Make it better: an inventor's dream. Polished brass and copper with warm reflections, teal glow from
the tubes against orange lamp light, steam, hanging chains and tools, a sense of huge machinery
behind the wall.

### 14. Stele balcony — output `salle_stele.png`
Sources: `fond_14_salle_stele`, `jeu_14_salle_stele`.
Keep: the colonnade with red curtains opening on a starry night sky with a large moon; the polished
floor; the small stone bowls on pedestals at the same places. **Paint the room WITHOUT the tall stele
in the centre** (it is a separate object, lot 3): leave only its low stone base on the floor.
**Calm areas:** the centre of the image where the stele stands; the right fifth, very dark and plain
(a text panel); the bottom strip (buttons).
Make it better: a sacred observatory terrace. Milky Way and shooting stars, moonlight on the marble,
ivy on the columns, soft reflections on the floor.

### 15. Victory — output `victoire_fond.png`
Source: `fond_15_victoire` (no game capture: a result panel covers the upper centre).
Keep: the **round stone platform with a faint star pattern at the bottom centre, empty** (the heroes
stand on it); the two big red banners on the sides; the tents and lanterns; the night view of the
harbour city and its castle under a full moon. **Calm area:** the upper centre (the result panel).
Make it better: triumphant and festive. Fireworks or lanterns rising over the city, golden light on
the platform, glowing windows, fireflies, a bright moon.

---

# LOT 2 — The 4 characters of the rooms

Each character is delivered as **2 images**: a resting pose and an action pose. I animate them myself
(breathing, small movements, light effects), so I need clean separate drawings.

Rules for every character:

- Redraw the character of the reference image (`sources/personnages/ref_*.png`): **same person, same
  outfit, same colours, same accessories**. The reference is a small pixel sprite: you make the
  high-quality painted version, in the style of `STYLE_PERSONNAGES.jpg`.
- **Transparent background** (PNG with alpha). No ground, no cast shadow, no scenery.
- **Full body**, nothing cropped, with a margin around. Portrait image, 2:3.
- The character **faces right**, in three-quarter view, standing on an invisible ground line near the
  bottom of the image.
- Soft warm light from the upper left, so they fit in every room.
- The action pose is the **same character at the same size and the same feet position**: only the
  pose changes. Make it by editing the resting image, so the face and outfit stay identical.
- No floating magic effects around the character (I add them). A glow **on** the object they hold is
  welcome.

Save as `recu/personnages/<name>.png`.

| Reference | Output files | Who | Resting pose | Action pose |
|---|---|---|---|---|
| `ref_mage.png` | `mage_repos.png`, `mage_action.png` | The summoner mage: a small old mage with a long white beard, face hidden in the shadow of a burgundy and gold hood with two glowing teal eyes, golden staff topped with a teal crystal | Standing calm, staff held upright | Leaning forward, staff thrust toward the right, crystal blazing |
| `ref_mecanicien.png` | `mecanicien_repos.png`, `mecanicien_action.png` | The mechanic: a sturdy old inventor with wild white hair and moustache, brass goggles on his forehead, burgundy shirt, leather apron with tools, one brass mechanical arm with a teal crystal | Standing, wiping his brow or hands on hips, friendly | Swinging a hammer down in front of him with his mechanical arm, focused |
| `ref_gardienne.png` | `gardienne_repos.png`, `gardienne_action.png` | The garden keeper: a young girl with short silver hair, a red hood decorated with leaves, a burgundy cape, cream tunic, brown boots, carrying a brass lantern with a blue-green glow | Standing gently, lantern held low at her side | Lantern raised high above her head, glowing golden, face lit with joy |
| `ref_marchande.png` | `marchande_repos.png`, `marchande_action.png` | The mask merchant: a mysterious woman in a wide dark witch hat, face hidden by a smooth white mask, burgundy coat with many buckles and pouches, masks hanging from her belt | Standing, one hand on her hip, holding a white fox mask in the other | Leaning forward, presenting the fox mask with both hands as an offer |

---

# LOT 3 — Big objects of the rooms

Transparent background (PNG with alpha), no ground, no cast shadow, object centred with a margin,
same painted style as the rooms, light from the upper left. Save as `recu/objets/<name>.png`.

| Reference | Output files | What |
|---|---|---|
| `ref_nid.png` | `nid_ferme.png`, `nid_ouvert.png` | The spirit nest of the garden: a large lotus-like flower with ivory and burgundy petals on a bed of green and gold vines, seen from slightly above. Two images at the **same size and position**: closed bud (left in the reference), then petals wide open around an empty glowing heart (right). Square image. |
| `ref_stele.png` | `stele_repos.png`, `stele_eveil.png` | The fusion stele: a tall dark-blue stone stele with teal and gold carvings, a **dark empty square socket near the top** (the game shows an icon in it: keep it empty), standing on a stepped stone base. Stele only: **no bowls, no flame**. Two images at the same size and position: carvings faintly lit, then all carvings blazing teal. Portrait image, 2:3. |
| `ref_etal.png` ⚠ | `etal.png` | The shop display stand: carved dark wood and brass, **three flat shelves covered in empty burgundy velvet**, an ornate crest with a teal gem on top. Keep exactly the same proportions and the three shelves at the same heights (items are placed on them). Shelves empty. Landscape image, 3:2. |
| `ref_lutrin.png` | `lutrin.png` | The reliquary lectern: a stone and brass lectern holding a large **blank parchment** tilted toward the viewer (text is drawn on it: keep it empty and light), a small burgundy banner on its foot. Same proportions as the reference. Portrait image. |

---

# LOT 4 — The 20 spirits (5 images)

The spirits are small magical creatures that hatch in the garden. There are 5 elements, and each
spirit has 4 growth stages. Each reference `sources/esprits/ref_esprits_<element>.png` shows the 4
stages of one element in a row: **egg, baby, adult, celestial form**.

For each element, paint **one landscape image (3:2) with the same 4 creatures in the same order, in a
single row, evenly spaced in four equal columns**, on a **transparent background**. Same species,
same colours, same personality as the reference, redrawn in the style of `STYLE_PERSONNAGES.jpg`:
cute, round, expressive, clean dark outline. Each stage is clearly bigger and more majestic than the
previous one; the celestial form glows. No ground, no shadow, no effects detached from the creature.

Save as `recu/esprits/esprits_feu.png`, `esprits_eau.png`, `esprits_nature.png`,
`esprits_lumiere.png`, `esprits_ombre.png`.

---

# Checklist before you send each image

- Room: is every listed object still at the same place? Are the calm areas really plain? No character,
  no text, no interface?
- Character / object / spirit: transparent background? Nothing cropped? Same design as the reference?
  Action pose at the same size and feet position as the resting pose?
- Style: does it sit next to the three STYLE images without looking like a different game?

If one of these fails, redo the image before moving on.
