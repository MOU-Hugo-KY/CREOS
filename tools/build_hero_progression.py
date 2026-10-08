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

def B(slot, stat, amount, text):  # bonus temporaire sur soi
    return E(slot, {"type": "buff", "stat": stat, "amount": amount, "duration": 4.0, "self_only": True}, text)

def SH(slot, power, stat, text, target=None, self_only=False):
    e = {"type": "shield", "power": power, "stat": stat}
    if target:
        e["target"] = target
    if self_only:
        e["self_only"] = True
    return E(slot, e, text)

def HE(slot, power, stat, text, target):
    return E(slot, {"type": "heal", "power": power, "stat": stat, "target": target}, text)

# Paliers I et II : un premier bonus propre au rôle du héros.
FIRST = {
    "corbin": [C(1, 1.0, "Fumée noire : recharge -1 s."), B(0, "crit", 0.1, "Lame du corbeau : +10 pts de critique 4 s.")],
    "aegis": [P(0, 0.1, "Coup de base : +10 % de dégâts."), SH(1, 0.5, "def", "Technique : se couvre d'un bouclier.", self_only=True)],
    "brume": [P(0, 0.1, "Attaque de base : +10 % de dégâts."), SH(0, 0.3, "mag", "Attaque de base : petit bouclier sur l'allié le plus blessé.", "lowest_hp_ally")],
    "orage": [P(0, 0.1, "Trois poings : +10 % de dégâts."), HE(0, 0.3, "atk", "Trois poings : se soigne un peu.", "self")],
    "kharok": [SH(0, 0.3, "def", "Percée de garde : petit bouclier sur lui.", self_only=True),
               E(2, {"type": "status", "name": "desequilibre", "duration": 4.0}, "Carapace royale : Déséquilibre.")],
    "braise": [P(2, 0.1, "Ultime : +10 % de dégâts."), B(0, "mag", 0.1, "Attaque de base : +10 % de magie 4 s.")],
    "nacre": [P(1, 0.15, "Régénération : +15 %."), HE(0, 0.4, "mag", "Attaque de base : soigne l'allié le plus blessé.", "lowest_hp_ally")],
    "rivet": [P(0, 0.1, "Carreau sournois : +10 % de dégâts."), B(0, "crit", 0.1, "Attaque de base : +10 pts de critique 4 s.")],
    "sylve": [E(0, {"type": "taunt", "self_only": True, "duration": 2.0}, "Attaque de base : provoque 2 s."),
              HE(1, 0.4, "mag", "Régénération : un soin immédiat en plus.", "all_allies")],
    "valen": [P(0, 0.1, "Pointe de garde : +10 % de dégâts."), P(1, 0.15, "Balayage : +15 % de dégâts.")],
    "bastion": [SH(1, 0.6, "def", "Provocation : bouclier sur lui.", self_only=True), P(0, 0.15, "Attaque de base : +15 % de dégâts.")],
    "saffran": [P(0, 0.1, "Trait trompeur : +10 % de dégâts."),
                E(1, {"type": "buff", "stat": "res", "amount": 0.15, "duration": 4.0}, "Leurre : +15 % de résistance à l'allié.")],
    "oona": [P(0, 0.15, "Jet d'encre : +15 % de dégâts."), HE(0, 0.4, "mag", "Jet d'encre : soigne l'allié le plus blessé.", "lowest_hp_ally")],
    "calx": [P(0, 0.1, "Attaque de base : +10 % de dégâts."), SH(1, 0.5, "mag", "Alarme : bouclier sur l'allié.")],
    "nyx": [P(0, 0.1, "Morsure : +10 % de dégâts."), B(1, "atk", 0.15, "Technique : +15 % d'attaque 4 s.")],
    "mei_lian": [P(2, 0.1, "Les 24 mouvements : +10 % de dégâts."), C(1, 1.0, "Pas du prunier : recharge -1 s.")],
    "jin_seok": [SH(0, 0.3, "def", "Poing de bronze : petit bouclier sur lui.", self_only=True), C(1, 1.0, "Cloche d'or : recharge -1 s.")],
    "yun_tao": [P(0, 0.1, "Fil du courant : +10 % de dégâts."), SH(1, 0.4, "def", "Cercle du Taiji : bouclier sur l'allié.")],
    "tang_su": [P(1, 0.15, "Méridiens fermés : +15 % de dégâts."), B(0, "crit", 0.1, "Aiguille silencieuse : +10 pts de critique 4 s.")],
}

# Échos (1, 3, 6, 9, 12 doublons) : en plus des statistiques, un bonus de compétence par palier.
ECHOES = {
    "corbin": [P(0, 0.08, "Lame du corbeau : +8 %."), B(1, "crit", 0.08, "Fumée noire : +8 pts de critique 4 s."),
               P(2, 0.1, "Banquet des corbeaux : +10 %."), C(1, 1.0, "Fumée noire : recharge -1 s."),
               H(2, 1, 0.4, "Banquet des corbeaux : un coup de plus.")],
    "aegis": [P(0, 0.08, "Coup de base : +8 %."), SH(1, 0.3, "def", "Technique : bouclier sur lui.", self_only=True),
              P(2, 0.1, "Ultime : +10 %."), C(1, 1.0, "Technique : recharge -1 s."),
              E(2, {"type": "status", "name": "armure_reduite", "duration": 4.0}, "Ultime : Armure réduite.")],
    "brume": [P(0, 0.08, "Attaque de base : +8 %."), P(1, 0.15, "Bouclier d'eau : +15 %."),
              P(2, 0.1, "Ultime : +10 %."), C(1, 1.0, "Bouclier d'eau : recharge -1 s."),
              SH(2, 0.4, "mag", "Ultime : bouclier sur toute l'équipe.", "all_allies")],
    "orage": [P(0, 0.08, "Trois poings : +8 %."), P(1, 0.15, "Soin collectif : +15 %."),
              H(2, 1, 0.25, "Ultime : un éclair de plus."), C(1, 1.0, "Soin collectif : recharge -1 s."),
              H(0, 1, 0.35, "Trois poings : un poing de plus.")],
    "kharok": [SH(0, 0.2, "def", "Percée de garde : petit bouclier.", self_only=True), P(1, 0.15, "Carapace partagée : +15 %."),
               P(2, 0.1, "Carapace royale : +10 %."), C(1, 1.0, "Carapace partagée : recharge -1 s."),
               E(0, {"type": "taunt", "self_only": True, "duration": 2.0}, "Percée de garde : provoque 2 s.")],
    "braise": [P(0, 0.08, "Attaque de base : +8 %."), P(1, 0.1, "Technique : +10 %."),
               P(2, 0.1, "Ultime : +10 %."), C(1, 1.0, "Technique : recharge -1 s."),
               E(2, {"type": "dot", "name": "brulure", "power": 0.15, "duration": 4.0}, "Ultime : brûlure renforcée.")],
    "nacre": [P(1, 0.1, "Régénération : +10 %."), HE(0, 0.25, "mag", "Attaque de base : soigne un allié.", "lowest_hp_ally"),
              C(1, 1.0, "Régénération : recharge -1 s."), P(1, 0.15, "Régénération : +15 %."),
              HE(2, 0.5, "mag", "Ultime : soigne toute l'équipe.", "all_allies")],
    "rivet": [P(0, 0.08, "Carreau sournois : +8 %."), B(0, "crit", 0.06, "Attaque de base : +6 pts de critique 4 s."),
              P(2, 0.1, "Casse du siècle : +10 %."), C(1, 1.0, "Tir de contrebande : recharge -1 s."),
              H(2, 1, 0.7, "Casse du siècle : un ricochet de plus.")],
    "sylve": [P(1, 0.1, "Régénération : +10 %."), SH(0, 0.25, "def", "Attaque de base : bouclier sur elle.", self_only=True),
              C(1, 1.0, "Régénération : recharge -1 s."), HE(1, 0.3, "mag", "Régénération : soin immédiat.", "all_allies"),
              E(0, {"type": "taunt", "self_only": True, "duration": 2.0}, "Attaque de base : provoque 2 s.")],
    "valen": [P(0, 0.08, "Pointe de garde : +8 %."), P(1, 0.1, "Balayage : +10 %."),
              P(2, 0.1, "Ultime : +10 %."), C(1, 1.0, "Balayage : recharge -1 s."),
              E(2, {"type": "status", "name": "armure_reduite", "duration": 4.0}, "Ultime : Armure réduite.")],
    "bastion": [P(2, 0.1, "Mur collectif : +10 %."), SH(1, 0.3, "def", "Provocation : bouclier sur lui.", self_only=True),
                C(1, 1.0, "Provocation : recharge -1 s."), P(2, 0.15, "Mur collectif : +15 %."),
                E(0, {"type": "status", "name": "desequilibre", "duration": 4.0}, "Attaque de base : Déséquilibre.")],
    "saffran": [P(0, 0.08, "Trait trompeur : +8 %."), C(1, 0.5, "Leurre : recharge -0,5 s."),
                P(2, 0.1, "Ultime : +10 %."), C(1, 1.0, "Leurre : recharge -1 s."),
                E(2, {"type": "status", "name": "scelle", "duration": 4.0}, "Ultime : Scellé sur tous.")],
    "oona": [P(1, 0.1, "Élixir : +10 %."), HE(0, 0.25, "mag", "Jet d'encre : soigne un allié.", "lowest_hp_ally"),
             C(1, 1.0, "Élixir : recharge -1 s."), P(2, 0.15, "Ultime : soin +15 %."),
             SH(1, 0.5, "mag", "Élixir : bouclier en plus.")],
    "calx": [P(0, 0.08, "Attaque de base : +8 %."), SH(1, 0.3, "mag", "Alarme : bouclier sur l'allié."),
             P(2, 0.1, "Ultime : +10 %."), C(1, 1.0, "Alarme : recharge -1 s."),
             E(2, {"type": "gauge", "amount": -0.1}, "Ultime : retarde encore les ennemis.")],
    "nyx": [P(0, 0.08, "Morsure : +8 %."), B(1, "crit", 0.08, "Technique : +8 pts de critique 4 s."),
            P(2, 0.1, "Ultime : +10 %."), C(1, 1.0, "Technique : recharge -1 s."),
            H(2, 1, 0.5, "Ultime : une morsure de plus.")],
    "mei_lian": [P(0, 0.08, "Pétale tranchant : +8 %."), C(1, 0.5, "Pas du prunier : recharge -0,5 s."),
                 H(2, 1, 0.3, "Les 24 mouvements : un coup de plus."), P(2, 0.1, "Les 24 mouvements : +10 %."),
                 H(2, 2, 0.3, "Les 24 mouvements : 2 coups de plus.")],
    "jin_seok": [SH(0, 0.2, "def", "Poing de bronze : petit bouclier.", self_only=True), P(1, 0.15, "Cloche d'or : +15 %."),
                 H(2, 1, 0.35, "Cent paumes : une paume de plus."), C(1, 1.0, "Cloche d'or : recharge -1 s."),
                 H(2, 2, 0.35, "Cent paumes : 2 paumes de plus.")],
    "yun_tao": [P(0, 0.08, "Fil du courant : +8 %."), SH(1, 0.3, "def", "Cercle du Taiji : bouclier."),
                P(2, 0.1, "Ultime : +10 %."), C(1, 1.0, "Cercle du Taiji : recharge -1 s."),
                E(2, {"type": "gauge", "amount": -0.1}, "Ultime : retarde encore les ennemis.")],
    "tang_su": [P(0, 0.1, "Poison de base : +10 %."), B(0, "crit", 0.06, "Aiguille : +6 pts de critique 4 s."),
                P(2, 0.1, "Pluie d'aiguilles : +10 %."), C(1, 1.0, "Méridiens fermés : recharge -1 s."),
                H(2, 1, 0.5, "Pluie d'aiguilles : une vague de plus.")],
}

out = {"_note": "Généré par tools/build_hero_progression.py : progression propre à chaque héros.", "heroes": {}}
for hero in GROWTH:
    g = dict(D)
    g.update(GROWTH[hero])
    stats = tiers(*RELIC_STATS[hero])
    relic = []
    for i in range(5):
        mod = FIRST[hero][i] if i < 2 else MODS[hero][i - 2]
        relic.append({"stats": stats[i], "mods": [mod]})
    out["heroes"][hero] = {"growth": g, "relic": relic, "echoes": [[m] for m in ECHOES[hero]]}
json.dump(out, open("data/hero_progression.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print(len(out["heroes"]), "héros")
