"""Importe le pack de combat pixel des héros (ChatGPT : heroes/<id>/<id>_combat.json + frames/ + effects/)
dans assets/anim/pixel/<id>/ : images + sheet.json lu par scripts/anim/pixel_sheet.gd.

    python tools/import_pixel_combat.py D:/chemin/CREOS_Heros_Combat [héros…]

Le pack n'a pas de marche de combat : on prend la marche vers la droite du hub
(assets/hub_px/heroes/<id>/<id>_walk_right.png), découpée en images. L'effet « signature »
(joué sur la cible à l'impact) est copié avec ses durées.
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MAP = {"idle": "idle", "walk": "walk", "run": "walk", "hurt": "hurt", "death": "death", "relic": "skill",
       "dodge": "dodge", "0": "attack_1", "1": "skill", "2": "ultimate", "3": "attack_2", "4": "skill", "5": "ultimate"}
SCALE = 4.8
HIT_EVENTS = ("hit_active", "release", "attack_active")


def import_hero(hero, src):
    data = json.loads((src / ("%s_combat.json" % hero)).read_text(encoding="utf-8"))
    out = ROOT / "assets/anim/pixel" / hero
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    anims = {}
    for name, a in data["animations"].items():
        frames = []
        for f in a["frames"]:
            dst = "%s_%s" % (hero, Path(f["file"]).name)
            shutil.copy(src / f["file"], out / dst)
            frames.append([dst, f["duration_ms"] / 1000.0])
        hit = next((e["frame"] for e in a.get("events", []) if e["name"] in HIT_EVENTS), None)
        anims[name] = {"loop": a["loop"], "frames": frames, "hit_frame": hit}
    # Marche : celle du hub, vue de profil droite.
    walk = ROOT / "assets/hub_px/heroes" / hero / ("%s_walk_right.png" % hero)
    if walk.exists():
        sheet = Image.open(walk)
        frames = []
        for i in range(sheet.width // 192):
            dst = "%s_walk_%03d.png" % (hero, i)
            sheet.crop((i * 192, 0, i * 192 + 192, 192)).save(out / dst)
            frames.append([dst, 0.1])
        anims["walk"] = {"loop": True, "frames": frames, "hit_frame": None}
    effect = None
    sig = data.get("effects", {}).get("signature")
    if sig:
        frames = []
        for i, ms in enumerate(sig["duration_ms"]):
            dst = "%s_fx_%03d.png" % (hero, i)
            shutil.copy(src / "effects" / ("signature_%03d.png" % i), out / dst)
            frames.append([dst, ms / 1000.0])
        effect = {"frames": frames, "pivot": sig["pivot"], "scale": sig.get("recommended_scale", {})}
    pivot = data.get("pivot", [96, 146])
    sheet = {"hero": hero, "scale": SCALE, "anchor": pivot, "map": MAP, "anims": anims, "effect": effect}
    (out / "sheet.json").write_text(json.dumps(sheet, ensure_ascii=False, indent=1), encoding="utf-8")
    print("%s : %d animations%s" % (hero, len(anims), " + effet" if effect else ""))


def main():
    pack = Path(sys.argv[1]) / "heroes"
    heroes = sys.argv[2:] or [p.name for p in sorted(pack.iterdir()) if p.is_dir()]
    for hero in heroes:
        import_hero(hero, pack / hero)


if __name__ == "__main__":
    main()
