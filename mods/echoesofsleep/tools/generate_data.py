#!/usr/bin/env python3
"""Generates blockstates, item/block models, loot tables, recipes, tags, worldgen and sounds.json
for Echoes of Sleep. Run from anywhere: python3 tools/generate_data.py"""
import json, os

MOD = 'echoesofsleep'
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'main', 'resources')
A = os.path.join(ROOT, 'assets', MOD)
D = os.path.join(ROOT, 'data', MOD)
MC = os.path.join(ROOT, 'data', 'minecraft')


def w(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
        f.write('\n')


def m(name):
    return '%s:%s' % (MOD, name)


# ---------------------------------------------------------------- blocks
BLOCKS = {
    'dream_shard_ore': {'parent': 'minecraft:block/cube_all', 'textures': {'all': m('block/dream_shard_ore')}},
    'deepslate_dream_shard_ore': {'parent': 'minecraft:block/cube_all', 'textures': {'all': m('block/deepslate_dream_shard_ore')}},
    'ashen_grass': {'parent': 'minecraft:block/cube_bottom_top', 'textures': {
        'top': m('block/ashen_grass_top'), 'side': m('block/ashen_grass_side'), 'bottom': 'minecraft:block/dirt'}},
    'dreamrot': {'parent': 'minecraft:block/cube_all', 'textures': {'all': m('block/dreamrot')}},
    'weeping_leaves': {'parent': 'minecraft:block/cube_all', 'render_type': 'minecraft:cutout_mipped',
                       'textures': {'all': m('block/weeping_leaves')}},
}
for name, model in BLOCKS.items():
    w(f'{A}/blockstates/{name}.json', {'variants': {'': {'model': m('block/' + name)}}})
    w(f'{A}/models/block/{name}.json', model)
    w(f'{A}/models/item/{name}.json', {'parent': m('block/' + name)})


def ore_loot(name):
    return {'type': 'minecraft:block', 'random_sequence': m('blocks/' + name), 'pools': [{
        'rolls': 1.0, 'bonus_rolls': 0.0, 'entries': [{'type': 'minecraft:alternatives', 'children': [
            {'type': 'minecraft:item', 'name': m(name), 'conditions': [{'condition': 'minecraft:match_tool', 'predicate': {
                'predicates': {'minecraft:enchantments': [{'enchantments': 'minecraft:silk_touch', 'levels': {'min': 1}}]}}}]},
            {'type': 'minecraft:item', 'name': m('dream_shard'), 'functions': [
                {'function': 'minecraft:set_count', 'count': {'type': 'minecraft:uniform', 'min': 1.0, 'max': 2.0}},
                {'function': 'minecraft:apply_bonus', 'enchantment': 'minecraft:fortune', 'formula': 'minecraft:ore_drops'},
                {'function': 'minecraft:explosion_decay'}]}]}]}]}


w(f'{D}/loot_table/blocks/dream_shard_ore.json', ore_loot('dream_shard_ore'))
w(f'{D}/loot_table/blocks/deepslate_dream_shard_ore.json', ore_loot('deepslate_dream_shard_ore'))
# Dream blocks only exist while the world dreams: breaking one dissolves it back into the original block.
for name in ('ashen_grass', 'dreamrot', 'weeping_leaves'):
    w(f'{D}/loot_table/blocks/{name}.json', {'type': 'minecraft:block', 'random_sequence': m('blocks/' + name), 'pools': []})

# ---------------------------------------------------------------- items
GENERATED = ['dream_shard', 'dawn_ingot', 'nightmare_heart', 'dawn_tincture', 'dream_totem', 'insomnia_lantern']
for s in ('dreamcatcher', 'wakeful', 'nightmare_eater'):
    for p in ('helmet', 'chestplate', 'leggings', 'boots'):
        GENERATED.append(f'{s}_{p}')
for name in GENERATED:
    w(f'{A}/models/item/{name}.json', {'parent': 'minecraft:item/generated', 'textures': {'layer0': m('item/' + name)}})
for name in ('dawn_blade', 'echo_scythe', 'lullaby_staff'):
    w(f'{A}/models/item/{name}.json', {'parent': 'minecraft:item/handheld', 'textures': {'layer0': m('item/' + name)}})
EGGS = ['echo_doppelganger', 'stitcher', 'sleepless', 'hollow_villager', 'deep_mother', 'the_dreamer']
for e in EGGS:
    w(f'{A}/models/item/{e}_spawn_egg.json', {'parent': 'minecraft:item/template_spawn_egg'})

# ---------------------------------------------------------------- entity loot
def item_entry(item, lo, hi, looting=1.0, weight=None):
    e = {'type': 'minecraft:item', 'name': item, 'functions': [
        {'function': 'minecraft:set_count', 'count': {'type': 'minecraft:uniform', 'min': float(lo), 'max': float(hi)}},
        {'function': 'minecraft:enchanted_count_increase', 'enchantment': 'minecraft:looting',
         'count': {'type': 'minecraft:uniform', 'min': 0.0, 'max': float(looting)}}]}
    if weight:
        e['weight'] = weight
    return e


def pool(entries, rolls=1.0, player_only=False, chance=None):
    p = {'rolls': rolls, 'bonus_rolls': 0.0, 'entries': entries}
    cond = []
    if player_only:
        cond.append({'condition': 'minecraft:killed_by_player'})
    if chance is not None:
        cond.append({'condition': 'minecraft:random_chance', 'chance': chance})
    if cond:
        p['conditions'] = cond
    return p


def entity_loot(name, pools):
    w(f'{D}/loot_table/entities/{name}.json', {'type': 'minecraft:entity', 'random_sequence': m('entities/' + name), 'pools': pools})


entity_loot('echo_doppelganger', [pool([item_entry(m('dream_shard'), 1, 2)]),
                                  pool([item_entry('minecraft:ender_pearl', 1, 1, 0)], player_only=True, chance=0.15)])
entity_loot('stitcher', [pool([item_entry(m('dream_shard'), 1, 3)]),
                         pool([item_entry('minecraft:rotten_flesh', 1, 3, 1, 3), item_entry('minecraft:bone', 1, 3, 1, 3),
                               item_entry('minecraft:string', 1, 3, 1, 2), item_entry('minecraft:spider_eye', 1, 1, 1, 1)])])
entity_loot('sleepless', [pool([item_entry(m('dream_shard'), 2, 4)]),
                          pool([item_entry('minecraft:ender_pearl', 1, 2)], player_only=True, chance=0.5),
                          pool([item_entry(m('insomnia_lantern'), 1, 1, 0)], player_only=True, chance=0.05)])
entity_loot('hollow_villager', [pool([item_entry(m('dream_shard'), 0, 2)]),
                                pool([item_entry('minecraft:emerald', 1, 2)], player_only=True, chance=0.35)])
entity_loot('deep_mother', [pool([item_entry(m('nightmare_heart'), 1, 1, 0)]),
                            pool([item_entry(m('dream_shard'), 8, 14, 3)]),
                            pool([item_entry(m('dawn_ingot'), 2, 4, 1)])])
entity_loot('the_dreamer', [pool([item_entry(m('nightmare_heart'), 2, 2, 1)]),
                            pool([item_entry(m('dream_shard'), 12, 20, 4)]),
                            pool([item_entry(m('dawn_ingot'), 3, 6, 1)]),
                            pool([item_entry('minecraft:nether_star', 1, 1, 0)], chance=0.35)])
entity_loot('mother_hand', [])

# ---------------------------------------------------------------- recipes
def shaped(name, pattern, key, result, count=1, cat='misc'):
    w(f'{D}/recipe/{name}.json', {'type': 'minecraft:crafting_shaped', 'category': cat, 'pattern': pattern,
                                  'key': {k: {'item': v} for k, v in key.items()}, 'result': {'id': result, 'count': count}})


def shapeless(name, items, result, count=1, cat='misc'):
    w(f'{D}/recipe/{name}.json', {'type': 'minecraft:crafting_shapeless', 'category': cat,
                                  'ingredients': [{'item': i} for i in items], 'result': {'id': result, 'count': count}})


for kind, t, xp in (('smelting', 200, 1.0), ('blasting', 100, 1.0)):
    for ore in ('dream_shard_ore', 'deepslate_dream_shard_ore'):
        w(f'{D}/recipe/dream_shard_from_{kind}_{ore}.json', {'type': 'minecraft:' + kind, 'category': 'misc',
                                                              'ingredient': {'item': m(ore)}, 'result': {'id': m('dream_shard')},
                                                              'experience': xp, 'cookingtime': t})

shapeless('dawn_ingot', [m('dream_shard'), m('dream_shard'), 'minecraft:gold_ingot', 'minecraft:glowstone_dust'], m('dawn_ingot'))
shapeless('dawn_tincture', ['minecraft:glass_bottle', m('dream_shard'), 'minecraft:glowstone_dust', 'minecraft:sunflower'], m('dawn_tincture'))
shaped('dream_totem', [' E ', 'SDS', ' O '], {'E': 'minecraft:ender_eye', 'S': m('dream_shard'), 'D': m('dawn_ingot'),
                                               'O': 'minecraft:crying_obsidian'}, m('dream_totem'))
shaped('dawn_blade', [' D ', ' D ', ' B '], {'D': m('dawn_ingot'), 'B': 'minecraft:blaze_rod'}, m('dawn_blade'), cat='equipment')
shaped('echo_scythe', ['SSN', ' B ', 'B  '], {'S': m('dream_shard'), 'N': m('nightmare_heart'), 'B': 'minecraft:bone'},
       m('echo_scythe'), cat='equipment')
shaped('lullaby_staff', ['  N', ' D ', 'S  '], {'N': 'minecraft:note_block', 'D': m('dream_shard'), 'S': 'minecraft:stick'},
       m('lullaby_staff'), cat='equipment')
shaped('insomnia_lantern', [' N ', 'DLD', ' N '], {'N': 'minecraft:iron_nugget', 'D': m('dream_shard'), 'L': 'minecraft:soul_lantern'},
       m('insomnia_lantern'), cat='equipment')

ARMOR = {'helmet': ['XXX', 'X X'], 'chestplate': ['X X', 'XXX', 'XXX'], 'leggings': ['XXX', 'X X', 'X X'], 'boots': ['X X', 'X X']}
for piece, pat in ARMOR.items():
    shaped(f'dreamcatcher_{piece}', pat, {'X': m('dream_shard')}, m(f'dreamcatcher_{piece}'), cat='equipment')
    shaped(f'wakeful_{piece}', pat, {'X': m('dawn_ingot')}, m(f'wakeful_{piece}'), cat='equipment')
EATER = {'helmet': ['DHD', 'D D'], 'chestplate': ['D D', 'DHD', 'DDD'], 'leggings': ['DHD', 'D D', 'D D'], 'boots': ['D D', 'DHD']}
for piece, pat in EATER.items():
    shaped(f'nightmare_eater_{piece}', pat, {'D': m('dawn_ingot'), 'H': m('nightmare_heart')}, m(f'nightmare_eater_{piece}'), cat='equipment')

# ---------------------------------------------------------------- tags
def tag(path, values):
    w(path, {'replace': False, 'values': values})


ORES = [m('dream_shard_ore'), m('deepslate_dream_shard_ore')]
tag(f'{MC}/tags/block/mineable/pickaxe.json', ORES)
tag(f'{MC}/tags/block/needs_iron_tool.json', ORES)
tag(f'{MC}/tags/block/mineable/shovel.json', [m('ashen_grass')])
tag(f'{MC}/tags/block/mineable/hoe.json', [m('dreamrot'), m('weeping_leaves')])
tag(f'{MC}/tags/item/swords.json', [m('dawn_blade'), m('echo_scythe')])
for t in ('enchantable/sword', 'enchantable/weapon', 'enchantable/sharp_weapon', 'enchantable/fire_aspect'):
    tag(f'{MC}/tags/item/{t}.json', [m('dawn_blade'), m('echo_scythe')])
ALL_ARMOR = [m(f'{s}_{p}') for s in ('dreamcatcher', 'wakeful', 'nightmare_eater') for p in ARMOR]
tag(f'{MC}/tags/item/enchantable/durability.json', [m('dawn_blade'), m('echo_scythe'), m('lullaby_staff')] + ALL_ARMOR)
tag(f'{MC}/tags/item/enchantable/armor.json', ALL_ARMOR)
tag(f'{MC}/tags/item/enchantable/equippable.json', ALL_ARMOR)
tag(f'{MC}/tags/item/trimmable_armor.json', ALL_ARMOR)
for piece, tname in (('helmet', 'head_armor'), ('chestplate', 'chest_armor'), ('leggings', 'leg_armor'), ('boots', 'foot_armor')):
    items = [m(f'{s}_{piece}') for s in ('dreamcatcher', 'wakeful', 'nightmare_eater')]
    tag(f'{MC}/tags/item/{tname}.json', items)
    tag(f'{MC}/tags/item/enchantable/{tname}.json', items)

# ---------------------------------------------------------------- worldgen
w(f'{D}/worldgen/configured_feature/dream_shard_ore.json', {'type': 'minecraft:ore', 'config': {
    'size': 4, 'discard_chance_on_air_exposure': 0.5, 'targets': [
        {'target': {'predicate_type': 'minecraft:tag_match', 'tag': 'minecraft:stone_ore_replaceables'},
         'state': {'Name': m('dream_shard_ore')}},
        {'target': {'predicate_type': 'minecraft:tag_match', 'tag': 'minecraft:deepslate_ore_replaceables'},
         'state': {'Name': m('deepslate_dream_shard_ore')}}]}})
w(f'{D}/worldgen/placed_feature/dream_shard_ore.json', {'feature': m('dream_shard_ore'), 'placement': [
    {'type': 'minecraft:count', 'count': 2},
    {'type': 'minecraft:in_square'},
    {'type': 'minecraft:height_range', 'height': {'type': 'minecraft:trapezoid',
                                                  'min_inclusive': {'above_bottom': 0}, 'max_inclusive': {'absolute': 0}}},
    {'type': 'minecraft:biome'}]})
w(f'{D}/forge/biome_modifier/add_dream_shard_ore.json', {'type': 'forge:add_features', 'biomes': '#minecraft:is_overworld',
                                                         'features': m('dream_shard_ore'), 'step': 'underground_ores'})

# ---------------------------------------------------------------- sounds.json
def snd(files, subtitle, stream=False, **kw):
    sounds = []
    for f in files:
        e = {'name': m(f)}
        e.update(kw)
        if stream:
            e['stream'] = True
        sounds.append(e)
    return {'subtitle': 'subtitles.%s.%s' % (MOD, subtitle), 'sounds': sounds}


def varied(files, subtitle, pitches=(0.85, 1.0, 1.15)):
    """Every file at three pitches, so repeated whispers and footsteps never sound identical."""
    sounds = [{'name': m(f), 'pitch': p} for f in files for p in pitches]
    return {'subtitle': 'subtitles.%s.%s' % (MOD, subtitle), 'sounds': sounds}


SOUNDS = {
    'ambient.whisper': varied(['whisper1', 'whisper2', 'whisper3'], 'whisper'),
    'ambient.heartbeat': snd(['heartbeat'], 'heartbeat'),
    'ambient.drone': snd(['drone'], 'drone'),
    'ambient.footsteps': varied(['footstep1', 'footstep2'], 'footsteps'),
    'event.wake_scream': snd(['scream'], 'wake_scream'),
    'event.glitch': snd(['glitch'], 'glitch'),
    'event.creak': snd(['creak'], 'creak'),
    'entity.echo_doppelganger.ambient': varied(['breath', 'whisper2'], 'doppelganger_ambient', (0.9, 1.0)),
    'entity.echo_doppelganger.hurt': snd(['gasp'], 'doppelganger_hurt'),
    'entity.echo_doppelganger.death': snd(['reverse_swell'], 'doppelganger_death'),
    'entity.echo_doppelganger.scream': snd(['scream'], 'doppelganger_scream'),
    'entity.stitcher.ambient': snd(['groan'], 'stitcher_ambient'),
    'entity.stitcher.hurt': snd(['wet_tear'], 'stitcher_hurt'),
    'entity.stitcher.death': snd(['flesh_fall'], 'stitcher_death'),
    'entity.sleepless.ambient': snd(['breath'], 'sleepless_ambient'),
    'entity.sleepless.hurt': snd(['bone_snap'], 'sleepless_hurt'),
    'entity.sleepless.death': snd(['bone_death'], 'sleepless_death'),
    'entity.sleepless.sting': snd(['sting'], 'sleepless_sting'),
    'entity.hollow_villager.ambient': varied(['whisper1', 'whisper3'], 'hollow_ambient', (0.7, 0.8)),
    'entity.hollow_villager.hurt': snd(['hollow_moan'], 'hollow_hurt'),
    'entity.hollow_villager.death': snd(['hollow_death'], 'hollow_death'),
    'entity.deep_mother.ambient': snd(['groan', 'rumble'], 'mother_ambient'),
    'entity.deep_mother.hurt': snd(['mother_roar'], 'mother_hurt'),
    'entity.deep_mother.death': snd(['wail', 'rumble'], 'mother_death'),
    'entity.deep_mother.emerge': snd(['rumble'], 'mother_emerge'),
    'entity.the_dreamer.ambient': snd(['drone', 'breath'], 'dreamer_ambient'),
    'entity.the_dreamer.hurt': snd(['choir_hit'], 'dreamer_hurt'),
    'entity.the_dreamer.death': snd(['choir_death'], 'dreamer_death'),
    'entity.the_dreamer.pulse': snd(['pulse'], 'dreamer_pulse'),
    'item.lullaby_staff.use': snd(['lullaby'], 'lullaby'),
    'item.echo_scythe.ghost_slash': snd(['ghost_slash'], 'ghost_slash'),
}
w(f'{A}/sounds.json', SOUNDS)
SOUND_FILES = sorted({s['name'].split(':')[1] for v in SOUNDS.values() for s in v['sounds']})
print('sound files needed:', ' '.join(SOUND_FILES))
