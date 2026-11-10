# Kit d'interface sobre (à coller dans ChatGPT)

À faire **dans la même conversation** que les fonds sobres (le port et l'arène du monde 1), pour que ChatGPT garde le même style.
Dépose l'image rendue dans ce dossier (`docs/pour_chatgpt/`) sous le nom **`kit_interface_sobre.png`**.

---

Using exactly the same pixel art style and color palette as the two backgrounds you just made,
create a UI kit sprite sheet for a mobile RPG game.

Format: one PNG, transparent background, pixel art with chunky readable pixels (no anti-aliasing, no blur),
every element drawn at 1 art pixel = 1 image pixel, laid out on a clean grid with at least 8 empty pixels
between elements. No text anywhere.

Style rules: minimal, calm and modern. Thin 1-pixel dark outline (#1c1b24), flat fills, one 1-pixel lighter line
on top and one darker line at the bottom for depth, a hard 1-pixel shadow under buttons. No gold ornaments,
no filigree, no gems, no rivets, no corner decorations. Gold (#d8b25a) only on the reward elements.
Colors: ink #1c1b24, night #2b2d3a, slate #4a5468, stone #7d8597, ivory #e9e0c9, teal #4fb3a5, wine #9c3f4a.

Elements (each one simple enough to be stretched with 9-slice, so keep the middle plain):
1. Main button, teal, 48x16: normal, pressed (moved down 1 pixel, no shadow), disabled (grey). 3 versions side by side.
2. Secondary button, slate, 48x16: normal, pressed, disabled.
3. Back button, slate, 40x16, with a small left arrow on the left: normal, pressed.
4. Title ribbon, wine red, 96x16, with small folded tails at both ends.
5. Light panel, ivory, 48x48 (for text windows and info scrolls), plain.
6. Dark panel, night, 48x48, plain.
7. Currency pill, night, 40x12, with a round empty slot on the left for an icon.
8. Tab, slate, 32x14: selected (ivory) and not selected.
9. Progress bar: empty frame 64x8 and its teal fill 60x4.
10. Small square slot for a hero portrait, 24x24: empty, selected (teal outline), locked (grey).
11. Close button, 14x14, wine with a white cross.
12. Star icons 12x12: empty and full (full in gold).
13. Reward chest 20x16 in two states: closed and open (this one may use gold).

---

Si le résultat est trop chargé, réponds à ChatGPT :
« Simpler: remove every decoration, flat colors only, 1-pixel outline, keep the middle of each piece completely plain. »
