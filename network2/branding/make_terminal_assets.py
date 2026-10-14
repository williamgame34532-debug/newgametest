"""The civic terminal (entities/entities/nw_terminal.lua): its screen wallpaper, cursors and sounds.
    materials/network2/terminal/wallpaper.png     1024x512 - the screen under the interface, in the
        spirit of the Combine terminal background (cmb_terminal_bg): deep sea-green dark, fine
        horizontal scan rows with brighter dashes of data running along them, a soft diagonal band
        of light, a faint Alliance ring emblem and a grid, rare red / amber cells of a busy system
    materials/network2/terminal/cursor.png        64x64 - the pointer: a sharp arrow with a glow
    materials/network2/terminal/cursor_hover.png  64x64 - over a button: four corner brackets
                                                  around a dot (the hotspot is the centre)
    sound/network2/terminal/select1.wav, select2.wav   a short glassy blip of a touch screen
    sound/network2/terminal/boot.wav     the identification: a scan sweep and a rising chord
    sound/network2/terminal/deny.wav     refused: two low buzzes
    sound/network2/terminal/alarm.wav    the call to Civil Protection: a two-tone signal
    sound/network2/terminal/loop.wav     the hum of the terminal (seamless loop, 4 s)
Synthesised here (own work).
Usage: python make_terminal_assets.py <network2 folder>"""
import math, os, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
MAT = os.path.join(ROOT, "content", "materials", "network2", "terminal")
SND = os.path.join(ROOT, "content", "sound", "network2", "terminal")
rng = np.random.default_rng(1704)
os.makedirs(MAT, exist_ok=True)
os.makedirs(SND, exist_ok=True)


# ------------------------------------------------------------------ wallpaper --
def smooth_noise(w, h, cell, seed):
    r = np.random.default_rng(seed)
    gw, gh = w // cell + 2, h // cell + 2
    g = r.random((gh, gw))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(img, dtype=float)[:h, :w] / 255


W, H = 1024, 512
y, x = np.mgrid[0:H, 0:W].astype(float)

# the base: dark sea-green, a little lighter in the middle
base = np.zeros((H, W, 3))
base[..., 0], base[..., 1], base[..., 2] = 9, 33, 42
centre = np.exp(-(((x - W * 0.5) / (W * 0.55)) ** 2 + ((y - H * 0.45) / (H * 0.7)) ** 2))
base += centre[..., None] * np.array([4, 14, 18])

# a soft diagonal band of light, like the brighter swath of the Combine screen
band = np.exp(-(((x - W * 0.46) + (y - H * 0.5) * 0.35) / (W * 0.13)) ** 2)
band *= 0.6 + 0.4 * smooth_noise(W, H, 64, 3)

# scan rows: every 8 px a thin line; along it the brightness wanders and data dashes run
rows = np.zeros((H, W))
for row in range(3, H, 8):
    level = 0.18 + 0.5 * band[row] + 0.25 * smooth_noise(W, 1, 48, row)[0]
    line = level.copy()
    # dashes of data
    pos = 0
    while pos < W:
        length = int(rng.integers(6, 70))
        if rng.random() < 0.28:
            line[pos:pos + length] += rng.uniform(0.25, 0.9) * (0.4 + band[row, pos:pos + length])
        pos += length + int(rng.integers(4, 60))
    rows[row] = line
    rows[row + 1] = line * 0.35
rows = np.clip(rows, 0, 1.6)

cyan = np.array([38, 150, 178])
img = base + rows[..., None] * cyan * 0.55 + band[..., None] * np.array([6, 28, 34])

# a faint grid and the Alliance ring emblem on the right
grid = ((x % 64 < 1) | (y % 64 < 1)).astype(float) * 0.05
img += grid[..., None] * cyan
emblem = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(emblem)
cx, cy = int(W * 0.79), int(H * 0.52)
for radius, width in ((150, 3), (118, 2), (84, 6), (40, 2)):
    d.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=255, width=width)
for angle in range(0, 360, 30):
    a = math.radians(angle)
    d.line((cx + math.cos(a) * 92, cy + math.sin(a) * 92, cx + math.cos(a) * 112, cy + math.sin(a) * 112),
           fill=255, width=3)
d.polygon([(cx, cy - 64), (cx + 20, cy - 12), (cx, cy + 6), (cx - 20, cy - 12)], outline=255)
emblem = np.asarray(emblem.filter(ImageFilter.GaussianBlur(1.2)), dtype=float) / 255
img += emblem[..., None] * cyan * 0.13

# rare busy cells: a few red and amber points on the rows (as on the original screen)
for _ in range(14):
    row = int(rng.integers(1, H // 8)) * 8 + 3
    col = int(rng.integers(40, W - 40))
    colour = np.array([200, 70, 60]) if rng.random() < 0.5 else np.array([214, 160, 64])
    img[row:row + 2, col:col + int(rng.integers(3, 9))] = colour * rng.uniform(0.5, 0.9)

# grain, a soft blur of the light, the dark edges
img += rng.normal(0, 2.2, (H, W, 1))
glow = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
img = img * 0.82 + np.asarray(glow, dtype=float) * 0.3
edge = np.clip(1 - (np.abs(x - W / 2) / (W / 2)) ** 6 * 0.55 - (np.abs(y - H / 2) / (H / 2)) ** 6 * 0.45, 0, 1)
img *= edge[..., None]
Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(MAT, "wallpaper.png"), optimize=True)


# --------------------------------------------------------------------- cursors --
def cursor(draw_shape, name):
    S = 4  # supersampling
    size = 64 * S
    shape = Image.new("L", (size, size), 0)
    draw_shape(ImageDraw.Draw(shape), S)
    shape = shape.resize((64, 64), Image.LANCZOS)
    glow = shape.filter(ImageFilter.GaussianBlur(3.5))
    core = np.asarray(shape, dtype=float) / 255
    halo = np.asarray(glow, dtype=float) / 255
    rgba = np.zeros((64, 64, 4))
    rgba[..., :3] = np.array([150, 236, 252]) * core[..., None] + np.array([40, 200, 240]) * (1 - core[..., None])
    rgba[..., :3] = np.where(core[..., None] > 0.5, np.array([226, 250, 255]), rgba[..., :3])
    rgba[..., 3] = np.clip(core * 255 + halo * 150, 0, 255)
    Image.fromarray(rgba.astype(np.uint8), "RGBA").save(os.path.join(MAT, name), optimize=True)


def arrow(d, S):
    # the tip at the centre (32, 32): the hotspot is the middle of the image
    tip = (32 * S, 32 * S)
    points = [tip, (32 * S, 56 * S), (38 * S, 50 * S), (43 * S, 60 * S), (47 * S, 58 * S), (42 * S, 48 * S),
              (50 * S, 48 * S)]
    d.polygon(points, fill=255)
    inner = [(33.6 * S, 36 * S), (33.6 * S, 52 * S), (38.4 * S, 47 * S), (43.6 * S, 57.2 * S), (45 * S, 56.5 * S),
             (39.8 * S, 46.6 * S), (46.2 * S, 46.6 * S)]
    d.polygon(inner, fill=150)


def brackets(d, S):
    c, r, l, w = 32 * S, 15 * S, 7 * S, int(2.4 * S)
    for sx in (-1, 1):
        for sy in (-1, 1):
            corner = (c + sx * r, c + sy * r)
            d.line([corner, (corner[0] - sx * l, corner[1])], fill=255, width=w)
            d.line([corner, (corner[0], corner[1] - sy * l)], fill=255, width=w)
    d.ellipse((c - 2.6 * S, c - 2.6 * S, c + 2.6 * S, c + 2.6 * S), fill=255)


cursor(arrow, "cursor.png")
cursor(brackets, "cursor_hover.png")

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
