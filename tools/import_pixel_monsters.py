"""Importe les monstres en pixel art (pack ChatGPT CREOS_Monstres_MondeNN : mondeNN/<id>/<id>_combat.json
+ frames/ + effects/) dans assets/anim/pixel/<id>/ : images + sheet.json lu par scripts/anim/pixel_sheet.gd.

    python tools/import_pixel_monsters.py D:/chemin/CREOS_Monstres_Monde01/monde01

Les monstres regardent à gauche (facing -1). Leur taille relative est déjà dans les images : l'échelle
est réglée pour qu'un petit monstre (slime) soit un peu plus petit qu'un héros.
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAP = {"idle": "idle", "walk": "walk", "run": "walk", "attack": "attack", "skill": "skill",
       "hurt": "hurt", "death": "death"}
SCALE = 1.6
HIT_EVENTS = ("hit_active", "release", "attack_active")


def import_monster(src):
    mid = src.name
    data = json.loads((src / ("%s_combat.json" % mid)).read_text(encoding="utf-8"))
    out = ROOT / "assets/anim/pixel" / mid
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    anims = {}
    for name, a in data["animations"].items():
        frames = []
        for f in a["frames"]:
            dst = "%s_%s" % (mid, Path(f["file"]).name)
            shutil.copy(src / f["file"], out / dst)
            frames.append([dst, f["duration_ms"] / 1000.0])
        hit = next((e["frame"] for e in a.get("events", []) if e["name"] in HIT_EVENTS), None)
        anims[name] = {"loop": a["loop"], "frames": frames, "hit_frame": hit}
    effect = None
    imp = data.get("effects", {}).get("impact")
    if imp:
        frames = []
        files = sorted((src / "effects/frames/impact").glob("*.png"))
        for i, ms in enumerate(imp["duration_ms"]):
            dst = "%s_fx_%03d.png" % (mid, i)
            shutil.copy(files[i], out / dst)
            frames.append([dst, ms / 1000.0])
        effect = {"frames": frames, "pivot": imp["pivot"], "scale": {"attack": 0.8, "skill": 1.2}}
    sheet = {"hero": mid, "scale": SCALE, "facing": -1, "anchor": data["pivot"], "map": MAP,
             "anims": anims, "effect": effect}
    (out / "sheet.json").write_text(json.dumps(sheet, ensure_ascii=False, indent=1), encoding="utf-8")
    return mid, len(anims)


def main():
    world = Path(sys.argv[1])
    for d in sorted(p for p in world.iterdir() if p.is_dir()):
        if (d / ("%s_combat.json" % d.name)).exists():
            print("%s : %d animations" % import_monster(d))


if __name__ == "__main__":
    main()
