"""Blockstates, block/item models (including the 3D weapon models) and sounds.json.

    python3 gen_models.py <mod_assets_dir>

Weapons are built from cuboids painted with swatches of item/gun_palette.png,
muzzle pointing to -Z (north) so the default first/third person pose aims forward.
"""
import json
import os
import sys

NS = 'scpzone19'

CUBE_BLOCKS = ['concrete_wall', 'concrete_wall_trim', 'white_wall', 'white_wall_trim', 'tile_floor',
               'concrete_floor', 'metal_panel', 'dirty_metal', 'office_wall', 'hazard_stripe',
               'ceiling_light', 'emergency_light', 'facility_glass']
DOORS = {'lcz_door': 'door_lcz', 'heavy_door': 'door_heavy'}
TERMINALS = {'recontainment_terminal': 'terminal', 'control_console': 'console',
             'backup_generator': 'generator', 'femur_breaker': 'femur'}
LOCKERS = {'armory_locker': 'locker_armory', 'medical_cabinet': 'locker_medical', 'o5_safe': 'locker_o5'}
FLAT_ITEMS = {
    'keycard_1': 'keycard_1', 'keycard_2': 'keycard_2', 'keycard_3': 'keycard_3', 'keycard_4': 'keycard_4',
    'keycard_5': 'keycard_5', 'keycard_omni': 'keycard_omni', 'ammo_9mm': 'ammo_9mm', 'ammo_57': 'ammo_57',
    'ammo_12g': 'ammo_12g', 'scp500': 'scp500', 'first_aid': 'first_aid', 'eyedrops': 'eyedrops',
    'radio': 'radio', 'snav': 'snav', 'gas_mask': 'gas_mask', 'ballistic_vest': 'ballistic_vest',
    'doc_173': 'document', 'doc_096': 'document', 'doc_106': 'document', 'doc_049': 'document',
}
SPAWN_EGGS = ['scp173_spawn_egg', 'scp096_spawn_egg', 'scp106_spawn_egg', 'scp049_2_spawn_egg']
FACING_Y = {'north': 0, 'east': 90, 'south': 180, 'west': 270}

# palette swatch indices (see gen_textures.GUN_PALETTE)
BLACK, DARK, GUNMETAL, STEEL, TAN, OLIVE, WOOD, ORANGE, RED, LENS, WHITE, BRASS, RUBBER, LIGHT, BLUE, CHAR = range(16)


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')


def uv(i):
    c, r = i % 4, i // 4
    return [c * 4 + 0.5, r * 4 + 0.5, c * 4 + 3.5, r * 4 + 3.5]


def box(frm, to, color, rot=None):
    e = {'from': list(frm), 'to': list(to),
         'faces': {f: {'uv': uv(color), 'texture': '#0'} for f in ('north', 'south', 'east', 'west', 'up', 'down')}}
    if rot:
        origin, axis, angle = rot
        e['rotation'] = {'origin': list(origin), 'axis': axis, 'angle': angle}
    return e


GUNS = {
    'usp': dict(grip=(8, 6.0, 9.6), parts=[
        box((7.2, 8.5, 2.5), (8.8, 10.0, 10.5), BLACK),
        box((7.6, 8.9, 2.0), (8.4, 9.6, 2.5), RUBBER),
        box((7.25, 7.7, 3.2), (8.75, 8.5, 10.2), DARK),
        box((7.85, 10.0, 3.0), (8.15, 10.35, 3.4), WHITE),
        box((7.5, 10.0, 9.6), (8.5, 10.35, 10.1), BLACK),
        box((7.2, 4.0, 8.4), (8.8, 7.8, 10.6), DARK, ((8, 7.8, 9.5), 'x', -22.5)),
        box((7.15, 4.6, 8.9), (8.85, 7.2, 10.1), CHAR, ((8, 7.8, 9.5), 'x', -22.5)),
        box((7.6, 6.8, 6.6), (8.4, 7.1, 8.6), DARK),
        box((7.6, 6.8, 6.6), (8.4, 7.7, 6.9), DARK),
        box((7.85, 7.0, 7.6), (8.15, 7.7, 7.9), RUBBER),
    ]),
    'mp5sd': dict(grip=(8, 5.5, 11.8), parts=[
        box((7.25, 8.0, -4.0), (8.75, 9.5, 3.0), BLACK),
        box((7.0, 7.5, 3.0), (9.0, 9.4, 7.0), DARK),
        box((6.95, 7.9, 3.5), (9.05, 8.1, 6.5), RUBBER),
        box((7.1, 8.0, 7.0), (8.9, 10.0, 13.0), GUNMETAL),
        box((7.4, 10.0, 2.5), (8.6, 10.4, 12.5), BLACK),
        box((7.5, 10.4, 3.0), (8.5, 11.4, 3.6), BLACK),
        box((7.4, 10.4, 11.4), (8.6, 11.2, 12.4), BLACK),
        box((7.35, 3.6, 7.6), (8.65, 8.0, 8.9), BLACK, ((8, 8, 8.2), 'x', 22.5)),
        box((7.2, 7.4, 7.4), (8.8, 8.0, 9.2), GUNMETAL),
        box((7.3, 7.0, 9.4), (8.7, 8.0, 12.6), DARK),
        box((7.25, 3.8, 11.0), (8.75, 7.2, 12.6), DARK, ((8, 7.2, 11.8), 'x', -22.5)),
        box((7.85, 6.4, 10.1), (8.15, 7.0, 10.4), RUBBER),
        box((7.3, 8.4, 13.0), (7.6, 8.9, 17.5), BLACK),
        box((8.4, 8.4, 13.0), (8.7, 8.9, 17.5), BLACK),
        box((7.0, 6.2, 17.5), (9.0, 9.4, 18.0), RUBBER),
    ]),
    'p90': dict(grip=(8, 6.6, 8.4), parts=[
        box((7.0, 8.2, 2.5), (9.0, 9.4, 15.0), BLACK),
        box((7.1, 9.4, 3.5), (8.9, 10.4, 13.0), STEEL),
        box((7.3, 10.4, 6.5), (8.7, 11.6, 9.5), BLACK),
        box((7.5, 10.6, 6.45), (8.5, 11.4, 6.5), LENS),
        box((7.55, 8.4, 0.8), (8.45, 9.2, 2.5), RUBBER),
        box((7.0, 5.2, 2.5), (9.0, 8.2, 3.6), BLACK),
        box((7.0, 5.2, 3.6), (9.0, 6.0, 6.0), BLACK),
        box((7.0, 5.2, 6.0), (9.0, 8.2, 7.2), BLACK),
        box((7.0, 4.0, 9.6), (9.0, 8.2, 15.0), BLACK),
        box((7.0, 4.0, 7.2), (9.0, 5.0, 9.6), BLACK),
        box((6.9, 4.0, 15.0), (9.1, 9.4, 15.6), RUBBER),
        box((7.85, 6.0, 4.6), (8.15, 6.8, 4.9), GUNMETAL),
    ]),
    'spas12': dict(grip=(8, 5.5, 11.0), parts=[
        box((7.4, 8.8, -6.0), (8.6, 9.8, 8.0), BLACK),
        box((7.45, 7.6, -4.5), (8.55, 8.8, 6.0), GUNMETAL),
        box((7.3, 8.7, -5.0), (8.7, 10.0, 1.0), DARK),
        box((7.0, 7.2, -1.5), (9.0, 9.0, 3.5), RUBBER),
        box((6.95, 7.6, -1.0), (9.05, 7.8, 3.0), DARK),
        box((7.0, 7.4, 6.0), (9.0, 10.0, 11.5), GUNMETAL),
        box((7.6, 6.4, 8.0), (8.4, 6.7, 10.5), BLACK),
        box((7.85, 6.7, 8.8), (8.15, 7.4, 9.1), RUBBER),
        box((7.25, 3.6, 10.2), (8.75, 7.4, 11.8), RUBBER, ((8, 7.4, 11), 'x', -22.5)),
        box((7.6, 9.6, 11.5), (8.4, 10.0, 18.0), BLACK),
        box((7.6, 7.0, 11.5), (8.4, 7.4, 16.5), BLACK),
        box((7.4, 6.2, 17.6), (8.6, 10.0, 18.2), BLACK),
    ]),
}

BATON = [
    box((7.5, 3.0, 7.5), (8.5, 16.0, 8.5), RUBBER),
    box((7.35, 0.0, 7.35), (8.65, 5.0, 8.65), DARK),
    box((7.4, 15.3, 7.4), (8.6, 16.3, 8.6), GUNMETAL),
    box((7.5, 4.0, 8.5), (8.5, 5.0, 11.5), RUBBER),
    box((7.6, 16.3, 7.8), (7.9, 16.8, 8.2), STEEL),
    box((8.1, 16.3, 7.8), (8.4, 16.8, 8.2), STEEL),
    box((7.45, 9.0, 7.45), (8.55, 9.4, 8.55), BRASS),
]


def gun_model(spec):
    parts = spec['parts']
    gx, gy, gz = spec['grip']
    zs = [p['from'][2] for p in parts] + [p['to'][2] for p in parts]
    ys = [p['from'][1] for p in parts] + [p['to'][1] for p in parts]
    length = max(zs) - min(zs)
    cy, cz = (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2
    gs = round(min(1.0, 15.0 / length), 3)
    r = lambda v: round(v, 3)
    tp = 0.8
    fp = 0.75
    return {
        'credit': 'SCP: Zone-19',
        'texture_size': [16, 16],
        'gui_light': 'front',
        'textures': {'0': f'{NS}:item/gun_palette', 'particle': f'{NS}:item/gun_palette'},
        'elements': parts,
        'display': {
            'thirdperson_righthand': {'rotation': [0, 0, 0],
                                      'translation': [0, r((8 - gy) * tp), r((8 - gz) * tp)],
                                      'scale': [tp, tp, tp]},
            'firstperson_righthand': {'rotation': [0, 4, 0],
                                      'translation': [-1, r((8 - gy) * fp + 1.5), r((8 - gz) * fp - 1)],
                                      'scale': [fp, fp, fp]},
            'gui': {'rotation': [0, -90, 0], 'translation': [r((cz - 8) * gs), r(-(cy - 8) * gs), 0],
                    'scale': [gs, gs, gs]},
            'ground': {'rotation': [0, 0, 0], 'translation': [0, 2, 0], 'scale': [0.5, 0.5, 0.5]},
            'fixed': {'rotation': [0, -90, 0], 'translation': [r((cz - 8) * gs), r(-(cy - 8) * gs), 0],
                      'scale': [gs, gs, gs]},
        },
    }


def baton_model():
    return {
        'texture_size': [16, 16],
        'gui_light': 'front',
        'textures': {'0': f'{NS}:item/gun_palette', 'particle': f'{NS}:item/gun_palette'},
        'elements': BATON,
        'display': {
            'thirdperson_righthand': {'rotation': [0, -90, 55], 'translation': [0, 4, 0.5], 'scale': [0.85, 0.85, 0.85]},
            'firstperson_righthand': {'rotation': [0, -90, 25], 'translation': [1.13, 3.2, 1.13], 'scale': [0.68, 0.68, 0.68]},
            'gui': {'rotation': [0, 0, -45], 'translation': [0, 0, 0], 'scale': [0.9, 0.9, 0.9]},
            'ground': {'rotation': [0, 0, 0], 'translation': [0, 2, 0], 'scale': [0.5, 0.5, 0.5]},
            'fixed': {'rotation': [0, 0, -45], 'scale': [0.9, 0.9, 0.9]},
        },
    }


def door_model(tex, half):
    faces = {}
    for f in ('north', 'south'):
        faces[f] = {'texture': '#door', 'uv': [0, 0, 16, 16] if f == 'north' else [16, 0, 0, 16], 'cullface': f}
    for f in ('east', 'west', 'up', 'down'):
        faces[f] = {'texture': '#frame', 'uv': [0, 0, 16, 16], 'cullface': f}
    return {
        'parent': 'minecraft:block/block',
        'textures': {'door': f'{NS}:block/{tex}_{half}', 'frame': f'{NS}:block/door_frame',
                     'particle': f'{NS}:block/door_frame'},
        'elements': [{'from': [0, 0, 0], 'to': [16, 16, 16], 'faces': faces}],
    }


def sounds_json():
    def ev(*files, stream=False, sub=None):
        d = {'sounds': [{'name': f'{NS}:{f}', 'stream': True} if stream else f'{NS}:{f}' for f in files]}
        if sub:
            d['subtitle'] = f'subtitles.{NS}.{sub}'
        return d
    return {
        'ambient.zone': ev('ambient/ambient1', 'ambient/ambient2', 'ambient/ambient3', sub='ambient'),
        'alarm': ev('alarm/alarm', sub='alarm'),
        'alarm.long': ev('alarm/alarm_long', stream=True, sub='alarm'),
        'door.open': ev('door/open', sub='door_open'),
        'door.close': ev('door/close', sub='door_close'),
        'door.big_open': ev('door/big_open', sub='door_open'),
        'door.error': ev('door/error', sub='door_error'),
        'keycard': ev('interact/keycard', sub='keycard'),
        'button': ev('interact/button', sub='button'),
        'pickup': ev('interact/pickup'),
        'gun.pistol': ev('gun/shot_pistol', sub='gunshot'),
        'gun.rifle': ev('gun/shot_rifle', sub='gunshot'),
        'scp173.snap': ev('scp173/snap1', 'scp173/snap2', sub='scp173_snap'),
        'scp173.drag': ev('scp173/drag', sub='scp173_drag'),
        'scp173.rattle': ev('scp173/rattle', sub='scp173_drag'),
        'scp096.scream': ev('scp096/scream', stream=True, sub='scp096_scream'),
        'scp096.triggered': ev('scp096/triggered', sub='scp096_triggered'),
        'scp106.laugh': ev('scp106/laugh', sub='scp106_laugh'),
        'scp106.breathing': ev('scp106/breathing', sub='scp106_breathing'),
        'scp106.decay': ev('scp106/decay', sub='scp106_decay'),
        'radio.chatter': ev('radio/chatter1', 'radio/chatter2', sub='radio'),
        'radio.beep': ev('radio/beep', sub='radio'),
        'radio.announcement': ev('radio/announcement', stream=True, sub='announcement'),
        'music.intro': ev('music/intro', stream=True),
        'music.hcz': ev('music/hcz', stream=True),
        'music.chase096': ev('music/chase096', stream=True),
        'music.scp106': ev('music/scp106', stream=True),
        'music.gateb': ev('music/gateb', stream=True),
        'music.menu': ev('music/menu', stream=True),
    }


def main():
    a = sys.argv[1]
    bs, bm, im = f'{a}/blockstates', f'{a}/models/block', f'{a}/models/item'

    for name in CUBE_BLOCKS:
        model = {'parent': 'minecraft:block/cube_all', 'textures': {'all': f'{NS}:block/{name}'}}
        if name == 'facility_glass':
            model['render_type'] = 'minecraft:cutout'
        write(f'{bm}/{name}.json', model)
        write(f'{bs}/{name}.json', {'variants': {'': {'model': f'{NS}:block/{name}'}}})
        write(f'{im}/{name}.json', {'parent': f'{NS}:block/{name}'})

    for name, tex in DOORS.items():
        write(f'{bm}/{name}_lower.json', door_model(tex, 'lower'))
        write(f'{bm}/{name}_upper.json', door_model(tex, 'upper'))
        write(f'{bm}/{name}_open.json', {'textures': {'particle': f'{NS}:block/door_frame'}})
        variants = {}
        for facing, y in FACING_Y.items():
            for open_ in ('false', 'true'):
                for upper in ('false', 'true'):
                    m = f'{name}_open' if open_ == 'true' else f'{name}_{"upper" if upper == "true" else "lower"}'
                    v = {'model': f'{NS}:block/{m}'}
                    if y:
                        v['y'] = y
                    for level in range(6):
                        variants[f'facing={facing},level={level},open={open_},upper={upper}'] = v
        write(f'{bs}/{name}.json', {'variants': variants})
        write(f'{im}/{name}.json', {'parent': f'{NS}:block/{name}_lower'})

    for name, tex in TERMINALS.items():
        for state in ('off', 'on'):
            write(f'{bm}/{name}_{state}.json', {
                'parent': 'minecraft:block/orientable',
                'textures': {'top': f'{NS}:block/machine_top', 'side': f'{NS}:block/machine_side',
                             'front': f'{NS}:block/{tex}_{state}'}})
        variants = {}
        for facing, y in FACING_Y.items():
            for active in ('false', 'true'):
                v = {'model': f'{NS}:block/{name}_{"on" if active == "true" else "off"}'}
                if y:
                    v['y'] = y
                variants[f'active={active},facing={facing}'] = v
        write(f'{bs}/{name}.json', {'variants': variants})
        write(f'{im}/{name}.json', {'parent': f'{NS}:block/{name}_off'})

    for name, tex in LOCKERS.items():
        write(f'{bm}/{name}.json', {
            'parent': 'minecraft:block/orientable',
            'textures': {'top': f'{NS}:block/machine_top', 'side': f'{NS}:block/machine_side',
                         'front': f'{NS}:block/{tex}'}})
        variants = {}
        for facing, y in FACING_Y.items():
            v = {'model': f'{NS}:block/{name}'}
            if y:
                v['y'] = y
            variants[f'facing={facing}'] = v
        write(f'{bs}/{name}.json', {'variants': variants})
        write(f'{im}/{name}.json', {'parent': f'{NS}:block/{name}'})

    for name, tex in FLAT_ITEMS.items():
        write(f'{im}/{name}.json', {'parent': 'minecraft:item/generated', 'textures': {'layer0': f'{NS}:item/{tex}'}})
    for name in SPAWN_EGGS:
        write(f'{im}/{name}.json', {'parent': 'minecraft:item/template_spawn_egg'})
    for name, spec in GUNS.items():
        write(f'{im}/{name}.json', gun_model(spec))
    write(f'{im}/stun_baton.json', baton_model())

    write(f'{a}/sounds.json', sounds_json())


if __name__ == '__main__':
    main()
