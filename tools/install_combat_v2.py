"""Installe des héros « combat v2 » (style du hub) livrés par ChatGPT.

Usage : python tools/install_combat_v2.py <dossier contenant les dossiers <héros>/sheet.json>

Pour chaque héros trouvé : remplace assets/anim/pixel/<héros>/, recale les pieds au sol (point
[96, 146]) sur chaque image sauf l'esquive et l'effet, et règle l'échelle pour que tous les héros
aient à peu près la même hauteur à l'écran (repos ≈ 130 pixels d'écran, entre 1,4 et 1,7 pixel
d'écran par pixel de dessin).
"""
import glob
import json
import os
import sys

from PIL import Image

GROUND = 146
SIZE = 288.0  # échelle = SIZE / taille du dessin (racine de hauteur × largeur au repos)


def _clean(im):
    """Pixel art net : supprime le halo presque transparent laissé par le détourage (« carré » visible)."""
    a = im.getchannel("A").point(lambda v: 0 if v < 110 else 255)
    im.putalpha(a)
    return im


def _box(im):
    return im.getchannel("A").point(lambda v: 255 if v > 200 else 0).getbbox()


def scale_for(folder: str, hero: str) -> float:
    idle = _box(Image.open(os.path.join(folder, f"{hero}_idle_000.png")).convert("RGBA"))
    metric = ((idle[3] - idle[1]) * (idle[2] - idle[0])) ** 0.5
    return round(min(3.9, max(2.6, SIZE / metric)), 3)


def refresh_installed() -> None:
    """Nettoie et recalcule la taille de tous les héros déjà installés."""
    for sheet_path in glob.glob(os.path.join("assets", "anim", "pixel", "*", "sheet.json")):
        folder = os.path.dirname(sheet_path)
        hero = os.path.basename(folder)
        if not os.path.exists(os.path.join("assets", "anim", "heroes", "fiches", hero + ".png")):
            continue
        for f in glob.glob(os.path.join(folder, "*_00?.png")):
            name = os.path.basename(f)
            anim = name[len(hero) + 1:-8]
            im = _clean(Image.open(f).convert("RGBA"))
            box = _box(im)
            if box and anim not in ("dodge", "fx") and box[3] != GROUND:
                moved = Image.new("RGBA", im.size, (0, 0, 0, 0))
                moved.paste(im, (0, GROUND - box[3]))
                im = moved
            im.save(f)
        sheet = json.load(open(sheet_path, encoding="utf-8"))
        sheet["scale"] = scale_for(folder, hero)
        json.dump(sheet, open(sheet_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
        print(hero, "échelle", sheet["scale"])


def install(src: str) -> None:
    hero = os.path.basename(src.rstrip("/\\"))
    dst = os.path.join("assets", "anim", "pixel", hero)
    os.makedirs(dst, exist_ok=True)
    for f in glob.glob(os.path.join(dst, "*.png")) + glob.glob(os.path.join(dst, "*.png.import")):
        os.remove(f)
    for f in glob.glob(os.path.join(src, "*_00?.png")):
        name = os.path.basename(f)
        anim = name[len(hero) + 1:-8]
        im = _clean(Image.open(f).convert("RGBA"))
        box = _box(im)
        if box and anim not in ("dodge", "fx") and box[3] != GROUND:
            moved = Image.new("RGBA", im.size, (0, 0, 0, 0))
            moved.paste(im, (0, GROUND - box[3]))
            im = moved
        im.save(os.path.join(dst, name))
    sheet = json.load(open(os.path.join(src, "sheet.json"), encoding="utf-8"))
    sheet["scale"] = scale_for(dst, hero)
    sheet.setdefault("map", {})["run"] = "walk"
    json.dump(sheet, open(os.path.join(dst, "sheet.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(hero, "échelle", sheet["scale"])


if __name__ == "__main__":
    if sys.argv[1] == "--refresh":
        refresh_installed()
        sys.exit()
    for s in sorted(glob.glob(os.path.join(sys.argv[1], "**", "sheet.json"), recursive=True)):
        install(os.path.dirname(s))
