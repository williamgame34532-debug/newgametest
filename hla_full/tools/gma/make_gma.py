import json, os, struct, sys, time, zlib, fnmatch

WHITELIST = ['data_static/*.csv', 'data_static/*.dat', 'data_static/*.json', 'data_static/*.txt', 'data_static/*.xml', 'gamemodes/*/*.fgd', 'gamemodes/*/*.txt', 'gamemodes/*/backgrounds/*.jpeg', 'gamemodes/*/backgrounds/*.jpg', 'gamemodes/*/backgrounds/*.png', 'gamemodes/*/content/maps/*.ain', 'gamemodes/*/content/maps/*.bsp', 'gamemodes/*/content/maps/*.nav', 'gamemodes/*/content/maps/thumb/*.png', 'gamemodes/*/content/materials/*.jpeg', 'gamemodes/*/content/materials/*.jpg', 'gamemodes/*/content/materials/*.png', 'gamemodes/*/content/materials/*.vmt', 'gamemodes/*/content/materials/*.vtf', 'gamemodes/*/content/materials/colorcorrection/*.raw', 'gamemodes/*/content/models/*.ani', 'gamemodes/*/content/models/*.mdl', 'gamemodes/*/content/models/*.phy', 'gamemodes/*/content/models/*.vtx', 'gamemodes/*/content/models/*.vvd', 'gamemodes/*/content/particles/*.pcf', 'gamemodes/*/content/resource/fonts/*.ttf', 'gamemodes/*/content/resource/localization/*/*.properties', 'gamemodes/*/content/scenes/*.vcd', 'gamemodes/*/content/scripts/vehicles/*.txt', 'gamemodes/*/content/sound/*.mp3', 'gamemodes/*/content/sound/*.ogg', 'gamemodes/*/content/sound/*.wav', 'gamemodes/*/entities/effects/*.lua', 'gamemodes/*/entities/entities/*.lua', 'gamemodes/*/entities/weapons/*.lua', 'gamemodes/*/gamemode/*.lua', 'gamemodes/*/icon24.png', 'gamemodes/*/logo.png', 'lua/*.lua', 'maps/*.ain', 'maps/*.bsp', 'maps/*.lmp', 'maps/*.nav', 'maps/thumb/*.png', 'materials/*.jpeg', 'materials/*.jpg', 'materials/*.png', 'materials/*.vmt', 'materials/*.vtf', 'materials/colorcorrection/*.raw', 'models/*.ani', 'models/*.mdl', 'models/*.phy', 'models/*.vtx', 'models/*.vvd', 'particles/*.pcf', 'resource/fonts/*.ttf', 'resource/localization/*/*.properties', 'scenes/*.vcd', 'scripts/vehicles/*.txt', 'shaders/fxc/*.vcs', 'sound/*.mp3', 'sound/*.ogg', 'sound/*.wav']
BLACKLIST = ['gamemodes/*/*/*.fgd', 'gamemodes/*/*/*.txt', 'gamemodes/*/content/models/*.360.vtx', 'gamemodes/*/content/models/*.sw.vtx', 'gamemodes/*/content/models/*.xbox.vtx', 'models/*.360.vtx', 'models/*.sw.vtx', 'models/*.xbox.vtx']

def allowed(rel):
    if any(fnmatch.fnmatchcase(rel, w) for w in BLACKLIST):
        return False
    return any(fnmatch.fnmatchcase(rel, w) for w in WHITELIST)

def build(folder, out):
    meta = json.load(open(os.path.join(folder, 'addon.json'), encoding='utf-8'))
    ignore = meta.get('ignore', [])
    files, bad = [], []
    for root, _, names in os.walk(folder):
        for n in sorted(names):
            full = os.path.join(root, n)
            rel = os.path.relpath(full, folder).replace(os.sep, '/').lower()
            if rel == 'addon.json' or any(fnmatch.fnmatchcase(rel, i) for i in ignore):
                continue
            (files if allowed(rel) else bad).append((rel, full))
    if bad:
        raise SystemExit('not allowed by the Garry\'s Mod whitelist: ' + ', '.join(r for r, _ in bad))
    files.sort()
    desc = json.dumps({'description': meta.get('description', 'Description'), 'type': meta.get('type', ''),
                       'tags': meta.get('tags', [])}, ensure_ascii=False)
    head = b'GMAD' + struct.pack('<BQQ', 3, 0, int(time.time())) + b'\0'
    head += meta['title'].encode('utf-8') + b'\0' + desc.encode('utf-8') + b'\0' + b'Author Name\0' + struct.pack('<i', 1)
    index, data = b'', b''
    for i, (rel, full) in enumerate(files, 1):
        blob = open(full, 'rb').read()
        index += struct.pack('<I', i) + rel.encode('utf-8') + b'\0' + struct.pack('<qI', len(blob), zlib.crc32(blob) & 0xFFFFFFFF)
        data += blob
    body = head + index + struct.pack('<I', 0) + data
    body += struct.pack('<I', zlib.crc32(body) & 0xFFFFFFFF)
    open(out, 'wb').write(body)
    return files

def read(path):
    b = open(path, 'rb').read()
    assert b[:4] == b'GMAD' and b[4] == 3
    p = 4 + 1 + 8 + 8
    while b[p] != 0:
        p = b.index(b'\0', p) + 1
    p += 1
    strs = []
    for _ in range(3):
        e = b.index(b'\0', p); strs.append(b[p:e].decode('utf-8')); p = e + 1
    p += 4
    entries = []
    while True:
        n, = struct.unpack_from('<I', b, p); p += 4
        if n == 0: break
        e = b.index(b'\0', p); name = b[p:e].decode('utf-8'); p = e + 1
        size, crc = struct.unpack_from('<qI', b, p); p += 12
        entries.append((name, size, crc))
    for name, size, crc in entries:
        assert zlib.crc32(b[p:p + size]) & 0xFFFFFFFF == crc, name
        p += size
    assert struct.unpack_from('<I', b, p)[0] == zlib.crc32(b[:p]) & 0xFFFFFFFF
    return strs, entries

if __name__ == '__main__':
    folder, out = sys.argv[1], sys.argv[2]
    build(folder, out)
    strs, entries = read(out)
    print(strs[0], strs[1])
    for e in entries: print(' ', e[0], e[1])
