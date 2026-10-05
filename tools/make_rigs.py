"""Crée les squelettes 2D des héros (assets/anim/rigs/<héros>.json) à partir de leurs pièces détachées.

- Pièces et positions : première image du clip `<héros>_idle`.
- Pivots trouvés automatiquement : jambes en haut, torse au bassin, tête au cou, bras au point
  de la pièce le plus proche de l'épaule, capes/ailes/queues au point le plus proche du corps.
- Animations : poses clés génériques (repos, marche, touché, mort, relique) et attaques calées sur
  les instants d'impact du clip d'origine ; le déplacement du personnage (élan, retour) est repris
  du clip pour que les effets restent alignés.

    python tools/make_rigs.py [héros…] [--force]
Un squelette déjà présent n'est pas écrasé sans --force (Corbin est réglé à la main).
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
HEROES = ROOT / "assets/anim/heroes"
RIGS = ROOT / "assets/anim/rigs"


def load_clip(name):
    p = HEROES / "clips" / (name + ".json")
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else None


def nearest_opaque(tex_name, rect, target, inset=0.1):
    """Point opaque de la pièce (en coordonnées personnage) le plus proche de `target`, un peu rentré."""
    im = Image.open(HEROES / "tex" / tex_name).convert("RGBA")
    a = im.getchannel("A")
    w, h = im.size
    sx, sy = rect[2] / w, rect[3] / h
    best, best_d = None, 1e18
    step = max(1, min(w, h) // 64)
    px = a.load()
    for y in range(0, h, step):
        for x in range(0, w, step):
            if px[x, y] > 128:
                X = rect[0] + x * sx
                Y = rect[1] + y * sy
                d = (X - target[0]) ** 2 + (Y - target[1]) ** 2
                if d < best_d:
                    best, best_d = (X, Y), d
    if best is None:
        return target
    cx, cy = rect[0] + rect[2] / 2, rect[1] + rect[3] / 2
    return (best[0] + (cx - best[0]) * inset, best[1] + (cy - best[1]) * inset)


def build_parts(hero):
    idle = load_clip(hero + "_idle")
    cmds = [c for c in idle["f"][0] if c[0] >= 0 and c[8] == 0]
    items = []
    for z, c in enumerate(cmds):
        tex = idle["tex"][c[0]]
        role = tex[len(hero) + 1:].rsplit(".", 1)[0]
        rect = (c[1] - c[3] / 2, c[2] - c[4] / 2, c[3], c[4])
        items.append({"tex": tex, "role": role, "z": z, "pos": [round(c[1], 1), round(c[2], 1)],
                      "size": [round(c[3], 1), round(c[4], 1)], "rect": rect})
    torso = next(i for i in items if i["role"].startswith(("torso", "body")))
    tz = torso["z"]
    tr = torso["rect"]
    hip = (tr[0] + tr[2] * 0.5, tr[1] + tr[3] * 0.82)
    chest = (tr[0] + tr[2] * 0.5, tr[1] + tr[3] * 0.3)
    arms = [i for i in items if i["role"].startswith("arm") and i["z"] > tz]
    arm_f = max(arms, key=lambda i: i["pos"][0]) if arms else None
    parts = [{"id": "root", "pivot": [0, 0]}, {"id": "hip", "parent": "root", "pivot": [round(hip[0]), round(hip[1])]}]
    extras = []
    for i in items:
        r, role = i["rect"], i["role"]
        part = {"tex": i["tex"], "pos": i["pos"], "size": i["size"], "z": i["z"]}
        if i is torso:
            part.update(id="torso", parent="hip", pivot=[round(hip[0]), round(hip[1])])
        elif role.startswith("head"):
            part.update(id="head", parent="torso", pivot=[round(r[0] + r[2] * 0.5), round(r[1] + r[3] * 0.86)])
        elif role.startswith("leg"):
            part.update(id="leg_front" if "front" in role else "leg_back", parent="root",
                        pivot=[round(r[0] + r[2] * 0.5), round(r[1] + r[3] * 0.12)])
        elif i is arm_f or (i in arms):
            pv = nearest_opaque(i["tex"], r, chest)
            part.update(id="arm_f" if i is arm_f else "arm_b", parent="torso", pivot=[round(pv[0]), round(pv[1])])
        else:
            low = role.startswith(("tail", "flap", "leg"))
            pv = nearest_opaque(i["tex"], r, hip if low else chest, inset=0.05)
            part.update(id="x%d" % len(extras), parent="hip" if low else "torso", pivot=[round(pv[0]), round(pv[1])])
            extras.append(part["id"])
        parts.append(part)
    order = {"root": 0, "hip": 1, "torso": 2}
    parts.sort(key=lambda p: order.get(p["id"], 3))
    has = {p["id"] for p in parts}
    return parts, extras, has


# --- Poses clés ----------------------------------------------------------------------------

def K(*keys):
    return [[round(t, 3), v] + ([e] if e else []) for t, v, e in keys]


def idle(extras):
    k = {
        "hip": K((0, {"y": 0}, ""), (1.0, {"y": 3}, ""), (2.0, {"y": 0}, "")),
        "torso": K((0, {"sy": 1.0, "r": 0}, ""), (1.0, {"sy": 1.025, "r": 1.5}, ""), (2.0, {"sy": 1.0, "r": 0}, "")),
        "head": K((0, {"r": -1.5}, ""), (1.1, {"r": 2}, ""), (2.0, {"r": -1.5}, "")),
        "arm_f": K((0, {"r": 3}, ""), (1.0, {"r": -4}, ""), (2.0, {"r": 3}, "")),
        "arm_b": K((0, {"r": -2}, ""), (1.0, {"r": 3}, ""), (2.0, {"r": -2}, "")),
    }
    for n, x in enumerate(extras):
        ph = 0.3 * n
        k[x] = K((0, {"r": 0}, ""), (0.9 + ph, {"r": -4}, ""), (2.0, {"r": 0}, ""))
    return {"dur": 2.0, "loop": True, "keys": k}


def walk(extras, dur):
    q = dur / 4
    k = {
        "hip": K((0, {"y": 0}, ""), (q, {"y": -6}, ""), (2 * q, {"y": 0}, ""), (3 * q, {"y": -6}, ""), (dur, {"y": 0}, "")),
        "leg_back": K((0, {"r": 20}, ""), (2 * q, {"r": -20}, ""), (dur, {"r": 20}, "")),
        "leg_front": K((0, {"r": -20}, ""), (2 * q, {"r": 20}, ""), (dur, {"r": -20}, "")),
        "torso": K((0, {"r": 5}, ""), (q, {"r": 7}, ""), (2 * q, {"r": 5}, ""), (3 * q, {"r": 7}, ""), (dur, {"r": 5}, "")),
        "head": K((0, {"r": -2}, ""), (2 * q, {"r": 2}, ""), (dur, {"r": -2}, "")),
        "arm_f": K((0, {"r": -16}, ""), (2 * q, {"r": 14}, ""), (dur, {"r": -16}, "")),
        "arm_b": K((0, {"r": 14}, ""), (2 * q, {"r": -14}, ""), (dur, {"r": 14}, "")),
    }
    for x in extras:
        k[x] = K((0, {"r": 5}, ""), (q, {"r": 9}, ""), (2 * q, {"r": 5}, ""), (3 * q, {"r": 9}, ""), (dur, {"r": 5}, ""))
    return {"dur": dur, "loop": True, "keys": k}


def hurt(extras, dur):
    e = dur * 0.85
    k = {
        "root": K((0, {"x": 0}, ""), (0.12, {"x": -26}, "o"), (e, {"x": 0}, "")),
        "hip": K((0, {"y": 0}, ""), (0.12, {"y": 6}, ""), (e, {"y": 0}, "")),
        "torso": K((0, {"r": 0}, ""), (0.1, {"r": -16}, "o"), (dur * 0.45, {"r": -8}, ""), (e, {"r": 0}, "")),
        "head": K((0, {"r": 0}, ""), (0.12, {"r": -14}, "o"), (e, {"r": 0}, "")),
        "arm_f": K((0, {"r": 0}, ""), (0.12, {"r": 28}, "o"), (e, {"r": 0}, "")),
        "arm_b": K((0, {"r": 0}, ""), (0.12, {"r": -20}, "o"), (e, {"r": 0}, "")),
    }
    for x in extras:
        k[x] = K((0, {"r": 0}, ""), (0.15, {"r": 12}, ""), (dur * 0.6, {"r": -4}, ""), (e, {"r": 0}, ""))
    return {"dur": dur, "keys": k}


def death(extras, dur, fall):
    s = fall / 1.4  # la chute tombe sur le repère du clip
    k = {
        "root": K((0, {"x": 0}, ""), (0.35 * s, {"x": -24}, "o"), (1.4 * s, {"x": -30}, "")),
        "hip": K((0, {"y": 0}, ""), (0.35 * s, {"y": 8}, "o"), (0.9 * s, {"y": 4}, ""), (1.4 * s, {"y": 40}, "i"),
                 (1.55 * s, {"y": 34}, "o"), (1.7 * s, {"y": 40}, "i")),
        "torso": K((0, {"r": 0}, ""), (0.35 * s, {"r": -18}, "o"), (0.9 * s, {"r": -12}, ""), (1.4 * s, {"r": 28}, "i"), (1.6 * s, {"r": 34}, "o")),
        "head": K((0, {"r": 0}, ""), (0.35 * s, {"r": -22}, "o"), (0.9 * s, {"r": -14}, ""), (1.4 * s, {"r": 20}, "i"), (1.7 * s, {"r": 30}, "o")),
        "arm_f": K((0, {"r": 0}, ""), (0.35 * s, {"r": 40}, "o"), (1.4 * s, {"r": 20}, ""), (1.7 * s, {"r": 35}, "b")),
        "arm_b": K((0, {"r": 0}, ""), (0.35 * s, {"r": -25}, "o"), (1.4 * s, {"r": 15}, ""), (1.7 * s, {"r": 25}, "b")),
        "leg_front": K((0, {"r": 0}, ""), (0.9 * s, {"r": 8}, ""), (1.4 * s, {"r": -55, "y": -6}, "i")),
        "leg_back": K((0, {"r": 0}, ""), (0.9 * s, {"r": -8}, ""), (1.4 * s, {"r": 50, "y": -6}, "i")),
    }
    for x in extras:
        k[x] = K((0, {"r": 0}, ""), (0.35 * s, {"r": 8}, ""), (1.4 * s, {"r": -10}, ""), (1.8 * s, {"r": 4}, "b"))
    return {"dur": dur, "keys": k}


def relic(extras, dur, cue):
    a, e = cue * 0.55, dur - 0.05
    k = {
        "hip": K((0, {"y": 0}, ""), (a, {"y": 8}, ""), (cue, {"y": -4}, "o"), (e - 0.45, {"y": -2}, ""), (e, {"y": 0}, "")),
        "torso": K((0, {"r": 0}, ""), (a, {"r": -6}, ""), (cue, {"r": -10}, "o"), (e - 0.45, {"r": -8}, ""), (e, {"r": 0}, "")),
        "head": K((0, {"r": 0}, ""), (a, {"r": 6}, ""), (cue, {"r": -14}, "o"), (e - 0.45, {"r": -12}, ""), (e, {"r": 0}, "")),
        "arm_f": K((0, {"r": 0}, ""), (a, {"r": 30}, ""), (cue, {"r": -115}, "b"), (e - 0.45, {"r": -110}, ""), (e, {"r": 0}, "")),
        "arm_b": K((0, {"r": 0}, ""), (a, {"r": -10}, ""), (cue, {"r": 20}, "o"), (e - 0.45, {"r": 18}, ""), (e, {"r": 0}, "")),
    }
    for x in extras:
        k[x] = K((0, {"r": 0}, ""), (a, {"r": -4}, ""), (cue, {"r": 12}, ""), (e - 0.45, {"r": 8}, ""), (e, {"r": 0}, ""))
    return {"dur": dur, "keys": k}


def root_track(clip):
    """Déplacement du personnage dans le clip d'origine (position du torse), en quelques clés."""
    tex = clip["tex"]
    ti = next((i for i, n in enumerate(tex) if "torso" in n or "body" in n), None)
    if ti is None:
        return None
    pts = []
    base = None
    for f, cmds in enumerate(clip["f"]):
        c = next((c for c in cmds if c[0] == ti and c[8] == 0), None)
        if c is None:
            continue
        if base is None:
            base = (c[1], c[2])
        pts.append((f / clip["fps"], c[1] - base[0], c[2] - base[1]))
    if not pts or max(abs(p[1]) for p in pts) < 6:
        return None
    step = max(1, round(clip["fps"] / 8))
    keys = [pts[i] for i in range(0, len(pts), step)] + [pts[-1]]
    return K(*[(t, {"x": round(x, 1), "y": round(min(0.0, y), 1)}, "s") for t, x, y in keys])


def aim(rest, target):
    """Rotation (degrés) qui amène un bras dont l'angle de repos est `rest` vers l'angle `target`."""
    return round((target - rest + 180) % 360 - 180)


def attack(extras, clip, slot, rest):
    dur = clip["dur"]
    cues = sorted({round(float(c[0]), 3) for c in clip.get("cue", [])}) or [dur * 0.55]
    first, last = cues[0], cues[-1]
    end = dur - 0.05
    hold = last + (end - last) * 0.35
    big = slot >= 2
    wind = max(0.1, first - (0.6 if big else 0.32))
    k = {}
    # Élan puis frappe(s), retenue, retour au repos.
    # Arme levée (sans passer devant le visage) puis abattue vers l'avant ; l'ultime va plus loin.
    # Un bras qui pend (angle de repos vers le bas) balaie plus large qu'un bras déjà tendu.
    wide = 1.4 if rest > 35 else 1.0
    up = round(-(70 if big else 48) * wide)
    hit, follow = (34 if big else 24), 14
    arm = [(0, {"r": 0}, ""), (wind, {"r": up}, "o")]
    torso = [(0, {"r": 0, "sy": 1}, ""), (wind, {"r": -14, "sy": 0.95 if big else 1}, "o")]
    hip = [(0, {"y": 0}, ""), (wind, {"y": 14 if big else 8}, "o")]
    head = [(0, {"r": 0}, ""), (wind, {"r": -8}, "o")]
    arm_b = [(0, {"r": 0}, ""), (wind, {"r": -25}, "o")]
    if big:  # ultime : on tient la charge en tremblant
        t = wind
        while t + 0.2 < first - 0.15:
            t += 0.2
            arm.append((t, {"r": up - (6 if len(arm) % 2 else 0)}, ""))
            torso.append((t, {"r": -16 if len(torso) % 2 else -12}, ""))
    prev = wind
    for n, c in enumerate(cues):
        if n > 0 and c - prev > 0.12:
            mid = (prev + c) / 2
            arm.append((mid, {"r": round(up * 0.7)}, "o"))
            torso.append((mid, {"r": -6}, ""))
        arm.append((c, {"r": hit}, "i"))
        torso.append((c, {"r": 18, "sy": 1}, "i"))
        hip.append((c, {"y": -4}, "o"))
        head.append((c, {"r": 9}, "o"))
        arm_b.append((c, {"r": 30}, "o"))
        prev = c
    arm += [(hold, {"r": follow}, ""), (end, {"r": 0}, "")]
    torso += [(hold, {"r": 10}, ""), (end, {"r": 0}, "")]
    hip += [(hold, {"y": 6 if big else 0}, ""), (end, {"y": 0}, "")]
    head += [(hold, {"r": 5}, ""), (end, {"r": 0}, "")]
    arm_b += [(hold, {"r": 15}, ""), (end, {"r": 0}, "")]
    k.update(arm_f=K(*arm), torso=K(*torso), hip=K(*hip), head=K(*head), arm_b=K(*arm_b))
    track = root_track(clip)
    moves = track is not None
    if track:
        k["root"] = track
    step = 26 if moves else 10
    k["leg_front"] = K((0, {"r": 0}, ""), (wind, {"r": 6}, ""), (first, {"r": -step}, "o"), (hold, {"r": -step * 0.7}, ""), (end, {"r": 0}, ""))
    k["leg_back"] = K((0, {"r": 0}, ""), (wind, {"r": -6}, ""), (first, {"r": step * 0.9}, "o"), (hold, {"r": step * 0.6}, ""), (end, {"r": 0}, ""))
    for x in extras:
        k[x] = K((0, {"r": 0}, ""), (wind, {"r": -8}, ""), (first, {"r": 16}, ""), (min(end, first + 0.3), {"r": 6}, "b"), (end, {"r": 0}, ""))
    return {"dur": dur, "keys": k}


def make(hero, force=False):
    out = RIGS / (hero + ".json")
    if out.exists() and not force:
        return False
    parts, extras, has = build_parts(hero)
    arm = next((p for p in parts if p["id"] == "arm_f"), None)
    rest = math.degrees(math.atan2(arm["pos"][1] - arm["pivot"][1], arm["pos"][0] - arm["pivot"][0])) if arm else 0.0
    anims = {"idle": idle(extras)}
    w = load_clip(hero + "_walk")
    anims["walk"] = walk(extras, w["dur"] if w else 1.2)
    h = load_clip(hero + "_hurt")
    anims["hurt"] = hurt(extras, h["dur"] if h else 0.75)
    d = load_clip(hero + "_death")
    if d:
        fall = float(d["cue"][0][0]) if d.get("cue") else d["dur"] * 0.65
        anims["death"] = death(extras, d["dur"], fall)
    r = load_clip(hero + "_relic")
    if r:
        anims["relic"] = relic(extras, r["dur"], float(r["cue"][0][0]) if r.get("cue") else r["dur"] * 0.45)
    for slot in range(6):
        c = load_clip("%s_%d" % (hero, slot))
        if c:
            anims[str(slot)] = attack(extras, c, slot, rest)
    # Retire les clés d'os absents (ex. héros sans bras).
    for a in anims.values():
        a["keys"] = {b: v for b, v in a["keys"].items() if b in has}
    rig = {"comment": "Généré par tools/make_rigs.py (pivots et poses automatiques ; retouchable à la main).",
           "parts": parts, "anims": anims}
    lines = ['{', ' "comment": %s,' % json.dumps(rig["comment"], ensure_ascii=False), ' "parts": [']
    lines.append(',\n'.join('  ' + json.dumps(p) for p in parts))
    lines.append(' ],\n "anims": {')
    blocks = []
    for n, a in anims.items():
        head = '  %s: {"dur": %s%s, "keys": {' % (json.dumps(n), round(a["dur"], 3), ', "loop": true' if a.get("loop") else "")
        body = ',\n'.join('   %s: %s' % (json.dumps(b), json.dumps(v)) for b, v in a["keys"].items())
        blocks.append(head + '\n' + body + '\n  }}')
    lines.append(',\n'.join(blocks))
    lines.append(' }\n}\n')
    out.write_text('\n'.join(lines), encoding="utf-8")
    return True


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    heroes = args or sorted(p.name[:-10] for p in (HEROES / "clips").glob("*_idle.json"))
    for h in heroes:
        print(h, "créé" if make(h, force) else "gardé (déjà là)")


if __name__ == "__main__":
    main()
