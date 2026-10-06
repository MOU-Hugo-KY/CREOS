"""Remplace le repos de combat des héros pixel par le repos « respiration » (pack ChatGPT
CREOS_Repos_Combat : heroes/<id>/idle_v2.json + frames/idle/) dans assets/anim/pixel/<id>/.

    python tools/import_pixel_idle.py D:/chemin/CREOS_Repos_Combat
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    pack = Path(sys.argv[1]) / "heroes"
    for src in sorted(p for p in pack.iterdir() if (p / "idle_v2.json").exists()):
        hero = src.name
        out = ROOT / "assets/anim/pixel" / hero
        sheet_path = out / "sheet.json"
        if not sheet_path.exists():
            print("%s : pas de héros pixel, ignoré" % hero)
            continue
        sheet = json.loads(sheet_path.read_text(encoding="utf-8"))
        for old in out.glob("%s_idle_*.png*" % hero):
            old.unlink()
        anim = json.loads((src / "idle_v2.json").read_text(encoding="utf-8"))["animation"]
        frames = []
        for f in anim["frames"]:
            dst = "%s_%s" % (hero, Path(f["file"]).name)
            shutil.copy(src / f["file"], out / dst)
            frames.append([dst, f["duration_ms"] / 1000.0])
        sheet["anims"]["idle"] = {"loop": True, "frames": frames, "hit_frame": None}
        sheet_path.write_text(json.dumps(sheet, ensure_ascii=False, indent=1), encoding="utf-8")
        print("%s : repos %.1f s" % (hero, sum(f[1] for f in frames)))


if __name__ == "__main__":
    main()
