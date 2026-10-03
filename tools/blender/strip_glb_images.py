"""Retire les images intégrées d'un dossier de GLB qui partagent le même atlas.

Les bâtiments du générateur Blender embarquent chacun une copie des 3 textures 2048 (5,5 Mo par
fichier). Le jeu charge l'atlas une seule fois (port_franc.gd, lot1_material()) : on enlève donc
les images, textures et liens de textures, et on reconstruit le buffer binaire.

Usage : python tools/blender/strip_glb_images.py <dossier_GLB_source> <dossier_destination>
"""
import json, os, struct, sys


def strip(raw: bytes) -> bytes:
    jlen, _ = struct.unpack_from('<II', raw, 12)
    doc = json.loads(raw[20:20 + jlen])
    bin_off = 20 + jlen
    blen, _ = struct.unpack_from('<II', raw, bin_off)
    binary = raw[bin_off + 8: bin_off + 8 + blen]
    image_views = {img['bufferView'] for img in doc.get('images', []) if 'bufferView' in img}
    for key in ('images', 'textures', 'samplers'):
        doc.pop(key, None)
    for m in doc.get('materials', []):
        pbr = m.get('pbrMetallicRoughness', {})
        pbr.pop('baseColorTexture', None)
        pbr.pop('metallicRoughnessTexture', None)
        m.pop('normalTexture', None)
        m.pop('occlusionTexture', None)
    new_bin = bytearray()
    remap, views = {}, []
    for i, v in enumerate(doc['bufferViews']):
        if i in image_views:
            continue
        start = v.get('byteOffset', 0)
        while len(new_bin) % 4:
            new_bin.append(0)
        nv = dict(v)
        nv['byteOffset'] = len(new_bin)
        new_bin += binary[start:start + v['byteLength']]
        remap[i] = len(views)
        views.append(nv)
    doc['bufferViews'] = views
    for a in doc.get('accessors', []):
        if 'bufferView' in a:
            a['bufferView'] = remap[a['bufferView']]
    while len(new_bin) % 4:
        new_bin.append(0)
    doc['buffers'] = [{'byteLength': len(new_bin)}]
    js = json.dumps(doc, separators=(',', ':')).encode()
    js += b' ' * ((-len(js)) % 4)
    head = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(js) + 8 + len(new_bin))
    return head + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(new_bin), 0x004E4942) + bytes(new_bin)


if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    for f in sorted(os.listdir(src)):
        if f.endswith('.glb'):
            out = strip(open(os.path.join(src, f), 'rb').read())
            open(os.path.join(dst, f), 'wb').write(out)
            print(f, len(out) // 1024, 'Ko')
