"""Half-Life: Alyx sounds (.vsnd_c) -> .wav / .mp3 for Garry's Mod.

  python vsnd.py <file.vsnd_c | folder> <out dir>

The DATA block of an HL:A sound is a 48-byte header:
  uint16 sample rate, uint8 format (0 PCM16, 1 PCM8, 2 MP3), uint8 channels,
  int32 loop start, uint32 sample count, float duration, ...
and the audio itself follows the resource (at the offset given by the first header field).
"""
import os
import struct
import sys
import wave

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from kv3 import read_resource


def convert(path, out_dir):
    b, bl = read_resource(path)
    o, _s = bl['DATA'][0]
    rate, fmt, channels = struct.unpack_from('<HBB', b, o)
    loop, count = struct.unpack_from('<iI', b, o + 4)
    start, = struct.unpack_from('<I', b, 0)
    audio = b[start:]
    name = os.path.splitext(os.path.basename(path))[0]
    if fmt == 2:
        dst = os.path.join(out_dir, name + '.mp3')
        open(dst, 'wb').write(audio)
    elif fmt in (0, 1):
        width = 2 if fmt == 0 else 1
        dst = os.path.join(out_dir, name + '.wav')
        with wave.open(dst, 'wb') as w:
            w.setnchannels(max(1, channels))
            w.setsampwidth(width)
            w.setframerate(rate)
            frames = audio[:count * max(1, channels) * width] if count else audio
            w.writeframes(frames)
    else:
        raise ValueError('%s: unknown sound format %d' % (path, fmt))
    return dst, rate, fmt, channels, count


def main(src, out):
    os.makedirs(out, exist_ok=True)
    files = [src] if os.path.isfile(src) else [os.path.join(r, f) for r, _d, fs in os.walk(src) for f in fs if f.endswith('.vsnd_c')]
    for f in sorted(files):
        dst, rate, fmt, ch, n = convert(f, out)
        print('%-60s %s %d Hz %d ch %.2f s' % (os.path.basename(dst), ('PCM16', 'PCM8', 'MP3')[fmt], rate, ch, n / float(rate) if n else 0))


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
