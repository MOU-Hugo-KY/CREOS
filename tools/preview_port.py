"""Aperçu de Port-Franc 2D d'après assets/hub2d/port/Scene.json (sans parallaxe), avec une grille
optionnelle, pour placer bâtiments et animations sans lancer le jeu.

  python tools/preview_port.py [sortie.png] [--grid] [--frame=0]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

DIR = Path(__file__).resolve().parent.parent / "assets" / "hub2d" / "port"


def sheet_frame(path, frame):
    im = Image.open(path).convert("RGBA")
    parts = path.stem.split("_")
    if len(parts) < 3 or not parts[-1].endswith("fps"):
        return im  # image fixe
    n = int(parts[-2].rstrip("f"))
    w = im.width // n
    return im.crop((w * (frame % n), 0, w * (frame % n) + w, im.height))


def main():
    out = next((a for a in sys.argv[1:] if not a.startswith("--")), "port_preview.png")
    grid = "--grid" in sys.argv
    frame = int(next((a.split("=")[1] for a in sys.argv if a.startswith("--frame=")), 0))
    scene = json.load(open(DIR / "Scene.json", encoding="utf-8"))
    W, H = scene["size"]
    img = Image.new("RGBA", (W, H))
    front = []
    for layer in scene["layers"]:
        if layer.get("front"):
            front.append(layer)
            continue
        img.alpha_composite(Image.open(DIR / layer["file"]).convert("RGBA"))
    items = []
    for b in scene["buildings"]:
        tex = Image.open(DIR / (b["file"] + ".png")).convert("RGBA")
        bb = tex.getbbox()
        s = b["w"] / tex.width
        t = tex.resize((int(tex.width * s), int(tex.height * s)))
        pos = (int(b["x"] - t.width / 2), int(b["y"] - bb[3] * s))
        items.append((b["y"] if b.get("parallax", 1) == 1 else -1, t, pos))
    for a in scene["anims"]:
        if a.get("front"):
            continue
        t = sheet_frame(DIR / a["file"], frame).resize((a["size"], a["size"]))
        if a.get("flip"):
            t = t.transpose(Image.FLIP_LEFT_RIGHT)
        z = a.get("ground", a["y"] + a["size"] / 2)
        if a.get("above"):
            z = next(b["y"] for b in scene["buildings"] if b["id"] == a["above"]) + 0.5
        if a.get("parallax", 1) != 1:
            z = -1
        items.append((z, t, (int(a["x"] - a["size"] / 2), int(a["y"] - a["size"] / 2))))
    items.sort(key=lambda i: i[0])
    for _, t, pos in items:
        img.alpha_composite(t, (max(0, pos[0]), max(0, pos[1])) if pos[0] >= 0 and pos[1] >= 0 else (0, 0)) \
            if pos[0] >= 0 and pos[1] >= 0 else _paste(img, t, pos)
    for layer in front:
        img.alpha_composite(Image.open(DIR / layer["file"]).convert("RGBA"))
    for a in scene["anims"]:
        if a.get("front"):
            t = sheet_frame(DIR / a["file"], frame).resize((a["size"], a["size"]))
            if a.get("flip"):
                t = t.transpose(Image.FLIP_LEFT_RIGHT)
            _paste(img, t, (int(a["x"] - a["size"] / 2), int(a["y"] - a["size"] / 2)))
    if grid:
        d = ImageDraw.Draw(img)
        for x in range(0, W, 100):
            d.line([(x, 0), (x, H)], fill=(255, 255, 255, 90 if x % 500 else 200), width=1 if x % 500 else 3)
            d.text((x + 3, 3), str(x), fill="white")
        for y in range(0, H, 100):
            d.line([(0, y), (W, y)], fill=(255, 255, 255, 90 if y % 500 else 200), width=1 if y % 500 else 3)
            d.text((3, y + 3), str(y), fill="white")
        wa = scene["walk_area"]
        d.rectangle([wa[0], wa[1], wa[0] + wa[2], wa[1] + wa[3]], outline=(255, 80, 80, 255), width=3)
    img.convert("RGB").save(out)


def _paste(img, t, pos):
    x, y = pos
    crop = t.crop((max(0, -x), max(0, -y), t.width, t.height))
    img.alpha_composite(crop, (max(0, x), max(0, y)))


if __name__ == "__main__":
    main()
