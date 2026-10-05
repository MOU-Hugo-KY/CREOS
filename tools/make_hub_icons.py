"""Icônes du hub et des monnaies (assets/ui/hub/<nom>.png, 256 × 256), dans le style encré des
héros : contour d'encre épais, aplats, une ombre franche dessous, un reflet clair.

- dessinées ici : or (pièces), gemmes (diamant taillé), énergie (éclair), primes (parchemin
  scellé), récompenses (coffre), corruption (œil), classement (trophée), guilde (bouclier) ;
- reprises des dessins du port : Table des chasses, Loge des héros, Lanterne, Marchand, Ma loge,
  Tour de Morvath ; éclats de serment = le cristal de la Lanterne ; reliques = une relique.

  python tools/make_hub_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui" / "hub"
PORT = ROOT / "assets" / "hub2d" / "port"
S = 1024  # dessin en grand, réduit à la fin (bords lisses)
INK = (41, 38, 46, 255)
W = 30  # épaisseur du contour


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def poly(d, pts, fill, w=W):
    if fill is not None:
        d.polygon(pts, fill=fill)
    if w > 0:
        d.line(pts + [pts[0]], fill=INK, width=int(w), joint="curve")


def ell(d, box, fill, w=W):
    d.ellipse(box, fill=fill, outline=INK if w > 0 else None, width=int(w))


def shadowed(draw_fn, offset=34):
    """Dessine la forme, plus une ombre d'encre franche décalée vers le bas."""
    shape = canvas()
    draw_fn(ImageDraw.Draw(shape))
    alpha = shape.getchannel("A")
    shadow = Image.new("RGBA", (S, S), INK)
    shadow.putalpha(alpha)
    out = canvas()
    out.alpha_composite(shadow, (0, offset))
    out.alpha_composite(shape)
    return out


def finish(img, name, glow=None):
    if glow:
        halo = canvas()
        ImageDraw.Draw(halo).ellipse([150, 150, S - 150, S - 150], fill=glow)
        halo = halo.filter(ImageFilter.GaussianBlur(90))
        halo.alpha_composite(img)
        img = halo
    img.resize((256, 256), Image.LANCZOS).save(OUT / (name + ".png"))


# --- Monnaies --------------------------------------------------------------------

def coin(d, cx, cy, r, tilt=0.9):
    gold, dark, light, deep = (242, 193, 78, 255), (196, 132, 34, 255), (255, 228, 140, 255), (150, 95, 25, 255)
    th = r * 0.22
    d.ellipse([cx - r, cy - r * tilt + th, cx + r, cy + r * tilt + th], fill=deep, outline=INK, width=W)
    d.rectangle([cx - r + W / 2, cy, cx + r - W / 2, cy + th], fill=deep)
    ell(d, [cx - r, cy - r * tilt, cx + r, cy + r * tilt], gold)
    ell(d, [cx - r * 0.78, cy - r * 0.78 * tilt, cx + r * 0.78, cy + r * 0.78 * tilt], dark, W * 0.6)
    ell(d, [cx - r * 0.7, cy - r * 0.7 * tilt, cx + r * 0.7, cy + r * 0.7 * tilt], gold, 0)
    # Étoile en relief au centre
    import math
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r * (0.42 if i % 2 == 0 else 0.18)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * tilt))
    poly(d, pts, light, W * 0.55)
    d.arc([cx - r * 0.86, cy - r * 0.86 * tilt, cx + r * 0.86, cy + r * 0.86 * tilt], 200, 260, fill=(255, 250, 220, 255),
          width=int(W * 0.9))


def icon_or():
    def draw(d):
        coin(d, 400, 420, 250)
        coin(d, 590, 560, 280)
    finish(shadowed(draw), "or")


def icon_gemmes():
    def draw(d):
        cx = 512
        top, girdle, tip = 230, 430, 860
        table = [(390, top), (634, top)]
        g = [(190, girdle), (834, girdle)]
        base, light, mid, dark, deep = (79, 179, 240, 255), (160, 222, 255, 255), (60, 150, 225, 255), (38, 108, 190, 255), (26, 78, 150, 255)
        poly(d, [table[0], table[1], g[1], (cx, tip), g[0]], base)
        # Couronne (facettes du haut)
        poly(d, [table[0], (cx, girdle - 40), g[0]], light, W * 0.5)
        poly(d, [table[0], table[1], (cx, girdle - 40)], (205, 240, 255, 255), W * 0.5)
        poly(d, [table[1], g[1], (cx, girdle - 40)], mid, W * 0.5)
        # Pavillon (facettes du bas)
        poly(d, [g[0], (cx - 120, girdle), (cx, tip)], mid, W * 0.5)
        poly(d, [(cx - 120, girdle), (cx + 120, girdle), (cx, tip)], dark, W * 0.5)
        poly(d, [(cx + 120, girdle), g[1], (cx, tip)], deep, W * 0.5)
        d.line([g[0], g[1]], fill=INK, width=int(W * 0.7))
        poly(d, [table[0], table[1], g[1], (cx, tip), g[0]], None)
        # Éclat
        sx, sy = 330, 290
        d.polygon([(sx, sy - 70), (sx + 16, sy - 16), (sx + 70, sy), (sx + 16, sy + 16), (sx, sy + 70), (sx - 16, sy + 16),
                   (sx - 70, sy), (sx - 16, sy - 16)], fill=(255, 255, 255, 255))
    finish(shadowed(draw), "gemmes", glow=(90, 180, 255, 110))


def icon_energie():
    def draw(d):
        bolt = [(600, 120), (300, 560), (480, 560), (380, 910), (740, 430), (550, 430), (680, 120)]
        poly(d, bolt, (255, 210, 63, 255))
        d.polygon([(600, 150), (330, 545), (430, 545), (560, 200)], fill=(255, 243, 170, 255))
        d.polygon([(560, 445), (720, 445), (420, 860)], fill=(242, 165, 30, 255))
        d.line(bolt + [bolt[0]], fill=INK, width=W, joint="curve")
        for (x, y, r) in [(250, 300, 34), (790, 640, 26), (800, 260, 20)]:
            d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 236, 140, 255), outline=INK, width=int(W * 0.5))
    finish(shadowed(draw), "energie", glow=(255, 210, 80, 100))


def icon_eclats():
    sheet = Image.open(PORT / "Lanterne_Pulse_8f_10fps.png").convert("RGBA")
    fw = sheet.width // 8
    frame = sheet.crop((0, 0, fw, sheet.height))
    finish(fit(frame, 0.92), "eclats", glow=(160, 90, 255, 120))


# --- Menus ----------------------------------------------------------------------

def icon_primes():
    def draw(d):
        poly(d, [(250, 230), (780, 230), (780, 760), (250, 760)], (238, 228, 205, 255))
        for y in (360, 440, 520, 600):
            d.line([(320, y), (700 if y != 600 else 560, y)], fill=(150, 130, 100, 255), width=22)
        ell(d, [180, 170, 320, 300], (211, 196, 166, 255))
        ell(d, [710, 170, 850, 300], (211, 196, 166, 255))
        ell(d, [180, 690, 320, 820], (211, 196, 166, 255))
        ell(d, [710, 690, 850, 820], (211, 196, 166, 255))
        # Sceau de cire et ruban
        poly(d, [(600, 640), (650, 900), (690, 800), (740, 880), (720, 640)], (121, 59, 73, 255), W * 0.7)
        ell(d, [560, 560, 760, 760], (150, 60, 75, 255))
        ell(d, [610, 610, 710, 710], (190, 90, 100, 255), W * 0.5)
    finish(shadowed(draw), "primes")


def icon_recompenses():
    def draw(d):
        wood, wood_d, brass = (150, 96, 52, 255), (110, 66, 36, 255), (198, 166, 108, 255)
        poly(d, [(170, 470), (854, 470), (854, 840), (170, 840)], wood)
        d.chord([170, 220, 854, 720], 180, 360, fill=wood_d, outline=INK, width=W)
        d.rectangle([170 + W / 2, 455, 854 - W / 2, 475], fill=wood_d)
        d.line([(170, 470), (854, 470)], fill=INK, width=W)
        for x in (260, 764):
            poly(d, [(x - 40, 300 if x == 260 else 300), (x + 40, 300), (x + 40, 840), (x - 40, 840)], brass, W * 0.6)
        poly(d, [(440, 420), (584, 420), (584, 580), (440, 580)], brass)
        ell(d, [490, 460, 534, 504], INK, 0)
        # Pièces qui débordent
        for (x, y) in [(360, 250), (520, 215), (650, 255)]:
            ell(d, [x - 70, y - 50, x + 70, y + 50], (242, 193, 78, 255), W * 0.6)
    finish(shadowed(draw), "recompenses", glow=(255, 200, 80, 90))


def icon_evenements():
    def draw(d):
        import math
        for i in range(7):
            a = math.pi * (0.15 + i * 0.7 / 6)
            x0, y0 = 512 + math.cos(a) * 300, 512 - math.sin(a) * 200
            d.line([(x0, y0), (512 + math.cos(a) * 430, 512 - math.sin(a) * 330)], fill=INK, width=34)
        eye = [(130, 512), (300, 330), (512, 270), (724, 330), (894, 512), (724, 694), (512, 754), (300, 694)]
        poly(d, eye, (238, 228, 205, 255))
        ell(d, [352, 352, 672, 672], (155, 93, 229, 255))
        ell(d, [412, 412, 612, 612], (109, 79, 140, 255), W * 0.5)
        poly(d, [(512, 400), (548, 512), (512, 624), (476, 512)], INK, 6)
        d.ellipse([560, 410, 610, 460], fill=(255, 255, 255, 255))
    finish(shadowed(draw), "evenements", glow=(155, 93, 229, 110))


def icon_classement():
    def draw(d):
        gold, dark, light = (242, 193, 78, 255), (196, 132, 34, 255), (255, 232, 150, 255)
        d.arc([150, 250, 420, 560], 90, 270, fill=INK, width=60)
        d.arc([604, 250, 874, 560], 270, 90, fill=INK, width=60)
        d.arc([150, 250, 420, 560], 90, 270, fill=gold, width=24)
        d.arc([604, 250, 874, 560], 270, 90, fill=gold, width=24)
        cup = [(270, 200), (754, 200), (720, 450), (600, 590), (424, 590), (304, 450)]
        poly(d, cup, gold)
        d.polygon([(330, 230), (420, 230), (440, 520), (360, 430)], fill=light)
        poly(d, [(460, 590), (564, 590), (590, 720), (434, 720)], dark)
        poly(d, [(330, 720), (694, 720), (694, 830), (330, 830)], (121, 59, 73, 255))
        poly(d, [(430, 750), (594, 750), (594, 800), (430, 800)], (198, 166, 108, 255), W * 0.4)
    finish(shadowed(draw), "classement", glow=(255, 210, 90, 80))


def icon_guilde():
    def draw(d):
        shield = [(230, 200), (794, 200), (794, 520), (512, 860), (230, 520)]
        poly(d, shield, (198, 166, 108, 255))
        inner = [(290, 260), (734, 260), (734, 505), (512, 780), (290, 505)]
        poly(d, inner, (121, 59, 73, 255), W * 0.6)
        d.polygon([(512, 260), (734, 260), (734, 505), (512, 780)], fill=(100, 46, 60, 255))
        # Deux lames croisées
        for (a, b) in [((350, 330), (670, 690)), ((670, 330), (350, 690))]:
            d.line([a, b], fill=INK, width=70)
            d.line([a, b], fill=(238, 228, 205, 255), width=30)
        d.polygon(inner, outline=INK)
        d.line(inner + [inner[0]], fill=INK, width=int(W * 0.6), joint="curve")
    finish(shadowed(draw), "guilde")


# --- Reprises des dessins du port --------------------------------------------------

def fit(img, fill=0.96):
    box = img.getbbox()
    img = img.crop(box)
    side = max(img.width, img.height)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(img, ((side - img.width) // 2, (side - img.height) // 2))
    out = canvas()
    inner = int(S * fill)
    out.alpha_composite(sq.resize((inner, inner), Image.LANCZOS), ((S - inner) // 2, (S - inner) // 2))
    return out


def from_port(file, name, fill=0.98):
    finish(fit(Image.open(PORT / file).convert("RGBA"), fill), name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icon_or()
    icon_gemmes()
    icon_energie()
    icon_eclats()
    icon_primes()
    icon_recompenses()
    icon_evenements()
    icon_classement()
    icon_guilde()
    from_port("Table_Des_Chasses.png", "chasses")
    from_port("Loge_Des_Heros.png", "heros")
    from_port("Lanterne_Des_Serments.png", "autel")
    from_port("Echoppe_Des_Masques.png", "marche")
    from_port("Ma_Loge.png", "ma_loge")
    from_port("Tour_De_Morvath.png", "tour")
    relic = ROOT / "assets" / "relics" / "relic_corbin.png"
    finish(fit(Image.open(relic).convert("RGBA"), 0.9), "reliques", glow=(198, 166, 108, 90))
    print("icônes du hub faites")


if __name__ == "__main__":
    main()
