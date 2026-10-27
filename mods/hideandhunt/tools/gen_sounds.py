#!/usr/bin/env python3
"""Synthesizes the Hide & Hunt sound effects (mono .ogg) with numpy + ffmpeg (libvorbis)."""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'main', 'resources', 'assets', 'hideandhunt', 'sounds')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.01, release=0.2, dur=None):
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def tone(freq, dur, kind='sine', decay=4.0, attack=0.005):
    t = t_axis(dur)
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(freq, t.shape)) / SR
    if kind == 'sine':
        w = np.sin(ph)
    elif kind == 'square':
        w = np.tanh(np.sin(ph) * 4) * 0.6
    elif kind == 'saw':
        w = 2 * ((ph / (2 * np.pi)) % 1) - 1
    else:
        w = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    return w * np.exp(-decay * t) * env(len(t), attack, min(0.05, dur / 3))


def place(buf, sig, at):
    i = int(at * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[:end - i]


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    pcm = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, name + '.wav')
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4',
                        os.path.join(OUT, name + '.ogg')], check=True)


# countdown beep: bright woodblock-like tick
x = tone(880, 0.18, 'rich', decay=22) + 0.4 * tone(1760, 0.18, 'sine', decay=30)
save('countdown', x)

# randomizer tick: soft woodblock knock (~1100 Hz body + short filtered noise transient)
d = 0.07
n = int(SR * d)
x = tone(1100, d, 'sine', decay=60) + 0.35 * tone(1650, d, 'sine', decay=90)
x += 0.25 * lowpass(rng.standard_normal(n), 0.3) * np.exp(-260 * t_axis(d))
save('randomizer_tick', x)

# randomizer pop: gentle "bloop" for each revealed name (rising sine, round attack)
d = 0.16
t = t_axis(d)
freq = 520 + 380 * (t / d)
x = tone(freq, d, 'sine', decay=14, attack=0.012) + 0.2 * tone(freq * 2, d, 'sine', decay=20, attack=0.012)
save('randomizer_pop', x)

# randomizer reveal: major chord "ding" with shimmer
x = np.zeros(int(SR * 1.1))
for f, a in [(1046.5, 1.0), (1318.5, 0.7), (1568.0, 0.6), (2093.0, 0.35)]:
    place(x, a * tone(f, 1.1, 'sine', decay=3.5), 0)
place(x, 0.4 * tone(2637, 0.4, 'sine', decay=10), 0.05)
save('randomizer_reveal', x)

# hide start: airy whoosh + soft chime
dur = 0.9
n = int(SR * dur)
noise = rng.standard_normal(n)
sweep = np.linspace(0.02, 0.35, n)
y = np.zeros(n)
acc = 0.0
for i in range(n):
    acc += sweep[i] * (noise[i] - acc)
    y[i] = acc
y *= np.sin(np.linspace(0, np.pi, n)) ** 1.5
place(y, 0.5 * tone(1318.5, 0.6, 'sine', decay=5), 0.3)
place(y, 0.4 * tone(1760, 0.5, 'sine', decay=6), 0.42)
save('hide_start', y)

# hunt start: hunting horn (two notes, vibrato)
x = np.zeros(int(SR * 1.5))
for f, at, d in [(220, 0.0, 0.45), (330, 0.42, 1.0)]:
    t = t_axis(d)
    freq = f * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t))
    s = tone(freq, d, 'saw', decay=0.6, attack=0.04)
    s = lowpass(s, 0.18)
    place(x, s, at)
save('hunt_start', x)

# caught: descending sting
x = np.zeros(int(SR * 0.8))
for i, f in enumerate([784, 622, 494, 392]):
    place(x, 0.8 * tone(f, 0.3, 'square', decay=8), i * 0.09)
save('caught', x)

# taunt: slide whistle up and down
t = t_axis(0.75)
freq = 900 + 700 * np.sin(np.pi * t / 0.75) ** 2 * (1 + 0.04 * np.sin(2 * np.pi * 9 * t))
x = tone(freq, 0.75, 'sine', decay=0.8, attack=0.02) + 0.15 * tone(freq * 2, 0.75, 'sine', decay=1.0)
save('taunt', x)

# hint ping: sonar ping with echo
x = np.zeros(int(SR * 1.0))
p = tone(1250, 0.5, 'sine', decay=7)
place(x, p, 0)
place(x, 0.35 * p, 0.22)
place(x, 0.15 * p, 0.44)
save('hint_ping', x)

# join: two-note blip up
x = np.zeros(int(SR * 0.3))
place(x, tone(660, 0.14, 'rich', decay=14), 0)
place(x, tone(990, 0.18, 'rich', decay=12), 0.08)
save('join', x)

# defeat: soft descending minor triad (C5 -> Ab4 -> F4), sine with a little warmth
x = np.zeros(int(SR * 1.0))
for i, f in enumerate([523.25, 415.30, 349.23]):
    place(x, 0.8 * tone(f, 0.45, 'sine', decay=3.5, attack=0.02) + 0.15 * tone(f * 2, 0.45, 'sine', decay=5, attack=0.02), i * 0.2)
save('defeat', x)

# victory: fanfare arpeggio + chord
x = np.zeros(int(SR * 1.8))
notes = [(523.25, 0.0), (659.25, 0.12), (783.99, 0.24), (1046.5, 0.36)]
for f, at in notes:
    place(x, 0.7 * lowpass(tone(f, 0.35, 'saw', decay=4), 0.25), at)
for f in (523.25, 659.25, 783.99, 1046.5):
    place(x, 0.45 * lowpass(tone(f, 1.3, 'saw', decay=1.6, attack=0.02), 0.2), 0.5)
save('victory', x)

print('sounds written to', os.path.abspath(OUT))
