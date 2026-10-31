"""Decompile Half-Life: Alyx shaders (.vcs, Source 2 v64, PC/DX11) into readable HLSL.

  python vcs_decompile.py <shader.vcs> <out dir>

Steps: the LZMA blocks of the .vcs hold the compiled programs (DXBC, Shader Model 5); each DXBC is
converted to SPIR-V with vkd3d-compiler and then to HLSL with spirv-cross. Needs (Linux / WSL):
  apt install vkd3d-compiler spirv-cross
Names of constants and textures are stripped from the DXBC (no RDEF chunk): constant buffers show
up as cbN_0_m0[i] and textures as tN. The parameter names of the shader are listed in names.txt
(taken from the .vcs) to map them by hand.
"""
import lzma
import os
import re
import struct
import subprocess
import sys


def lzma_blocks(d):
    i = 0
    while True:
        i = d.find(b'LZMA', i)
        if i < 0:
            return
        try:
            us, cs = struct.unpack_from('<II', d, i + 4)
            props = d[i + 12:i + 17]
            filt = {'id': lzma.FILTER_LZMA1, 'dict_size': struct.unpack('<I', props[1:5])[0],
                    'lc': props[0] % 9, 'lp': (props[0] // 9) % 5, 'pb': props[0] // 45}
            out = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=[filt]).decompress(d[i + 17:i + 17 + cs], us)
            yield out
            i += 17 + cs
        except Exception:
            i += 4


def dxbc_programs(d):
    seen = set()
    for blk in [d] + list(lzma_blocks(d)):
        i = 0
        while True:
            j = blk.find(b'DXBC', i)
            if j < 0:
                break
            size, = struct.unpack_from('<I', blk, j + 24)
            prog = blk[j:j + size]
            if len(prog) == size and prog not in seen:
                seen.add(prog)
                yield prog
            i = j + max(size, 4)


def main(vcs, out):
    os.makedirs(out, exist_ok=True)
    d = open(vcs, 'rb').read()
    names = sorted(set(m.decode() for m in re.findall(rb'g_[A-Za-z0-9_]{3,}', d)))
    open(os.path.join(out, 'names.txt'), 'w').write('\n'.join(names) + '\n')
    base = os.path.splitext(os.path.basename(vcs))[0]
    n = 0
    for k, prog in enumerate(dxbc_programs(d)):
        stem = os.path.join(out, '%s_%03d' % (base, k))
        open(stem + '.dxbc', 'wb').write(prog)
        r = subprocess.run(['vkd3d-compiler', '-x', 'dxbc-tpf', '-b', 'spirv-binary', '-o', stem + '.spv', stem + '.dxbc'],
                           capture_output=True, text=True)
        if r.returncode:
            print('vkd3d failed', stem, r.stderr.strip()[:200])
            continue
        r = subprocess.run(['spirv-cross', stem + '.spv', '--hlsl', '--shader-model', '50', '--output', stem + '.hlsl'],
                           capture_output=True, text=True)
        if r.returncode:
            print('spirv-cross failed', stem, r.stderr.strip()[:200])
            continue
        n += 1
    print('%s: %d programs decompiled, %d parameter names -> %s' % (base, n, len(names), out))


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
