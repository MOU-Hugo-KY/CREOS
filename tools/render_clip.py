"""Dessine une image d'un clip compact (format de tools/import_creos_packs.py) avec Pillow, pour
vérifier tailles et positions sans lancer Godot.

  python tools/render_clip.py <dossier_bundle> <clip_id> [temps_s] [sortie.png]
Ou en module : draw_clip(image, bundle, clip_id, t, origin=(x, y), scale=1.0, flip=False)
"""
import json
import math
import sys
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw


@lru_cache(maxsize=None)
def load_clip(bundle, clip_id):
    return json.load(open(Path(bundle) / "clips" / (clip_id + ".json"), encoding="utf-8"))


@lru_cache(maxsize=None)
def load_tex(path):
    return Image.open(path).convert("RGBA")


def _color(hexstr, alpha):
    h = hexstr.lstrip("#")
    if len(h) == 8:  # rrggbbaa
        r, g, b, a = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16)
    else:
        r, g, b, a = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255
    return (r, g, b, int(a * alpha))


def draw_clip(img, bundle, clip_id, t=0.0, origin=(0, 0), scale=1.0, flip=False, actor_only=False, effects_only=False, sprites_only=False):
    clip = load_clip(str(bundle), clip_id)
    f = min(int(t * clip["fps"]), len(clip["f"]) - 1)
    sx = -scale if flip else scale
    ox, oy = origin
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(over)
    for cmd in clip["f"][f]:
        if actor_only and cmd[8] != 0:
            continue
        if effects_only and cmd[8] != 1:
            continue
        if sprites_only and cmd[0] < 0:
            continue
        k = cmd[0]
        if k >= 0:
            tex = load_tex(str(Path(bundle) / "tex" / clip["tex"][k]))
            w, h = max(1, int(abs(cmd[3] * scale))), max(1, int(abs(cmd[4] * scale)))
            piece = tex.resize((w, h))
            if cmd[7] ^ flip:
                piece = piece.transpose(Image.FLIP_LEFT_RIGHT)
            ang = cmd[5] * (-1 if flip else 1)
            piece = piece.rotate(-math.degrees(ang), expand=True, resample=Image.BICUBIC)
            if cmd[6] < 1:
                a = piece.getchannel("A").point(lambda v: int(v * cmd[6]))
                piece.putalpha(a)
            cx, cy = ox + cmd[1] * sx, oy + cmd[2] * scale
            over.alpha_composite(piece, (int(cx - piece.width / 2), int(cy - piece.height / 2)))
        elif k == -1:
            draw.line([(ox + cmd[1] * sx, oy + cmd[2] * scale), (ox + cmd[3] * sx, oy + cmd[4] * scale)],
                      fill=_color(cmd[5], cmd[7]), width=max(1, int(cmd[6] * scale)))
        else:
            r = cmd[3] * scale
            cx, cy = ox + cmd[1] * sx, oy + cmd[2] * scale
            draw.ellipse([cx - r, cy - r * cmd[4], cx + r, cy + r * cmd[4]], outline=_color(cmd[5], cmd[7]),
                         width=max(1, int(cmd[6] * scale)))
    img.alpha_composite(over)


if __name__ == "__main__":
    bundle, cid = sys.argv[1], sys.argv[2]
    t = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    out = sys.argv[4] if len(sys.argv) > 4 else "clip.png"
    im = Image.new("RGBA", (1280, 720), (80, 80, 100, 255))
    draw_clip(im, bundle, cid, t, origin=(340, 600))
    im.save(out)
