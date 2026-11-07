"""Static intake gate for untrusted GLB files; does not execute Blender or scripts.

Passing this gate does not certify appearance, deformation, orientation, or gameplay.
Usage: python scripts/check_character_glb.py FILE --character noen
"""
import argparse
import json
from pathlib import Path
import struct

BUDGETS = {'noen': (15000, 40000), 'sheila': (15000, 40000),
           'undertaker': (30000, 60000), 'ashwalker': (10000, 20000)}


def inspect(path, character):
    if path.stat().st_size > 50 * 1024 * 1024:
        raise ValueError('File exceeds the 50 MiB intake limit')
    raw = path.read_bytes()
    if len(raw) < 20:
        raise ValueError('Truncated GLB')
    magic, version, length = struct.unpack_from('<III', raw)
    if magic != 0x46546C67 or version != 2 or length != len(raw):
        raise ValueError('Invalid GLB 2.0 header or declared length')
    chunks, offset = {}, 12
    while offset < length:
        if offset + 8 > length:
            raise ValueError('Truncated chunk header')
        size, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        if size % 4 or offset + size > length or kind in chunks:
            raise ValueError('Invalid chunk size or duplicate chunk')
        chunks[kind] = raw[offset:offset + size]
        offset += size
    data = json.loads(chunks[0x4E4F534A])
    errors = []
    if not chunks.get(0x004E4942):
        errors.append('Embedded binary buffer missing')
    if any('uri' in b for b in data.get('buffers', [])):
        errors.append('External buffer URI is not permitted')
    accessors = data.get('accessors', [])
    triangles = 0
    for node in data.get('nodes', []):
        if 'mesh' not in node:
            continue
        if 'skin' not in node:
            errors.append('Mesh node has no skin: ' + node.get('name', '<unnamed>'))
        for primitive in data['meshes'][node['mesh']]['primitives']:
            attrs = primitive.get('attributes', {})
            if not {'POSITION', 'NORMAL', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0'} <= attrs.keys():
                errors.append('Primitive lacks geometry, UV, or skin attributes')
            if primitive.get('mode', 4) != 4:
                errors.append('Only triangle-list primitives supported by this gate')
                continue
            index = primitive.get('indices', attrs.get('POSITION'))
            if index is None:
                errors.append('Primitive has no position/index accessor')
                continue
            count = accessors[index]['count']
            if count % 3:
                errors.append('Triangle list count is not divisible by three')
            triangles += count // 3
    low, high = BUDGETS[character]
    if not low <= triangles <= high:
        errors.append(f'Triangle budget {low}..{high}, found {triangles}')
    if not data.get('skins') or not all(s.get('joints') and 'inverseBindMatrices' in s for s in data.get('skins', [])):
        errors.append('Missing skin joints or inverse bind matrices')
    mats = data.get('materials', [])
    if not mats:
        errors.append('No materials')
    for mat in mats:
        pbr = mat.get('pbrMetallicRoughness', {})
        if not ('baseColorTexture' in pbr and 'metallicRoughnessTexture' in pbr and 'normalTexture' in mat and 'occlusionTexture' in mat):
            errors.append('Missing BaseColor, Normal, or ORM channels: ' + mat.get('name', '<unnamed>'))
        if 'occlusionTexture' in mat and 'metallicRoughnessTexture' in pbr and mat['occlusionTexture']['index'] != pbr['metallicRoughnessTexture']['index']:
            errors.append('Occlusion and metallic/roughness must share a packed ORM texture')
    expected = {'undertaker': 'M_FrameJoint', 'ashwalker': 'M_Dial'}.get(character)
    if expected and expected not in {m.get('name') for m in mats}:
        errors.append('Required independent material slot missing: ' + expected)
    images = data.get('images', [])
    if not images:
        errors.append('No embedded texture images')
    for image in images:
        if 'uri' in image or 'bufferView' not in image:
            errors.append('Texture must be embedded, with no URI')
    return {'file': path.name, 'character': character, 'triangles': triangles,
            'skins': len(data.get('skins', [])), 'materials': len(mats),
            'images': len(images), 'static_gate_pass': not errors, 'errors': errors,
            'manual_checks_required': ['Texture dimensions <=2048 (not decoded by this gate)',
                'Y-up, -Z facing, meter scale and body height',
                'Texture decoding and visual quality', 'Skin weights and posed deformation',
                'Godot import, animation playback, attachment and weak-point alignment']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path)
    parser.add_argument('--character', choices=BUDGETS, required=True)
    args = parser.parse_args()
    try:
        result = inspect(args.file, args.character)
    except (ValueError, KeyError, IndexError, TypeError, OSError, struct.error, RecursionError) as error:
        result = {'static_gate_pass': False, 'errors': [str(error)]}
    print(json.dumps(result, indent=2, ensure_ascii=False))
    raise SystemExit(0 if result['static_gate_pass'] else 1)
