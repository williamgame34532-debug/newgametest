"""Sounds of using items and of searching -> content/sound/network2/use/*.wav (44.1 kHz, 16 bit, mono).
    drink_water.wav   a plastic cap twisted off (ratchet clicks), two gulps, a short breath out
    drink_soda.wav    a can tab: a metal click, the hiss of the gas, two gulps, a little fizz
    eat_bread.wav     the paper unfolded, chewing
    eat_canned.wav    a spoon scraped twice inside a tin, chewing
    eat_ration.wav    a foil wrapper torn open, chewing
    pills.wav         a pill bottle: the cap pops, three shakes of the pills, one gulp
    medkit.wav        the latch of the case, a zipper, cloth, a strip of tape ripped off, cloth
    bandage.wav       a strip of fabric torn, the bandage wrapped round twice
    search_1..4.wav   rummaging through clothes and pockets: cloth, leather, a zipper, small things
Recordings used (branding/src/sounds, content/sound/network2/inv):
    gulps             mcl_potions_drinking.ogg (VoxeLibre, CC0)
    chewing           hunger_eat.ogg - BlockMen (CC BY 3.0)
    cloth, leather,   Kenney - RPG Audio (CC0)
    latch, belt
The rest is synthesised here.
Usage: python make_use_sounds.py <network2 folder>"""
import os, sys, wave
import numpy as np

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "branding", "src", "sounds")
INV = os.path.join(ROOT, "content", "sound", "network2", "inv")
OUT = os.path.join(ROOT, "content", "sound", "network2", "use")
SR = 44100
rng = np.random.default_rng(23)


def load(path):
    with wave.open(path, "rb") as w:
        n, ch, sw = w.getnframes(), w.getnchannels(), w.getsampwidth()
        assert w.getframerate() == SR and sw == 2, path
        x = np.frombuffer(w.readframes(n), dtype="<i2").astype(float) / 32768

    if ch > 1:
        x = x.reshape(-1, ch).mean(1)

    return x - np.mean(x)


def src(name):
    return load(os.path.join(SRC, name))


def inv(name):
    return load(os.path.join(INV, name))


def bandpass(x, lo, hi):
    """FFT band filter with soft edges."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    w = np.clip((f - lo * 0.7) / (lo * 0.3), 0, 1) * np.clip((hi * 1.3 - f) / (hi * 0.3), 0, 1)
    return np.fft.irfft(X * w, len(x))


def env(n, attack, decay):
    tt = np.arange(n) / SR
    return np.clip(tt / attack, 0, 1) * np.exp(-tt / decay)


def norm(x, peak=1.0):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def pitch(x, rate):
    """Resample: rate > 1 is higher and shorter."""
    idx = np.arange(0, len(x) - 1, rate)
    return np.interp(idx, np.arange(len(x)), x)


def fade(x, out=0.04, inn=0.003):
    x = x.copy()
    a, b = int(SR * inn), int(SR * out)
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


class Mix:
    def __init__(self, length):
        self.x = np.zeros(int(SR * length))

    def add(self, sound, at, gain=1.0):
        i = max(0, int(SR * at))
        j = min(len(self.x), i + len(sound))
        self.x[i:j] += sound[:j - i] * gain

    def save(self, name, peak=0.85):
        x = self.x - np.mean(self.x)
        # a soft high shelf: the synthesised clicks lose their edge (-6 dB from 12 kHz up)
        X = np.fft.rfft(x)
        f = np.fft.rfftfreq(len(x), 1 / SR)
        x = np.fft.irfft(X * (1 - 0.5 * np.clip((f - 4500) / 7500, 0, 1)), len(x))
        # trim the silence at the end, a soft limit, a fade
        alive = np.where(np.abs(x) > 0.002 * np.max(np.abs(x)))[0]
        x = x[:alive[-1] + int(SR * 0.05)] if len(alive) else x
        x = np.tanh(norm(x, 1.25)) / np.tanh(1.25) * peak
        x = fade(x, 0.03, 0.001)
        os.makedirs(OUT, exist_ok=True)
        with wave.open(os.path.join(OUT, name), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767).astype("<i2").tobytes())
        print(f"{name:20s} {len(x) / SR:.2f} s")


# ---------------------------------------------------------------- pieces --
def click(lo, hi, length=0.006, decay=0.0015):
    """A short dry transient (plastic, a fingernail)."""
    n = int(SR * length)
    return bandpass(rng.normal(0, 1, n), lo, hi) * env(n, 0.0002, decay)


def ring(freqs, decay, length, noise=0.4):
    """A struck metal part: inharmonic partials over a noise hit."""
    n = int(SR * length)
    tt = np.arange(n) / SR
    out = sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * np.exp(-tt / (decay * (1 - i * 0.18)))
              for i, f in enumerate(freqs))
    hit = bandpass(rng.normal(0, 1, n), 2000, 9000) * env(n, 0.0002, 0.002)
    return norm(out) * 0.6 + norm(hit) * noise


def crinkle(length, density, lo=1800, hi=7500, swell=True):
    """Paper / foil / plastic: many tiny random crackles, denser in the middle."""
    n = int(SR * length)
    x = np.zeros(n)
    count = int(density * length)
    shape = np.sin(np.linspace(0, np.pi, 200)) ** 0.7 if swell else np.ones(200)

    for _ in range(count):
        i = int(rng.uniform(0, 1) ** 1.0 * (n - 400))
        a = shape[int(i / n * 199)] * rng.uniform(0.2, 1) ** 2
        c = click(lo, hi, rng.uniform(0.002, 0.009), rng.uniform(0.0004, 0.002))
        x[i:i + len(c)] += c * a

    return norm(x)


def ratchet(count, length, lo=1500, hi=6000):
    """A cap being twisted: regular plastic clicks, slowing a little."""
    n = int(SR * length)
    x = np.zeros(n)
    times = np.cumsum(np.linspace(1, 1.4, count))
    times = times / times[-1] * (length - 0.02)

    for t0 in times:
        c = click(lo, hi, 0.008, 0.0012)
        i = int(t0 * SR)
        x[i:i + len(c)] += c * rng.uniform(0.6, 1)

    return norm(x)


def hiss(length, lo, hi, attack=0.004, decay=0.12):
    n = int(SR * length)
    return norm(bandpass(rng.normal(0, 1, n), lo, hi) * env(n, attack, decay))


def fizz(length, rate=260):
    """Small bubbles bursting: sparse high ticks fading out."""
    n = int(SR * length)
    x = np.zeros(n)

    for _ in range(int(rate * length)):
        i = int(rng.uniform(0, 1) ** 1.6 * (n - 200))
        c = click(4000, 11000, 0.003, 0.0004)
        x[i:i + len(c)] += c * rng.uniform(0.1, 1)

    return norm(x * np.exp(-np.arange(n) / SR / (length * 0.45)))


def zipper(length, start_rate=70, end_rate=140):
    """Teeth of a zipper: a fast train of clicks with a rising rate and a cloth body."""
    n = int(SR * length)
    x = np.zeros(n)
    t0 = 0.0

    while t0 < length - 0.01:
        k = t0 / length
        c = click(1200, 5000, 0.004, 0.0008)
        i = int(t0 * SR)
        x[i:i + len(c)] += c * (0.5 + 0.5 * np.sin(np.pi * k)) * rng.uniform(0.6, 1)
        t0 += 1 / (start_rate + (end_rate - start_rate) * k) * rng.uniform(0.8, 1.2)

    body = bandpass(rng.normal(0, 1, n), 300, 1800) * np.sin(np.linspace(0, np.pi, n)) * 0.15
    return norm(x + body)


def rip(length, lo=700, hi=5200):
    """Tape / fabric torn: noise in jagged bursts, louder at the start."""
    n = int(SR * length)
    noise = bandpass(rng.normal(0, 1, n), lo, hi)
    grain = np.repeat(rng.uniform(0.2, 1, n // 90 + 1) ** 2, 90)[:n]
    shape = np.minimum(np.arange(n) / (SR * 0.01), 1) * np.exp(-np.arange(n) / (SR * length * 0.6))
    return norm(noise * bandpass(grain, 20, 400) * shape)


def breath(length=0.38):
    """A short breath out after drinking ("ah")."""
    n = int(SR * length)
    tt = np.arange(n) / SR
    voice = bandpass(rng.normal(0, 1, n), 500, 2600) + 0.3 * np.sin(2 * np.pi * 125 * tt) * \
        bandpass(rng.normal(0, 1, n), 80, 900)
    return norm(voice * np.sin(np.linspace(0, np.pi, n)) ** 1.5 * np.exp(-tt / 0.3))


def spoon(length=0.22):
    """A spoon scraping the inside of a tin: metal partials excited by a rough stroke."""
    n = int(SR * length)
    tt = np.arange(n) / SR
    stroke = bandpass(rng.normal(0, 1, n), 1500, 7000) * np.sin(np.linspace(0, np.pi, n)) ** 0.6
    metal = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((1870, 1), (3240, 0.7), (5530, 0.4)))
    return norm(stroke * (0.55 + 0.45 * norm(metal)))


def rattle(length=0.22, pills=16):
    """Pills thrown against the walls of a plastic bottle (one shake)."""
    n = int(SR * length)
    x = np.zeros(n)

    for _ in range(pills):
        i = int(rng.beta(2, 3) * (n - 300))
        c = click(2600, 7500, 0.005, 0.0009)
        x[i:i + len(c)] += c * rng.uniform(0.3, 1)

    tt = np.arange(n) / SR
    body = np.sin(2 * np.pi * 2200 * tt) * np.exp(-tt / 0.01)
    return norm(x + 0.05 * body)


def drop_tail(x, rate=1.0, cut=None):
    y = pitch(x, rate)
    return fade(y[:int(SR * cut)] if cut else y, 0.05)


# --------------------------------------------------------------- the sounds --
gulp = fade(src("mcl_potions_drinking.wav"), 0.06)
chew = fade(src("hunger_eat.wav"), 0.06)

# water: cap, gulp, gulp, breath
m = Mix(2.1)
m.add(ratchet(7, 0.32), 0.0, 0.55)
m.add(click(500, 2500, 0.02, 0.004), 0.33, 0.5)
m.add(gulp, 0.5, 1.0)
m.add(drop_tail(gulp, 0.94), 0.98, 0.9)
m.add(breath(), 1.55, 0.22)
m.save("drink_water.wav")

# soda: tab click + hiss, gulps, fizz
m = Mix(2.0)
m.add(ring((2410, 3890, 6120), 0.012, 0.06), 0.0, 0.7)
m.add(hiss(0.45, 3000, 10000, 0.002, 0.11), 0.012, 0.75)
m.add(fizz(1.6), 0.08, 0.12)
m.add(drop_tail(gulp, 1.03), 0.55, 1.0)
m.add(drop_tail(gulp, 0.97), 1.02, 0.85)
m.save("drink_soda.wav")

# bread: paper unfolded, chewing
m = Mix(1.6)
m.add(crinkle(0.42, 160, 1200, 5500), 0.0, 0.35)
m.add(chew, 0.32, 1.0)
m.save("eat_bread.wav")

# canned: two spoon scrapes, chewing
m = Mix(1.75)
m.add(spoon(0.2), 0.0, 0.55)
m.add(spoon(0.16), 0.26, 0.45)
m.add(ring((1870, 3240, 5530), 0.02, 0.08, 0.2), 0.42, 0.25)
m.add(drop_tail(chew, 0.97), 0.55, 1.0)
m.save("eat_canned.wav")

# ration bar: a foil wrapper torn open, chewing
m = Mix(1.6)
m.add(crinkle(0.5, 420, 2200, 9000), 0.0, 0.55)
m.add(rip(0.18, 1500, 7000), 0.16, 0.35)
m.add(drop_tail(chew, 1.04), 0.45, 1.0)
m.save("eat_ration.wav")

# pills: cap pop, three shakes, a gulp
m = Mix(1.5)
m.add(click(700, 3200, 0.02, 0.003), 0.0, 0.8)
m.add(rattle(0.2, 14), 0.12, 0.6)
m.add(rattle(0.18, 12), 0.34, 0.5)
m.add(rattle(0.16, 9), 0.54, 0.4)
m.add(drop_tail(gulp, 1.06, 0.42), 0.82, 0.75)
m.save("pills.wav")

# medkit: latch, zipper, cloth, tape ripped, cloth
m = Mix(2.3)
m.add(inv("metal_latch.wav"), 0.0, 0.7)
m.add(zipper(0.5), 0.16, 0.55)
m.add(inv("cloth1.wav"), 0.68, 0.8)
m.add(rip(0.32), 1.2, 0.7)
m.add(inv("cloth3.wav"), 1.6, 0.8)
m.save("medkit.wav")

# bandage: fabric torn, wrapped round twice
m = Mix(1.9)
m.add(rip(0.42, 600, 4200), 0.0, 0.8)
m.add(inv("cloth2.wav"), 0.5, 0.9)
m.add(inv("cloth4.wav"), 0.95, 1.0)
m.add(inv("cloth3.wav"), 1.3, 0.7)
m.save("bandage.wav")

# searching: four takes of rummaging (played one after another while the search runs)
parts = {
    "cloth1": inv("cloth1.wav"), "cloth2": inv("cloth2.wav"), "cloth3": inv("cloth3.wav"),
    "cloth4": inv("cloth4.wav"), "belt": inv("cloth_belt.wav"), "belt2": inv("cloth_belt2.wav"),
    "leather": inv("handle_small_leather.wav"), "leather2": inv("handle_small_leather2.wav"),
    "buckle": inv("belt_handle1.wav")
}
takes = [
    [("cloth1", 0.0, 0.9), ("leather", 0.38, 0.8), ("cloth3", 0.62, 0.7), ("zip", 0.85, 0.35)],
    [("belt2", 0.0, 0.8), ("cloth4", 0.45, 1.0), ("coins", 0.7, 0.4), ("cloth2", 0.9, 0.8)],
    [("cloth2", 0.0, 0.9), ("buckle", 0.3, 0.45), ("leather2", 0.55, 1.0), ("cloth1", 0.8, 0.6)],
    [("belt", 0.0, 0.7), ("paper", 0.35, 0.3), ("cloth3", 0.62, 0.9), ("leather", 0.95, 0.7)]
]

for index, take in enumerate(takes, 1):
    m = Mix(1.9)

    for name, at, gain in take:
        if name == "zip":
            sound = zipper(0.32, 90, 160)
        elif name == "coins":
            sound = ring((3120, 4710, 6890), 0.03, 0.12, 0.3) + np.pad(ring((2780, 4390), 0.025, 0.1), (2200, 0))[:5292]
        elif name == "paper":
            sound = crinkle(0.3, 120, 1200, 5000)
        else:
            sound = parts[name]

        m.add(sound, at + rng.uniform(-0.03, 0.03), gain)

    m.save(f"search_{index}.wav", 0.7)
