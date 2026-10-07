"""Installe les arènes vues en plongée (pack ChatGPT CREOS_Arenes_MondeNN : mondeNN/sceneS/arene.png,
premier_plan.png, arene.json) dans assets/decors/mondeNN/ : areneS.png, areneS_avant.png (s'il n'est
pas vide), areneS.json. BattleStage les préfère à l'ancien décor de côté.

    python tools/import_arenas.py D:/chemin/CREOS_Arenes_Monde02/monde02
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def main():
    src = Path(sys.argv[1])
    out = ROOT / "assets/decors" / src.name
    out.mkdir(parents=True, exist_ok=True)
    for s in (1, 2, 3):
        d = src / ("scene%d" % s)
        if not (d / "arene.png").exists():
            print("scène %d absente" % s)
            continue
        shutil.copy(d / "arene.png", out / ("arene%d.png" % s))
        shutil.copy(d / "arene.json", out / ("arene%d.json" % s))
        fg = d / "premier_plan.png"
        avant = out / ("arene%d_avant.png" % s)
        if fg.exists() and Image.open(fg).convert("RGBA").getbbox():
            shutil.copy(fg, avant)
        elif avant.exists():
            avant.unlink()
        print("%s scène %d : %s" % (src.name, s, "avec premier plan" if avant.exists() else "sans premier plan"))


if __name__ == "__main__":
    main()
