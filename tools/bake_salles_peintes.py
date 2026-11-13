"""Installe les personnages, objets et esprits peints des salles (livrés par ChatGPT en poses fixes).

    python tools/bake_salles_peintes.py <dossier recu/> [racine du projet]

À partir de deux poses par personnage (repos, action), fabrique des planches d'animation au format de
`MageRoom.Sheet` (grille de 4 colonnes) : respiration au repos, puis élan, pose d'action et retour.
Même principe pour le nid (fermé → ouvert) et les 20 Esprits (apparition). Pose aussi la stèle dans sa
salle, l'étal et le comptoir de l'échoppe, le lutrin, et recale les niches du reliquaire sur le fond.
Les fonds des salles doivent déjà être installés (1920 × 1080).
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageFilter

SRC = sys.argv[1]
ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
U = ROOT + '/assets/ui/'
B = 1.5  # les planches sont dessinées 1,5 fois plus grandes que l'affichage (écrans denses)
COLS = 4


# ---------------------------------------------------------------- outils d'image
def load(path):
    """Image RGBA recadrée sur ce qui est vraiment visible (alpha > 8)."""
    im = Image.open(path).convert('RGBA')
    a = np.asarray(im)[:, :, 3] > 8
    ys, xs = np.where(a)
    return im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def resize(im, w, h):
    """Mise à l'échelle sans liseré sombre (alpha prémultiplié)."""
    w, h = max(1, int(round(w))), max(1, int(round(h)))
    return im.convert('RGBa').resize((w, h), Image.LANCZOS).convert('RGBA')


def feet_x(im):
    """Abscisse du milieu des pieds (bas de l'image)."""
    a = np.asarray(im)[:, :, 3] > 60
    band = a[int(im.height * 0.94):, :]
    xs = np.where(band.any(axis=0))[0]
    return float(xs.min() + xs.max()) / 2.0 if len(xs) else im.width / 2.0


def whiten(im, k):
    """Mélange vers le blanc (éclat), sans toucher à la transparence."""
    if k <= 0:
        return im
    a = np.asarray(im).astype(np.float32)
    a[:, :, :3] = a[:, :, :3] * (1 - k) + 255.0 * k
    return Image.fromarray(a.astype(np.uint8), 'RGBA')


def glow_disc(size, color, alpha):
    """Disque lumineux flou, de la couleur de l'élément."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.sqrt((x - size / 2) ** 2 + (y - size / 2) ** 2) / (size / 2)
    a = np.clip(1 - d, 0, 1) ** 1.6 * 255 * alpha
    out = np.zeros((size, size, 4), np.uint8)
    out[:, :, 0], out[:, :, 1], out[:, :, 2] = color
    out[:, :, 3] = a.astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


def stamp(frame, im, pivot, ax, sx=1.0, sy=1.0, dy=0.0, white=0.0):
    """Colle `im` dans `frame`, son point de pied (`ax`, bas de l'image) posé sur `pivot`."""
    w, h = im.width * sx, im.height * sy
    t = whiten(resize(im, w, h), white)
    frame.alpha_composite(t, (int(round(pivot[0] - ax * sx)), int(round(pivot[1] - h + dy))))


def save_sheet(frames, path):
    fw, fh = frames[0].size
    rows = int(math.ceil(len(frames) / COLS))
    sheet = Image.new('RGBA', (fw * COLS, fh * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % COLS) * fw, (i // COLS) * fh))
    sheet.save(path, optimize=True)


def frame_box(poses, margin=24):
    """Taille d'image et pivot communs à des poses [(image, ax)] (pieds au même point)."""
    half = max(max(ax, im.width - ax) for im, ax in poses) * 1.08 + margin
    top = max(im.height for im, _ in poses) * 1.10 + margin
    fw = int(math.ceil(half * 2 / 4.0)) * 4
    fh = int(math.ceil((top + margin) / 4.0)) * 4
    return (fw, fh), (fw // 2, fh - margin)


# ---------------------------------------------------------------- personnages
def character(name_rest, name_act, shown_height, act_ratio=1.0):
    """Deux poses à la même échelle ; `shown_height` : hauteur à l'écran de la pose de repos."""
    rest = load('%s/personnages/%s.png' % (SRC, name_rest))
    act = load('%s/personnages/%s.png' % (SRC, name_act))
    s = shown_height * B / rest.height
    rest = resize(rest, rest.width * s, rest.height * s)
    act = resize(act, act.width * s * act_ratio, act.height * s * act_ratio)
    return (rest, feet_x(rest)), (act, feet_x(act))


def idle_frames(pose, size, pivot, n=8):
    out = []
    for i in range(n):
        b = math.sin(2 * math.pi * i / n)
        f = Image.new('RGBA', size, (0, 0, 0, 0))
        stamp(f, pose[0], pivot, pose[1], 1 - 0.006 * b, 1 + 0.012 * b)
        out.append(f)
    return out


def action_frames(rest, act, size, pivot):
    """12 images : élan, pose d'action qui claque, tenue avec un léger battement, retour."""
    plan = [(rest, 1.04, 0.95, 0), (rest, 1.07, 0.91, 0), (act, 0.94, 1.09, 0.25), (act, 0.98, 1.04, 0.08),
        (act, 1.0, 1.0, 0), (act, 1.01, 0.99, 0.05), (act, 1.0, 1.0, 0), (act, 1.01, 0.99, 0.05),
        (act, 1.0, 1.0, 0), (act, 1.03, 0.96, 0), (rest, 0.97, 1.05, 0), (rest, 1.0, 1.0, 0)]
    out = []
    for pose, sx, sy, wh in plan:
        f = Image.new('RGBA', size, (0, 0, 0, 0))
        stamp(f, pose[0], pivot, pose[1], sx, sy, white=wh)
        out.append(f)
    return out


def bake_character(rest_name, act_name, shown_height, idle_path, act_path, act_ratio=1.0):
    rest, act = character(rest_name, act_name, shown_height, act_ratio)
    size, pivot = frame_box([rest, act])
    save_sheet(idle_frames(rest, size, pivot), U + idle_path)
    save_sheet(action_frames(rest, act, size, pivot), U + act_path)
    print(rest_name, 'image', size, 'pivot', pivot)
    return list(size), list(pivot)


INV = U + 'invocateurs/invocateurs.json'
inv = json.load(open(INV, encoding='utf8'))
for who, rest_n, act_n, h, idle, act in [
        ('mage', 'mage_repos', 'mage_action', 350, 'mage_repos', 'mage_incantation'),
        ('mecanicien', 'mecanicien_repos', 'mecanicien_action', 335, 'mecanicien_repos', 'mecanicien_travail')]:
    size, pivot = bake_character(rest_n, act_n, h, 'invocateurs/%s/%s.png' % (who, idle), 'invocateurs/%s/%s.png' % (who, act))
    for key, n, ms in [(idle, 8, 140), (act, 12, 100)]:
        a = inv['animations'][key]
        a.update({'frame_size': size, 'pivot': pivot, 'frame_count': n, 'frame_durations_ms': [ms] * n, 'duration_ms': ms,
            'columns': COLS, 'smooth': True, 'scale': round(1 / B, 4), 'layout': 'grid'})
json.dump(inv, open(INV, 'w', encoding='utf8', newline='\n'), ensure_ascii=False, indent=2)

JAR = U + 'invocateurs/jardin_esprits.json'
jar = json.load(open(JAR, encoding='utf8'))
size, pivot = bake_character('gardienne_repos', 'gardienne_action', 285, 'invocateurs/jardin/gardien_repos.png',
    'invocateurs/jardin/gardien_appel.png')
for key, n in [('gardien_repos', 8), ('gardien_appel', 12)]:
    jar['planches'][key].update({'taille_image': size, 'pivot': pivot, 'nombre': n, 'colonnes': COLS, 'lisse': True,
        'echelle': round(1 / B, 4), 'ordre': 'grille'})

# La marchande : deux images fixes (l'échoppe la fait respirer par code).
for n in ['marchande_repos', 'marchande_action']:
    m = load('%s/personnages/%s.png' % (SRC, n))
    k = 1050.0 / m.height * (0.94 if n.endswith('action') else 1.0)
    resize(m, m.width * k, m.height * k).save(U + 'echoppe/echoppe/%s.png' % n, optimize=True)

# ---------------------------------------------------------------- nid du jardin
closed = load(SRC + '/objets/nid_ferme.png')
opened = load(SRC + '/objets/nid_ouvert.png')
s = 470.0 * B / opened.width  # la fleur ouverte fait 470 px de large à l'écran
closed = resize(closed, closed.width * s, closed.height * s)
opened = resize(opened, opened.width * s, opened.height * s)
pc, po = (closed, closed.width / 2.0), (opened, opened.width / 2.0)
size, pivot = frame_box([pc, po])
plan = [(pc, 1.0, 1.0, 0), (pc, 1.05, 0.94, 0), (pc, 0.96, 1.07, 0.1), (pc, 0.93, 1.12, 0.4), (po, 0.86, 0.86, 0.6),
    (po, 1.09, 1.09, 0.25), (po, 1.03, 1.03, 0.08), (po, 1.0, 1.0, 0), (po, 1.01, 1.01, 0.05), (po, 1.0, 1.0, 0),
    (po, 1.01, 1.01, 0.05), (po, 1.0, 1.0, 0)]
frames = []
for pose, sx, sy, wh in plan:
    f = Image.new('RGBA', size, (0, 0, 0, 0))
    stamp(f, pose[0], pivot, pose[1], sx, sy, white=wh)
    frames.append(f)
save_sheet(frames, U + 'invocateurs/jardin/nid_ouverture.png')
jar['planches']['nid_ouverture'].update({'taille_image': list(size), 'pivot': list(pivot), 'nombre': 12, 'colonnes': COLS,
    'lisse': True, 'echelle': round(1 / B, 4), 'ordre': 'grille'})
json.dump(jar, open(JAR, 'w', encoding='utf8', newline='\n'), ensure_ascii=False, indent=2)
# Le jardin au repos : le fond avec le bouton de fleur fermé, posé exactement là où la planche le dessine.
garden = Image.open(U + 'invocateurs/jardin/jardin_sans_nid.png').convert('RGBA')
pos = jar['planches']['nid_ouverture']['position']
shown = resize(closed, closed.width / B, closed.height / B)
garden.alpha_composite(shown, (int(round(pos[0] - shown.width / 2.0)), int(round(pos[1] - shown.height))))
garden.convert('RGB').save(U + 'invocateurs/jardin/jardin_esprits.png', optimize=True)
print('nid', size, pivot)

# ---------------------------------------------------------------- stèle
room_path = U + 'invocateurs/stele/salle_stele.png'
bare_path = U + 'invocateurs/stele/salle_sans_mecanisme.png'
room = Image.open(SRC + '/salles/salle_stele.png').convert('RGB').resize((1920, 1080), Image.LANCZOS)
room.save(bare_path, optimize=True)  # la salle sans la stèle
room = room.convert('RGBA')
STELE_H, STELE_BOTTOM, STELE_X = 640, 815, 960
for n, out in [('stele_repos', None), ('stele_eveil', 'invocateurs/stele/stele_eveil.png')]:
    st = load('%s/objets/%s.png' % (SRC, n))
    st = resize(st, st.width * STELE_H / st.height, STELE_H)
    at = (int(STELE_X - st.width / 2.0), STELE_BOTTOM - st.height)
    if out is None:
        room.alpha_composite(st, at)
        room.convert('RGB').save(room_path, optimize=True)
    else:
        st.save(U + out, optimize=True)
    print(n, 'rect', [at[0], at[1], st.width, st.height])
    stele_rect = [at[0], at[1], st.width, st.height]
jar = json.load(open(JAR, encoding='utf8'))
jar['positions']['stele']['eveil_rect'] = stele_rect
json.dump(jar, open(JAR, 'w', encoding='utf8', newline='\n'), ensure_ascii=False, indent=2)

# ---------------------------------------------------------------- échoppe : étal, comptoir ; reliquaire : lutrin
def refit(new_path, old_path, out_path):
    """Remplace une pièce en gardant sa toile et l'emplacement de son dessin (interface calée dessus)."""
    old = Image.open(old_path).convert('RGBA')
    a = np.asarray(old)[:, :, 3] > 8
    ys, xs = np.where(a)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    new = load(new_path)
    canvas = Image.new('RGBA', old.size, (0, 0, 0, 0))
    canvas.alpha_composite(resize(new, box[2] - box[0], box[3] - box[1]), (box[0], box[1]))
    canvas.save(out_path, optimize=True)


OLD = sys.argv[3] if len(sys.argv) > 3 else ''
if OLD:
    refit(SRC + '/objets/etal.png', OLD + '/etal.png', U + 'echoppe/echoppe/etal.png')
    refit(SRC + '/objets/lutrin.png', OLD + '/lutrin_relique.png', U + 'echoppe/reliquaire/lutrin_relique.png')
ecr_path = U + 'echoppe/ecrans.json'
ecr = json.load(open(ecr_path, encoding='utf8'))
fc = ecr['echoppe']['foreground_counter']['rect']
shop = Image.open(U + 'echoppe/echoppe/echoppe_fond.png').convert('RGBA')
# Le devant du comptoir, redécoupé dans le nouveau fond : il cache le bas de la marchande.
shop.crop((fc[0], fc[1], fc[0] + fc[2], fc[1] + fc[3])).save(U + 'echoppe/echoppe/comptoir_avant.png', optimize=True)
ecr['echoppe']['merchant_rect'] = [140, 318, 600, 720]

# Niches du reliquaire : recalées sur les 3 rangées de 7 du fond peint (19 héros : 7, 7, puis 5 au milieu).
CX = [252, 406, 560, 712, 864, 1016, 1169]
CY = [337, 567, 795]
cells = [(r, c) for r in (0, 1) for c in range(7)] + [(2, c) for c in range(1, 6)]
niches = []
for i, (r, c) in enumerate(cells):
    cx, cy = CX[c], CY[r]
    niches.append({'id': i, 'row': r, 'column': c, 'hero_id': None,
        'rect': [cx - 62, cy - 74, 124, 142], 'relic_rect': [cx - 38, cy - 44, 76, 84],
        'palier_rects': [[cx - 65 + k * 26, cy + 76, 26, 26] for k in range(5)]})
ecr['reliquaire']['niches'] = niches
ecr['reliquaire']['rows'] = [7, 7, 5]
json.dump(ecr, open(ecr_path, 'w', encoding='utf8', newline='\n'), ensure_ascii=False, indent=2)

# ---------------------------------------------------------------- les 20 Esprits
COLORS = {'feu': (255, 150, 60), 'eau': (90, 195, 255), 'nature': (140, 225, 100), 'lumiere': (255, 228, 130),
    'ombre': (175, 110, 255)}
STAGES = ['oeuf', 'petit', 'grand', 'celeste']
GARDEN_SCALE = {'oeuf': 0.5, 'petit': 0.62, 'grand': 0.74, 'celeste': 0.86}
FS, PIV = 512, (256, 416)
invp = U + 'invocateurs/esprits/invocations.json'
invo = json.load(open(invp, encoding='utf8'))
for elem, col in COLORS.items():
    row = Image.open('%s/esprits/esprits_%s.png' % (SRC, elem)).convert('RGBA')
    a = np.asarray(row)[:, :, 3] > 40
    cols = a.sum(axis=0)
    segs, start = [], None
    for x, v in enumerate(list(cols) + [0]):
        if v > 0 and start is None:
            start = x
        elif v == 0 and start is not None:
            if x - start > 30:
                segs.append((start, x))
            start = None
    assert len(segs) == 4, (elem, segs)
    for stage, (x0, x1) in zip(STAGES, segs):
        part = row.crop((x0, 0, x1, row.height))
        ys = np.where((np.asarray(part)[:, :, 3] > 8).any(axis=1))[0]
        cr = part.crop((0, int(ys.min()), part.width, int(ys.max()) + 1))
        k = min(400.0 / cr.width, 380.0 / cr.height)
        cr = resize(cr, cr.width * k, cr.height * k)
        pose = (cr, cr.width / 2.0)
        white = Image.new('RGBA', cr.size, (255, 255, 255, 0))
        white.putalpha(cr.getchannel('A'))
        wpose = (white, cr.width / 2.0)
        plan = [(None, 0.35, 0.5, 0, 0), (None, 0.6, 0.7, 0, 0), (wpose, 0.3, 0.9, 0, 0), (wpose, 0.7, 1.0, 0, 0),
            (pose, 1.15, 0.8, 0.6, 0), (pose, 0.95, 0.5, 0.25, 0), (pose, 1.04, 0.3, 0.08, 0), (pose, 1.0, 0.15, 0, 0),
            (pose, 1.0, 0, 0, -6), (pose, 1.0, 0, 0, -10), (pose, 1.0, 0, 0, -6), (pose, 1.0, 0, 0, 0)]
        frames = []
        for p, sc, glow, wh, dy in plan:
            f = Image.new('RGBA', (FS, FS), (0, 0, 0, 0))
            if glow > 0:
                gs = int(FS * (0.5 + 0.5 * glow))
                f.alpha_composite(glow_disc(gs, col, glow), ((FS - gs) // 2, PIV[1] - cr.height // 2 - gs // 2))
            if p is None:
                p, sc = wpose, 0.12
            stamp(f, p[0], (PIV[0], PIV[1] - int((1 - sc) * cr.height * 0.35)), p[1], sc, sc, dy, wh)
            frames.append(f)
        key = '%s_%s' % (stage, elem)
        save_sheet(frames, U + 'invocateurs/esprits/%s.png' % key)
        invo['animations'][key].update({'taille_image': [FS, FS], 'pivot': list(PIV), 'images': 12, 'colonnes': COLS,
            'lisse': True, 'echelle_jardin': GARDEN_SCALE[stage], 'durees_ms': [100] * 10 + [120, 280]})
        for name, px in [(64, 128), (128, 256)]:  # icônes (dessinées deux fois plus fines que leur nom)
            ic = Image.new('RGBA', (px, px), (0, 0, 0, 0))
            m = px * 0.9
            q = min(m / cr.width, m / cr.height)
            t = resize(cr, cr.width * q, cr.height * q)
            ic.alpha_composite(t, ((px - t.width) // 2, (px - t.height) // 2))
            ic.save(U + 'coffres/esprits/esprit_%s_%d.png' % (key, name), optimize=True)
json.dump(invo, open(invp, 'w', encoding='utf8', newline='\n'), ensure_ascii=False, indent=2)
print('esprits : 20 planches et 40 icônes')
