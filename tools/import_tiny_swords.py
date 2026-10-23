"""Copie les images utiles du pack Tiny Swords (Pixel Frog) dans assets/tiny/.

Le pack n'est pas redistribuable : assets/tiny/ est ignoré par git, chacun lance cet outil
après avoir téléchargé le pack sur https://pixelfrog-assets.itch.io/tiny-swords.

    python tools/import_tiny_swords.py [D:/dev/CREOS_sources/TinySwords]
"""
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "assets" / "tiny"

# destination -> chemin dans le pack
FILES = {
    "terrain/tilemap.png": "Terrain/Tileset/Tilemap_color1.png",
    "terrain/foam.png": "Terrain/Tileset/Water Foam.png",
    "terrain/shadow.png": "Terrain/Tileset/Shadow.png",
    "terrain/rock1.png": "Terrain/Decorations/Rocks/Rock1.png",
    "terrain/rock2.png": "Terrain/Decorations/Rocks/Rock2.png",
    "terrain/water_rocks.png": "Terrain/Decorations/Rocks in the Water/Water Rocks_01.png",
    "terrain/bush.png": "Terrain/Decorations/Bushes/Bushe1.png",
    "terrain/tree.png": "Terrain/Resources/Wood/Trees/Tree1.png",
    "terrain/cloud.png": "Terrain/Decorations/Clouds/Clouds_01.png",
    "terrain/duck.png": "Terrain/Decorations/Rubber Duck/Rubber duck.png",
    "buildings/castle.png": "Buildings/Blue Buildings/Castle.png",
    "buildings/tower.png": "Buildings/Blue Buildings/Tower.png",
    "buildings/archery.png": "Buildings/Blue Buildings/Archery.png",
    "buildings/house.png": "Buildings/Blue Buildings/House1.png",
    "fx/explosion.png": "Particle FX/Explosion_01.png",
    "fx/dust.png": "Particle FX/Dust_01.png",
    "fx/arrow.png": "Units/Blue Units/Archer/Arrow.png",
    "ui/button.png": "UI Elements/UI Elements/Buttons/SmallBlueSquareButton_Regular.png",
    "ui/button_pressed.png": "UI Elements/UI Elements/Buttons/SmallBlueSquareButton_Pressed.png",
    "ui/button_red.png": "UI Elements/UI Elements/Buttons/SmallRedSquareButton_Regular.png",
}
# unités : couleur du pack -> nom dans le jeu
for color, team in (("Blue", "blue"), ("Red", "red"), ("Yellow", "yellow")):
    u = f"Units/{color} Units"
    FILES.update({
        f"units/{team}/warrior_idle.png": f"{u}/Warrior/Warrior_Idle.png",
        f"units/{team}/warrior_run.png": f"{u}/Warrior/Warrior_Run.png",
        f"units/{team}/warrior_attack.png": f"{u}/Warrior/Warrior_Attack1.png",
        f"units/{team}/archer_idle.png": f"{u}/Archer/Archer_Idle.png",
        f"units/{team}/archer_run.png": f"{u}/Archer/Archer_Run.png",
        f"units/{team}/archer_attack.png": f"{u}/Archer/Archer_Shoot.png",
        f"units/{team}/lancer_idle.png": f"{u}/Lancer/Lancer_Idle.png",
        f"units/{team}/lancer_run.png": f"{u}/Lancer/Lancer_Run.png",
        f"units/{team}/lancer_attack.png": f"{u}/Lancer/Lancer_Right_Attack.png",
    })


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "D:/dev/CREOS_sources/TinySwords")
    packs = [p for p in src.rglob("Terrain") if p.is_dir()]
    if not packs:
        sys.exit(f"Pack introuvable dans {src}")
    pack = packs[0].parent
    for dest, rel in FILES.items():
        out = DEST / dest
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(pack / rel, out)
    print(f"{len(FILES)} images copiées dans {DEST}")


if __name__ == "__main__":
    main()
