"""Génère data/heroes.json, data/monsters.json (ennemis de l'acte I), data/dungeons.json,
data/regions.json et data/relics.json à partir :
- de la fiche de combat (CREOS_Donnees_Combat.json : stats, techniques, voies, reliques, quatuors) ;
- des ennemis importés (assets/anim/enemies/rNN/enemies.json) ;
- des décors importés (assets/decors/mondeNN/decor.json) ;
- de la table ci-dessous, qui traduit chaque technique en effets du moteur de combat.

Les chiffres sont ceux de la fiche (propositions non testées). Durées : le moteur compte en
secondes ; « 2 tours » = T secondes, « 1 action » = A secondes.

  python tools/build_game_data.py [chemin/vers/CREOS_Donnees_Combat.json]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
SHEET = Path(sys.argv[1] if len(sys.argv) > 1 else
             "D:/dev/CREOS_sources/CREOS_Fiches_Combat_19_Heros/CREOS_Fiches_Combat_v1/CREOS_Donnees_Combat.json")

T = 4.0  # « 2 tours »
A = 2.0  # « 1 action »
CD = 6.0  # recharge d'une compétence (3 actions)


def dmg(power, stat="atk", **kw):
    return dict(type="damage", power=power, stat=stat, **kw)


def st(name, dur=T, **kw):
    return dict(type="status", name=name, duration=dur, **kw)


def heal(power, stat="mag", **kw):
    return dict(type="heal", power=power, stat=stat, **kw)


def shield(power, stat="def", **kw):
    return dict(type="shield", power=power, stat=stat, **kw)


def buff(stat, amount, dur=T, **kw):
    return dict(type="buff", stat=stat, amount=amount, duration=dur, **kw)


def debuff(stat, amount, dur=T, **kw):
    return dict(type="buff", stat=stat, amount=-amount, duration=dur, **kw)


def armor_break(**kw):
    return dict(type="buff", stat="def", amount=-0.2, duration=T, status="armure_reduite", **kw)


def dot(power, stat="mag", dur=T, name="brulure"):
    return dict(type="dot", power=power, stat=stat, duration=dur, name=name)


# id : élément, portée, type d'attaque, rareté, classe, [3 techniques : (cible, [effets])]
HEROES = {
    "corbin": ("ombre", "melee", "physical", 3, "lame", 0.10, [
        ("single_enemy", [dmg(1.0), st("marque")]),
        ("single_enemy", [st("aveugle"), buff("evade", 0.15, self_only=True)]),
        ("single_enemy", [dmg(0.4), dmg(0.4), dmg(0.4), dmg(0.4), armor_break(if_status="marque", consume=True)]),
    ]),
    "aegis": ("lumiere", "melee", "physical", 3, "gardien", 0.05, [
        ("single_enemy", [dmg(1.15)]),
        ("single_enemy", [dmg(1.1), st("desequilibre"), armor_break()]),
        ("all_enemies", [dmg(1.9), dict(type="stun", duration=A, if_status="desequilibre", consume=True)]),
    ]),
    "brume": ("eau", "ranged", "magic", 3, "arcaniste", 0.05, [
        ("single_enemy", [dmg(1.0, "mag"), st("mouille")]),
        ("lowest_hp_ally", [shield(1.1, "mag")]),
        ("all_enemies", [dmg(1.6, "mag"), st("mouille")]),
    ]),
    "orage": ("lumiere", "melee", "physical", 3, "moine", 0.08, [
        ("single_enemy", [dmg(0.35), dmg(0.35), dmg(0.35)]),
        ("all_allies", [heal(1.05, "atk")]),
        ("random_enemy", [dmg(0.25, bonus_if="mouille", bonus=0.5)] * 8 + [heal(1.2, "atk", target="all_allies")]),
    ]),
    "kharok": ("nature", "melee", "physical", 3, "gardien", 0.05, [
        ("single_enemy", [dmg(1.0), st("desequilibre")]),
        ("lowest_hp_ally", [shield(1.0), st("protege")]),
        ("all_enemies", [dmg(1.2, "def"), shield(1.0, target="all_allies")]),
    ]),
    "braise": ("feu", "ranged", "magic", 4, "arcaniste", 0.05, [
        ("single_enemy", [dmg(1.0, "mag"), dot(0.12)]),
        ("all_enemies", [dmg(0.9, "mag", bonus_if="brulure", bonus=0.2)]),
        ("all_enemies", [dmg(1.8, "mag", bonus_if="enracine", bonus=0.3, consume=True), dot(0.12)]),
    ]),
    "nacre": ("lumiere", "ranged", "magic", 4, "soutien", 0.05, [
        ("single_enemy", [dmg(0.9, "mag"), st("somnolence")]),
        ("lowest_hp_ally", [dict(type="cleanse"), dict(type="regen", power=0.3, stat="mag", duration=T)]),
        ("all_enemies", [dict(type="stun", duration=A, if_status="somnolence", consume=True, label="Endormi !"),
                         buff("crit", 0.2, target="all_allies")]),
    ]),
    "rivet": ("ombre", "ranged", "physical", 3, "traqueur", 0.15, [
        ("single_enemy", [dmg(1.0, bonus_if="marque", bonus=0.15)]),
        ("single_enemy", [dmg(1.2), armor_break()]),
        ("single_enemy", [dmg(1.4, bonus_if="marque", bonus=0.25, consume=True),
                          dmg(0.7, target="random_enemy"), dmg(0.7, target="random_enemy")]),
    ]),
    "sylve": ("nature", "melee", "physical", 4, "gardien", 0.05, [
        ("single_enemy", [dmg(0.9), st("enracine", A)]),
        ("all_allies", [dict(type="regen", power=0.04, stat="hp", duration=T), buff("res", 0.1)]),
        ("all_enemies", [st("enracine", A), buff("def", 0.2, target="all_allies")]),
    ]),
    "valen": ("lumiere", "melee", "physical", 3, "lancier", 0.08, [
        ("single_enemy", [dmg(1.05)]),
        ("two_enemies", [dmg(0.85), st("desequilibre")]),
        ("all_enemies", [dmg(1.7, bonus_if="armure_reduite", bonus=0.25)]),
    ]),
    "bastion": ("lumiere", "melee", "physical", 3, "gardien", 0.05, [
        ("single_enemy", [dmg(1.0)]),
        ("self", [dict(type="taunt", duration=3.0), buff("def", 0.25)]),
        ("all_allies", [shield(1.6)]),
    ]),
    "saffran": ("feu", "ranged", "magic", 4, "illusionniste", 0.08, [
        ("single_enemy", [dmg(0.95, "mag"), st("scelle")]),
        ("lowest_hp_ally", [st("leurre")]),
        ("all_enemies", [dmg(1.4, "mag", bonus_if="scelle", bonus=0.4), st("aveugle", if_status="scelle", consume=True)]),
    ]),
    "oona": ("eau", "ranged", "magic", 4, "soutien", 0.05, [
        ("single_enemy", [dmg(0.9, "mag"), st("aveugle")]),
        ("lowest_hp_ally", [heal(1.8), dict(type="cleanse")]),
        ("all_enemies", [st("enracine", A), heal(1.2, target="all_allies")]),
    ]),
    "calx": ("feu", "ranged", "magic", 4, "automate", 0.05, [
        ("single_enemy", [dmg(1.0, "mag"), st("resonance")]),
        ("lowest_hp_ally", [dict(type="cleanse"), st("alarme")]),
        ("all_enemies", [dmg(1.5, "mag"), dict(type="gauge", amount=-0.1, bonus_if="resonance", consume=True)]),
    ]),
    "nyx": ("ombre", "melee", "physical", 4, "lame", 0.12, [
        ("single_enemy", [dmg(1.0), dict(type="lifesteal", ratio=0.2)]),
        ("self", [buff("evade", 0.15), buff("crit", 0.2)]),
        ("single_enemy", [dmg(0.5), dmg(0.5), dmg(0.5), dmg(0.5), dict(type="lifesteal", ratio=0.2)]),
    ]),
    "mei_lian": ("nature", "melee", "physical", 5, "lame", 0.10, [
        ("single_enemy", [dmg(1.0), st("petale")]),
        ("self", [buff("evade", 0.2, A)]),
        ("all_enemies", [armor_break(if_status="petale")] + [dmg(0.3)] * 6),
    ]),
    "jin_seok": ("lumiere", "melee", "physical", 5, "moine", 0.05, [
        ("single_enemy", [dmg(1.0), st("desequilibre")]),
        ("lowest_hp_ally", [shield(1.5)]),
        ("random_enemy", [dmg(0.35)] * 5 + [dict(type="stun", duration=A, if_status="desequilibre", consume=True,
                                                 target="all_enemies")]),
    ]),
    "yun_tao": ("eau", "melee", "physical", 5, "moine", 0.05, [
        ("single_enemy", [dmg(1.0), st("ouverture")]),
        ("lowest_hp_ally", [st("garde")]),
        ("all_enemies", [dmg(1.4), dict(type="gauge", amount=-0.15)]),
    ]),
    "tang_su": ("ombre", "ranged", "physical", 5, "traqueur", 0.10, [
        ("single_enemy", [dmg(0.9), dot(0.12, "atk", name="poison")]),
        ("single_enemy", [dmg(1.0), debuff("atk", 0.15, if_status="poison")]),
        ("all_enemies", [dmg(1.5), dot(0.12, "atk", name="poison"), armor_break(if_status="ouverture", consume=True)]),
    ]),
}

SHORT = {"mei_lian": "Mei Lian", "jin_seok": "Jin Seok", "yun_tao": "Yun Tao", "tang_su": "Tang Su"}
QUARTET_ORDER = ["murim", "elements", "rempart", "ombres"]
# Contribution de chaque membre à l'attaque combinée : [puissance, statistique] (fiche de combat).
QUARTET_CONTRIB = {
    "murim": {"mei_lian": [1.6, "atk"], "jin_seok": [1.6, "atk"], "yun_tao": [1.6, "atk"], "tang_su": [1.6, "atk"]},
    "elements": {"brume": [1.5, "mag"], "orage": [1.5, "atk"], "braise": [1.5, "mag"], "sylve": [1.0, "atk"]},
    "rempart": {"bastion": [1.0, "def"], "kharok": [1.2, "def"], "aegis": [1.8, "atk"], "valen": [1.6, "atk"]},
    "ombres": {"corbin": [1.4, "atk"], "rivet": [1.4, "atk"], "saffran": [1.4, "mag"], "nyx": [1.4, "atk"]},
}
RELIC_ORDER = ["corbin", "aegis", "brume", "orage", "kharok", "braise", "nacre", "rivet", "sylve", "valen",
               "bastion", "saffran", "oona", "calx", "nyx", "mei_lian", "jin_seok", "yun_tao", "tang_su"]
REGION_ELEMENTS = {1: "eau", 2: "nature", 3: "nature", 4: "feu", 5: "", 6: "ombre", 7: "ombre", 8: "feu", 9: "feu",
                   10: "ombre"}


def clip_cues(bundle, clip_id):
    path = ROOT / "assets" / "anim" / bundle / "clips" / (clip_id + ".json")
    c = json.load(open(path, encoding="utf-8"))
    return c["dur"], [q[0] for q in c["cue"]]


def hit_times(bundle, clip_id, hits):
    dur, cues = clip_cues(bundle, clip_id)
    if not cues:
        cues = [round(dur * 0.55, 3)]
    if hits <= 1:
        return [cues[0]]
    if len(cues) >= hits:
        return cues[:hits]
    # Moins de repères que de coups : on étale les coups restants après le dernier repère.
    out = list(cues)
    step = 0.16
    while len(out) < hits:
        out.append(round(min(dur - 0.05, out[-1] + step), 3))
    return out


def build_heroes(sheet):
    out = {}
    by_id = {h["id"]: h for h in sheet["heroes"]}
    for hid, (elem, rng, kind, rarity, cls, crit, techs) in HEROES.items():
        h = by_id[hid]
        s = h["base_stats"]
        attacks = []
        for slot, (target, effects) in enumerate(techs):
            src = h["attacks"][slot]
            clip = "%s_%d" % (hid, slot)
            hits = sum(1 for e in effects if e["type"] == "damage") or 1
            a = {
                "id": "%s_%d" % (hid, slot), "name": src["name"], "description": src["effect"],
                "visual": src.get("visual", ""), "clip": clip, "target": target, "effects": effects,
                "hit_times": hit_times("heroes", clip, hits),
            }
            if slot == 1:
                a["cooldown"] = CD
            if slot == 2:
                a["energy"] = 100
            attacks.append(a)
        secrets = []
        for i, p in enumerate(h["paths"]):
            st6 = p["stages"].get("6", "")
            secrets.append({"name": st6.split(" :")[0] if " :" in st6 else p["name"], "clip": "%s_%d" % (hid, 3 + i)})
        out[hid] = {
            "name": h["name"], "short": SHORT.get(hid, h["name"]), "species": h["species"], "role": h["role"],
            "class": cls, "element": elem, "family": "chasseurs", "rarity": rarity, "range": rng,
            "attack_kind": kind, "primary": h["primary"], "secondary": h["secondary"],
            "description": "%s. %s." % (h["species"], h["role"]),
            "anim": "res://assets/anim/heroes/", "portrait": "res://assets/anim/heroes/portraits/%s.png" % hid,
            "fiche": "res://assets/anim/heroes/fiches/%s.png" % hid,
            "quartet": h.get("quartet") or "",
            "stats": {"hp": s["PV"], "atk": s["ATQ"], "mag": s["MAG"], "def": s["DEF"], "res": s["DEF"],
                      "spd": s["VIT"], "crit": crit},
            "attacks": attacks,
            "paths": [{"name": p["name"], "focus": p["focus"], "stages": p["stages"],
                       "conclusion": p.get("quartet_conclusion", {}).get("effect", "")} for p in h["paths"]],
            "secret_techniques": secrets,
            "ultimate_visual": h.get("ultimate_visual", ""),
        }
    return out


def build_relics(sheet):
    out = {}
    for h in sheet["heroes"]:
        r = h["relic"]
        out[h["id"]] = {
            "name": r["name"], "hero": h["id"], "dungeon": r["dungeon"], "material": r["material"],
            "trial": r["trial"], "awakening": r["awakening"], "accord": r["accord"], "contribution": r["contribution"],
            "icon": "res://assets/relics/relic_%s_icon.png" % h["id"],
            "sprite": "res://assets/relics/relic_%s.png" % h["id"],
            "clip": "%s_relic" % h["id"],
        }
    return {"tiers": [
        {"name": "Retrouvée", "primary": 0.05, "secondary": 0.02, "fragments": 100, "materials": 0},
        {"name": "Restaurée", "primary": 0.10, "secondary": 0.04, "fragments": 10, "materials": 20},
        {"name": "Éveillée", "primary": 0.15, "secondary": 0.06, "fragments": 20, "materials": 40},
        {"name": "Accordée", "primary": 0.20, "secondary": 0.08, "fragments": 30, "materials": 70},
        {"name": "Héritage", "primary": 0.25, "secondary": 0.10, "fragments": 40, "materials": 100},
    ], "relics": out}


def build_quartets(sheet):
    out = {}
    for i, qid in enumerate(QUARTET_ORDER):
        q = next(x for x in sheet["quartets"] if x["id"] == qid)
        out[qid] = {"name": q["name"], "members": q["members"], "attack": q["attack"], "effect": q["effect"],
                    "bonus": q["bonus"], "resonance": q["resonance"], "visual": q["visual"],
                    "clip": "quatuor_%d" % i, "contributions": QUARTET_CONTRIB[qid],
                    "hit_times": clip_cues("heroes", "quatuor_%d" % i)[1][:4]}
    return out


def enemy_stats(g, boss, regional):
    """Stats d'un ennemi selon sa place dans la campagne (g = 0..79)."""
    m = 1.0 + 0.09 * g
    hp, atk, de = 430 * m, 52 * m, 28 + 1.2 * g
    if boss:
        hp, atk, de = hp * 2.4, atk * 1.25, de * 1.2
    if regional:
        hp, atk = hp * 1.5, atk * 1.1
    return {"hp": round(hp), "atk": round(atk), "mag": round(atk), "def": round(de), "res": round(de),
            "spd": 92 + (g % 8) * 2 + (6 if boss else 0), "crit": 0.05}


def build_campaign():
    monsters, dungeons, regions = {}, {}, {}
    for region in range(1, 11):
        d_info = json.load(open(ROOT / "assets" / "decors" / ("monde%02d" % region) / "decor.json", encoding="utf-8"))
        rid = "monde%02d" % region
        regions[rid] = {"name": d_info["name"], "order": region, "element": REGION_ELEMENTS[region] or None,
                        "decor": "res://assets/decors/%s/" % rid, "scenes": [s["name"] for s in d_info["scenes"]]}
        path = ROOT / "assets" / "anim" / "enemies" / ("r%02d" % region) / "enemies.json"
        enemies = json.load(open(path, encoding="utf-8"))["enemies"]
        by_level = {}
        for e in enemies:
            lvl = int(e["level"])
            g = (region - 1) * 8 + lvl - 1
            regional = bool(e.get("regional_boss")) or (e["boss"] and lvl == 8)
            style = e.get("attack_style", "")
            ranged = style in ("ranged", "cast") or e.get("kind") in ("bird", "specter")
            mon = {
                "name": e["name"], "element": REGION_ELEMENTS[region], "family": e.get("kind", ""),
                "range": "ranged" if ranged else "melee", "attack_kind": "magic" if style == "cast" or e.get("kind") == "specter" else "physical",
                "boss": bool(e["boss"]), "regional_boss": regional, "size": e.get("size", 160),
                "anim": "res://assets/anim/enemies/r%02d/" % region, "drop": e.get("drop", ""),
                "stats": enemy_stats(g, e["boss"], regional),
                "attacks": [{"id": e["id"] + "_attack", "name": "Attaque", "clip": e["id"] + "_attack",
                             "hit_times": hit_times("enemies/r%02d" % region, e["id"] + "_attack", 1)}],
            }
            if e["boss"]:
                mon["attacks"].append({
                    "id": e["id"] + "_skill", "name": e.get("skill", "Compétence"), "clip": e["id"] + "_skill",
                    "cooldown": 9.0, "target": "all_enemies", "effects": [{"type": "damage", "power": 0.8}],
                    "hit_times": hit_times("enemies/r%02d" % region, e["id"] + "_skill", 1)})
            monsters[e["id"]] = mon
            by_level.setdefault(lvl, {})["boss" if e["boss"] else "normal"] = e["id"]
        for lvl in range(1, 9):
            pair = by_level.get(lvl)
            if not pair or "normal" not in pair or "boss" not in pair:
                continue
            n, b = pair["normal"], pair["boss"]
            prev = by_level.get(lvl - 1, {}).get("normal", n)
            g = (region - 1) * 8 + lvl - 1
            scene = 1 if lvl <= 3 else (2 if lvl <= 7 else 3)
            dungeons["%s_%d" % (rid, lvl)] = {
                "name": "%s — %d" % (d_info["name"], lvl), "region": rid, "level": lvl, "decor_scene": scene,
                "waves": [[n, n, prev], [n, prev, n], [n, b, n]],
                "rewards": {"gold": 120 + 15 * g, "xp": 60 + 8 * g, "essence_ombre": 1 + g // 10,
                            monsters[n]["drop"] or "fragments_relique": 2,
                            # Chaque niveau garde la relique d'un héros : 3 fragments garantis par victoire.
                            "relique_" + RELIC_ORDER[g % len(RELIC_ORDER)]: 3, "materiaux_relique": 5},
                "energy_cost": 4 + region // 2,
            }
    return monsters, dungeons, regions


def main():
    sheet = json.load(open(SHEET, encoding="utf-8"))
    heroes = build_heroes(sheet)
    json.dump(heroes, open(DATA / "heroes.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    relics = build_relics(sheet)
    relics["quartets"] = build_quartets(sheet)
    relics["echoes"] = {"thresholds": sheet["echo_thresholds"], "stats": sheet["echo_stats"]}
    json.dump(relics, open(DATA / "relics.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    monsters, dungeons, regions = build_campaign()
    json.dump(monsters, open(DATA / "monsters.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(dungeons, open(DATA / "dungeons.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(regions, open(DATA / "regions.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(heroes), "héros,", len(monsters), "ennemis,", len(dungeons), "niveaux,", len(regions), "mondes")


if __name__ == "__main__":
    main()
