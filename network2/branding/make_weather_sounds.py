"""The weather (sh_weather.lua, cl_weather.lua): its sounds, synthesised (own work).
    sound/network2/weather/rain_loop.wav        light rain: a soft hiss and scattered drops (loop, 8 s)
    sound/network2/weather/rain_heavy_loop.wav  a downpour: a dense roar and many drops (loop, 8 s)
    sound/network2/weather/wind_loop.wav        wind: a low rush with gusts swelling and falling (loop, 12 s)
    sound/network2/weather/thunder_1..3.wav     thunder: a crack, then a long rolling rumble
Loops: mono 44.1 kHz, the end crossfaded into the start and a cue point at 0 (Source loops a wav only
with one). Usage: python make_weather_sounds.py <network2 folder>"""
import os, sys, struct, wave
import numpy as np

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "content", "sound", "network2", "weather")
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(1984)


def band(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = ((f >= lo) & (f <= hi)).astype(float)
    # soft edges
    gain = np.convolve(gain, np.ones(64) / 64, mode="same")
    return np.fft.irfft(X * gain, len(x))


def pink(n):
    white = rng.normal(0, 1, n)
    X = np.fft.rfft(white)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1
    return np.fft.irfft(X / np.sqrt(f), n)


def brown(n):
    return np.cumsum(rng.normal(0, 1, n)) - np.convolve(np.cumsum(rng.normal(0, 1, n)), np.ones(4000) / 4000, "same")


def norm(x, peak):
    x = x - x.mean()
    return x / (np.abs(x).max() or 1) * peak


def level(x, rms, peak=0.97):
    x = x - x.mean()
    x = x / (np.sqrt((x ** 2).mean()) or 1) * rms
    # the loud drops and cracks are rounded off, not the whole sound turned down
    return np.tanh(x / peak) * peak


def write(name, x, loop=False, fade=0.4):
    if loop:
        f = int(SR * fade)
        head, tail = x[:f].copy(), x[-f:].copy()
        ramp = np.linspace(0, 1, f)
        x = x[:-f].copy()
        x[:f] = head * ramp + tail * (1 - ramp)
    else:
        n = int(SR * 0.01)
        x[:n] *= np.linspace(0, 1, n)
        x[-n * 20:] *= np.linspace(1, 0, n * 20)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    if loop:
        b = open(path, "rb").read()
        cue = b"cue " + struct.pack("<II", 28, 1) + struct.pack("<II4sIII", 1, 0, b"data", 0, 0, 0)
        b = b + cue
        b = b[:4] + struct.pack("<I", len(b) - 8) + b[8:]
        open(path, "wb").write(b)


def drops(n, count, lo, hi):
    out = np.zeros(n)
    t = np.arange(int(SR * 0.03)) / SR
    for _ in range(count):
        at = rng.integers(0, n - len(t))
        freq = rng.uniform(lo, hi)
        click = np.sin(2 * np.pi * freq * t * (1 - t * 8)) * np.exp(-t / rng.uniform(0.002, 0.008))
        out[at:at + len(t)] += click * rng.uniform(0.2, 1)
    return out


# light rain
n = SR * 8
hiss = band(pink(n), 900, 9000)
rain = norm(hiss, 0.45) + norm(drops(n, 900, 1800, 5200), 0.35)
write("rain_loop.wav", level(rain, 0.11), loop=True)

# a downpour
roar = band(pink(n), 300, 11000) + 0.6 * band(brown(n), 60, 400)
heavy = norm(roar, 0.6) + norm(drops(n, 3200, 1200, 6000), 0.3)
write("rain_heavy_loop.wav", level(heavy, 0.2), loop=True)

# wind with gusts
n = SR * 12
t = np.arange(n) / SR
rush = band(brown(n), 80, 900) * 0.7 + band(pink(n), 300, 2400) * 0.3
gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / 12 * 2 + 0.7) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * t / 12 * 5))
whistle = band(rng.normal(0, 1, n), 700, 760) * (0.3 + 0.7 * np.sin(2 * np.pi * t / 12 * 3) ** 4)
write("wind_loop.wav", level(norm(rush, 1) * gust + norm(whistle, 0.15), 0.14), loop=True)

# thunder
for k in range(1, 4):
    length = rng.uniform(6, 9)
    n = int(SR * length)
    t = np.arange(n) / SR
    crack = band(rng.normal(0, 1, n), 400, 6000) * np.exp(-t / rng.uniform(0.08, 0.2))
    rumble = band(brown(n), 25, 220)
    rolls = np.zeros(n)
    for _ in range(int(rng.integers(3, 6))):
        at = rng.uniform(0.2, length * 0.6)
        width = rng.uniform(0.4, 1.4)
        rolls += np.exp(-((t - at) / width) ** 2) * rng.uniform(0.5, 1)
    env = np.minimum(t / 0.05, 1) * np.exp(-t / (length * 0.35)) * 0.6 + rolls * np.exp(-t / (length * 0.5)) * 0.5
    thunder = norm(crack, 0.25) * (k != 2) + norm(rumble, 1) * env
    write("thunder_%d.wav" % k, level(thunder, 0.17))
print("weather sounds written")
