"""Écrit data/hero_progression.json : la progression propre à chaque héros.

- growth : gain par niveau de chaque statistique (multiplicatif ; « crit » = points ajoutés par niveau).
- relic  : 5 paliers ; chacun donne des statistiques (multiplicatives, « crit » ajouté) et, aux
           paliers III à V, des effets de gameplay (« mods ») appliqués à ses attaques :
    power       {slot, mult}            : +x % de puissance (dégâts, soins, boucliers, brûlure…)
    extra_hits  {slot, count, power}    : coups en plus à la fin de l'attaque
    cooldown    {slot, seconds}         : recharge plus courte
    add_effect  {slot, effect}          : effet en plus (état, bouclier, provocation…)

Lancer : python tools/build_hero_progression.py
"""
import json

D = {"hp": 0.05, "atk": 0.04, "mag": 0.04, "def": 0.03, "res": 0.03, "spd": 0.0, "crit": 0.0}

GROWTH = {
    "corbin": {"atk": 0.046, "hp": 0.045, "def": 0.025, "spd": 0.0025, "crit": 0.0012},
    "aegis": {"atk": 0.044, "def": 0.036, "hp": 0.052, "spd": 0.001, "crit": 0.0006},
    "brume": {"mag": 0.047, "hp": 0.048, "res": 0.036, "spd": 0.0015, "heal": 0.003},
    "orage": {"atk": 0.042, "hp": 0.05, "spd": 0.002, "crit": 0.0008, "heal": 0.003},
    "kharok": {"def": 0.042, "hp": 0.056, "res": 0.036, "atk": 0.03},
    "braise": {"mag": 0.048, "atk": 0.03, "hp": 0.045, "crit": 0.0008},
    "nacre": {"hp": 0.055, "mag": 0.042, "res": 0.035, "spd": 0.002, "heal": 0.006},
    "rivet": {"atk": 0.045, "hp": 0.043, "spd": 0.002, "crit": 0.0016},
    "sylve": {"hp": 0.06, "def": 0.036, "res": 0.036, "mag": 0.035, "heal": 0.004},
    "valen": {"atk": 0.045, "def": 0.033, "spd": 0.0015, "crit": 0.0008},
    "bastion": {"def": 0.045, "hp": 0.06, "res": 0.035, "atk": 0.028, "heal": 0.003},
    "saffran": {"mag": 0.046, "hp": 0.044, "spd": 0.0025, "crit": 0.0008},
    "oona": {"mag": 0.045, "hp": 0.052, "res": 0.035, "heal": 0.007},
    "calx": {"mag": 0.042, "def": 0.038, "hp": 0.052},
    "nyx": {"atk": 0.045, "hp": 0.042, "spd": 0.003, "crit": 0.0014},
    "mei_lian": {"atk": 0.045, "hp": 0.044, "spd": 0.0025, "crit": 0.0012},
    "jin_seok": {"def": 0.04, "hp": 0.055, "atk": 0.036},
    "yun_tao": {"def": 0.036, "atk": 0.04, "hp": 0.05, "spd": 0.002},
    "tang_su": {"atk": 0.044, "mag": 0.035, "spd": 0.0025, "crit": 0.0012},
}

# Statistiques des 5 paliers de relique (I à V), propres à chaque héros.
def tiers(a, b):
    """a, b : deux statistiques principales du héros ; les paliers montent jusqu'à +25 % / +12 %."""
    steps = [(0.05, 0.02), (0.10, 0.05), (0.15, 0.07), (0.20, 0.10), (0.25, 0.12)]
    out = []
    for p, s in steps:
        d = {}
        for key, v in ((a, p), (b, s)):
            d[key] = round(v / 5.0, 3) if key == "crit" else round(v, 3) if key == "heal" else (round(v / 2.0, 3) if key == "spd" else v)
        out.append(d)
    return out

RELIC_STATS = {
    "corbin": ("atk", "crit"), "aegis": ("atk", "def"), "brume": ("mag", "hp"), "orage": ("atk", "spd"),
    "kharok": ("def", "hp"), "braise": ("mag", "crit"), "nacre": ("heal", "hp"), "rivet": ("atk", "crit"),
    "sylve": ("hp", "def"), "valen": ("atk", "def"), "bastion": ("def", "hp"), "saffran": ("mag", "spd"),
    "oona": ("heal", "mag"), "calx": ("mag", "def"), "nyx": ("crit", "spd"), "mei_lian": ("atk", "spd"),
    "jin_seok": ("def", "atk"), "yun_tao": ("def", "spd"), "tang_su": ("atk", "crit"),
}

def P(slot, mult, text):
    return {"type": "power", "slot": slot, "mult": mult, "text": text}

def H(slot, count, power, text):
    return {"type": "extra_hits", "slot": slot, "count": count, "power": power, "text": text}

def C(slot, seconds, text):
    return {"type": "cooldown", "slot": slot, "seconds": seconds, "text": text}

def E(slot, effect, text):
    return {"type": "add_effect", "slot": slot, "effect": effect, "text": text}

# Effets de gameplay des paliers III, IV et V.
MODS = {
    "corbin": [P(0, 0.2, "Lame du corbeau : +20 % de dégâts."),
               H(2, 1, 0.4, "Banquet des corbeaux : un 5e coup."),
               E(2, {"type": "status", "name": "armure_reduite", "duration": 4.0}, "Banquet des corbeaux : Armure réduite.")],
    "aegis": [P(2, 0.15, "Ultime : +15 % de dégâts."),
              C(1, 1.5, "Technique : recharge -1,5 s."),
              E(0, {"type": "status", "name": "desequilibre", "duration": 4.0}, "Attaque de base : Déséquilibre.")],
    "brume": [P(2, 0.15, "Ultime : +15 % de dégâts."),
              P(1, 0.25, "Bouclier d'eau : +25 %."),
              C(1, 1.5, "Bouclier d'eau : recharge -1,5 s.")],
    "orage": [H(0, 1, 0.35, "Trois poings : un 4e poing."),
              H(2, 2, 0.25, "Ultime : 2 éclairs de plus."),
              P(1, 0.25, "Soin collectif : +25 %.")],
    "kharok": [P(1, 0.25, "Carapace partagée : bouclier +25 %."),
               P(2, 0.2, "Carapace royale : +20 %."),
               C(1, 1.5, "Carapace partagée : recharge -1,5 s.")],
    "braise": [P(0, 0.5, "Brûlure de base : +50 %."),
               P(1, 0.2, "Technique : +20 % de dégâts."),
               E(1, {"type": "dot", "name": "brulure", "power": 0.1, "duration": 4.0}, "Technique : brûle aussi.")],
    "nacre": [P(1, 0.3, "Régénération : +30 %."),
              C(1, 1.5, "Régénération : recharge -1,5 s."),
              P(0, 0.3, "Attaque de base : +30 % de dégâts.")],
    "rivet": [H(2, 1, 0.7, "Casse du siècle : un ricochet de plus."),
              P(1, 0.2, "Tir de contrebande : +20 %."),
              E(0, {"type": "status", "name": "marque", "duration": 4.0}, "Attaque de base : Marque.")],
    "sylve": [P(1, 0.3, "Régénération : +30 %."),
              C(1, 1.5, "Régénération : recharge -1,5 s."),
              E(2, {"type": "shield", "power": 0.6, "stat": "def", "target": "all_allies"}, "Ultime : bouclier sur toute l'équipe.")],
    "valen": [P(2, 0.15, "Ultime : +15 % de dégâts."),
              E(2, {"type": "status", "name": "desequilibre", "duration": 4.0}, "Ultime : Déséquilibre sur tous."),
              C(1, 1.5, "Balayage : recharge -1,5 s.")],
    "bastion": [P(2, 0.2, "Mur collectif : bouclier +20 %."),
                C(1, 1.5, "Provocation : recharge -1,5 s."),
                E(0, {"type": "taunt", "self_only": True, "duration": 3.0}, "Attaque de base : provoque.")],
    "saffran": [P(2, 0.15, "Ultime : +15 % de dégâts."),
                C(1, 1.5, "Leurre : recharge -1,5 s."),
                H(0, 1, 0.4, "Trait trompeur : un second trait.")],
    "oona": [P(1, 0.25, "Élixir : +25 % de soin."),
             C(1, 1.5, "Élixir : recharge -1,5 s."),
             P(2, 0.3, "Ultime : soin collectif +30 %.")],
    "calx": [P(2, 0.15, "Ultime : +15 % de dégâts."),
             C(1, 1.5, "Alarme : recharge -1,5 s."),
             E(0, {"type": "gauge", "amount": -0.05}, "Attaque de base : retarde la cible.")],
    "nyx": [H(2, 1, 0.5, "Ultime : une 5e morsure."),
            P(0, 0.15, "Attaque de base : +15 % de dégâts."),
            H(2, 1, 0.5, "Ultime : une 6e morsure.")],
    "mei_lian": [H(2, 1, 0.3, "Les 24 mouvements : un 7e coup."),
                 H(2, 1, 0.3, "Les 24 mouvements : un 8e coup."),
                 H(2, 2, 0.3, "Les 24 mouvements : 2 coups de plus (10).")],
    "jin_seok": [H(2, 1, 0.35, "Cent paumes : une paume de plus."),
                 P(1, 0.25, "Cloche d'or : bouclier +25 %."),
                 H(2, 2, 0.35, "Cent paumes : 2 paumes de plus.")],
    "yun_tao": [P(2, 0.15, "Ultime : +15 % de dégâts."),
                C(1, 1.5, "Cercle du Taiji : recharge -1,5 s."),
                E(0, {"type": "status", "name": "desequilibre", "duration": 4.0}, "Attaque de base : Déséquilibre.")],
    "tang_su": [P(0, 0.5, "Poison de base : +50 %."),
                H(2, 1, 0.5, "Pluie d'aiguilles : une vague de plus."),
                E(1, {"type": "dot", "name": "poison", "power": 0.12, "duration": 4.0}, "Méridiens fermés : empoisonne.")],
}

out = {"_note": "Généré par tools/build_hero_progression.py : progression propre à chaque héros.", "heroes": {}}
for hero in GROWTH:
    g = dict(D)
    g.update(GROWTH[hero])
    stats = tiers(*RELIC_STATS[hero])
    relic = []
    for i in range(5):
        relic.append({"stats": stats[i], "mods": [MODS[hero][i - 2]] if i >= 2 else []})
    out["heroes"][hero] = {"growth": g, "relic": relic}
json.dump(out, open("data/hero_progression.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print(len(out["heroes"]), "héros")
