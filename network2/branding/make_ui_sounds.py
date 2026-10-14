"""UI sounds of the main menu -> content/sound/network2/ui/*.wav (44.1 kHz, 16 bit, mono).
Grey city mood: muffled, mechanical, heavy - no bright beeps.
    hover.wav    a dull mechanical tick (a relay / a worn switch brushed)
    click.wav    a stiff toggle switch: press and release clicks, a low body thump, a short
                 metallic ring of the housing
    confirm.wav  a deep heavy impact with a falling pitch, a low city rumble and a distant metal
                 resonance fading out ("Играть", under the fade to black)
Synthesised here (own sounds, nothing taken from other games)."""
import os, sys, wave
import numpy as np
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
SR = 44100
rng = np.random.default_rng(11)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, attack, decay, start=0):
    tt = np.arange(n) / SR - start
    a = np.clip(tt / attack, 0, 1)
    return np.where(tt < 0, 0, a * np.exp(-np.clip(tt, 0, None) / decay))


def bandpass(x, lo, hi):
    """FFT band filter with soft edges."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    w = np.clip((f - lo * 0.7) / (lo * 0.3), 0, 1) * np.clip((hi * 1.3 - f) / (hi * 0.3), 0, 1)
    return np.fft.irfft(X * w, len(x))


def lowpass(x, hi):
    return bandpass(x, 1, hi)


def save(name, x, gain):
    x = x - np.mean(x)
    x = x / np.max(np.abs(x)) * gain
    fade = int(SR * 0.006)
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


# hover: 60 ms - a muffled tick: band-limited noise burst 900-2500 Hz + a tiny low knock
d = t(0.06)
n = len(d)
tick = bandpass(rng.normal(0, 1, n), 900, 2500) * env(n, 0.0008, 0.006)
knock = np.sin(2 * np.pi * 190 * d) * env(n, 0.001, 0.012)
save("hover.wav", lowpass(tick + 0.5 * knock, 4000), 0.32)

# click: 220 ms - press (t=0) and release (t=38 ms): dry noise transients, a body thump
# at 95 Hz, a short ring of the metal housing (920 + 1460 Hz, inharmonic)
d = t(0.22)
n = len(d)
press = bandpass(rng.normal(0, 1, n), 700, 3500) * env(n, 0.0005, 0.005)
release = bandpass(rng.normal(0, 1, n), 1000, 4000) * env(n, 0.0005, 0.004, start=0.038) * 0.6
thump = np.sin(2 * np.pi * 95 * d * (1 - 0.15 * d)) * env(n, 0.001, 0.03)
ring = (np.sin(2 * np.pi * 920 * d) + 0.6 * np.sin(2 * np.pi * 1460 * d)) * env(n, 0.001, 0.045) * 0.22
save("click.wav", lowpass(press + release + 0.9 * thump + ring, 6000), 0.6)

# confirm: 1.6 s - heavy impact (55 Hz falling to 38 Hz), a dull noise hit, low rumble,
# a distant metallic resonance (slow beating partials) fading out
d = t(1.6)
n = len(d)
freq = 55 - 17 * (1 - np.exp(-d / 0.25))
boom = np.sin(2 * np.pi * np.cumsum(freq) / SR) * env(n, 0.004, 0.35)
hit = lowpass(rng.normal(0, 1, n), 900) * env(n, 0.001, 0.05) * 0.8
rumble = lowpass(rng.normal(0, 1, n), 160) * env(n, 0.08, 0.6) * 2.0
metal = sum(a * np.sin(2 * np.pi * f * d) for f, a in ((233, 1.0), (237.5, 0.8), (591, 0.35), (1210, 0.12)))
metal *= env(n, 0.03, 0.55) * 0.12
save("confirm.wav", boom + hit + rumble + metal, 0.75)
print("written", sorted(os.listdir(OUT)))
