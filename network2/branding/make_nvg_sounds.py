"""The night vision (cl_vision.lua): its sounds, synthesised (own work) -> sound/network2/nvg/
    on.wav / off.wav           the goggles of the city: a click, the tube charging up with a rising
                               whine / winding down
    cmb_on.wav / cmb_off.wav   the visor of the Alliance: a digital two-tone chirp over a soft thump
    overheat.wav               crackling and three short warning beeps
    hum_loop.wav               the faint whine of a working tube (loop, cue point)
    python make_nvg_sounds.py <network2 folder>"""
import os, sys, struct, wave
import numpy as np

ROOT = sys.argv[1]
OUT = os.path.join(ROOT, "content", "sound", "network2", "nvg")
SR = 44100
rng = np.random.default_rng(7)
os.makedirs(OUT, exist_ok=True)


def write(name, x, loop=False, peak=0.8):
    x = x / (np.abs(x).max() or 1) * peak
    n = int(SR * 0.004)
    if not loop:
        x[:n] *= np.linspace(0, 1, n)
        x[-n * 5:] *= np.linspace(1, 0, n * 5)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    if loop:
        b = open(path, "rb").read() + b"cue " + struct.pack("<II", 28, 1) + struct.pack("<II4sIII", 1, 0, b"data", 0, 0, 0)
        open(path, "wb").write(b[:4] + struct.pack("<I", len(b) - 8) + b[8:])


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def sweep(seconds, f0, f1, curve=2.0):
    tt = t(seconds)
    f = f0 + (f1 - f0) * (tt / seconds) ** (1 / curve)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def click(seconds=0.02, tone=2600):
    tt = t(seconds)
    return (rng.normal(0, 1, len(tt)) * 0.6 + np.sin(2 * np.pi * tone * tt)) * np.exp(-tt / 0.004)


def pad(x, seconds):
    return np.concatenate([x, np.zeros(int(SR * seconds))])


def mix(*parts):
    n = max(len(p[1]) + int(SR * p[0]) for p in parts)
    out = np.zeros(n)
    for at, x in parts:
        i = int(SR * at)
        out[i:i + len(x)] += x
    return out


# the goggles of the city
whine = sweep(0.9, 1800, 9500, 1.6) + 0.3 * sweep(0.9, 3600, 14000, 1.6)
whine *= np.minimum(t(0.9) / 0.05, 1) * np.exp(-t(0.9) / 0.6) * 0.5
write("on.wav", mix((0, click()), (0.03, whine), (0.0, click(0.012, 4200) * 0.5)))
down = sweep(0.5, 9000, 900, 0.7) * np.exp(-t(0.5) / 0.18) * 0.45
write("off.wav", mix((0, click(0.02, 2000)), (0.02, down)))

# the visor of the Alliance
tt = t(0.09)
chirp = lambda f: np.sign(np.sin(2 * np.pi * f * tt)) * 0.25 * np.exp(-tt / 0.06)
thump = np.sin(2 * np.pi * 70 * t(0.25)) * np.exp(-t(0.25) / 0.06)
write("cmb_on.wav", mix((0, thump * 0.8), (0.02, chirp(880)), (0.11, chirp(1320)), (0.2, chirp(1760)),
                        (0.0, click(0.015, 3000) * 0.6)))
write("cmb_off.wav", mix((0, chirp(1760)), (0.09, chirp(1100)), (0.18, thump * 0.6), (0.18, chirp(660))))

# overheat: crackle and beeps
crackle = np.zeros(int(SR * 0.6))
for _ in range(40):
    i = int(rng.integers(0, len(crackle) - 400))
    crackle[i:i + 300] += rng.normal(0, 1, 300) * np.exp(-np.arange(300) / 40) * rng.uniform(0.2, 1)
beep = np.sin(2 * np.pi * 1250 * t(0.08)) * 0.5
write("overheat.wav", mix((0, crackle * 0.5), (0.25, beep), (0.4, beep), (0.55, beep)))

# the hum: two seconds, whole periods so it loops clean
tt = t(2.0)
hum = np.sin(2 * np.pi * 7800 * tt) * 0.25 + np.sin(2 * np.pi * 120 * tt) * 0.1 + rng.normal(0, 0.06, len(tt))
write("hum_loop.wav", hum, loop=True, peak=0.25)
print("nvg sounds written")
