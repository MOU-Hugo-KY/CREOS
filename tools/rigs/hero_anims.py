"""Animations des héros redécoupés (pièces ChatGPT : bras en 3 morceaux, armes séparées, jambes à
genou, plus capes, queues, ailes, tentacules, oreilles…), d'après leur façon de se battre.

    python tools/rigs/hero_anims.py [héros…]      (tous sauf Corbin, écrit à la main)

Le geste (taille, coup écrasant, estoc, poings, tir, sort) et le poids (lourd, vif, volant) viennent de
STYLES dans tools/make_rigs.py ; les instants d'impact et le déplacement viennent des clips d'origine.
Clés : (temps, {r, x, y, sx, sy}, courbe) ; r négatif = vers l'avant/le haut.
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from make_rigs import STYLES, TIMING, load_clip, root_track  # noqa: E402

RIGS = Path(__file__).resolve().parents[2] / "assets/anim/rigs"
STD = {"root", "hip", "pelvis", "torso", "head", "upper_arm_front", "forearm_front", "hand_front", "weapon_front",
       "upper_arm_back", "forearm_hand_back", "weapon_back", "thigh_front", "shin_front", "thigh_back", "shin_back"}


def K(*keys):
    return [[round(k[0], 3), k[1]] + ([k[2]] if len(k) > 2 and k[2] else []) for k in keys]


def R(*pairs):
    return K(*[(p[0], {"r": p[1]}) + tuple(p[2:]) for p in pairs])


class Body:
    """Ce que le héros a : quel bras frappe, quelles pièces flottent."""

    def __init__(self, rig, hero):
        self.parts = {p["id"]: p for p in rig["parts"]}
        self.kind, self.weight = STYLES.get(hero, ("slash", "normal"))
        has = self.parts.__contains__
        chains = {
            "front": ("upper_arm_front", "forearm_front", "weapon_front"),
            "back": ("upper_arm_back", "forearm_hand_back", "weapon_back"),
        }
        armed = [c for c, (_, _, w) in chains.items() if has(w)]
        hand_x = {c: self.parts[f]["pos"][0] for c, (_, f, _) in chains.items() if has(f)}
        pool = armed or list(hand_x)
        main = max(pool, key=lambda c: hand_x.get(c, 0)) if pool else "front"
        other = "back" if main == "front" else "front"
        self.ua, self.fa, self.wp = chains[main]
        self.ua2, self.fa2, self.wp2 = chains[other]
        self.extras = [p for p in self.parts if p not in STD and p != "shield"]
        self.shield2 = has("shield") and self.parts["shield"].get("parent") in (self.fa2, self.ua2)
        # Directions de repos (degrés, 0 = vers l'avant, 90 = vers le bas) du bras qui frappe.
        self.up_angle = self._angle(self.ua, self.fa)
        tip = self.wp if has(self.wp) else self.fa
        self.fore_rel = self._angle(self.fa, tip, use_pos=True) - self.up_angle if has(self.fa) else 0.0
        self.tentacles = sorted(p for p in self.extras if p.startswith("tentacle"))
        self.wings = [p for p in self.extras if p.startswith("wing")]
        self.legs = has("thigh_front")
        self.floaty = self.weight == "floaty"

    def _angle(self, a, b, use_pos=False):
        if a not in self.parts or b not in self.parts:
            return 90.0
        pa = self.parts[a]["pivot"]
        pb = self.parts[b]["pos"] if use_pos else self.parts[b]["pivot"]
        if abs(pb[0] - pa[0]) + abs(pb[1] - pa[1]) < 3:
            pb = self.parts[b]["pos"]
        return math.degrees(math.atan2(pb[1] - pa[1], pb[0] - pa[0]))

    def aim(self, target, rest=None):
        rest = self.up_angle if rest is None else rest
        return round((target - rest + 180) % 360 - 180)

    def flutter(self, name):
        """Ampleur du flottement d'une pièce libre (cape, queue, oreilles…)."""
        if name.startswith("wing"):
            return 3.0
        if name.startswith(("tail", "cape", "sash", "coat", "scarf")):
            return 1.4
        if name.startswith(("ear", "hair", "ribbon", "beard", "sleeve", "foliage", "moss")):
            return 0.8
        return 0.6


def secondary(b, keys, beats, amp=1.0):
    """Pièces libres : suivent le mouvement en retard (beats = [(t, sens)]), chacune un peu décalée."""
    for n, x in enumerate(b.extras):
        if x in b.tentacles:
            continue
        a = b.flutter(x) * amp
        lag = 0.05 * (n % 3)
        keys[x] = R(*[(max(0.0, t + lag if i else t), round(v * a, 1)) + (("b",) if i == len(beats) - 1 else ())
                      for i, (t, v) in enumerate(beats)])


def tentacle_wave(b, keys, dur, amp=12):
    for n, x in enumerate(b.tentacles):
        ph = (n * 0.37) % 1.0 * dur
        keys[x] = R((0, 0), ((0.25 * dur + ph) % dur, amp), ((0.75 * dur + ph) % dur, -amp), (dur, 0))
        keys[x].sort(key=lambda k: k[0])


def idle(b):
    k = {
        "hip": K((0, {"y": -12 if b.floaty else 0}), (1.0, {"y": -20 if b.floaty else 3}), (2.0, {"y": -12 if b.floaty else 0})),
        "torso": K((0, {"r": 0, "sy": 1}), (1.0, {"r": 1.5, "sy": 1.02}), (2.0, {"r": 0, "sy": 1})),
        "head": R((0, -1.5), (1.1, 2), (2.0, -1.5)),
        b.ua: R((0, 3), (1.0, -3), (2.0, 3)), b.fa: R((0, 4), (1.15, -4), (2.0, 4)), b.wp: R((0, 0), (1.3, 5), (2.0, 0)),
        b.ua2: R((0, -3), (1.0, 3), (2.0, -3)), b.fa2: R((0, -4), (1.15, 4), (2.0, -4)),
    }
    if b.floaty:
        k["thigh_front"] = R((0, -8), (1.0, -14), (2.0, -8))
        k["shin_front"] = R((0, 14), (1.0, 22), (2.0, 14))
        k["thigh_back"] = R((0, 6), (1.0, 2), (2.0, 6))
        k["shin_back"] = R((0, 18), (1.0, 26), (2.0, 18))
    secondary(b, k, [(0, 0), (1.2, -3), (2.0, 0)])
    for w in b.wings:  # battements d'ailes
        k[w] = R((0, 0), (0.25, -16, "o"), (0.6, 8), (1.0, 0), (1.25, -16, "o"), (1.6, 8), (2.0, 0))
    tentacle_wave(b, k, 2.0)
    return {"dur": 2.0, "loop": True, "keys": k}


def walk(b, dur):
    q = dur / 4
    k = {
        "hip": K((0, {"y": 0}), (q, {"y": -6}), (2 * q, {"y": 0}), (3 * q, {"y": -6}), (dur, {"y": 0})),
        "torso": R((0, 6), (q, 8), (2 * q, 6), (3 * q, 8), (dur, 6)),
        "head": R((0, -2), (2 * q, 2), (dur, -2)),
        "thigh_front": R((0, -22), (2 * q, 22), (dur, -22)),
        "shin_front": R((0, 0), (1.5 * q, 8), (2.5 * q, 32), (3.3 * q, 12), (dur, 0)),
        "thigh_back": R((0, 22), (2 * q, -22), (dur, 22)),
        "shin_back": R((0, 12), (0.5 * q, 32), (1.3 * q, 12), (2 * q, 0), (3.5 * q, 8), (dur, 12)),
        b.ua: R((0, 18), (2 * q, -18), (dur, 18)), b.fa: R((0, 10), (2 * q, -12), (dur, 10)),
        b.ua2: R((0, -18), (2 * q, 18), (dur, -18)), b.fa2: R((0, -12), (2 * q, 12), (dur, -12)),
    }
    if b.floaty:
        k["hip"] = K((0, {"y": -14}), (2 * q, {"y": -22}), (dur, {"y": -14}))
        for leg in ("thigh_front", "thigh_back", "shin_front", "shin_back"):
            k[leg] = R((0, 10), (2 * q, 18), (dur, 10))
    secondary(b, k, [(0, 8), (q, 13), (2 * q, 8), (3 * q, 13), (dur, 8)])
    for w in b.wings:
        k[w] = R((0, 0), (q, -18, "o"), (2 * q, 8), (3 * q, -18, "o"), (dur, 0))
    tentacle_wave(b, k, dur, 18)
    return {"dur": dur, "loop": True, "keys": k}


def arm_poses(b, big):
    """(prêt, impact) pour le bras qui frappe : rotations (épaule, coude, arme) et réaction du buste.
    Les angles visés sont absolus (0 = devant, -90 = en haut, 90 = en bas) : chaque héros, quel que
    soit le dessin de repos de son bras, lève puis abat son arme de la même façon."""
    kind = b.kind
    straight = round(-b.fore_rel * 0.6)  # avant-bras qui se tend dans l'axe du bras
    if kind == "slash":
        up, down = (-135, 50) if big else (-115, 35)
        return (b.aim(up), 25, 30), (b.aim(down), straight, -45), -12, 18
    if kind == "slam":
        up, down = (-140, 70) if big else (-125, 60)
        return (b.aim(up), -15, -25), (b.aim(down), straight, 40), -16, 26
    if kind in ("thrust", "punch"):
        return (b.aim(125), round(-110 - b.fore_rel * 0.3), 15), (b.aim(5), straight, -5), -10, 16
    if kind == "shoot":
        return (-4, -4, 0), (-12, -10, -8), -4, -8
    up = -95 if big else -75  # cast : bras levé vers l'avant puis tendu vers l'ennemi
    return (b.aim(up), -20, -15), (b.aim(-10), straight, 10), -6, 10


def attack(b, clip, slot):
    dur = clip["dur"]
    cues = sorted({round(float(c[0]), 3) for c in clip.get("cue", [])}) or [dur * 0.55]
    first, last = cues[0], cues[-1]
    end = dur - 0.05
    big = slot >= 2
    t_wind, t_wind_big, snap, keep = TIMING[b.weight]
    wind = max(0.08, first - (t_wind_big if big else t_wind))
    hold = min(end - 0.15, last + keep + (end - last) * 0.25)
    (ru, rf, rw), (hu, hf, hw), lean_r, lean_h = arm_poses(b, big)
    hover = -12 if b.floaty else 0
    dip = {"heavy": 16, "normal": 10, "light": 7, "floaty": 4}[b.weight]
    ua = [(0, 0), (wind, ru, "o")]
    fa = [(0, 0), (wind, rf, "o")]
    wp = [(0, 0), (wind, rw, "o")]
    guard = b.shield2  # le bras au bouclier reste en garde, devant
    ua2 = [(0, 0), (wind, -12 if guard else (-25 if b.kind != "punch" else 30))]
    fa2 = [(0, 0), (wind, -10 if guard else (-15 if b.kind != "punch" else 70))]
    torso = [(0, {"r": 0, "sy": 1}), (wind, {"r": lean_r, "sy": 0.95 if big else 0.98}, "o")]
    hip = [(0, {"y": hover}), (wind, {"y": hover + dip}, "o")]
    head = [(0, 0), (wind, -8, "o")]
    # Charge tenue (tremblement sur l'ultime) jusqu'au déclenchement.
    t = wind
    while t + 0.16 < first - snap:
        t += 0.16
        odd = len(ua) % 2
        ua.append((t, ru + (4 if odd and big else 0)))
        torso.append((t, {"r": lean_r - (2 if odd and big else 0)}))
    for n, c in enumerate(cues):
        alt = b.kind == "punch" and n % 2 == 1
        su, sf = (ua2, fa2) if alt else (ua, fa)
        start = max(wind, c - snap) if n == 0 else max(cues[n - 1] + 0.06, c - snap)
        su.append((start, ru))
        sf.append((start, rf))
        su.append((c, round(hu * 1.1), "i"))  # frappe sèche, le bras dépasse un peu
        sf.append((c, hf, "i"))
        if not alt:
            wp.append((start + 0.01, rw))
            wp.append((min(end, c + 0.04), round(hw * 1.1), "o"))  # l'arme part en retard (fouet)
        if c + 0.06 < end:
            su.append((c + 0.06, hu, "o"))
        if guard:
            ua2.append((c, -18, "o"))
        if b.kind == "punch":  # l'autre poing revient en garde
            (ua if alt else ua2).append((c, 30))
            (fa if alt else fa2).append((c, 70))
        torso.append((c, {"r": lean_h, "sy": 1.03}, "i"))
        hip.append((c, {"y": hover + (dip * 0.8 if b.kind == "slam" else -4)}, "o"))
        head.append((c, 8 if lean_h > 0 else -6, "o"))
    for lst, v in ((ua, round(hu * 0.7)), (fa, round(hf * 0.5)), (wp, round(hw * 0.4)), (ua2, 8), (fa2, 6)):
        lst.append((hold, v))
        lst.append((end, 0))
        lst.sort(key=lambda a: a[0])
    torso += [(hold, {"r": lean_h * 0.6, "sy": 1}), (end, {"r": 0}, "b")]
    hip += [(hold, {"y": hover + dip * 0.3}), (end, {"y": hover})]
    head += [(hold, 4), (end, 0, "b")]
    k = {b.ua: R(*ua), b.fa: R(*fa), b.wp: R(*wp), b.ua2: R(*ua2), b.fa2: R(*fa2),
         "torso": K(*torso), "hip": K(*hip), "head": R(*head)}
    if b.kind == "thrust":  # estoc : la lance recule puis file droit devant, sans tourner
        th = [(0, {"r": 0, "x": 0, "y": 0}), (wind, {"r": 6, "x": -30, "y": 4}, "o")]
        for n, c in enumerate(cues):
            start = max(wind, c - snap) if n == 0 else max(cues[n - 1] + 0.06, c - snap)
            th += [(start, {"r": 6, "x": -30, "y": 4}), (c, {"r": -4, "x": 52, "y": -2}, "i")]
            if c + 0.06 < end:
                th.append((c + 0.06, {"x": 44}, "o"))
        th += [(hold, {"r": -2, "x": 30, "y": 0}), (end, {"r": 0, "x": 0, "y": 0})]
        k[b.ua] = K(*sorted(th, key=lambda a: a[0]))
        k[b.fa] = R((0, 0), (wind, -6), (first, 4), (end, 0))
        k[b.wp] = R((0, 0), (end, 0))
    track = root_track(clip)
    if track:
        k["root"] = track
    if b.legs and not b.floaty:
        lunge = 1.0 if track else 0.5
        k["thigh_front"] = R((0, 0), (wind, 6), (first, round(-30 * lunge), "o"), (hold, round(-20 * lunge)), (end, 0))
        k["shin_front"] = R((0, 0), (wind, 12), (first, 18), (hold, 10), (end, 0))
        k["thigh_back"] = R((0, 0), (wind, -6), (first, round(26 * lunge), "o"), (hold, round(16 * lunge)), (end, 0))
        k["shin_back"] = R((0, 0), (wind, 6), (first, 30), (hold, 15), (end, 0))
    secondary(b, k, [(0, 0), (wind, -7), (first, 16), (min(end, first + 0.3), 6), (end, 0)], 2.0 if b.floaty else 1.0)
    for w in b.wings:
        k[w] = R((0, 0), (wind, -20, "o"), (first, 22, "i"), (min(end, first + 0.25), -10), (end, 0))
    if b.tentacles:
        for n, x in enumerate(b.tentacles):
            s = 1 if n % 2 else -1
            k[x] = R((0, 0), (wind, 14 * s), (first, -20 * s, "o"), (hold, -8 * s), (end, 0))
    return {"dur": dur, "keys": k}


def hurt(b, dur):
    e = dur * 0.85
    k = {
        "root": K((0, {"x": 0}), (0.12, {"x": -26}, "o"), (e, {"x": 0})),
        "hip": K((0, {"y": 0}), (0.12, {"y": 6}), (e, {"y": 0})),
        "torso": R((0, 0), (0.1, -16, "o"), (dur * 0.45, -8), (e, 0)),
        "head": R((0, 0), (0.12, -14, "o"), (e, 0)),
        b.ua: R((0, 0), (0.12, 30, "o"), (e, 0)), b.fa: R((0, 0), (0.16, 20), (e, 0)), b.wp: R((0, 0), (0.18, 20), (e, 0)),
        b.ua2: R((0, 0), (0.12, 25, "o"), (e, 0)), b.fa2: R((0, 0), (0.16, 18), (e, 0)),
        "shin_front": R((0, 0), (0.12, 8), (e, 0)), "shin_back": R((0, 0), (0.12, 10), (e, 0)),
    }
    secondary(b, k, [(0, 0), (0.15, 12), (dur * 0.6, -4), (e, 0)])
    return {"dur": dur, "keys": k}


def death(b, dur, fall):
    s = fall / 1.4
    k = {
        "root": K((0, {"x": 0}), (0.35 * s, {"x": -24}, "o"), (1.4 * s, {"x": -30})),
        "hip": K((0, {"y": 0}), (0.35 * s, {"y": 8}, "o"), (0.9 * s, {"y": 4}), (1.4 * s, {"y": 40}, "i"), (1.55 * s, {"y": 34}, "o"), (1.7 * s, {"y": 40}, "i")),
        "torso": R((0, 0), (0.35 * s, -18, "o"), (0.9 * s, -12), (1.4 * s, 28, "i"), (1.6 * s, 34, "o")),
        "head": R((0, 0), (0.35 * s, -22, "o"), (0.9 * s, -14), (1.4 * s, 20, "i"), (1.7 * s, 30, "o")),
        b.ua: R((0, 0), (0.35 * s, 40, "o"), (1.4 * s, 15), (1.7 * s, 25, "b")),
        b.fa: R((0, 0), (0.35 * s, 20), (1.4 * s, 10), (1.7 * s, 20, "b")),
        b.wp: R((0, 0), (0.4 * s, 30), (1.5 * s, 50), (1.8 * s, 60, "b")),
        b.ua2: R((0, 0), (0.35 * s, 30, "o"), (1.4 * s, 10), (1.7 * s, 20, "b")),
        b.fa2: R((0, 0), (0.35 * s, 15), (1.4 * s, 10), (1.7 * s, 18, "b")),
        "thigh_front": K((0, {"r": 0, "y": 0}), (0.9 * s, {"r": 8, "y": 0}), (1.4 * s, {"r": -60, "y": 36}, "i")),
        "shin_front": R((0, 0), (0.9 * s, 6), (1.4 * s, 75, "i")),
        "thigh_back": K((0, {"r": 0, "y": 0}), (0.9 * s, {"r": -8, "y": 0}), (1.4 * s, {"r": -15, "y": 36}, "i")),
        "shin_back": R((0, 0), (0.9 * s, 4), (1.4 * s, 95, "i")),
    }
    secondary(b, k, [(0, 0), (0.35 * s, 10), (1.4 * s, -10), (1.8 * s, 4)])
    for n, x in enumerate(b.tentacles):
        k[x] = R((0, 0), (1.4 * s, 25 if n % 2 else -25, "i"))
    return {"dur": dur, "keys": k}


def relic(b, dur, cue):
    a, e = cue * 0.55, dur - 0.05
    k = {
        "hip": K((0, {"y": 0}), (a, {"y": 8}), (cue, {"y": -4}, "o"), (e - 0.45, {"y": -2}), (e, {"y": 0})),
        "torso": R((0, 0), (a, -6), (cue, -10, "o"), (e - 0.45, -8), (e, 0)),
        "head": R((0, 0), (a, 6), (cue, -14, "o"), (e - 0.45, -12), (e, 0)),
        b.ua: R((0, 0), (a, 30), (cue, -115, "b"), (e - 0.45, -110), (e, 0)),
        b.fa: R((0, 0), (a, 20), (cue, -10), (e - 0.45, -8), (e, 0)),
        b.ua2: R((0, 0), (a, -10), (cue, 20, "o"), (e - 0.45, 18), (e, 0)),
    }
    secondary(b, k, [(0, 0), (a, -4), (cue, 14), (e - 0.45, 10), (e, 0)])
    return {"dur": dur, "keys": k}


def build(hero):
    path = RIGS / (hero + ".json")
    rig = json.loads(path.read_text(encoding="utf-8"))
    b = Body(rig, hero)
    anims = {"idle": idle(b)}
    w = load_clip(hero + "_walk")
    anims["walk"] = walk(b, w["dur"] if w else 1.2)
    h = load_clip(hero + "_hurt")
    anims["hurt"] = hurt(b, h["dur"] if h else 0.75)
    d = load_clip(hero + "_death")
    if d:
        anims["death"] = death(b, d["dur"], float(d["cue"][0][0]) if d.get("cue") else d["dur"] * 0.65)
    r = load_clip(hero + "_relic")
    if r:
        anims["relic"] = relic(b, r["dur"], float(r["cue"][0][0]) if r.get("cue") else r["dur"] * 0.45)
    for slot in range(6):
        c = load_clip("%s_%d" % (hero, slot))
        if c:
            anims[str(slot)] = attack(b, c, slot)
    # Le bras qui frappe passe devant le corps s'il était dessiné derrière.
    torso_z = b.parts["torso"].get("z", 10)
    for p in rig["parts"]:
        if p["id"] in (b.ua, b.fa, b.wp) and p.get("z", 0) < torso_z:
            p["z"] = 40 + p["z"]
    for a in anims.values():
        a["keys"] = {n: v for n, v in a["keys"].items() if n in b.parts}
    blocks = []
    for n, a in anims.items():
        hd = '  %s: {"dur": %s%s, "keys": {' % (json.dumps(n), round(a["dur"], 3), ', "loop": true' if a.get("loop") else "")
        body = ',\n'.join('   %s: %s' % (json.dumps(x), json.dumps(v)) for x, v in a["keys"].items())
        blocks.append(hd + '\n' + body + '\n  }}')
    text = ('{\n "comment": "Pièces redécoupées (tools/import_rig_parts.py) ; animations : tools/rigs/hero_anims.py.",\n'
            ' "source": "parts",\n "parts": [\n' + ',\n'.join('  ' + json.dumps(p) for p in rig["parts"]) + '\n ],\n'
            ' "anims": {\n' + ',\n'.join(blocks) + '\n }\n}\n')
    json.loads(text)
    path.write_text(text, encoding="utf-8")
    return "%s : %s/%s, frappe avec %s, %d pièces libres" % (hero, b.kind, b.weight, b.ua, len(b.extras))


def main():
    heroes = sys.argv[1:] or sorted(STYLES)
    for h in heroes:
        print(build(h))


if __name__ == "__main__":
    main()
