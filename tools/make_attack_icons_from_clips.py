"""Icônes rondes des attaques des héros (assets/ui/attacks/<id>.png, 256 px), tirées de leur clip
d'animation : l'image au moment de l'impact, recadrée sur l'action, dans un médaillon de la
couleur de l'élément du héros.

  python tools/make_attack_icons_from_clips.py
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_clip import draw_clip  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = ROOT / "assets" / "anim" / "heroes"
OUT = ROOT / "assets" / "ui" / "attacks"
SIZE = 256
ELEMENT_COLORS = {"feu": (201, 92, 54), "eau": (64, 132, 196), "nature": (88, 150, 74), "lumiere": (214, 170, 72),
                  "ombre": (112, 72, 150), "": (110, 110, 120)}


def icon_for(hero_id, attack, element):
    clip = json.load(open(BUNDLE / "clips" / (attack["clip"] + ".json"), encoding="utf-8"))
    t = attack.get("hit_times", [clip["dur"] * 0.5])[0]
    # L'effet de l'attaque seul (au moment de l'impact, ou juste après) ; sinon le héros.
    canvas = None
    for dt in (0.0, 0.08, 0.16, -0.08, 0.3):
        c = Image.new("RGBA", (2400, 1400), (0, 0, 0, 0))
        draw_clip(c, BUNDLE, attack["clip"], max(0.0, t + dt), origin=(700, 900), scale=1.0, effects_only=True, sprites_only=True)
        if c.getbbox() and (c.getbbox()[2] - c.getbbox()[0]) * (c.getbbox()[3] - c.getbbox()[1]) > 9000:
            canvas = c
            break
    if canvas is None:
        canvas = Image.new("RGBA", (2400, 1400), (0, 0, 0, 0))
        draw_clip(canvas, BUNDLE, attack["clip"], t, origin=(700, 900), scale=1.0)
    box = canvas.getbbox()
    if box is None:
        return None
    crop = canvas.crop(box)
    side = max(crop.width, crop.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
    inner = int(SIZE * 0.86)
    art = square.resize((inner, inner), Image.LANCZOS)
    base = ELEMENT_COLORS.get(element, ELEMENT_COLORS[""])
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(icon)
    d.ellipse([4, 4, SIZE - 4, SIZE - 4], fill=(41, 38, 46, 255))
    d.ellipse([14, 14, SIZE - 14, SIZE - 14], fill=tuple(int(c * 0.55) for c in base) + (255,))
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([50, 50, SIZE - 50, SIZE - 50], fill=base + (200,))
    icon.alpha_composite(glow.filter(ImageFilter.GaussianBlur(28)))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse([14, 14, SIZE - 14, SIZE - 14], fill=255)
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    layer.alpha_composite(art, ((SIZE - inner) // 2, (SIZE - inner) // 2))
    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", (SIZE, SIZE), 0), mask))
    icon.alpha_composite(layer)
    d = ImageDraw.Draw(icon)
    d.ellipse([10, 10, SIZE - 10, SIZE - 10], outline=(198, 166, 108, 255), width=6)
    return icon


def main():
    heroes = json.load(open(ROOT / "data" / "heroes.json", encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    for hid, h in heroes.items():
        for a in h["attacks"]:
            icon = icon_for(hid, a, h.get("element", ""))
            if icon:
                icon.save(OUT / (a["id"] + ".png"))
                n += 1
    print(n, "icônes")


if __name__ == "__main__":
    main()
