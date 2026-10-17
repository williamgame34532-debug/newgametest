"""Block, item and GUI textures for the mod plus the interface resource pack.

    python3 gen_textures.py <scpcb_GFX_dir> <mod_assets_dir> <resourcepack_dir>

Photo textures (walls, floors, doors, keycards, documents) are taken from the
SCP - Containment Breach source release (CC BY-SA 3.0, see CREDITS.md); the
rest is drawn here.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

FONT_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_MONO = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
FONT_COND = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'

RNG = random.Random(19)


def mk(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def photo(src, size, crop=None, bright=1.0, contrast=1.0):
    im = Image.open(src).convert('RGB')
    if crop:
        im = im.crop(crop)
    im = im.resize((size, size), Image.LANCZOS)
    if bright != 1.0:
        im = ImageEnhance.Brightness(im).enhance(bright)
    if contrast != 1.0:
        im = ImageEnhance.Contrast(im).enhance(contrast)
    return im.convert('RGBA')


def key_black(im, thr=28):
    """INV icons in SCP:CB sit on black; turn that into transparency."""
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            m = max(r, g, b)
            if m < thr:
                px[x, y] = (r, g, b, 0)
            elif m < thr * 2:
                px[x, y] = (r, g, b, int(255 * (m - thr) / thr))
    return im


def noise_fill(w, h, base, amt=0.08, seed=0):
    rng = random.Random(seed)
    im = Image.new('RGBA', (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            f = 1 + rng.uniform(-amt, amt)
            px[x, y] = tuple(max(0, min(255, int(c * f))) for c in base) + (255,)
    return im


# ------------------------------------------------------------------ blocks
def hazard(size=32):
    im = Image.new('RGBA', (size, size))
    px = im.load()
    for y in range(size):
        for x in range(size):
            stripe = ((x + y) // (size // 4)) % 2 == 0
            c = (214, 168, 30) if stripe else (24, 24, 24)
            f = 1 + RNG.uniform(-0.08, 0.08)
            px[x, y] = tuple(int(min(255, v * f)) for v in c) + (255,)
    return im


def light_panel(size=32, glow=(236, 240, 232), frame=(70, 72, 76)):
    im = noise_fill(size, size, frame, 0.05, 2)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 3, size - 4, size - 4], fill=glow + (255,))
    for i in range(1, 4):
        x = 3 + i * (size - 6) // 4
        d.line([x, 3, x, size - 4], fill=tuple(int(c * 0.86) for c in glow) + (255,))
    d.rectangle([3, 3, size - 4, size - 4], outline=tuple(int(c * 0.75) for c in glow) + (255,))
    return im


def screen_block(kind, active):
    """32px front faces for terminals, consoles, generators and the femur breaker."""
    im = noise_fill(32, 32, (52, 55, 58), 0.06, hash(kind) & 0xff)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 31, 31], outline=(30, 31, 33, 255))
    if kind in ('terminal', 'console'):
        scr = (8, 30, 14) if active else (30, 8, 8)
        txt = (80, 230, 110) if active else (210, 60, 50)
        if kind == 'console':
            scr = (8, 18, 34) if active else (16, 16, 20)
            txt = (110, 180, 255) if active else (90, 90, 100)
        d.rectangle([4, 4, 27, 19], fill=scr + (255,), outline=(20, 20, 22, 255))
        for i, w in enumerate((18, 12, 15, 9)):
            d.line([6, 6 + i * 3, 6 + w, 6 + i * 3], fill=txt + (255,))
        d.rectangle([4, 22, 27, 28], fill=(36, 38, 40, 255))
        for x in range(6, 26, 3):
            d.point((x, 24), fill=(90, 92, 96, 255))
            d.point((x, 26), fill=(90, 92, 96, 255))
        d.rectangle([24, 22, 26, 23], fill=((60, 220, 90) if active else (200, 40, 40)) + (255,))
    elif kind == 'generator':
        d.rectangle([3, 3, 28, 16], fill=(28, 29, 31, 255))
        for y in range(5, 16, 2):
            d.line([5, y, 26, y], fill=(14, 14, 15, 255))
        d.ellipse([5, 18, 15, 28], fill=(210, 205, 190, 255), outline=(20, 20, 20, 255))
        ang = -40 if active else -150
        cx, cy = 10, 23
        d.line([cx, cy, cx + 4 * math.cos(math.radians(ang)), cy + 4 * math.sin(math.radians(ang))],
               fill=(180, 20, 20, 255), width=1)
        d.rectangle([18, 19, 27, 27], fill=(214, 168, 30, 255))
        d.rectangle([20, 21, 25, 25], fill=((70, 230, 90) if active else (90, 20, 20)) + (255,))
    elif kind == 'femur':
        d.rectangle([3, 3, 28, 28], fill=(214, 168, 30, 255))
        for i in range(-28, 32, 6):
            d.line([3 + i, 3, 3 + i + 25, 28], fill=(24, 24, 24, 255), width=2)
        d.rectangle([3, 3, 28, 28], outline=(20, 20, 20, 255))
        d.ellipse([9, 9, 22, 22], fill=(30, 30, 30, 255))
        d.ellipse([10, 10, 21, 21], fill=((90, 20, 20) if active else (220, 30, 30)) + (255,))
    return im


def locker(kind):
    if kind == 'armory':
        im = noise_fill(32, 32, (70, 76, 70), 0.06, 7)
        d = ImageDraw.Draw(im)
        for x0 in (1, 16):
            d.rectangle([x0, 1, x0 + 14, 30], outline=(40, 44, 40, 255))
            for y in range(4, 12, 2):
                d.line([x0 + 3, y, x0 + 11, y], fill=(35, 38, 35, 255))
            d.rectangle([x0 + 11, 15, x0 + 12, 19], fill=(150, 150, 150, 255))
        d.rectangle([12, 22, 19, 26], fill=(214, 168, 30, 255))
    elif kind == 'medical':
        im = noise_fill(32, 32, (220, 222, 224), 0.03, 8)
        d = ImageDraw.Draw(im)
        d.rectangle([1, 1, 30, 30], outline=(150, 154, 158, 255))
        d.line([16, 1, 16, 30], fill=(150, 154, 158, 255))
        d.rectangle([12, 6, 19, 21], fill=(190, 30, 30, 255))
        d.rectangle([8, 10, 23, 17], fill=(190, 30, 30, 255))
        d.rectangle([13, 24, 14, 27], fill=(120, 120, 120, 255))
        d.rectangle([17, 24, 18, 27], fill=(120, 120, 120, 255))
    else:  # o5 safe
        im = noise_fill(32, 32, (40, 42, 46), 0.05, 9)
        d = ImageDraw.Draw(im)
        d.rectangle([2, 2, 29, 29], outline=(80, 84, 90, 255))
        d.ellipse([9, 8, 22, 21], fill=(110, 114, 120, 255), outline=(20, 20, 20, 255))
        d.ellipse([13, 12, 18, 17], fill=(30, 30, 30, 255))
        for a in range(0, 360, 45):
            x = 15.5 + 6 * math.cos(math.radians(a))
            y = 14.5 + 6 * math.sin(math.radians(a))
            d.point((x, y), fill=(220, 220, 220, 255))
        d.rectangle([7, 24, 24, 26], fill=(201, 162, 39, 255))
    return im


def glass():
    im = Image.new('RGBA', (32, 32), (150, 190, 200, 40))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 31, 31], outline=(60, 64, 68, 255), width=2)
    d.line([6, 26, 12, 20], fill=(255, 255, 255, 90))
    d.line([8, 27, 14, 21], fill=(255, 255, 255, 60))
    return im


def make_blocks(gfx, out):
    b = f'{out}/textures/block'
    m = f'{gfx}/map'
    photo(f'{m}/concretewall.jpg', 64, bright=1.25).save(mk(f'{b}/concrete_wall.png'))
    trim = photo(f'{m}/concretewall.jpg', 64, bright=1.1)
    hz = hazard(64)
    trim.paste(hz.crop((0, 0, 64, 12)), (0, 52))
    trim.save(f'{b}/concrete_wall_trim.png')
    photo(f'{m}/whitewall.jpg', 64, bright=1.05).save(f'{b}/white_wall.png')
    wt = photo(f'{m}/whitewall.jpg', 64, bright=1.0)
    ImageDraw.Draw(wt).rectangle([0, 50, 63, 63], fill=(52, 58, 66, 255))
    ImageDraw.Draw(wt).line([0, 50, 63, 50], fill=(150, 30, 30, 255), width=2)
    wt.save(f'{b}/white_wall_trim.png')
    photo(f'{m}/tilefloor.jpg', 64, crop=(0, 0, 683, 683), bright=0.95).save(f'{b}/tile_floor.png')
    photo(f'{m}/concretefloor.jpg', 64, bright=1.3).save(f'{b}/concrete_floor.png')
    photo(f'{m}/metalpanels.jpg', 64, bright=1.2).save(f'{b}/metal_panel.png')
    photo(f'{m}/dirtymetal.jpg', 64, bright=1.4).save(f'{b}/dirty_metal.png')
    photo(f'{m}/officewall.jpg', 64, bright=1.15).save(f'{b}/office_wall.png')
    hazard(32).save(f'{b}/hazard_stripe.png')
    light_panel().save(f'{b}/ceiling_light.png')
    light_panel(glow=(220, 40, 30), frame=(50, 30, 30)).save(f'{b}/emergency_light.png')
    glass().save(f'{b}/facility_glass.png')

    door = Image.open(f'{m}/door.jpg').convert('RGB').crop((100, 0, 780, 1024))
    door.crop((0, 0, 680, 512)).resize((64, 64), Image.LANCZOS).save(f'{b}/door_lcz_upper.png')
    door.crop((0, 512, 680, 1024)).resize((64, 64), Image.LANCZOS).save(f'{b}/door_lcz_lower.png')
    heavy = Image.open(f'{m}/containment_doors.jpg').convert('RGB').crop((0, 124, 618, 777))
    heavy = ImageEnhance.Brightness(heavy).enhance(1.25)
    hh = heavy.height // 2
    heavy.crop((0, 0, heavy.width, hh)).resize((64, 64), Image.LANCZOS).save(f'{b}/door_heavy_upper.png')
    heavy.crop((0, hh, heavy.width, heavy.height)).resize((64, 64), Image.LANCZOS).save(f'{b}/door_heavy_lower.png')
    photo(f'{m}/metalpanels2.jpg', 64, bright=1.1).save(f'{b}/door_frame.png')

    side = noise_fill(32, 32, (60, 63, 66), 0.05, 4)
    ImageDraw.Draw(side).rectangle([0, 0, 31, 31], outline=(34, 35, 37, 255))
    side.save(f'{b}/machine_side.png')
    top = noise_fill(32, 32, (48, 50, 53), 0.05, 5)
    top.save(f'{b}/machine_top.png')
    for kind in ('terminal', 'console', 'generator', 'femur'):
        screen_block(kind, False).save(f'{b}/{kind}_off.png')
        screen_block(kind, True).save(f'{b}/{kind}_on.png')
    for kind in ('armory', 'medical', 'o5'):
        locker(kind).save(f'{b}/locker_{kind}.png')


# ------------------------------------------------------------------ items
GUN_PALETTE = [
    (27, 28, 30), (44, 46, 49), (69, 72, 76), (111, 115, 120),
    (138, 122, 90), (75, 80, 50), (90, 58, 34), (196, 106, 29),
    (163, 34, 29), (47, 191, 74), (217, 220, 223), (201, 162, 39),
    (20, 20, 20), (154, 160, 166), (42, 74, 122), (60, 60, 64),
]


def gun_palette():
    im = Image.new('RGBA', (16, 16))
    px = im.load()
    rng = random.Random(5)
    for i, c in enumerate(GUN_PALETTE):
        cx, cy = (i % 4) * 4, (i // 4) * 4
        for y in range(4):
            for x in range(4):
                f = 1.08 - 0.05 * (x + y) / 2 + rng.uniform(-0.03, 0.03)
                px[cx + x, cy + y] = tuple(max(0, min(255, int(v * f))) for v in c) + (255,)
    return im


def pixel_item(draw_fn, size=16):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(im))
    return im


def ammo_9mm(d):
    d.rectangle([2, 6, 13, 13], fill=(92, 74, 46, 255), outline=(52, 40, 24, 255))
    d.rectangle([2, 6, 13, 7], fill=(120, 98, 62, 255))
    for x in (4, 7, 10):
        d.rectangle([x, 2, x + 1, 6], fill=(201, 162, 39, 255))
        d.point((x, 2), fill=(150, 110, 60, 255))
        d.point((x + 1, 2), fill=(150, 110, 60, 255))
    d.text((4, 8), '9', fill=(230, 230, 230, 255))


def ammo_57(d):
    d.rectangle([3, 2, 12, 13], fill=(40, 40, 42, 255), outline=(15, 15, 15, 255))
    d.rectangle([4, 3, 11, 5], fill=(150, 150, 150, 120))
    for x in range(4, 12, 2):
        d.rectangle([x, 6, x, 9], fill=(201, 162, 39, 255))
    d.rectangle([4, 11, 11, 12], fill=(70, 72, 76, 255))


def ammo_12g(d):
    for i, x in enumerate((2, 6, 10)):
        d.rectangle([x, 3, x + 3, 13], fill=(163, 34, 29, 255), outline=(100, 20, 18, 255))
        d.rectangle([x, 11, x + 3, 13], fill=(201, 162, 39, 255))


def document(d):
    d.polygon([(3, 1), (11, 1), (13, 3), (13, 14), (3, 14)], fill=(232, 228, 214, 255), outline=(120, 116, 104, 255))
    for y in (4, 6, 8):
        d.line([5, y, 11, y], fill=(90, 90, 90, 255))
    d.rectangle([6, 10, 11, 12], outline=(170, 30, 30, 255))
    d.point((8, 11), fill=(170, 30, 30, 255))


def eyedrops(d):
    d.rectangle([5, 6, 10, 14], fill=(210, 225, 235, 255), outline=(90, 110, 125, 255))
    d.rectangle([6, 9, 9, 12], fill=(40, 110, 200, 255))
    d.rectangle([6, 3, 9, 5], fill=(240, 240, 240, 255), outline=(120, 120, 120, 255))
    d.rectangle([7, 1, 8, 2], fill=(240, 240, 240, 255))


def make_items(gfx, out):
    i = f'{out}/textures/item'
    it = f'{gfx}/items'
    for n in range(1, 6):
        key_black(photo(f'{it}/INVkey{n}.jpg', 32)).save(mk(f'{i}/keycard_{n}.png'))
    key_black(photo(f'{it}/INVkeyomni.jpg', 32)).save(f'{i}/keycard_omni.png')
    for name, src in (('scp500', 'INVpill'), ('radio', 'INVradio'), ('snav', 'INVnavigator'),
                      ('first_aid', 'INVfirstaid'), ('gas_mask', 'INVgasmask'), ('ballistic_vest', 'INVvest')):
        key_black(photo(f'{it}/{src}.jpg', 32)).save(f'{i}/{name}.png')
    pixel_item(ammo_9mm).save(f'{i}/ammo_9mm.png')
    pixel_item(ammo_57).save(f'{i}/ammo_57.png')
    pixel_item(ammo_12g).save(f'{i}/ammo_12g.png')
    pixel_item(document).save(f'{i}/document.png')
    pixel_item(eyedrops).save(f'{i}/eyedrops.png')
    gun_palette().save(f'{i}/gun_palette.png')

    g = f'{out}/textures/gui/docs'
    for scp in ('173', '096', '106', '049'):
        im = Image.open(f'{it}/doc{scp}.jpg').convert('RGB').resize((400, 564), Image.LANCZOS)
        im.save(mk(f'{g}/doc_{scp}.png'))


# ------------------------------------------------------------------ gui / logo
def emblem(size, color=(235, 235, 235, 255)):
    """The Foundation roundel: outer ring, inner ring, three inward arrows."""
    s = size * 4
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = s / 2
    R = s * 0.48

    def ring(r_out, r_in):
        d.ellipse([c - r_out, c - r_out, c + r_out, c + r_out], fill=color)
        d.ellipse([c - r_in, c - r_in, c + r_in, c + r_in], fill=(0, 0, 0, 0))

    ring(R, R * 0.80)
    ring(R * 0.42, R * 0.30)
    for k in range(3):
        a = math.radians(-90 + k * 120)
        ux, uy = math.cos(a), math.sin(a)
        px_, py_ = -uy, ux
        # gap in the outer ring
        gw = R * 0.16
        gap = [(c + ux * R * 1.02 + px_ * gw, c + uy * R * 1.02 + py_ * gw),
               (c + ux * R * 1.02 - px_ * gw, c + uy * R * 1.02 - py_ * gw),
               (c + ux * R * 0.74 - px_ * gw, c + uy * R * 0.74 - py_ * gw),
               (c + ux * R * 0.74 + px_ * gw, c + uy * R * 0.74 + py_ * gw)]
        d.polygon(gap, fill=(0, 0, 0, 0))
        sw = R * 0.075
        shaft = [(c + ux * R * 1.0 + px_ * sw, c + uy * R * 1.0 + py_ * sw),
                 (c + ux * R * 1.0 - px_ * sw, c + uy * R * 1.0 - py_ * sw),
                 (c + ux * R * 0.66 - px_ * sw, c + uy * R * 0.66 - py_ * sw),
                 (c + ux * R * 0.66 + px_ * sw, c + uy * R * 0.66 + py_ * sw)]
        d.polygon(shaft, fill=color)
        hw = R * 0.2
        head = [(c + ux * R * 0.70 + px_ * hw, c + uy * R * 0.70 + py_ * hw),
                (c + ux * R * 0.70 - px_ * hw, c + uy * R * 0.70 - py_ * hw),
                (c + ux * R * 0.47, c + uy * R * 0.47)]
        d.polygon(head, fill=color)
    return im.resize((size, size), Image.LANCZOS)


def title_logo(w, h, subtitle=True):
    s = 4
    im = Image.new('RGBA', (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    em = emblem(int(h * s * 0.9))
    im.alpha_composite(em, (0, int(h * s * 0.05)))
    x0 = int(h * s * 0.98)
    big = ImageFont.truetype(FONT_BOLD, int(h * s * 0.56))
    d.text((x0 + 4 * s, int(h * s * 0.36) + 4 * s), 'SCP', font=big, fill=(0, 0, 0, 160), anchor='ls')
    d.text((x0, int(h * s * 0.36)), 'SCP', font=big, fill=(238, 238, 238, 255), anchor='ls')
    bw = d.textlength('SCP', font=big)
    zone = ImageFont.truetype(FONT_BOLD, int(h * s * 0.30))
    zx = x0 + bw + 10 * s
    d.text((zx, int(h * s * 0.36)), 'ЗОНА-19', font=zone, fill=(196, 40, 34, 255), anchor='ls')
    d.line([x0, int(h * s * 0.47), w * s - 6 * s, int(h * s * 0.47)], fill=(200, 200, 200, 255), width=max(1, s))
    if subtitle:
        sub = ImageFont.truetype(FONT_BOLD, int(h * s * 0.13))
        d.text((x0, int(h * s * 0.66)), 'ОБЕЗОПАСИТЬ · УДЕРЖАТЬ · СОХРАНИТЬ', font=sub,
               fill=(190, 190, 190, 255), anchor='ls')
        tiny = ImageFont.truetype(FONT_MONO, int(h * s * 0.10))
        d.text((x0, int(h * s * 0.86)), 'ТЕРМИНАЛ СЛУЖБЫ БЕЗОПАСНОСТИ // КОМПЛЕКС 19', font=tiny,
               fill=(130, 130, 130, 255), anchor='ls')
    return im.resize((w, h), Image.LANCZOS)


def make_gui(gfx, out):
    g = f'{out}/textures/gui'
    os.makedirs(g, exist_ok=True)
    title_logo(512, 128).save(f'{g}/logo.png')
    emblem(256).save(f'{g}/emblem.png')
    back = Image.open(f'{gfx}/menu/173back.jpg').convert('RGB')
    back = ImageEnhance.Brightness(back).enhance(1.6).resize((312, 441), Image.LANCZOS)
    back.save(f'{g}/scp173_back.png')
    icon = Image.open(f'{gfx}/BlinkIcon.png').convert('L')
    bi = Image.new('RGBA', icon.size, (235, 235, 235, 0))
    bi.putalpha(icon)
    bi.save(f'{g}/blink_icon.png')
    Image.open(f'{gfx}/BlinkMeter.jpg').convert('RGBA').save(f'{g}/blink_segment.png')


# ------------------------------------------------------------------ resource pack
def nine_button(w, h, state):
    """SCP-terminal styled button: dark plate, thin frame, red bar on hover."""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if state == 'disabled':
        d.rectangle([0, 0, w - 1, h - 1], fill=(22, 22, 24, 230), outline=(48, 48, 50, 255))
        return im
    base = (30, 31, 34, 235) if state == 'normal' else (52, 22, 22, 245)
    edge = (92, 94, 98, 255) if state == 'normal' else (210, 50, 42, 255)
    d.rectangle([0, 0, w - 1, h - 1], fill=base, outline=edge)
    d.line([1, 1, w - 2, 1], fill=(255, 255, 255, 28))
    d.line([1, h - 2, w - 2, h - 2], fill=(0, 0, 0, 90))
    d.rectangle([1, 2, 2, h - 3], fill=(196, 40, 34, 255) if state == 'hover' else (120, 122, 126, 255))
    return im


def widgets_png():
    im = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # hotbar 182x22
    d.rectangle([0, 0, 181, 21], fill=(18, 19, 21, 220), outline=(80, 82, 86, 255))
    for k in range(9):
        x = 1 + k * 20
        d.rectangle([x + 1, 1, x + 20, 20], outline=(54, 56, 60, 255))
        d.line([x + 2, 19, x + 19, 19], fill=(110, 30, 26, 200))
    # selection 24x24 at (0,22)
    d.rectangle([0, 22, 23, 45], outline=(230, 230, 230, 255))
    d.rectangle([1, 23, 22, 44], outline=(196, 40, 34, 255))
    d.rectangle([0, 22, 3, 25], fill=(196, 40, 34, 255))
    # buttons
    im.alpha_composite(nine_button(200, 20, 'disabled'), (0, 46))
    im.alpha_composite(nine_button(200, 20, 'normal'), (0, 66))
    im.alpha_composite(nine_button(200, 20, 'hover'), (0, 86))
    # language button (0,106) + hover (0,126)
    for i, st in enumerate(('normal', 'hover')):
        y = 106 + i * 20
        im.alpha_composite(nine_button(20, 20, st), (0, y))
        d.ellipse([5, y + 4, 15, y + 14], outline=(220, 220, 220, 255))
        d.line([10, y + 4, 10, y + 14], fill=(220, 220, 220, 255))
        d.line([5, y + 9, 15, y + 9], fill=(220, 220, 220, 255))
    # lock buttons (0,146): locked/unlocked x hover rows
    for row, st in enumerate(('normal', 'hover', 'disabled')):
        for col, locked in enumerate((True, False)):
            x, y = col * 20, 146 + row * 20
            im.alpha_composite(nine_button(20, 20, st), (x, y))
            d.rectangle([x + 6, y + 9, x + 13, y + 15], fill=(210, 210, 210, 255))
            if locked:
                d.arc([x + 7, y + 4, x + 12, y + 12], 180, 360, fill=(210, 210, 210, 255))
            else:
                d.arc([x + 9, y + 3, x + 14, y + 11], 180, 360, fill=(210, 210, 210, 255))
    return im


def slider_png():
    im = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, (fill, edge) in enumerate((((20, 21, 23, 235), (70, 72, 76, 255)),
                                      ((26, 26, 30, 240), (196, 40, 34, 255)))):
        y = i * 20
        d.rectangle([0, y, 199, y + 19], fill=fill, outline=edge)
        for x in range(10, 200, 20):
            d.line([x, y + 15, x, y + 17], fill=(80, 82, 86, 255))
    im.alpha_composite(nine_button(200, 20, 'normal'), (0, 40))
    im.alpha_composite(nine_button(200, 20, 'hover'), (0, 60))
    return im


def options_background():
    base = Image.open(OPTIONS_SRC).convert('RGB').resize((64, 64), Image.LANCZOS)
    base = ImageEnhance.Brightness(base).enhance(1.9)
    return base.convert('RGBA')


def edition_png():
    im = Image.new('RGBA', (128 * 4, 16 * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_BOLD, 40)
    d.text((4, 30), 'SECURE · CONTAIN · PROTECT', font=f, fill=(196, 40, 34, 255), anchor='lm')
    return im.resize((128, 16), Image.LANCZOS)


def pack_png():
    im = Image.new('RGBA', (128, 128), (14, 14, 16, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, 128, 3):
        d.line([0, y, 127, y], fill=(20, 20, 22, 255))
    em = emblem(104)
    im.alpha_composite(em, (12, 8))
    d.rectangle([0, 110, 127, 127], fill=(150, 28, 24, 255))
    f = ImageFont.truetype(FONT_BOLD, 13)
    d.text((64, 119), 'ЗОНА-19', font=f, fill=(240, 240, 240, 255), anchor='mm')
    return im


def panorama_overlay():
    im = Image.new('RGBA', (256, 256))
    px = im.load()
    for y in range(256):
        for x in range(256):
            dx, dy = (x - 128) / 128, (y - 128) / 128
            v = min(1.0, (dx * dx + dy * dy) ** 0.5)
            px[x, y] = (0, 0, 0, int(60 + 150 * v ** 2))
    return im


def make_resourcepack(gfx, rp):
    a = f'{rp}/assets/minecraft/textures/gui'
    widgets_png().save(mk(f'{a}/widgets.png'))
    slider_png().save(f'{a}/slider.png')
    ob = options_background()
    ob.save(f'{a}/options_background.png')
    ImageEnhance.Brightness(ob).enhance(1.4).save(f'{a}/light_dirt_background.png')
    title_logo(256, 64, subtitle=False).save(mk(f'{a}/title/minecraft.png'))
    edition_png().save(f'{a}/title/edition.png')
    panorama_overlay().save(mk(f'{a}/title/background/panorama_overlay.png'))
    pack_png().save(f'{rp}/pack.png')


OPTIONS_SRC = None

if __name__ == '__main__':
    gfx, mod_assets, rp = sys.argv[1], sys.argv[2], sys.argv[3]
    OPTIONS_SRC = f'{gfx}/map/metalpanels.jpg'
    make_blocks(gfx, mod_assets)
    make_items(gfx, mod_assets)
    make_gui(gfx, mod_assets)
    make_resourcepack(gfx, rp)
    pack_png().save(f'{mod_assets}/textures/gui/pack_icon.png')
