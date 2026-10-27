#!/usr/bin/env python3
"""Synthesises the creepy sounds of Echoes of Sleep (numpy -> WAV -> ffmpeg/libvorbis -> .ogg, mono)."""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'src', 'main', 'resources', 'assets', 'echoesofsleep', 'sounds')
rng = np.random.default_rng(1234)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def band(x, lo, hi):
    """FFT band-pass with soft edges."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    X = np.fft.rfft(x)
    w = 1 / (1 + ((f / max(hi, 1)) ** 4))
    if lo > 0:
        w = w * (1 - 1 / (1 + ((f / lo) ** 4)))
    return np.fft.irfft(X * w, n)


def lowpass(x, hi):
    return band(x, 0, hi)


def reverb(x, decay=1.2, mix=0.35):
    ir_len = int(SR * decay)
    ir = rng.standard_normal(ir_len) * np.exp(-np.linspace(0, 6, ir_len))
    ir = lowpass(ir, 4000)
    ir /= np.abs(ir).sum() / 8
    n = len(x) + ir_len
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    out = np.concatenate([x, np.zeros(ir_len)]) * (1 - mix) + y * mix
    return out


def env(n, attack=0.01, release=0.1):
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def norm(x, peak=0.85):
    m = np.abs(x).max()
    return x / m * peak if m > 0 else x


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = norm(x)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + '.wav')
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        ogg = os.path.join(OUT, name + '.ogg')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4', ogg], check=True)
    print('%-12s %6.1f KB' % (name, os.path.getsize(ogg) / 1024))


# ------------------------------------------------------------------------------------------- voices
def whisper(seed, dur=2.2):
    r = np.random.default_rng(seed)
    n = int(SR * dur)
    out = np.zeros(n)
    pos = int(0.05 * SR)
    while pos < n - int(0.25 * SR):
        syl = int(SR * r.uniform(0.08, 0.22))
        noise = r.standard_normal(syl)
        if r.random() < 0.4:   # sibilant "s"/"sh"
            s = band(noise, 3500, 7000) * 0.7
        else:                  # breathy vowel with a moving formant
            f1 = r.uniform(500, 900)
            s = band(noise, f1, f1 * 2.2) + band(noise, 1800, 3000) * 0.5
        e = np.sin(np.linspace(0, np.pi, syl)) ** 1.5
        out[pos:pos + syl] += s * e * r.uniform(0.5, 1.0)
        pos += syl + int(SR * r.uniform(0.01, 0.12))
    out *= 0.6 + 0.4 * np.sin(np.linspace(0, r.uniform(2, 5), n)) ** 2
    return reverb(out, 0.9, 0.4)


def heartbeat():
    x = t(1.0)
    out = np.zeros_like(x)
    for start, amp in ((0.0, 1.0), (0.24, 0.7)):
        tt = x - start
        m = tt >= 0
        thump = np.sin(2 * np.pi * (55 - 20 * np.clip(tt, 0, 0.2)) * tt) * np.exp(-tt * 14)
        out += np.where(m, thump * amp, 0)
    out += lowpass(rng.standard_normal(len(x)), 120) * np.exp(-x * 9) * 0.6
    return lowpass(out, 400)


def drone(dur=8.0):
    x = t(dur)
    freqs = [55.0, 55.6, 82.4, 110.3, 116.5, 164.8]
    out = sum(np.sin(2 * np.pi * f * x + rng.uniform(0, 6)) * a for f, a in zip(freqs, (1, 0.9, 0.5, 0.4, 0.25, 0.2)))
    out *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.17 * x)
    out += lowpass(rng.standard_normal(len(x)), 150) * 0.8
    high = np.sin(2 * np.pi * 1318 * x) * 0.03 * np.clip(np.sin(2 * np.pi * 0.11 * x), 0, 1) ** 3
    high += np.sin(2 * np.pi * 1397 * x) * 0.03 * np.clip(np.sin(2 * np.pi * 0.09 * x + 1), 0, 1) ** 3
    return reverb((out + high) * env(len(x), 1.5, 2.0), 2.0, 0.4)


def footstep(seed):
    r = np.random.default_rng(seed)
    x = t(0.35)
    thud = band(r.standard_normal(len(x)), 60, 350) * np.exp(-x * 30)
    crunch = band(r.standard_normal(len(x)), 1200, 4000) * np.exp(-x * 45) * 0.35
    return reverb(thud + crunch, 0.5, 0.3)


def scream():
    x = t(1.9)
    f0 = 520 + 380 * np.sin(np.pi * np.clip(x / 1.2, 0, 1)) - 200 * np.clip(x - 1.2, 0, 1)
    f0 *= 1 + 0.03 * np.sin(2 * np.pi * 7 * x) + 0.02 * rng.standard_normal(len(x)).cumsum() / 300
    phase = 2 * np.pi * np.cumsum(f0) / SR
    saw = 2 * ((phase / (2 * np.pi)) % 1) - 1
    voice = band(saw, 700, 1300) + band(saw, 2300, 3200) * 0.7 + band(rng.standard_normal(len(x)), 1500, 5000) * 0.25
    voice = np.tanh(voice * 3)
    return reverb(voice * env(len(x), 0.05, 0.6), 1.6, 0.45)


def glitch():
    x = t(0.7)
    out = np.zeros_like(x)
    pos = 0
    while pos < len(x):
        seg = int(SR * rng.uniform(0.015, 0.05))
        kind = rng.integers(0, 3)
        tt = np.arange(seg) / SR
        if kind == 0:
            s = np.sign(np.sin(2 * np.pi * rng.uniform(200, 2400) * tt))
        elif kind == 1:
            s = rng.standard_normal(seg)
        else:
            s = np.zeros(seg)
        out[pos:pos + seg] = s[:len(out[pos:pos + seg])] * rng.uniform(0.3, 1)
        pos += seg
    out = np.round(out * 6) / 6  # bit-crush
    return out * env(len(x), 0.002, 0.05)


def creak():
    x = t(1.6)
    out = np.zeros_like(x)
    rate = np.linspace(38, 12, len(x))
    phase = np.cumsum(rate) / SR
    ticks = np.where(np.diff(np.floor(phase), prepend=0) > 0)[0]
    ping_t = np.arange(int(0.03 * SR)) / SR
    for i, p in enumerate(ticks):
        f = 520 + 200 * np.sin(i * 0.3)
        ping = np.sin(2 * np.pi * f * ping_t) * np.exp(-ping_t * 120) + np.sin(2 * np.pi * f * 1.7 * ping_t) * np.exp(-ping_t * 160) * 0.4
        end = min(len(out), p + len(ping))
        out[p:end] += ping[:end - p]
    return reverb(band(out, 200, 2500) * env(len(x), 0.05, 0.3), 0.7, 0.3)


def breath():
    x = t(2.4)
    noise = rng.standard_normal(len(x))
    inhale = band(noise, 400, 2200) * np.clip(np.sin(np.pi * x / 1.0), 0, 1) * (x < 1.0)
    exh = (x >= 1.1) * np.clip(np.sin(np.pi * (x - 1.1) / 1.3), 0, 1)
    exhale = band(noise, 250, 1400) * exh * (0.7 + 0.3 * np.sign(np.sin(2 * np.pi * 26 * x)))  # wet rattle
    return reverb(inhale * 0.6 + exhale, 0.6, 0.25)


def crack():
    x = t(0.45)
    out = lowpass(rng.standard_normal(len(x)), 200) * np.exp(-x * 25) * 0.8
    for start in (0.0, 0.03, 0.07, 0.12):
        s = int(start * SR)
        burst = band(rng.standard_normal(int(0.02 * SR)), 2000, 8000) * np.exp(-np.arange(int(0.02 * SR)) / SR * 250)
        out[s:s + len(burst)] += burst * rng.uniform(0.6, 1.0)
    return reverb(out, 0.4, 0.2)


def groan():
    x = t(2.2)
    f0 = 78 - 12 * x / 2.2 + 3 * np.sin(2 * np.pi * 0.8 * x)
    phase = 2 * np.pi * np.cumsum(f0) / SR
    saw = 2 * ((phase / (2 * np.pi)) % 1) - 1
    v = band(saw, 300, 700) + band(saw, 700, 1100) * 0.5
    v *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 29 * x))  # vocal fry
    return reverb(np.tanh(v * 2) * env(len(x), 0.2, 0.6), 1.2, 0.35)


def wail():
    x = t(2.6)
    f0 = 430 - 160 * x / 2.6
    f0 = f0 * (1 + 0.04 * np.sin(2 * np.pi * 5.5 * x))
    phase = 2 * np.pi * np.cumsum(f0) / SR
    v = np.sin(phase) + 0.4 * np.sin(2 * phase + 0.5) + 0.2 * np.sin(3.01 * phase)
    v += band(rng.standard_normal(len(x)), 800, 3000) * 0.2
    return reverb(v * env(len(x), 0.3, 1.0), 2.0, 0.5)


def sting():
    x = t(1.6)
    cluster = sum(np.sin(2 * np.pi * f * x) for f in (1180, 1252, 1331, 1905, 2013)) / 5
    cluster *= np.exp(-x * 2.2) * (1 + 0.3 * np.sin(2 * np.pi * 9 * x))
    boom = np.sin(2 * np.pi * 45 * x) * np.exp(-x * 4)
    attack = band(rng.standard_normal(len(x)), 2000, 7000) * np.exp(-x * 40) * 0.5
    return reverb(cluster + boom + attack, 1.5, 0.4)


def rumble():
    x = t(3.0)
    out = lowpass(rng.standard_normal(len(x)), 110) * 3
    for _ in range(14):
        s = int(rng.uniform(0, 2.7) * SR)
        c = band(rng.standard_normal(int(0.08 * SR)), 300, 2500) * np.exp(-np.arange(int(0.08 * SR)) / SR * 40)
        out[s:s + len(c)] += c * rng.uniform(0.2, 0.6)
    return reverb(out * env(len(x), 0.3, 0.8), 1.0, 0.3)


def pulse():
    x = t(1.8)
    f = 120 * np.exp(-x * 1.6) + 30
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
    swell = band(rng.standard_normal(len(x)), 80, 900) * np.exp(-((x - 0.25) ** 2) / 0.02)
    return reverb(np.tanh((tone * np.exp(-x * 1.5) + swell * 0.8) * 2), 1.5, 0.35)


def lullaby():
    notes = [76, 79, 81, 79, 76, 74, 76, 71]  # music-box melody, slightly out of tune
    dur = 0.34
    total = t(dur * len(notes) + 1.2)
    out = np.zeros_like(total)
    for i, nnum in enumerate(notes):
        f = 440 * 2 ** ((nnum - 69) / 12) * (1 + rng.uniform(-0.012, 0.012))
        tt = np.arange(int(SR * 1.2)) / SR
        tone = (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * f * 2.01 * tt) + 0.15 * np.sin(2 * np.pi * f * 3.98 * tt)) * np.exp(-tt * 4)
        s = int(i * dur * SR)
        end = min(len(out), s + len(tone))
        out[s:end] += tone[:end - s]
    out *= 1 - 0.08 * np.sin(2 * np.pi * 0.7 * total)  # warped tape
    return reverb(out, 2.0, 0.45)


def ghost_slash():
    x = t(0.8)
    noise = rng.standard_normal(len(x))
    sweep = np.zeros_like(x)
    for k in range(6):
        seg = slice(int(k / 6 * len(x)), int((k + 1) / 6 * len(x)))
        lo = 3000 - k * 400
        sweep[seg] = band(noise, lo, lo * 1.6)[seg]
    sweep *= np.exp(-((x - 0.15) ** 2) / 0.01)
    chord = sum(np.sin(2 * np.pi * f * x) for f in (523, 622, 784)) / 3 * np.exp(-x * 3) * 0.4
    return reverb(sweep + chord, 1.2, 0.5)


def run():
    save('whisper1', whisper(1))
    save('whisper2', whisper(2, 1.8))
    save('whisper3', whisper(3, 2.6))
    save('heartbeat', heartbeat())
    save('drone', drone())
    save('footstep1', footstep(11))
    save('footstep2', footstep(12))
    save('scream', scream())
    save('glitch', glitch())
    save('creak', creak())
    save('breath', breath())
    save('crack', crack())
    save('groan', groan())
    save('wail', wail())
    save('sting', sting())
    save('rumble', rumble())
    save('pulse', pulse())
    save('lullaby', lullaby())
    save('ghost_slash', ghost_slash())


if __name__ == '__main__':
    run()
