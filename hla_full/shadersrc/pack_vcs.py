"""Wrap one compiled DX9 shader (ps_3_0 / vs_3_0 bytecode) into a Source engine .vcs (version 6),
the format Garry's Mod loads from shaders/fxc. One static and one dynamic combo, stored uncompressed.

  python pack_vcs.py <bytecode.bin> <source.hlsl> <out.vcs>

Layout (Source SDK 2013, public/materialsystem/shader_vcs_version.h + shadermanager.cpp):
  ShaderHeader_t  version=6, totalCombos=1, dynamicCombos=1, flags, centroidMask,
                  numStaticCombos (with the sentinel), sourceCRC32
  StaticComboRecord_t[ ]  {id 0, offset of its data}, sentinel {0xFFFFFFFF, end offset}
  uint32 number of alias records (0)
  combo data: blocks {uint32 size | 0x80000000 (uncompressed)} of records
              {int32 dynamicComboID, int32 bytecodeSize, bytecode}, then 0xFFFFFFFF
"""
import struct
import sys
import zlib


def pack(bytecode, source):
    rec = struct.pack('<ii', 0, len(bytecode)) + bytecode
    block = struct.pack('<I', len(rec) | 0x80000000) + rec + struct.pack('<I', 0xFFFFFFFF)
    header_size = 7 * 4
    records_size = 2 * 8
    alias_size = 4
    data_offset = header_size + records_size + alias_size
    end = data_offset + len(block)
    out = struct.pack('<iiiIIII', 6, 1, 1, 0, 0, 2, zlib.crc32(source) & 0xFFFFFFFF)
    out += struct.pack('<II', 0, data_offset) + struct.pack('<II', 0xFFFFFFFF, end)
    out += struct.pack('<I', 0)
    out += block
    return out


def check(vcs):
    """Read the file back the way the engine does and return the bytecode of combo 0."""
    ver, total, dyn, flags, centroid, nstatic, crc = struct.unpack_from('<iiiIIII', vcs, 0)
    assert ver == 6 and nstatic >= 2
    recs = [struct.unpack_from('<II', vcs, 28 + 8 * i) for i in range(nstatic)]
    assert recs[-1][0] == 0xFFFFFFFF
    p = recs[0][1]
    out = []
    while True:
        size, = struct.unpack_from('<I', vcs, p)
        p += 4
        if size == 0xFFFFFFFF:
            break
        assert size & 0xC0000000 == 0x80000000, 'only uncompressed blocks are written'
        size &= 0x3FFFFFFF
        q, e = p, p + size
        while q < e:
            cid, n = struct.unpack_from('<ii', vcs, q)
            out.append((cid, vcs[q + 8:q + 8 + n]))
            q += 8 + n
        p = e
    assert p == recs[-1][1], 'data must end at the sentinel offset'
    return out


if __name__ == '__main__':
    code = open(sys.argv[1], 'rb').read()
    src = open(sys.argv[2], 'rb').read()
    if struct.unpack_from('<I', code, 0)[0] not in (0xFFFF0300, 0xFFFE0300, 0xFFFF0200, 0xFFFE0200, 0xFFFF0201):
        sys.exit('not DX9 shader bytecode')
    vcs = pack(code, src)
    back = check(vcs)
    assert back == [(0, code)]
    open(sys.argv[3], 'wb').write(vcs)
    print('wrote', sys.argv[3], len(vcs), 'bytes')
