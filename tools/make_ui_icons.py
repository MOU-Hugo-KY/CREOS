"""Dessine les icônes du hub (Port-Franc) en pixel art, même style que les icônes d'attaque.

Lancer depuis le dossier du projet :  python tools/make_ui_icons.py
Sortie : assets/ui/hub/<nom>.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_attack_icons import (  # noqa: E402
    BOLT, BOLT_LIGHT, CLOUD_DARK, FIRE, FIRE_LIGHT, POISON, RED, STEEL, STEEL_DARK, WOOD, WOOD_DARK,
    canvas, finish, line,
)

OUT = os.path.join("assets", "ui", "hub")

GOLD = (255, 205, 70, 255)
GOLD_DARK = (190, 130, 30, 255)
GOLD_LIGHT = (255, 240, 170, 255)
PAPER = (240, 222, 175, 255)
PAPER_DARK = (200, 170, 115, 255)
GEM = (90, 210, 255, 255)
GEM_DARK = (40, 120, 200, 255)
GEM_LIGHT = (210, 245, 255, 255)
PURPLE = (170, 90, 255, 255)
PURPLE_DARK = (95, 45, 160, 255)
PURPLE_LIGHT = (225, 190, 255, 255)
STONE = (120, 118, 130, 255)
STONE_DARK = (75, 72, 85, 255)
ROOF = (200, 70, 55, 255)
ROOF_DARK = (140, 45, 40, 255)
WALL = (235, 220, 190, 255)
GREEN = (90, 190, 90, 255)
BLUE = (70, 120, 220, 255)
BLUE_DARK = (40, 70, 150, 255)


def save(img, name):
    finish(img, name, OUT)


def chasses():
    """Carte roulée avec un chemin et une croix rouge."""
    img, d = canvas()
    d.rectangle([5, 7, 26, 25], fill=PAPER)
    d.rectangle([5, 7, 7, 25], fill=PAPER_DARK)
    d.rectangle([24, 7, 26, 25], fill=PAPER_DARK)
    for i, (x, y) in enumerate([(9, 21), (11, 19), (13, 19), (15, 17), (16, 15), (18, 13)]):
        d.point((x, y), WOOD_DARK)
    line(d, [(19, 9), (23, 13)], RED, 2)
    line(d, [(23, 9), (19, 13)], RED, 2)
    d.rectangle([9, 9, 12, 12], fill=GREEN)
    save(img, "chasses")


def heros():
    """Casque à plumet."""
    img, d = canvas()
    d.pieslice([6, 8, 26, 30], 180, 360, fill=STEEL)
    d.rectangle([6, 18, 26, 26], fill=STEEL)
    d.rectangle([6, 18, 26, 20], fill=STEEL_DARK)
    d.rectangle([14, 19, 18, 26], fill=(30, 30, 40, 255))
    d.rectangle([9, 21, 23, 22], fill=(30, 30, 40, 255))
    d.polygon([(15, 9), (12, 2), (20, 1), (18, 9)], fill=RED)
    d.point((15, 3), (255, 120, 110, 255))
    save(img, "heros")


def autel():
    """Cristal-relique qui brille."""
    img, d = canvas()
    d.polygon([(16, 2), (24, 12), (16, 28), (8, 12)], fill=PURPLE)
    d.polygon([(16, 2), (16, 28), (8, 12)], fill=PURPLE_DARK)
    d.polygon([(16, 2), (20, 12), (16, 22), (12, 12)], fill=PURPLE_LIGHT)
    for x, y in ((4, 6), (27, 8), (26, 22), (5, 24), (16, 30)):
        d.point((x, y), GOLD_LIGHT)
    save(img, "autel")


def marche():
    """Bourse de pièces."""
    img, d = canvas()
    d.ellipse([7, 11, 25, 29], fill=WOOD)
    d.ellipse([9, 13, 21, 25], fill=(160, 105, 60, 255))
    d.polygon([(11, 12), (21, 12), (19, 6), (13, 6)], fill=WOOD)
    line(d, [(11, 11), (21, 11)], GOLD, 2)
    d.ellipse([18, 19, 28, 29], fill=GOLD)
    d.ellipse([20, 21, 26, 27], fill=GOLD_DARK)
    d.point((22, 22), GOLD_LIGHT)
    save(img, "marche")


def ma_loge():
    """Maison avec une bannière."""
    img, d = canvas()
    d.rectangle([6, 15, 24, 28], fill=WALL)
    d.polygon([(3, 16), (15, 5), (27, 16)], fill=ROOF)
    d.polygon([(3, 16), (15, 5), (15, 16)], fill=ROOF_DARK)
    d.rectangle([13, 21, 17, 28], fill=WOOD_DARK)
    d.rectangle([8, 18, 10, 20], fill=GOLD)
    d.rectangle([20, 18, 22, 20], fill=GOLD)
    line(d, [(26, 3), (26, 15)], WOOD, 1)
    d.polygon([(27, 3), (31, 5), (27, 8)], fill=BLUE)
    save(img, "ma_loge")


def primes():
    """Parchemin scellé (avis de primes)."""
    img, d = canvas()
    d.rectangle([7, 5, 24, 27], fill=PAPER)
    d.rectangle([5, 3, 26, 6], fill=PAPER_DARK)
    d.rectangle([5, 26, 26, 29], fill=PAPER_DARK)
    for y in (10, 13, 16):
        line(d, [(10, y), (21, y)], WOOD, 1)
    d.ellipse([16, 18, 24, 26], fill=RED)
    d.point((20, 22), (255, 150, 140, 255))
    save(img, "primes")


def recompenses():
    """Coffre au trésor."""
    img, d = canvas()
    d.rectangle([5, 14, 27, 27], fill=WOOD)
    d.pieslice([5, 6, 27, 22], 180, 360, fill=(150, 95, 50, 255))
    line(d, [(5, 14), (27, 14)], GOLD, 2)
    d.rectangle([14, 13, 18, 19], fill=GOLD)
    d.point((16, 16), WOOD_DARK)
    line(d, [(9, 8), (9, 27)], GOLD_DARK, 1)
    line(d, [(23, 8), (23, 27)], GOLD_DARK, 1)
    for x, y in ((3, 5), (29, 6), (16, 3)):
        d.point((x, y), GOLD_LIGHT)
    save(img, "recompenses")


def evenements():
    """Œil violet de la corruption."""
    img, d = canvas()
    d.ellipse([3, 9, 29, 23], fill=PURPLE_DARK)
    d.ellipse([10, 10, 22, 22], fill=PURPLE)
    d.ellipse([13, 13, 19, 19], fill=(25, 10, 40, 255))
    d.point((14, 14), PURPLE_LIGHT)
    for x in (6, 11, 16, 21, 26):
        line(d, [(x, 8), (x + 1, 4)], PURPLE, 1)
    save(img, "evenements")


def classement():
    """Trophée."""
    img, d = canvas()
    d.rectangle([9, 4, 23, 14], fill=GOLD)
    d.pieslice([9, 6, 23, 22], 0, 180, fill=GOLD)
    d.rectangle([9, 4, 12, 16], fill=GOLD_DARK)
    d.arc([3, 6, 11, 16], 90, 270, fill=GOLD, width=2)
    d.arc([21, 6, 29, 16], 270, 90, fill=GOLD, width=2)
    d.rectangle([14, 20, 18, 24], fill=GOLD_DARK)
    d.rectangle([10, 24, 22, 28], fill=WOOD)
    d.point((19, 7), GOLD_LIGHT)
    save(img, "classement")


def guilde():
    """Écu avec une bande."""
    img, d = canvas()
    d.polygon([(6, 4), (26, 4), (26, 16), (16, 29), (6, 16)], fill=BLUE)
    d.polygon([(16, 4), (26, 4), (26, 16), (16, 29)], fill=BLUE_DARK)
    line(d, [(8, 6), (24, 22)], GOLD, 3)
    d.point((11, 8), (160, 190, 255, 255))
    save(img, "guilde")


def tour():
    """Tour noire de Morvath."""
    img, d = canvas()
    d.rectangle([11, 8, 21, 29], fill=STONE_DARK)
    d.rectangle([9, 6, 23, 9], fill=STONE)
    for x in (9, 13, 17, 21):
        d.rectangle([x, 3, x + 1, 6], fill=STONE)
    d.rectangle([14, 13, 17, 17], fill=PURPLE)
    d.rectangle([14, 21, 17, 25], fill=PURPLE)
    d.polygon([(16, 0), (13, 3), (19, 3)], fill=PURPLE_LIGHT)
    save(img, "tour")


def or_():
    img, d = canvas()
    d.ellipse([5, 5, 27, 27], fill=GOLD)
    d.ellipse([9, 9, 23, 23], fill=GOLD_DARK)
    d.rectangle([14, 11, 17, 21], fill=GOLD)
    d.point((10, 9), GOLD_LIGHT)
    save(img, "or")


def gemmes():
    img, d = canvas()
    d.polygon([(8, 10), (12, 5), (20, 5), (24, 10), (16, 27)], fill=GEM)
    d.polygon([(8, 10), (24, 10), (16, 27)], fill=GEM_DARK)
    d.polygon([(12, 5), (16, 10), (20, 5)], fill=GEM_LIGHT)
    save(img, "gemmes")


def energie():
    img, d = canvas()
    line(d, [(19, 3), (11, 17), (19, 15), (12, 29)], BOLT, 5)
    line(d, [(19, 3), (11, 17), (19, 15), (12, 29)], BOLT_LIGHT, 1)
    save(img, "energie")


if __name__ == "__main__":
    for fn in (chasses, heros, autel, marche, ma_loge, primes, recompenses, evenements,
               classement, guilde, tour, or_, gemmes, energie):
        fn()
