"""Importe un héros en pixel art (pack ChatGPT : frames_192/<anim>/<anim>_NNN.png + <héros>_animations.json)
dans assets/anim/pixel/<héros>/ : images + sheet.json lu par scripts/anim/pixel_sheet.gd.

    python tools/import_pixel_hero.py corbin D:/dev/CREOS_sources/px_corbin

Les animations du pack sont reliées aux clips du jeu (MAP) : le jeu joue l'animation pixel à la place
des pièces du héros, étirée pour que son instant de frappe tombe sur l'impact du clip.
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# clip du jeu -> animation du pack
MAP = {"idle": "idle", "walk": "walk", "run": "run", "hurt": "hurt", "death": "death", "relic": "skill",
       "dodge": "dodge", "0": "attack_1", "1": "attack_2", "2": "ultimate", "3": "skill", "4": "skill", "5": "skill"}
# Taille à l'écran : le personnage (≈ 70 px de haut dans sa case) est agrandi pour faire la taille des
# autres héros (repère du ClipPlayer, avant l'échelle de l'unité).
SCALE = 4.8


def main():
    hero, src = sys.argv[1], Path(sys.argv[2])
    data = json.loads(next(src.glob("*_animations.json")).read_text(encoding="utf-8"))
    out = ROOT / "assets/anim/pixel" / hero
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    anims = {}
    for name, a in data["animations"].items():
        frames = []
        for f in a["frames"]:
            file = Path(f["file_192"])
            dst = "%s_%s" % (hero, file.name)
            shutil.copy(src / file, out / dst)
            frames.append([dst, f["duration_ms"] / 1000.0])
        hit = next((e["frame"] for e in a.get("events", []) if e["name"] in ("attack_active", "release")), None)
        anims[name] = {"loop": a["loop"], "frames": frames, "hit_frame": hit}
    anchor = data.get("anchor_192", {"x": 96, "y": 146})
    sheet = {"hero": hero, "scale": SCALE, "anchor": [anchor["x"], anchor["y"]], "map": MAP, "anims": anims}
    (out / "sheet.json").write_text(json.dumps(sheet, ensure_ascii=False, indent=1), encoding="utf-8")
    print("%s : %d animations -> %s" % (hero, len(anims), out))


if __name__ == "__main__":
    main()
