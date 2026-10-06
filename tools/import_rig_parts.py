"""Importe un héros redécoupé pour le squelette (zip livré par ChatGPT : PNG par pièce + <héros>_rig.json
avec position, pivot, parent et ordre de dessin) et écrit les pièces de assets/anim/rigs/<héros>.json.

    python tools/import_rig_parts.py corbin D:/dev/CREOS_sources/rig_corbin

Les pièces sont copiées dans assets/anim/heroes/tex/<héros>_rig_<pièce>.png. L'échelle et l'origin
(pieds au sol en 0,0) sont calées sur le clip de repos actuel du héros, pour que les effets des clips
d'attaque restent à la bonne place. Les animations déjà écrites dans le fichier du squelette sont
gardées (elles utilisent les noms des pièces).
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
HEROES = ROOT / "assets/anim/heroes"
RIGS = ROOT / "assets/anim/rigs"
# Les jambes restent accrochées au sol (pas au bassin) : les pieds ne glissent pas quand le corps bouge.
GROUNDED = ("thigh_front", "thigh_back")


def main():
    hero, src = sys.argv[1], Path(sys.argv[2])
    data = json.loads((src / (hero + "_rig.json")).read_text(encoding="utf-8"))
    # Calage sur le clip de repos actuel : même hauteur, pieds en y = 0, même centre.
    idle = json.loads((HEROES / "clips" / (hero + "_idle.json")).read_text(encoding="utf-8"))
    xs, ys = [], []
    for c in idle["f"][0]:
        if c[0] >= 0 and c[8] == 0:
            xs += [c[1] - c[3] / 2, c[1] + c[3] / 2]
            ys += [c[2] - c[4] / 2, c[2] + c[4] / 2]
    box = Image.open(src / (hero + "_montage.png")).getbbox()
    s = (max(ys) - min(ys)) / (box[3] - box[1])
    ox = box[0] - min(xs) / s
    oy = box[3]

    def to_game(x, y):
        return [round((x - ox) * s, 1), round((y - oy) * s, 1)]

    parts = {}
    for p in data["parts"]:
        name = p["name"]
        shutil.copy(src / p["file"], HEROES / "tex" / ("%s_rig_%s.png" % (hero, name)))
        w, h = p["size"]["width"], p["size"]["height"]
        x, y = p["position"]["x"], p["position"]["y"]
        parent = p.get("parent") or "hip"
        if name in GROUNDED:
            parent = "root"
        parts[name] = {"id": name, "parent": parent, "tex": "%s_rig_%s.png" % (hero, name),
                       "pos": to_game(x + w / 2, y + h / 2), "size": [round(w * s, 1), round(h * s, 1)],
                       "pivot": to_game(p["pivot_world"]["x"], p["pivot_world"]["y"]), "z": p["layer"]}
    pelvis = parts.get("pelvis")
    hip = {"id": "hip", "parent": "root", "pivot": pelvis["pivot"] if pelvis else [0, -60]}
    ordered = [{"id": "root", "pivot": [0, 0]}, hip]
    done = {"root", "hip"}
    while len(ordered) < len(parts) + 2:  # parents avant enfants
        for p in parts.values():
            if p["id"] not in done and p["parent"] in done:
                ordered.append(p)
                done.add(p["id"])
    out = RIGS / (hero + ".json")
    old = json.loads(out.read_text(encoding="utf-8")) if out.exists() else {}
    keep = old.get("anims", {}) if old.get("source") == "parts" else {}
    lines = ['{', ' "comment": "Pièces redécoupées (tools/import_rig_parts.py) ; animations écrites à la main.",',
             ' "source": "parts",', ' "parts": [', ',\n'.join('  ' + json.dumps(p) for p in ordered), ' ],',
             ' "anims": ' + json.dumps(keep, ensure_ascii=False), '}', '']
    out.write_text('\n'.join(lines), encoding="utf-8")
    print("échelle %.3f, %d pièces -> %s" % (s, len(parts), out))


if __name__ == "__main__":
    main()
