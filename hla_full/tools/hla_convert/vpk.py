"""Half-Life: Alyx VPK reader: list and extract files straight from the game's pak01_dir.vpk + pak01_NNN.vpk.

  python vpk.py <...\\Half-Life Alyx\\game\\hlvr\\pak01_dir.vpk> list  <pattern>
  python vpk.py <pak01_dir.vpk> extract <pattern> <out dir> [--deps]
  python vpk.py <pak01_dir.vpk> need    <pattern> [--deps]     # which pak01_NNN.vpk files are needed

<pattern> is a shell glob on the path inside the VPK, e.g. "models/hologram_fx/logo_text_*".
--deps follows the resource references (RERL) of Source 2 files: a model pulls its materials,
a material pulls its textures, and so on, recursively.
Only the archives that hold the requested files are opened.
"""
import fnmatch
import os
import struct
import sys
import zlib

INLINE = 0x7FFF


def _cstr(d, o):
    e = d.index(b'\0', o)
    return d[o:e].decode('utf-8', 'replace'), e + 1


class VPK:
    def __init__(self, dir_path):
        self.dir_path = dir_path
        self.base = dir_path[:-len('_dir.vpk')] if dir_path.endswith('_dir.vpk') else dir_path
        d = open(dir_path, 'rb').read()
        sig, ver, tree = struct.unpack_from('<III', d, 0)
        if sig != 0x55AA1234:
            raise ValueError('not a VPK directory: ' + dir_path)
        hdr = 12 if ver == 1 else 28
        self.data_start = hdr + tree  # data stored inside the dir file (archive index 0x7FFF)
        self.raw = d
        self.files = {}
        o = hdr
        while True:
            ext, o = _cstr(d, o)
            if not ext:
                break
            while True:
                path, o = _cstr(d, o)
                if not path:
                    break
                while True:
                    name, o = _cstr(d, o)
                    if not name:
                        break
                    crc, pre, arc, off, ln, _term = struct.unpack_from('<IHHIIH', d, o)
                    o += 18
                    full = ((path + '/') if path.strip() else '') + name + '.' + ext
                    self.files[full.lower()] = (full, crc, d[o:o + pre], arc, off, ln)
                    o += pre

    def find(self, pattern):
        pattern = pattern.lower().replace('\\', '/')
        return sorted(v[0] for k, v in self.files.items() if fnmatch.fnmatchcase(k, pattern))

    def archive_of(self, path):
        e = self.files.get(path.lower())
        return None if e is None else e[3]

    def read(self, path):
        full, crc, pre, arc, off, ln = self.files[path.lower()]
        if arc == INLINE:
            body = self.raw[self.data_start + off:self.data_start + off + ln]
        elif ln:
            name = '%s_%03d.vpk' % (self.base, arc)
            if not os.path.exists(name):
                raise FileNotFoundError('%s needs %s' % (full, os.path.basename(name)))
            with open(name, 'rb') as f:
                f.seek(off)
                body = f.read(ln)
        else:
            body = b''
        data = pre + body
        if zlib.crc32(data) & 0xFFFFFFFF != crc:
            raise IOError('CRC mismatch: ' + full)
        return data


def references(data):
    """Names of the resources a compiled Source 2 file refers to (RERL block)."""
    if len(data) < 16:
        return []
    _size, _hv, _ver, bo, bc = struct.unpack_from('<IHHII', data, 0)
    base = 8 + bo
    if bc > 64 or base + bc * 12 > len(data):  # not a Source 2 resource
        return []
    for i in range(bc):
        o = base + i * 12
        if data[o:o + 4] != b'RERL':
            continue
        off, _sz = struct.unpack_from('<II', data, o + 4)
        blk = o + 4 + off
        if blk + 8 > len(data):
            return []
        roff, cnt = struct.unpack_from('<iI', data, blk)
        if cnt > 100000 or blk + roff + cnt * 16 > len(data):
            return []
        out = []
        p = blk + roff
        for k in range(cnt):
            e = p + k * 16
            noff, = struct.unpack_from('<i', data, e + 8)
            name, _ = _cstr(data, e + 8 + noff)
            out.append(name)
        return out
    return []


def with_deps(vpk, paths):
    """paths plus everything they reference, recursively (only what exists in this VPK)."""
    seen, todo = set(), list(paths)
    while todo:
        p = todo.pop()
        key = p.lower()
        if key in seen or key not in vpk.files:
            continue
        seen.add(key)
        try:
            data = vpk.read(p)
        except FileNotFoundError:
            continue
        for ref in references(data):
            ref = ref.replace('\\', '/')
            cand = ref if ref.endswith('_c') else ref + '_c'
            if cand.lower() in vpk.files:
                todo.append(vpk.files[cand.lower()][0])
    return sorted(vpk.files[k][0] for k in seen)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    vpk = VPK(argv[0])
    cmd, pattern = argv[1], argv[2]
    deps = '--deps' in argv
    paths = vpk.find(pattern)
    if not paths:
        print('nothing matches', pattern)
        return 1
    if cmd == 'list':
        for p in paths:
            print('%-90s pak01_%03d.vpk' % (p, vpk.archive_of(p)))
        return 0
    if deps:
        paths = with_deps(vpk, paths)
    if cmd == 'need':
        arcs = sorted({vpk.archive_of(p) for p in paths} - {INLINE})
        print('\n'.join('pak01_%03d.vpk' % a for a in arcs))
        return 0
    if cmd == 'extract':
        out = [a for a in argv[3:] if not a.startswith('--')][0]
        missing = set()
        for p in paths:
            try:
                data = vpk.read(p)
            except FileNotFoundError as e:
                missing.add(str(e).split(' needs ')[-1])
                continue
            dst = os.path.join(out, p)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            open(dst, 'wb').write(data)
            print('ok', p)
        if missing:
            print('missing archives:', ', '.join(sorted(missing)))
            return 2
        return 0
    print(__doc__)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
