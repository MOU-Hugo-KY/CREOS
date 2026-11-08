"""Exporte les planches pixelfx des monstres : résout les règles de data/pixelfx_monsters.json pour chaque
attaque de data/monsters.json (même logique que PixelFx.monster_entry), écrit la liste dans un fichier
temporaire et appelle tools/export_pixelfx.mjs dessus.

    python tools/pixelfx_monsters_export.py [chemin_de_pixelfx]
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def resolve(rules: dict, m: dict, attack_id: str) -> dict:
    if attack_id in rules.get("ids", {}):
        return rules["ids"][attack_id]
    el = m.get("element", "")
    if attack_id.endswith("_skill") and m.get("boss"):
        e = rules.get("regional_skill" if m.get("regional_boss") else "skill", {}).get(el, {})
    elif m.get("attack_kind") == "magic":
        e = rules.get("magic", {}).get(el, {})
    elif m.get("range") == "ranged":
        e = rules.get("ranged", {})
    else:
        fam = rules.get("families", {})
        e = fam.get(m.get("family", ""), fam.get("_default", {}))
    e = dict(e)
    pal = rules.get("elements", {}).get(el, {}).get("pal", "none")
    if e and "pal" not in e and pal != "none":
        e["pal"] = pal
    return e


def main() -> None:
    rules = json.load(open(os.path.join(ROOT, "data/pixelfx_monsters.json"), encoding="utf8"))
    monsters = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf8"))
    out = {}
    for mid, m in monsters.items():
        for a in m.get("attacks", []):
            e = resolve(rules, m, a["id"])
            if e:
                out[a["id"]] = e
    tmp = "data/_pixelfx_monsters_resolved.json"
    with open(os.path.join(ROOT, tmp), "w", encoding="utf8") as f:
        json.dump({"attacks": out}, f)
    print(f"{len(out)} attaques de monstres ont un effet")
    try:
        subprocess.run(["node", "tools/export_pixelfx.mjs", "--data=" + tmp, *sys.argv[1:]], cwd=ROOT, check=True)
    finally:
        os.remove(os.path.join(ROOT, tmp))


if __name__ == "__main__":
    main()
