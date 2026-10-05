"""Importe les packs livrés par ChatGPT (dossier décompressé, par défaut D:/dev/CREOS_sources) dans
le jeu, en version allégée :

- clips d'animation (héros, ennemis) : JSON compact, coordonnées ramenées au point au sol de
  l'acteur (0, 0), nombres arrondis, cibles de démonstration retirées ;
- pièces PNG, sons WAV -> OGG (ffmpeg) ;
- décors des 10 mondes (fonds en JPG, sol et premier plan en PNG) + configs d'ambiance ;
- reliques (icônes et sprites).

Usage : python tools/import_creos_packs.py [dossier_sources]
Format d'un clip compact (lu par scripts/anim/clip_player.gd) :
  {"fps", "dur", "loop", "tex": [noms], "snd": [[t, fichier]], "cue": [[t, nom]],
   "f": [[cmd, ...] par image]}
  cmd sprite : [i_tex, x, y, w, h, angle, alpha, flip, calque]   (calque 0 acteur, 1 effets)
  cmd ligne  : [-1, x1, y1, x2, y2, couleur, épaisseur, alpha, calque]
  cmd anneau : [-2, x, y, r, ratio, couleur, épaisseur, alpha, calque]
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "D:/dev/CREOS_sources")
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets"

# Point au sol de l'acteur dans le cadre de travail 1280 × 720 de chaque pack.
HERO_STATE_ORIGIN = (340.0, 600.0)
HERO_ATTACK_ORIGIN = (210.0, 600.0)
HERO_ATTACK_SCALE = 320.0 / 270.0  # les attaques sont dessinées à la taille 270, les états à 320
ENEMY_ORIGIN = (865.0, 590.0)


def r1(v):
    return round(float(v), 1)


def r3(v):
    return round(float(v), 3)


def compact_clip(data, origin, scale, tex_index, tex_list):
    ox, oy = origin
    frames = []
    for frame in data["frames"]:
        out = []
        for c in frame:
            layer = c.get("layer", "effects")
            if layer == "preview_enemy":
                continue
            L = 0 if layer == "actor" else 1
            alpha = r3(c.get("alpha", 1.0))
            if alpha <= 0.003:
                continue
            t = c["type"]
            if t == "sprite":
                name = c["file"]
                if name not in tex_index:
                    tex_index[name] = len(tex_list)
                    tex_list.append(name)
                out.append([tex_index[name], r1((c["x"] - ox) * scale), r1((c["y"] - oy) * scale),
                            r1(c["w"] * scale), r1(c["h"] * scale), r3(c.get("angle", 0)), alpha,
                            1 if c.get("flipX") else 0, L])
            elif t == "line":
                out.append([-1, r1((c["x1"] - ox) * scale), r1((c["y1"] - oy) * scale),
                            r1((c["x2"] - ox) * scale), r1((c["y2"] - oy) * scale), c["color"],
                            r1(c["lw"] * scale), alpha, L])
            elif t == "ring":
                out.append([-2, r1((c["x"] - ox) * scale), r1((c["y"] - oy) * scale), r1(c["r"] * scale),
                            r3(c.get("ratio", 1.0)), c["color"], r1(c["lw"] * scale), alpha, L])
        frames.append(out)
    return frames


def convert_clip(path, origin, scale, sound_dir_prefix=""):
    data = json.load(open(path, encoding="utf-8"))
    tex_index, tex_list = {}, []
    frames = compact_clip(data, origin, scale, tex_index, tex_list)
    snd = [[r3(s["time"]), Path(s["file"]).stem + ".ogg"] for s in data.get("sound_cues", [])]
    cue = [[r3(v["time"]), v["name"]] for v in data.get("visual_cues", [])]
    return {"id": data["id"], "fps": data.get("fps", 24), "dur": data["duration"], "loop": bool(data.get("loop", False)),
            "tex": tex_list, "snd": snd, "cue": cue, "f": frames}, tex_list


def to_ogg(src, dst):
    if dst.exists():
        return
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src), "-c:a", "libvorbis", "-q:a", "3", str(dst)],
                   check=True)


def import_clip_pack(pack_dir, out_dir, origin_for, scale_for, used_textures):
    """Convertit tous les clips d'un pack. Renvoie la liste des clips (id, titre, durée)."""
    (out_dir / "clips").mkdir(parents=True, exist_ok=True)
    (out_dir / "tex").mkdir(parents=True, exist_ok=True)
    (out_dir / "audio").mkdir(parents=True, exist_ok=True)
    manifest = json.load(open(pack_dir / "manifest.json", encoding="utf-8"))
    listed = []
    for c in manifest["clips"]:
        cid = c["id"]
        src = pack_dir / c.get("file", "clips/%s.json" % cid)
        if not src.exists():
            continue  # le catalogue d'une partie peut citer les clips de l'autre partie
        clip, texs = convert_clip(src, origin_for(cid), scale_for(cid))
        used_textures.update(texs)
        json.dump(clip, open(out_dir / "clips" / (cid + ".json"), "w", encoding="utf-8"), separators=(",", ":"),
                  ensure_ascii=False)
        for s in clip["snd"]:
            wav = pack_dir / "audio" / (Path(s[1]).stem + ".wav")
            if wav.exists():
                to_ogg(wav, out_dir / "audio" / s[1])
        listed.append({"id": cid, "title": c.get("title", ""), "dur": c.get("duration", clip["dur"])})
    for name in used_textures:
        src = pack_dir / "assets" / name
        dst = out_dir / "tex" / name
        if src.exists() and not dst.exists():
            shutil.copy2(src, dst)
    return manifest, listed


def import_heroes():
    pack = SRC / "CREOS_Pack_Animations_Reliques_V2" / "CREOS_Animations_2D_V2"
    out = OUT / "anim" / "heroes"

    def origin(cid):
        return HERO_STATE_ORIGIN if not cid[-1].isdigit() else HERO_ATTACK_ORIGIN

    def scale(cid):
        return 1.0 if not cid[-1].isdigit() else HERO_ATTACK_SCALE

    used = set()
    manifest, listed = import_clip_pack(pack, out, origin, scale, used)
    # Portrait et fiche de chaque héros (le dessin complet).
    for f in (pack / "assets").glob("*_full.png"):
        shutil.copy2(f, out / "tex" / f.name)
    json.dump({"clips": listed}, open(out / "clips.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    # Reliques
    rel = OUT / "relics"
    rel.mkdir(parents=True, exist_ok=True)
    for f in (pack / "assets").glob("relic_*.png"):
        shutil.copy2(f, rel / f.name)
    shutil.copy2(pack / "relics" / "relics.json", rel / "relics_source.json")
    print("héros :", len(listed), "clips,", len(used), "textures")


def import_enemy_pack(pack_dir, region):
    out = OUT / "anim" / "enemies" / ("r%02d" % region)
    used = set()
    manifest, listed = import_clip_pack(pack_dir, out, lambda c: ENEMY_ORIGIN, lambda c: 1.0, used)
    enemies = manifest["enemies"]
    old = []
    if (out / "enemies.json").exists():
        old = json.load(open(out / "enemies.json", encoding="utf-8"))["enemies"]
    ids = {e["id"] for e in enemies}
    merged = [e for e in old if e["id"] not in ids] + enemies
    merged.sort(key=lambda e: (e.get("level", 0), e.get("boss", False)))
    json.dump({"region": region, "pack": manifest.get("pack", ""), "enemies": merged},
              open(out / "enemies.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("ennemis région", region, ":", len(enemies), "ennemis,", len(listed), "clips")


def import_enemies():
    r1_pack = SRC / "CREOS_Ennemis_Region1_Animes" / "CREOS_Ennemis_Acte1_Region1_V1"
    if r1_pack.exists():
        import_enemy_pack(r1_pack, 1)
    for region in range(2, 11):
        for part in (1, 2):
            base = SRC / ("CREOS_Monde%02d_Partie%d" % (region, part))
            inner = base / ("CREOS_Region%d_Partie%d" % (region, part))
            if (inner / "manifest.json").exists():
                import_enemy_pack(inner, region)
            else:
                print("MANQUANT : monde", region, "partie", part)


def import_decors():
    amb = SRC / "CREOS_Ambiances_Animees" / "CREOS_Ambiances_Animees"
    for world in range(1, 11):
        src = SRC / ("CREOS_Decors_Monde%02d" % world) / ("CREOS_Decors_Monde%02d" % world)
        if not src.exists():
            print("MANQUANT : décors monde", world)
            continue
        out = OUT / "decors" / ("monde%02d" % world)
        out.mkdir(parents=True, exist_ok=True)
        m = json.load(open(src / "manifest.json", encoding="utf-8"))
        for i in (1, 2, 3):
            dst = out / ("fond%d.jpg" % i)
            if not dst.exists():
                Image.open(src / "assets" / ("Fond%d.png" % i)).convert("RGB").save(dst, quality=90)
        for name, dst_name in (("Sol.png", "sol.png"), ("PremierPlan.png", "premier_plan.png")):
            dst = out / dst_name
            if not dst.exists():
                shutil.copy2(src / "assets" / name, dst)
        info = {"world": world, "name": m.get("world", ""), "foot_baseline": m.get("foot_baseline", 590),
                "safe_combat_rect": m.get("safe_combat_rect"), "foreground_offset": m.get("foreground_offset", 96),
                "scenes": [{"name": s["name"], "role": s["role"]} for s in m["scenes"]]}
        for i in (1, 2, 3):
            cfg = amb / "configs" / ("Monde%02d_%02d.json" % (world, i))
            if cfg.exists():
                shutil.copy2(cfg, out / ("ambiance%d.json" % i))
        json.dump(info, open(out / "decor.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("décors importés")


if __name__ == "__main__":
    what = sys.argv[2:] or ["heroes", "enemies", "decors"]
    if "heroes" in what:
        import_heroes()
    if "enemies" in what:
        import_enemies()
    if "decors" in what:
        import_decors()
