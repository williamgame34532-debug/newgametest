"""Guard skins, SCP mob textures and armor layers for SCP: Zone-19.

    python3 -I gen_skins.py <mod_assets_dir> <extra_skins_out_dir>
"""
import os
import sys

from skinpaint import Painter, SIDES, shade

SKIN = '#c99a7a'
SKIN_DARK = '#a87a5c'


def face(p, skin=SKIN, eyes='#2b3a55', hair=None, mouth='#8a5a48'):
    p.fill('head', skin, noise=0.04)
    if hair:
        p.fill('head', hair, faces=('top', 'back'), noise=0.08)
        p.band('head', 0, 1, hair, faces=('right', 'left'))
        p.rect('head', 'front', 0, 0, 7, 0, hair)
    p.rect('head', 'front', 1, 4, 2, 4, '#f0f0f0', 0)
    p.rect('head', 'front', 5, 4, 6, 4, '#f0f0f0', 0)
    p.dot('head', 'front', 2, 4, eyes)
    p.dot('head', 'front', 5, 4, eyes)
    p.rect('head', 'front', 1, 3, 2, 3, shade(skin, 0.75), 0)
    p.rect('head', 'front', 5, 3, 6, 3, shade(skin, 0.75), 0)
    p.dot('head', 'front', 4, 5, shade(skin, 0.85))
    p.rect('head', 'front', 3, 6, 4, 6, mouth, 0)


def scp_patch(p, part, face_name, y):
    """Small white Foundation roundel on a sleeve or chest."""
    p.rect(part, face_name, 1, y, 2, y + 2, '#d8dbde', 0.02)
    p.dot(part, face_name, 1, y + 1, '#3a3d40')
    p.dot(part, face_name, 2, y + 1, '#d8dbde')


def boots(p, color='#101113'):
    for leg in ('rleg', 'lleg'):
        p.band(leg, 9, 11, color)
        p.band(leg, 11, 11, '#2a2a2a')
        p.fill(leg, '#1a1a1a', faces=('bottom',))


def hands(p, color):
    for arm in ('rarm', 'larm'):
        p.band(arm, 10, 11, color)
        p.fill(arm, color, faces=('bottom',))


def guard_standard(seed=11):
    """Security officer: black helmet with smoked visor, navy shirt, plate vest."""
    p = Painter(seed=seed)
    face(p, hair='#3a2a1e')
    navy = '#25303f'
    p.fill('body', navy)
    for arm in ('rarm', 'larm'):
        p.fill(arm, navy)
        p.band(arm, 0, 0, shade(navy, 1.15))
    hands(p, '#141517')
    for leg in ('rleg', 'lleg'):
        p.fill(leg, '#1e2329')
        p.rect(leg, 'front', 0, 4, 3, 5, '#2c3036')
    boots(p)
    # belt
    p.band('body', 10, 11, '#121314')
    p.rect('body', 'front', 3, 10, 4, 10, '#8a8f94', 0)
    # helmet (hat layer)
    hel = '#1c1e21'
    p.fill('hat', hel, faces=('top', 'back'))
    p.band('hat', 0, 2, hel)
    p.band('hat', 3, 4, hel, faces=('right', 'left'))
    p.rect('hat', 'front', 0, 2, 7, 3, (40, 60, 80, 120), 0)
    p.rect('hat', 'front', 0, 1, 7, 1, '#2a2d31', 0)
    p.rect('hat', 'back', 0, 3, 7, 5, hel)
    p.rect('hat', 'right', 0, 7, 0, 7, '#111')
    p.rect('hat', 'left', 7, 7, 7, 7, '#111')
    # vest (jacket layer)
    vest = '#17191c'
    p.fill('jacket', vest, faces=('front', 'back', 'right', 'left', 'top'))
    p.rect('jacket', 'front', 0, 10, 7, 11, (0, 0, 0, 0), 0)
    p.rect('jacket', 'back', 0, 10, 7, 11, (0, 0, 0, 0), 0)
    p.band('jacket', 10, 11, (0, 0, 0, 0), faces=('right', 'left'))
    for x in (0, 3, 6):
        p.rect('jacket', 'front', x, 6, x + 1, 8, '#2a2d31')
    p.rect('jacket', 'front', 1, 1, 2, 2, '#c9a227', 0.02)  # badge
    p.rect('jacket', 'back', 1, 2, 6, 3, '#cfd3d6', 0.02)  # SECURITY strip
    for x in (1, 3, 5):
        p.dot('jacket', 'back', x, 2, '#55595e')
    scp_patch(p, 'rsleeve', 'right', 1)
    p.band('rsleeve', 0, 0, '#17191c')
    p.band('lsleeve', 0, 0, '#17191c')
    # holster
    p.rect('rpants', 'right', 0, 1, 3, 4, '#0e0f10')
    p.rect('rpants', 'right', 1, 2, 2, 2, '#3a3d40', 0)
    return p


def guard_senior(seed=12):
    """Senior officer: peaked cap, grey-blue uniform with tie, red armband."""
    p = Painter(seed=seed)
    face(p, hair='#2a221c')
    uni = '#3d4b5c'
    p.fill('body', uni)
    p.rect('body', 'front', 3, 0, 4, 7, '#141414', 0.02)
    p.rect('body', 'front', 2, 0, 5, 0, '#d9dcdf', 0.02)
    p.rect('body', 'front', 1, 2, 1, 2, '#c9a227', 0)
    for arm in ('rarm', 'larm'):
        p.fill(arm, uni)
        p.fill(arm, '#c9a227', faces=('top',), noise=0.1)
    hands(p, SKIN)
    p.band('larm', 2, 3, '#9b1f1f')
    p.dot('larm', 'left', 1, 2, '#e6e6e6')
    for leg in ('rleg', 'lleg'):
        p.fill(leg, '#2b2f36')
        p.rect(leg, 'right', 2, 0, 2, 8, '#c9a227', 0.05)
    boots(p, '#0c0c0c')
    p.band('body', 10, 11, '#1a1a1a')
    p.rect('body', 'front', 3, 10, 4, 11, '#c9a227', 0)
    cap = '#2d3846'
    p.fill('hat', cap, faces=('top',))
    p.band('hat', 0, 1, cap)
    p.rect('hat', 'front', 0, 2, 7, 2, '#111', 0)
    p.rect('hat', 'front', 3, 0, 4, 1, '#c9a227', 0)
    scp_patch(p, 'rsleeve', 'right', 1)
    return p


def guard_heavy(seed=13):
    """Heavy containment officer: full gas mask helmet and olive armour plates."""
    p = Painter(seed=seed)
    face(p, skin=SKIN_DARK)
    olive = '#2f3328'
    p.fill('body', '#22261e')
    for arm in ('rarm', 'larm'):
        p.fill(arm, '#22261e')
    hands(p, '#111')
    for leg in ('rleg', 'lleg'):
        p.fill(leg, '#272b22')
    boots(p)
    p.band('body', 10, 11, '#111')
    # mask covers everything
    p.fill('hat', '#1b1d1a')
    p.rect('hat', 'front', 0, 0, 7, 7, '#2a2c2a')
    for x in (1, 5):
        p.rect('hat', 'front', x, 3, x + 1, 4, (70, 120, 95, 230), 0)
        p.dot('hat', 'front', x, 3, (160, 220, 190, 230))
    p.rect('hat', 'front', 3, 5, 4, 7, '#3a3d3a')
    p.dot('hat', 'front', 3, 6, '#111')
    p.dot('hat', 'front', 4, 6, '#111')
    p.rect('hat', 'front', 0, 0, 7, 1, '#1b1d1a')
    # plates
    p.fill('jacket', olive, faces=('front', 'back', 'right', 'left', 'top'))
    p.rect('jacket', 'front', 0, 0, 7, 0, shade(olive, 1.3), 0.02)
    p.rect('jacket', 'front', 0, 5, 7, 5, shade(olive, 0.7), 0.02)
    p.rect('jacket', 'front', 2, 2, 5, 3, '#c9a227', 0.05)
    p.rect('jacket', 'front', 3, 2, 4, 3, '#1b1d1a', 0)
    p.band('jacket', 10, 11, (0, 0, 0, 0), faces=SIDES)
    for s in ('rsleeve', 'lsleeve'):
        p.band(s, 0, 3, olive)
        p.fill(s, shade(olive, 1.2), faces=('top',))
    for s in ('rpants', 'lpants'):
        p.band(s, 0, 4, olive)
        p.band(s, 5, 6, '#3b4033', faces=('front',))
    scp_patch(p, 'rsleeve', 'right', 1)
    return p


def guard_night(seed=14):
    """Night shift officer: beret, dark jacket with reflective stripes, headlamp."""
    p = Painter(seed=seed)
    face(p, hair='#1d1712', eyes='#3b2a20')
    jacket = '#1a1d22'
    p.fill('body', jacket)
    for arm in ('rarm', 'larm'):
        p.fill(arm, jacket)
        p.band(arm, 6, 6, '#b8c2c8', noise=0.02)
    hands(p, '#0f0f10')
    for leg in ('rleg', 'lleg'):
        p.fill(leg, '#20242a')
        p.band(leg, 7, 7, '#b8c2c8', noise=0.02)
    boots(p)
    p.band('body', 6, 6, '#b8c2c8', noise=0.02)
    p.band('body', 10, 11, '#0b0b0c')
    p.rect('body', 'front', 3, 0, 4, 9, '#2a2e34')
    p.dot('body', 'front', 6, 2, '#c9a227')
    beret = '#3a1e2a'
    p.fill('hat', beret, faces=('top',))
    p.band('hat', 0, 1, beret)
    p.rect('hat', 'front', 5, 0, 6, 1, '#c9a227', 0)
    p.rect('hat', 'front', 0, 2, 7, 2, '#151515', 0)
    p.rect('hat', 'front', 3, 2, 4, 2, '#fff7c8', 0)
    scp_patch(p, 'rsleeve', 'right', 1)
    p.fill('jacket', (0, 0, 0, 0))
    p.rect('jacket', 'front', 0, 0, 7, 3, '#23272d')
    p.rect('jacket', 'front', 1, 1, 2, 2, '#3c4046')
    return p


def mtf_e11(seed=15):
    """MTF Epsilon-11 'Nine-Tailed Fox' operator: NVG helmet, balaclava, plate carrier."""
    p = Painter(seed=seed)
    face(p, skin='#151617', eyes='#d0d6dc', mouth='#151617')
    p.rect('head', 'front', 0, 4, 7, 4, '#151617', 0)
    p.rect('head', 'front', 1, 4, 2, 4, SKIN, 0)
    p.rect('head', 'front', 5, 4, 6, 4, SKIN, 0)
    p.dot('head', 'front', 2, 4, '#2b3a55')
    p.dot('head', 'front', 5, 4, '#2b3a55')
    p.rect('head', 'front', 1, 3, 6, 3, '#151617', 0)
    blk = '#1b1d20'
    p.fill('body', blk)
    for arm in ('rarm', 'larm'):
        p.fill(arm, '#24272b')
    hands(p, '#0d0e0f')
    for leg in ('rleg', 'lleg'):
        p.fill(leg, '#24272b')
        p.rect(leg, 'front', 0, 4, 3, 5, '#111214')
    boots(p, '#0c0c0d')
    p.band('body', 10, 11, '#101112')
    hel = '#2b2e32'
    p.fill('hat', hel, faces=('top', 'back'))
    p.band('hat', 0, 2, hel)
    p.rect('hat', 'front', 0, 0, 7, 1, hel)
    p.rect('hat', 'front', 2, 1, 5, 2, '#141414', 0)
    p.dot('hat', 'front', 2, 2, '#46ff7a')
    p.dot('hat', 'front', 5, 2, '#46ff7a')
    p.rect('hat', 'right', 2, 3, 4, 4, '#3c3f43')
    # plate carrier with pouches and radio
    car = '#30343a'
    p.fill('jacket', car, faces=('front', 'back', 'right', 'left', 'top'))
    p.band('jacket', 9, 11, (0, 0, 0, 0))
    for x in (0, 3, 6):
        p.rect('jacket', 'front', x, 5, x + 1, 8, '#3c4148')
    p.rect('jacket', 'front', 5, 0, 6, 3, '#151515')
    p.dot('jacket', 'front', 6, 0, '#a3221d')
    p.rect('jacket', 'back', 2, 1, 5, 6, '#2a2e33')
    # fox patch (orange, white tip)
    p.rect('rsleeve', 'right', 0, 1, 3, 3, '#c4621a', 0.04)
    p.dot('rsleeve', 'right', 3, 1, '#e8e8e8')
    p.dot('rsleeve', 'right', 1, 2, '#1a1a1a')
    p.band('lsleeve', 1, 2, '#3c4148')
    return p


def class_d(seed=16):
    p = Painter(seed=seed)
    face(p, skin='#b98463')
    p.fill('head', '#b98463', faces=('top',), noise=0.03)
    orange = '#d5671e'
    p.fill('body', orange)
    p.rect('body', 'front', 2, 0, 5, 0, '#e0e0e0', 0.02)
    p.rect('body', 'back', 2, 2, 5, 4, '#1a1a1a', 0)
    p.rect('body', 'back', 3, 3, 4, 3, orange, 0)
    for arm in ('rarm', 'larm'):
        p.fill(arm, orange)
    hands(p, '#b98463')
    p.band('rarm', 4, 11, '#b98463')
    p.band('larm', 4, 11, '#b98463')
    for leg in ('rleg', 'lleg'):
        p.fill(leg, orange)
    boots(p, '#262626')
    p.rect('jacket', 'front', 0, 1, 1, 1, '#1a1a1a', 0)
    return p


def scientist(seed=17):
    p = Painter(seed=seed)
    face(p, hair='#5a3d26', eyes='#2f5a3a')
    p.rect('head', 'front', 0, 4, 7, 4, '#1a1a1a', 0)
    p.rect('head', 'front', 1, 4, 2, 4, '#dfe8ee', 0)
    p.rect('head', 'front', 5, 4, 6, 4, '#dfe8ee', 0)
    coat = '#e6e8ea'
    p.fill('body', '#4b6a8a')
    p.rect('body', 'front', 3, 0, 4, 8, '#7a1e22', 0.02)
    for arm in ('rarm', 'larm'):
        p.fill(arm, coat, noise=0.03)
    hands(p, SKIN)
    for leg in ('rleg', 'lleg'):
        p.fill(leg, '#2b2d31')
    boots(p, '#2a1b12')
    p.fill('jacket', coat, faces=('back', 'right', 'left', 'top'), noise=0.03)
    p.rect('jacket', 'front', 0, 0, 1, 11, coat, 0.03)
    p.rect('jacket', 'front', 6, 0, 7, 11, coat, 0.03)
    p.rect('jacket', 'front', 6, 3, 6, 4, '#d0d4d8', 0)
    p.dot('jacket', 'front', 7, 6, '#2a4a7a')
    return p


GUARD_SKINS = {
    'guard_standard': guard_standard,
    'guard_senior': guard_senior,
    'guard_heavy': guard_heavy,
    'guard_night': guard_night,
    'mtf_e11': mtf_e11,
    'class_d': class_d,
    'scientist': scientist,
}


# ---------------------------------------------------------------- SCP mobs
# Mobs using ModelLayers.ZOMBIE: head 0,0 / hat 32,0 / body 16,16 / arm 40,16 / leg 0,16
MOB_PARTS = {
    'head': (0, 0, 8, 8, 8), 'hat': (32, 0, 8, 8, 8), 'body': (16, 16, 8, 12, 4),
    'rarm': (40, 16, 4, 12, 4), 'rleg': (0, 16, 4, 12, 4),
    'larm': (40, 16, 4, 12, 4), 'lleg': (0, 16, 4, 12, 4),
}


def scp096():
    p = Painter(parts=MOB_PARTS, seed=96)
    pale = '#d6d1cb'
    for part in ('head', 'body', 'rarm', 'rleg'):
        p.fill(part, pale, noise=0.05)
    # gaunt face: tiny black eyes, enormous mouth
    p.rect('head', 'front', 1, 2, 2, 2, '#1a1616', 0)
    p.rect('head', 'front', 5, 2, 6, 2, '#1a1616', 0)
    p.rect('head', 'front', 1, 1, 2, 1, '#a9a39c', 0)
    p.rect('head', 'front', 5, 1, 6, 1, '#a9a39c', 0)
    p.rect('head', 'front', 2, 4, 5, 7, '#2a0d0d', 0)
    p.rect('head', 'front', 3, 5, 4, 6, '#5a1414', 0)
    p.rect('head', 'front', 2, 4, 5, 4, '#e8e4dc', 0)
    p.fill('head', '#c7c1ba', faces=('top', 'back'))
    for y in (2, 4, 6):
        p.rect('body', 'front', 1, y, 2, y, '#b5aea6', 0)
        p.rect('body', 'front', 5, y, 6, y, '#b5aea6', 0)
    p.rect('body', 'back', 3, 0, 4, 11, '#bdb6ae', 0.03)
    p.band('rarm', 10, 11, '#c2bbb3')
    return p


def scp106():
    p = Painter(parts=MOB_PARTS, seed=106)
    base = '#2a231c'
    for part in ('head', 'body', 'rarm', 'rleg'):
        p.fill(part, base, noise=0.25)
    for _ in range(140):
        part = p.rng.choice(['head', 'body', 'rarm', 'rleg'])
        f = p.rng.choice(['front', 'back', 'right', 'left'])
        p.dot(part, f, p.rng.randint(0, 7), p.rng.randint(0, 11), p.rng.choice(['#0c0a08', '#3b2e22', '#14100c']))
    p.rect('head', 'front', 1, 3, 2, 3, '#0a0806', 0)
    p.rect('head', 'front', 5, 3, 6, 3, '#0a0806', 0)
    p.dot('head', 'front', 2, 3, '#6d5a3a')
    p.dot('head', 'front', 5, 3, '#6d5a3a')
    p.rect('head', 'front', 2, 5, 5, 7, '#050404', 0)
    p.rect('head', 'front', 2, 5, 5, 5, '#4a3b2c', 0)
    # hat layer: dripping ooze around the head
    p.band('hat', 6, 7, (12, 10, 8, 200), noise=0.2)
    for x in (0, 3, 6):
        p.dot('hat', 'front', x, 7, (12, 10, 8, 220))
    return p


def scp049_2():
    p = Painter(parts=MOB_PARTS, seed=492)
    flesh = '#7d8872'
    p.fill('head', flesh, noise=0.12)
    p.fill('rarm', flesh, noise=0.12)
    gown = '#93aab8'
    p.fill('body', gown, noise=0.07)
    p.fill('rleg', '#6f7a66', noise=0.1)
    p.band('rarm', 0, 3, gown)
    p.band('rleg', 0, 2, gown)
    p.rect('head', 'front', 1, 3, 2, 4, '#e8e4cf', 0)
    p.rect('head', 'front', 5, 3, 6, 4, '#e8e4cf', 0)
    p.dot('head', 'front', 2, 4, '#5a5a4a')
    p.dot('head', 'front', 5, 4, '#5a5a4a')
    p.rect('head', 'front', 2, 6, 5, 7, '#2a1010', 0)
    p.rect('head', 'front', 3, 7, 4, 7, '#6a1515', 0)
    for _ in range(26):
        part = p.rng.choice(['head', 'body', 'rarm'])
        f = p.rng.choice(['front', 'back', 'right', 'left'])
        p.dot(part, f, p.rng.randint(0, 7), p.rng.randint(0, 11), p.rng.choice(['#6a1515', '#4a0e0e', '#7a2020']))
    p.rect('body', 'front', 2, 4, 5, 9, '#7a2020', 0.2)
    p.rect('hat', 'front', 0, 0, 7, 0, (0, 0, 0, 0), 0)
    return p


# SCP-173 uses its own model (see Scp173Model.java)
S173_PARTS = {
    'head': (0, 0, 8, 8, 8),
    'body': (0, 16, 8, 12, 6),
    'arm': (32, 16, 3, 10, 3),
    'leg': (32, 32, 3, 8, 3),
    'nose': (48, 0, 2, 3, 2),
}


def scp173():
    p = Painter(parts=S173_PARTS, seed=173)
    conc = '#c9b48a'
    for part in S173_PARTS:
        p.fill(part, conc, noise=0.12)
    for _ in range(220):
        part = p.rng.choice(list(S173_PARTS))
        f = p.rng.choice(['front', 'back', 'right', 'left', 'top'])
        p.dot(part, f, p.rng.randint(0, 7), p.rng.randint(0, 11),
              p.rng.choice(['#8f7a55', '#a8916a', '#6e5c40', '#b9a27a']))
    # Krylon face: red eyes ringed in green, red streak down from the mouth
    p.rect('head', 'front', 1, 2, 2, 3, '#2f6b2a', 0)
    p.rect('head', 'front', 5, 2, 6, 3, '#2f6b2a', 0)
    p.dot('head', 'front', 1, 3, '#b3201a')
    p.dot('head', 'front', 6, 3, '#b3201a')
    p.dot('head', 'front', 2, 2, '#0f0f0f')
    p.dot('head', 'front', 5, 2, '#0f0f0f')
    p.rect('head', 'front', 3, 1, 4, 6, '#9b1d16', 0.08)
    p.rect('head', 'front', 2, 6, 5, 6, '#1a1a1a', 0)
    p.rect('head', 'front', 3, 7, 4, 7, '#9b1d16', 0)
    p.rect('nose', 'front', 0, 0, 1, 2, '#9b1d16', 0.1)
    for y in range(0, 12, 2):
        p.rect('body', 'front', 3 + (y // 2) % 2, y, 4 + (y // 2) % 2, y + 1, '#8a1f17', 0.1)
    p.rect('body', 'back', 1, 3, 2, 7, '#3d6e34', 0.1)
    p.rect('body', 'back', 5, 2, 6, 5, '#8a1f17', 0.1)
    p.rect('body', 'right', 2, 2, 4, 3, '#6e5c40', 0.05)
    return p


# ---------------------------------------------------------------- armor
ARMOR_PARTS = {'head': (0, 0, 8, 8, 8), 'body': (16, 16, 8, 12, 4),
               'rarm': (40, 16, 4, 12, 4), 'rleg': (0, 16, 4, 12, 4)}


def armor_gasmask():
    p = Painter(64, 32, ARMOR_PARTS, seed=3)
    p.rect('head', 'front', 0, 1, 7, 7, '#2b2e2b', 0.05)
    for x in (1, 5):
        p.rect('head', 'front', x, 2, x + 1, 3, (80, 130, 105, 235), 0)
        p.dot('head', 'front', x, 2, (170, 225, 200, 235))
    p.rect('head', 'front', 3, 4, 4, 7, '#3d413d', 0)
    p.dot('head', 'front', 3, 5, '#151515')
    p.dot('head', 'front', 4, 5, '#151515')
    p.band('head', 3, 3, '#1b1b1b', faces=('right', 'left', 'back'))
    return p


def armor_vest():
    p = Painter(64, 32, ARMOR_PARTS, seed=4)
    p.fill('body', '#202327', faces=('front', 'back', 'right', 'left', 'top'), noise=0.06)
    p.band('body', 10, 11, (0, 0, 0, 0))
    for x in (0, 3, 6):
        p.rect('body', 'front', x, 5, x + 1, 8, '#30343a')
    p.rect('body', 'back', 1, 2, 6, 3, '#cfd3d6', 0.02)
    p.band('rarm', 0, 2, '#202327', faces=('right', 'front', 'back'))
    p.fill('rarm', '#202327', faces=('top',))
    return p


def main():
    assets, extra = sys.argv[1], sys.argv[2]
    os.makedirs(f'{assets}/textures/entity/skins', exist_ok=True)
    os.makedirs(f'{assets}/textures/models/armor', exist_ok=True)
    os.makedirs(extra, exist_ok=True)
    for name, fn in GUARD_SKINS.items():
        img = fn()
        img.save(f'{assets}/textures/entity/skins/{name}.png')
        img.save(f'{extra}/{name}.png')
    scp173().save(f'{assets}/textures/entity/scp173.png')
    scp096().save(f'{assets}/textures/entity/scp096.png')
    scp106().save(f'{assets}/textures/entity/scp106.png')
    scp049_2().save(f'{assets}/textures/entity/scp049_2.png')
    armor_gasmask().save(f'{assets}/textures/models/armor/gasmask_layer_1.png')
    armor_vest().save(f'{assets}/textures/models/armor/tactical_layer_1.png')


if __name__ == '__main__':
    main()
