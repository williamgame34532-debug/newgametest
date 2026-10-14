"""The civic terminal (entities/entities/nw_terminal.lua): its screen wallpaper, cursors and sounds.
    materials/network2/terminal/wallpaper.png     1024x512 - the holographic glass of a civic station
        (the Half-Life: Alyx / cmb_terminal_bg look): a pale cyan haze, dense soft scan streaks of
        uneven brightness, a faint perspective floor plane below, a brighter rim
    materials/network2/terminal/cursor.png        64x64 - a small glowing diamond with a dot
    materials/network2/terminal/cursor_hover.png  64x64 - over a button: the diamond filled, four
                                                  ticks around (the hotspot is the centre)
    sound/network2/terminal/select1.wav, select2.wav   a short glassy blip of a touch screen
    sound/network2/terminal/boot.wav     the identification: a scan sweep and a rising chord
    sound/network2/terminal/deny.wav     refused: two low buzzes
    sound/network2/terminal/alarm.wav    the call to Civil Protection: a two-tone signal
    sound/network2/terminal/loop.wav     the hum of the terminal (seamless loop, 4 s)
Synthesised here (own work). The terminal now plays the real civic station sounds
(content/sound/network2/terminal/civic); the synthesised ones are kept as spares - the script writes
them, they are not shipped.
Usage: python make_terminal_assets.py <network2 folder>"""
import math, os, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
MAT = os.path.join(ROOT, "content", "materials", "network2", "terminal")
SND = os.path.join(ROOT, "branding", "out", "terminal_sounds")  # spares, not shipped
rng = np.random.default_rng(1704)
os.makedirs(MAT, exist_ok=True)
os.makedirs(SND, exist_ok=True)


# ------------------------------------------------------------------ wallpaper --
# The holographic glass of a Combine civic station (Half-Life: Alyx look): a pale cyan haze, dense
# soft scan streaks of uneven brightness, a faint perspective "floor" plane in the lower half, the
# light gathering in the middle and at the rim. The interface is drawn over it in thin cyan lines.
def smooth_noise(w, h, cell, seed):
    r = np.random.default_rng(seed)
    gw, gh = w // cell + 2, h // cell + 2
    g = r.random((gh, gw))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(img, dtype=float)[:h, :w] / 255


W, H = 1024, 512
y, x = np.mgrid[0:H, 0:W].astype(float)
cyan = np.array([120, 214, 232])

# the haze: brighter in the middle, a slow wave of light across
haze = 0.34 + 0.22 * np.exp(-(((x - W * 0.5) / (W * 0.62)) ** 2 + ((y - H * 0.48) / (H * 0.75)) ** 2))
haze *= 0.85 + 0.3 * smooth_noise(W, H, 128, 5)

# scan streaks: every 6 px a soft line two pixels thick; its brightness drifts along it and
# between lines, with long brighter runs (the streaks of the Alyx screens)
streaks = np.zeros((H, W))
for row in range(2, H, 6):
    level = 0.25 + 0.55 * smooth_noise(W, 1, 96, row)[0] ** 1.6
    line = level.copy()
    pos = 0
    while pos < W:
        length = int(rng.integers(30, 240))
        if rng.random() < 0.35:
            line[pos:pos + length] *= rng.uniform(1.3, 1.9)
        pos += length + int(rng.integers(10, 120))
    streaks[row] = line
    streaks[row + 1] = line * 0.7
    streaks[row - 1] += line * 0.18
streaks = np.asarray(Image.fromarray(np.clip(streaks * 255, 0, 255).astype(np.uint8)).filter(
    ImageFilter.GaussianBlur(0.8)), dtype=float) / 255

# the perspective floor: a lighter trapezoid going away, with a few depth lines
floor = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(floor)
d.polygon([(int(W * 0.05), H), (int(W * 0.95), H), (int(W * 0.78), int(H * 0.56)), (int(W * 0.22), int(H * 0.56))],
          fill=70)
for k in range(1, 6):
    yy = int(H * 0.56 + (H * 0.44) * (k / 6) ** 1.7)
    d.line([(0, yy), (W, yy)], fill=110, width=1)
floor = np.asarray(floor.filter(ImageFilter.GaussianBlur(6)), dtype=float) / 255

light = haze * 0.55 + streaks * 0.5 + floor * 0.35
img = np.zeros((H, W, 3)) + np.array([10, 34, 42])
img += light[..., None] * cyan

# grain, then the edges a little brighter (the rim of the glass)
img += rng.normal(0, 2.0, (H, W, 1))
rim = np.clip(1 - np.minimum(np.minimum(x, W - 1 - x) / 40, np.minimum(y, H - 1 - y) / 28), 0, 1) ** 2
img += rim[..., None] * cyan * 0.35
Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(MAT, "wallpaper.png"), optimize=True)


# --------------------------------------------------------------------- cursors --
def cursor(draw_shape, name):
    S = 4  # supersampling
    size = 64 * S
    shape = Image.new("L", (size, size), 0)
    draw_shape(ImageDraw.Draw(shape), S)
    shape = shape.resize((64, 64), Image.LANCZOS)
    glow = shape.filter(ImageFilter.GaussianBlur(3))
    core = np.asarray(shape, dtype=float) / 255
    halo = np.asarray(glow, dtype=float) / 255
    rgba = np.zeros((64, 64, 4))
    rgba[..., :3] = np.array([236, 252, 255]) * core[..., None] + np.array([110, 220, 240]) * (1 - core[..., None])
    rgba[..., 3] = np.clip(core * 255 + halo * 170, 0, 255)
    Image.fromarray(rgba.astype(np.uint8), "RGBA").save(os.path.join(MAT, name), optimize=True)


# the cursor of the Alyx stations: a small diamond with a dot (the hotspot is the centre)
def diamond(d, S):
    c, r, w = 32 * S, 9 * S, int(2 * S)
    d.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], outline=255)
    for k in range(w):
        rr = r - k
        d.polygon([(c, c - rr), (c + rr, c), (c, c + rr), (c - rr, c)], outline=255)
    d.ellipse((c - 2.2 * S, c - 2.2 * S, c + 2.2 * S, c + 2.2 * S), fill=255)


# over a button: the diamond filled, with four short ticks around
def diamond_hover(d, S):
    c, r = 32 * S, 7 * S
    d.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=255)
    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        d.line([(c + dx * 12 * S, c + dy * 12 * S), (c + dx * 17 * S, c + dy * 17 * S)], fill=255, width=int(2 * S))


cursor(diamond, "cursor.png")
cursor(diamond_hover, "cursor_hover.png")

# ---------------------------------------------------------------------- sounds --
SR = 44100


def t(d):
    return np.arange(int(SR * d)) / SR


def save(name, x, peak=0.8, fade=0.004):
    x = x - np.mean(x)
    x = x / (np.max(np.abs(x)) or 1) * peak
    n = int(SR * fade)
    if n:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    with wave.open(os.path.join(SND, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def band(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * ((f > lo) & (f < hi)), len(x))


def blip(f0, f1, dur, decay):
    tt = t(dur)
    freq = np.linspace(f0, f1, len(tt))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    tone = np.sin(phase) + 0.35 * np.sin(phase * 2.01) + 0.12 * np.sin(phase * 3.02)
    click = band(rng.normal(0, 1, len(tt)), 2500, 9000) * np.exp(-tt / 0.0015)
    return tone * np.exp(-tt / decay) * np.minimum(tt / 0.002, 1) + click * 0.5


save("select1.wav", blip(1850, 2350, 0.12, 0.028), 0.55)
save("select2.wav", blip(1500, 1980, 0.12, 0.03) + np.pad(blip(2400, 2600, 0.06, 0.012), (1700, 5292))[:5292] * 0.5,
     0.55)

tt = t(1.6)
sweep_f = np.linspace(400, 3200, len(tt))
sweep = np.sin(2 * np.pi * np.cumsum(sweep_f) / SR) * np.sin(np.pi * np.minimum(tt / 0.9, 1)) * (tt < 0.9)
scan = band(rng.normal(0, 1, len(tt)), 1500, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 24 * tt)) * (tt < 0.9) * 0.25
chord = sum(np.sin(2 * np.pi * f * tt) for f in (523.3, 659.3, 784.0, 1046.5)) * np.exp(-np.maximum(tt - 0.95, 0) / 0.25) \
    * (tt > 0.95) * np.minimum(np.maximum(tt - 0.95, 0) / 0.01, 1)
save("boot.wav", sweep * 0.35 + scan + chord * 0.25, 0.6, 0.02)

tt = t(0.42)
buzz = np.sign(np.sin(2 * np.pi * 150 * tt)) * 0.5 + np.sin(2 * np.pi * 300 * tt) * 0.5
gate = ((tt < 0.14) | ((tt > 0.2) & (tt < 0.36))).astype(float)
save("deny.wav", band(buzz, 80, 2500) * gate, 0.5, 0.006)

tt = t(1.8)
tone = np.where((tt % 0.45) < 0.225, 880, 660)
alarm = np.sin(2 * np.pi * np.cumsum(tone) / SR)
alarm = alarm + 0.3 * np.sin(2 * 2 * np.pi * np.cumsum(tone) / SR)
save("alarm.wav", alarm * (0.6 + 0.4 * np.sin(2 * np.pi * 2.2 * tt) ** 2), 0.55, 0.02)

# the hum: mains harmonics, a soft air of fans and slow data chirps; 4 s exactly, every part
# repeats a whole number of times so the loop has no seam
tt = t(4.0)
hum = sum(a * np.sin(2 * np.pi * f * tt) for f, a in ((60, 1), (120, 0.6), (180, 0.25), (240, 0.18), (300, 0.08)))
hum *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.5 * tt)
air = band(rng.normal(0, 1, len(tt)), 200, 1800)
air = air * 0.5 + np.roll(air, len(tt) // 2) * 0.5
chirps = np.zeros(len(tt))
for k in range(6):
    at = int(SR * (0.3 + k * 0.62))
    c = blip(3000 + k * 140, 3300 + k * 140, 0.05, 0.01) * 0.12
    chirps[at:at + len(c)] += c
save("loop.wav", hum * 0.6 + air * 0.08 + chirps, 0.35, 0)
print("terminal assets written")
