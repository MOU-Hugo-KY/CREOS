"""Dessine les icônes d'attaque des héros en pixel art (32 × 32, agrandies × 4).

Lancer depuis le dossier du projet :  python tools/make_attack_icons.py
Sortie : assets/ui/attacks/<id_attaque>.png (fond transparent, contour sombre).
Dépendances : Pillow et NumPy.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

N = 32
SCALE = 4
OUT = os.path.join("assets", "ui", "attacks")

# Palette commune
OUTLINE = (20, 16, 24, 255)
STEEL = (205, 214, 222, 255)
STEEL_DARK = (130, 140, 155, 255)
WOOD = (130, 82, 45, 255)
WOOD_DARK = (88, 52, 28, 255)
FIRE = (255, 140, 50, 255)
FIRE_LIGHT = (255, 214, 110, 255)
WATER = (90, 175, 255, 255)
WATER_LIGHT = (190, 230, 255, 255)
POISON = (120, 230, 70, 255)
POISON_DARK = (55, 140, 40, 255)
POISON_LIGHT = (210, 255, 160, 255)
GLASS = (175, 210, 200, 255)
BOLT = (255, 236, 90, 255)
BOLT_LIGHT = (255, 255, 220, 255)
SKIN = (222, 170, 120, 255)
SKIN_DARK = (170, 115, 75, 255)
CLOUD = (120, 125, 150, 255)
CLOUD_DARK = (80, 82, 105, 255)
RED = (200, 40, 50, 255)


def canvas():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def line(d, pts, color, width=1):
    d.line(pts, fill=color, width=width)


def finish(img, name):
    """Ajoute un contour sombre d'un pixel, agrandit et enregistre."""
    a = np.array(img)
    alpha = a[:, :, 3] > 0
    grown = alpha.copy()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grown |= np.roll(np.roll(alpha, dx, axis=1), dy, axis=0)
    outline = grown & ~alpha
    a[outline] = OUTLINE
    out = Image.fromarray(a).resize((N * SCALE, N * SCALE), Image.NEAREST)
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, name + ".png"))
    print("icône :", name)


def axe(d, x0, y0, x1, y1, flip=False):
    """Hache : manche de (x0,y0) à (x1,y1), lame double près de (x1,y1)."""
    line(d, [(x0, y0), (x1, y1)], WOOD, 2)
    line(d, [(x0, y0 + 1), (x1, y1 + 1)], WOOD_DARK, 1)
    s = -1 if flip else 1
    d.polygon([(x1 - 4 * s, y1 - 5), (x1 + 5 * s, y1 - 1), (x1 - 1 * s, y1 + 6)], fill=STEEL)
    d.polygon([(x1 - 4 * s, y1 - 5), (x1 - 1 * s, y1 + 6), (x1 - 6 * s, y1 + 1)], fill=STEEL_DARK)


def sword(d, x0, y0, x1, y1, guard=FIRE_LIGHT):
    """Lame de (x0,y0) (garde) à (x1,y1) (pointe)."""
    line(d, [(x0, y0), (x1, y1)], STEEL, 2)
    line(d, [(x0 + 1, y0), (x1 + 1, y1)], STEEL_DARK, 1)
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1
    px, py = -dy / length * 3, dx / length * 3
    line(d, [(x0 - px, y0 - py), (x0 + px, y0 + py)], guard, 2)
    line(d, [(x0, y0), (x0 - dx / length * 4, y0 - dy / length * 4)], RED, 2)


def bolt(d, pts, color=BOLT, light=BOLT_LIGHT, width=3):
    line(d, pts, color, width)
    line(d, pts, light, 1)


def arc(d, cx, cy, r, a0, a1, color, width=2):
    d.arc([cx - r, cy - r, cx + r, cy + r], a0, a1, fill=color, width=width)


# --- Torvald (Barbare, feu) -----------------------------------------------------

def coup_de_hache():
    img, d = canvas()
    axe(d, 7, 27, 21, 9)
    for i, (x, y) in enumerate([(25, 18), (27, 22), (23, 24)]):
        d.point((x, y), FIRE_LIGHT)
    line(d, [(24, 6), (28, 12)], FIRE, 1)
    finish(img, "coup_de_hache")


def tourbillon_furieux():
    img, d = canvas()
    arc(d, 16, 16, 12, 200, 470, FIRE, 2)
    arc(d, 16, 16, 8, 20, 290, FIRE_LIGHT, 2)
    arc(d, 16, 16, 4, 180, 450, FIRE, 1)
    axe(d, 13, 19, 22, 8)
    finish(img, "tourbillon_furieux")


def ecrasement_berserk():
    img, d = canvas()
    # Sol fissuré
    d.rectangle([3, 25, 28, 27], fill=WOOD_DARK)
    for x0, x1 in ((8, 5), (16, 16), (24, 27)):
        line(d, [(x0, 25), (x1, 29)], FIRE, 1)
    # Deux haches croisées qui frappent le sol
    axe(d, 6, 4, 14, 20)
    axe(d, 26, 4, 18, 20, flip=True)
    for x, y in ((4, 22), (28, 22), (16, 22)):
        d.point((x, y), FIRE_LIGHT)
    finish(img, "ecrasement_berserk")


# --- Kaïto (Ronin, eau) -----------------------------------------------------------

def double_entaille():
    img, d = canvas()
    line(d, [(5, 24), (25, 6)], WATER, 3)
    line(d, [(5, 24), (25, 6)], WATER_LIGHT, 1)
    line(d, [(9, 28), (27, 12)], WATER, 2)
    line(d, [(9, 28), (27, 12)], WATER_LIGHT, 1)
    sword(d, 8, 9, 20, 21, guard=FIRE_LIGHT)
    finish(img, "double_entaille")


def coupe_tournoyante():
    img, d = canvas()
    arc(d, 16, 16, 12, 160, 470, WATER, 3)
    arc(d, 16, 16, 12, 160, 470, WATER_LIGHT, 1)
    sword(d, 13, 18, 25, 7)
    finish(img, "coupe_tournoyante")


def frappe_plongeante():
    img, d = canvas()
    sword(d, 12, 4, 12, 22)
    sword(d, 20, 4, 20, 22)
    d.rectangle([4, 26, 27, 27], fill=WATER)
    for x, y0 in ((6, 23), (26, 23), (16, 24)):
        line(d, [(x, y0), (x, y0 + 2)], WATER_LIGHT, 1)
    line(d, [(3, 25), (8, 21)], WATER_LIGHT, 1)
    line(d, [(28, 25), (23, 21)], WATER_LIGHT, 1)
    finish(img, "frappe_plongeante")


# --- Docteur Vesprin (Alchimiste, nature) -------------------------------------------

def fiole_explosive():
    img, d = canvas()
    d.ellipse([7, 12, 23, 28], fill=GLASS)
    d.ellipse([8, 17, 22, 27], fill=POISON)
    d.ellipse([10, 18, 14, 21], fill=POISON_LIGHT)
    d.rectangle([12, 6, 18, 12], fill=GLASS)
    d.rectangle([11, 4, 19, 6], fill=WOOD)
    # Mèche / étincelles
    line(d, [(19, 5), (24, 2)], WOOD_DARK, 1)
    for x, y in ((25, 2), (27, 4), (26, 1), (28, 2)):
        d.point((x, y), FIRE_LIGHT)
    finish(img, "fiole_explosive")


def flaque_toxique():
    img, d = canvas()
    d.ellipse([3, 19, 29, 29], fill=POISON_DARK)
    d.ellipse([6, 20, 26, 27], fill=POISON)
    for cx, cy, r in ((10, 15, 2), (18, 11, 3), (23, 16, 2), (14, 6, 1)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=POISON_LIGHT)
    d.point((9, 22), POISON_LIGHT)
    d.point((20, 24), POISON_LIGHT)
    finish(img, "flaque_toxique")


def explosion_reservoir():
    img, d = canvas()
    pts = []
    for i in range(16):
        ang = i * math.pi / 8
        r = 14 if i % 2 == 0 else 8
        pts.append((16 + math.cos(ang) * r, 16 + math.sin(ang) * r))
    d.polygon(pts, fill=POISON_DARK)
    pts2 = [(16 + (x - 16) * 0.65, 16 + (y - 16) * 0.65) for x, y in pts]
    d.polygon(pts2, fill=POISON)
    d.ellipse([12, 12, 20, 20], fill=POISON_LIGHT)
    # Tête de mort stylisée au centre
    d.rectangle([14, 14, 15, 15], fill=POISON_DARK)
    d.rectangle([17, 14, 18, 15], fill=POISON_DARK)
    d.rectangle([15, 18, 17, 18], fill=POISON_DARK)
    finish(img, "explosion_reservoir")


# --- Frère Orage (Moine, lumière) -----------------------------------------------------

def fist(d, x, y):
    d.rectangle([x, y, x + 10, y + 9], fill=SKIN)
    for i in range(4):
        d.line([(x + 1 + i * 2.5, y), (x + 1 + i * 2.5, y + 3)], fill=SKIN_DARK)
    d.rectangle([x - 2, y + 9, x + 8, y + 12], fill=(40, 50, 80, 255))
    d.rectangle([x - 2, y + 10, x + 8, y + 10], fill=BOLT)


def paume_foudroyante():
    img, d = canvas()
    fist(d, 5, 13)
    bolt(d, [(17, 14), (22, 10), (20, 16), (28, 11)])
    bolt(d, [(17, 19), (24, 20), (21, 23), (29, 24)], width=2)
    finish(img, "paume_foudroyante")


def pas_du_tonnerre():
    img, d = canvas()
    # Jambe et pied
    d.polygon([(6, 6), (12, 6), (17, 18), (12, 20)], fill=(40, 50, 80, 255))
    d.rectangle([12, 18, 25, 23], fill=SKIN)
    d.rectangle([12, 22, 25, 23], fill=SKIN_DARK)
    d.rectangle([11, 16, 15, 18], fill=BOLT)
    # Traînées de vitesse
    for y in (9, 13, 17):
        line(d, [(1, y), (5, y)], BOLT_LIGHT, 1)
    bolt(d, [(26, 12), (29, 17), (26, 18), (30, 25)], width=2)
    finish(img, "pas_du_tonnerre")


def sentence_celeste():
    img, d = canvas()
    for cx, cy, r in ((10, 8, 6), (17, 6, 7), (24, 9, 5)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CLOUD)
    d.rectangle([5, 9, 28, 13], fill=CLOUD)
    d.rectangle([5, 12, 28, 13], fill=CLOUD_DARK)
    bolt(d, [(17, 13), (12, 21), (18, 21), (13, 30)], width=4)
    for x, y in ((8, 28), (21, 27), (24, 29)):
        d.point((x, y), BOLT)
    finish(img, "sentence_celeste")


if __name__ == "__main__":
    for fn in (coup_de_hache, tourbillon_furieux, ecrasement_berserk,
               double_entaille, coupe_tournoyante, frappe_plongeante,
               fiole_explosive, flaque_toxique, explosion_reservoir,
               paume_foudroyante, pas_du_tonnerre, sentence_celeste):
        fn()
