"""Dessine une animation de squelette (assets/anim/rigs/<héros>.json) en planche d'images, pour
vérifier les poses sans lancer Godot. Même calcul que scripts/anim/rig.gd.

    python tools/render_rig.py corbin 0 sortie.png [--frames=12] [--clip]
--clip ajoute à côté le clip d'origine (pour comparer).
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
HEROES = ROOT / "assets/anim/heroes"
DEFAULT = {"r": 0.0, "x": 0.0, "y": 0.0, "sx": 1.0, "sy": 1.0, "a": 1.0}


def ease(kind, u):
    if kind == "l":
        return u
    if kind == "o":
        return 1 - (1 - u) ** 3
    if kind == "i":
        return u ** 3
    if kind == "b":
        c = 1.70158
        return 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2
    return u * u * (3 - 2 * u)


def channel(keys, t):
    """Valeurs {r,x,y,sx,sy,a} d'un os à l'instant t (clés déjà complétées)."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0, _), (t1, v1, k) in zip(keys, keys[1:]):
        if t <= t1:
            u = ease(k, (t - t0) / max(1e-6, t1 - t0))
            return {c: v0[c] + (v1[c] - v0[c]) * u for c in DEFAULT}
    return keys[-1][1]


def prepare(anim):
    out = {}
    for bone, keys in anim["keys"].items():
        cur = dict(DEFAULT)
        full = []
        for k in keys:
            cur = {**cur, **k[1]}
            full.append((float(k[0]), dict(cur), k[2] if len(k) > 2 else "s"))
        out[bone] = full
    return out


def mul(a, b):
    # matrices 2x3 (a, b, c, d, e, f) : x' = a x + b y + c ; y' = d x + e y + f
    return (a[0] * b[0] + a[1] * b[3], a[0] * b[1] + a[1] * b[4], a[0] * b[2] + a[1] * b[5] + a[2],
            a[3] * b[0] + a[4] * b[3], a[3] * b[1] + a[4] * b[4], a[3] * b[2] + a[4] * b[5] + a[5])


def pose(rig, anim, t):
    parts = {p["id"]: p for p in rig["parts"]}
    world = {}
    for p in rig["parts"]:
        v = channel(anim[p["id"]], t) if p["id"] in anim else DEFAULT
        par = parts.get(p.get("parent", ""))
        off = (p["pivot"][0] - (par["pivot"][0] if par else 0), p["pivot"][1] - (par["pivot"][1] if par else 0))
        r = math.radians(v["r"])
        c, s = math.cos(r), math.sin(r)
        local = (c * v["sx"], -s * v["sy"], off[0] + v["x"], s * v["sx"], c * v["sy"], off[1] + v["y"])
        m = mul(world[par["id"]], local) if par else local
        world[p["id"]] = m
    return world


def draw(rig, anim, t, size=(560, 440), origin=(330, 400)):
    canvas = Image.new("RGBA", size, (70, 96, 80, 255))
    world = pose(rig, anim, t)
    for p in sorted([p for p in rig["parts"] if "tex" in p], key=lambda p: p.get("z", 0)):
        tex = Image.open(HEROES / "tex" / p["tex"]).convert("RGBA")
        w, h = p["size"]
        x0 = p["pos"][0] - p["pivot"][0] - w / 2
        y0 = p["pos"][1] - p["pivot"][1] - h / 2
        # pixel du tex -> local -> monde -> écran
        tm = (w / tex.width, 0, x0, 0, h / tex.height, y0)
        m = mul(world[p["id"]], tm)
        m = (m[0], m[1], m[2] + origin[0], m[3], m[4], m[5] + origin[1])
        det = m[0] * m[4] - m[1] * m[3]
        inv = (m[4] / det, -m[1] / det, (m[1] * m[5] - m[4] * m[2]) / det,
               -m[3] / det, m[0] / det, (m[3] * m[2] - m[0] * m[5]) / det)
        layer = tex.transform(size, Image.AFFINE, inv, resample=Image.BILINEAR)
        canvas.alpha_composite(layer)
    d = ImageDraw.Draw(canvas)
    d.line([(0, origin[1]), (size[0], origin[1])], fill=(0, 0, 0, 90))
    d.text((6, 6), "t=%.2f" % t, fill="white")
    return canvas


def main():
    hero, name, out = sys.argv[1:4]
    n = 12
    for a in sys.argv[4:]:
        if a.startswith("--frames="):
            n = int(a.split("=")[1])
    rig = json.loads((ROOT / "assets/anim/rigs" / (hero + ".json")).read_text(encoding="utf-8"))
    raw = rig["anims"][rig.get("alias", {}).get(name, name)]
    anim = prepare(raw)
    dur = raw["dur"]
    cols = 6
    rows = math.ceil(n / cols)
    sheet = Image.new("RGBA", (560 * cols, 440 * rows))
    for i in range(n):
        t = dur * i / (n - 1 if not raw.get("loop") else n)
        sheet.paste(draw(rig, anim, t), ((i % cols) * 560, (i // cols) * 440))
    sheet.convert("RGB").resize((sheet.width // 2, sheet.height // 2)).save(out)


if __name__ == "__main__":
    main()
