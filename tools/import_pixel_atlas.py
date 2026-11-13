"""Importe une planche pixel sans modifier ses pixels ni supprimer les dessins existants.

Exemple : python tools/import_pixel_atlas.py corbin attack_1 planche.png --columns 4 --frames 16 --hit-frame 8
Les pieds sont recalés par image ; la taille reste celle de la pose d'origine.
Dépendance : Pillow (comme les autres outils d'import du projet).
"""
import argparse
import json
import re
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def bounds_and_feet(image):
    # Lecture de l'alpha uniquement : aucun rééchantillonnage de l'image livrée.
    alpha = image.getchannel("A")
    opaque = [(x, y) for y in range(image.height) for x in range(image.width)
              if alpha.getpixel((x, y)) >= 128]
    if not opaque:
        raise ValueError("Une case de la planche est vide")
    bottom = max(y for _, y in opaque) + 1
    top = min(y for _, y in opaque)
    feet = [x for x, y in opaque if y >= bottom - 5]
    return bottom - top, [round(sum(feet) / len(feet), 2), bottom]


def import_atlas(hero, animation, source, columns, count, hit_frame, durations=None):
    if not re.fullmatch(r"[a-z0-9_]+", hero) or not re.fullmatch(r"[a-z0-9_]+", animation):
        raise ValueError("Identifiant de héros ou d'animation invalide")
    if columns < 1 or count < 1 or not 0 <= hit_frame < count:
        raise ValueError("Grille ou image d'impact invalide")
    folder = ROOT / "assets/anim/pixel" / hero
    manifest = folder / "sheet.json"
    sheet = json.loads(manifest.read_text(encoding="utf-8"))
    original_key = animation + "_original"
    original = sheet["anims"].get(original_key, sheet["anims"][animation])
    image = Image.open(source).convert("RGBA")
    rows = (count + columns - 1) // columns
    reference = Image.open(folder / original["frames"][0][0]).convert("RGBA")
    original_height, _ = bounds_and_feet(reference)
    original_total = sum(f[1] for f in original["frames"])
    durations = durations or [original_total / count] * count
    if len(durations) != count or any(d <= 0 for d in durations):
        raise ValueError("Il faut une durée positive par image")
    filename = f"{hero}_{animation}_16f.png" if count == 16 else f"{hero}_{animation}_{count}f.png"
    frames = []
    first_height = 0
    for i in range(count):
        col, row = i % columns, i // columns
        left, right = round(col * image.width / columns), round((col + 1) * image.width / columns)
        top, bottom = round(row * image.height / rows), round((row + 1) * image.height / rows)
        height, anchor = bounds_and_feet(image.crop((left, top, right, bottom)))
        if i == 0:
            first_height = height
        frames.append([filename, round(durations[i], 6), {
            "region": [left, top, right - left, bottom - top], "anchor": anchor,
            "scale": round(float(sheet["scale"]) * original_height / first_height, 6),
        }])
    # Valider toute la planche avant d'écrire quoi que ce soit.
    if Path(source).resolve() != (folder / filename).resolve():
        shutil.copyfile(source, folder / filename)
    sheet["anims"].setdefault(original_key, original)
    sheet["anims"][animation] = {"loop": original["loop"], "hit_frame": hit_frame, "frames": frames}
    manifest.write_text(json.dumps(sheet, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{hero}/{animation} : {len(original['frames'])} → {count} poses, original conservé, impact {hit_frame}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("hero")
    parser.add_argument("animation")
    parser.add_argument("source", type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--frames", type=int, default=16)
    parser.add_argument("--hit-frame", type=int, default=8)
    args = parser.parse_args()
    import_atlas(args.hero, args.animation, args.source, args.columns, args.frames, args.hit_frame)
