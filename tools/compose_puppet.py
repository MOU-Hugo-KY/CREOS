"""Recolle une marionnette 2D (puppet.json) en une image, pour vérifier les points d'attache.
Affiche aussi sa hauteur en pixels et le pixel_size pour une hauteur voulue (en mètres).
Usage : python tools/compose_puppet.py assets/heroes2d/corbin [hauteur_m] [sortie.png]"""
import json, sys, math
from PIL import Image

folder = sys.argv[1]
cfg = json.load(open(folder + "/puppet.json", encoding="utf8"))
parts = cfg["parts"]
placed = {}  # nom -> (origine du pivot en px monde, image)

def place(name):
    if name in placed:
        return placed[name]
    p = parts[name]
    img = Image.open(folder + "/" + p.get("file", name + ".png")).convert("RGBA")
    if p.get("rest", 0):
        pass  # la rotation de repos n'est pas montrée ici
    parent = p.get("parent", "")
    if parent:
        ppos, _ = place(parent)
        ppiv = parts[parent].get("pivot", [0, 0])
        at = p.get("at", [0, 0])
        pos = (ppos[0] + at[0] - ppiv[0], ppos[1] + at[1] - ppiv[1])
    else:
        pos = (0, 0)
    placed[name] = (pos, img)
    return placed[name]

for n in parts:
    place(n)
minx = min(placed[n][0][0] - parts[n].get("pivot", [0, 0])[0] for n in parts)
miny = min(placed[n][0][1] - parts[n].get("pivot", [0, 0])[1] for n in parts)
maxx = max(placed[n][0][0] - parts[n].get("pivot", [0, 0])[0] + placed[n][1].width for n in parts)
maxy = max(placed[n][0][1] - parts[n].get("pivot", [0, 0])[1] + placed[n][1].height for n in parts)
W, H = int(maxx - minx) + 20, int(maxy - miny) + 20
out = Image.new("RGBA", (W, H), (200, 200, 210, 255))
for n in sorted(parts, key=lambda k: parts[k].get("z", 0)):
    pos, img = placed[n]
    piv = parts[n].get("pivot", [0, 0])
    out.alpha_composite(img, (int(pos[0] - piv[0] - minx + 10), int(pos[1] - piv[1] - miny + 10)))
height_px = -miny  # du sol (pivot du corps, y = 0) au sommet
print("hauteur", int(height_px), "px", end="")
if len(sys.argv) > 2:
    print("  -> pixel_size", round(float(sys.argv[2]) / height_px, 5), end="")
print()
if len(sys.argv) > 3:
    out.save(sys.argv[3])
