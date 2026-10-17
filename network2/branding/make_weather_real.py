"""The weather (cl_weather.lua): real recordings instead of the synthesised ones (make_weather_sounds.py).
Source: the npm package sounds-for-focus 0.1.0 (MIT; the catalogue of Moodist, recordings from Pixabay
and Freesound under their free licences):
    rain/light-rain    -> rain_loop.wav          light rain (loop)
    rain/heavy-rain    -> rain_heavy_loop.wav    a downpour (loop)
    rain/rain-on-window-> rain_indoor_loop.wav   rain on the window: heard indoors (loop)
    nature/wind        -> wind_loop.wav          wind (loop)
    nature/howling-wind-> wind_storm_loop.wav    the howling wind of a storm (loop)
    rain/thunder       -> thunder_1..3.wav       the three loudest claps
Mono 22.05 kHz; loops crossfaded end into start with a cue point at 0 (Source loops a wav only with one).
    python make_weather_real.py <sounds-for-focus package dir> <network2 folder>"""
import os, subprocess, sys, struct, wave
import numpy as np

PKG, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, "content", "sound", "network2", "weather")
SR = 22050
os.makedirs(OUT, exist_ok=True)


def load(name):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(PKG, "audio", name + ".mp3"), "-ac", "1", "-ar",
                          str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def level(x, rms, peak=0.95):
    x = x - x.mean()
    x = x / (np.sqrt((x ** 2).mean()) or 1) * rms
    return np.tanh(x / peak) * peak


def write(name, x, loop=False, fade=1.5):
    if loop:
        f = int(SR * fade)
        head, tail = x[:f].copy(), x[-f:].copy()
        ramp = np.sqrt(np.linspace(0, 1, f))
        x = x[:-f].copy()
        x[:f] = head * ramp + tail * np.sqrt(1 - ramp ** 2)
    else:
        n = int(SR * 0.01)
        x[:n] *= np.linspace(0, 1, n)
        x[-n * 40:] *= np.linspace(1, 0, n * 40)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    if loop:
        b = open(path, "rb").read() + b"cue " + struct.pack("<II", 28, 1) + struct.pack("<II4sIII", 1, 0, b"data", 0, 0, 0)
        open(path, "wb").write(b[:4] + struct.pack("<I", len(b) - 8) + b[8:])


def part(x, start, seconds):
    return x[int(SR * start):int(SR * (start + seconds))]


write("rain_loop.wav", level(part(load("rain/light-rain"), 30, 22), 0.12), loop=True)
write("rain_heavy_loop.wav", level(part(load("rain/heavy-rain"), 2, 18), 0.2), loop=True)
write("rain_indoor_loop.wav", level(part(load("rain/rain-on-window"), 4, 22), 0.12), loop=True)
write("wind_loop.wav", level(part(load("nature/wind"), 10, 26), 0.13), loop=True)
write("wind_storm_loop.wav", level(part(load("nature/howling-wind"), 6, 22), 0.15), loop=True)

# thunder: the three loudest moments, ten seconds apart at least; from just before each to its end
thunder = load("rain/thunder")
win = int(SR * 0.25)
env = np.sqrt(np.convolve(thunder ** 2, np.ones(win) / win, "same"))
taken = []
for at in np.argsort(env)[::-1]:
    if all(abs(at - other) > SR * 10 for other in taken):
        taken.append(at)
    if len(taken) == 3:
        break
for k, at in enumerate(sorted(taken), 1):
    start = max(0, at - int(SR * 0.6))
    write("thunder_%d.wav" % k, level(thunder[start:start + int(SR * 7)], 0.18))
print("weather sounds written:", sorted(os.listdir(OUT)))
