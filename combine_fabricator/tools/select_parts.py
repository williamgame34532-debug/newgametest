"""Select model components for each moving part (entity space rules). Writes /tmp/u/parts.json"""
import json
C = json.load(open('/tmp/u/comps_all.json'))
hidden = lambda c: c['vis'] < 0.02
def inbox(c, x0, x1, y0, y1, z0, z1):
    return x0 <= c['c'][0] <= x1 and y0 <= c['c'][1] <= y1 and z0 <= c['c'][2] <= z1
def dims(c): return [c['hi'][k] - c['lo'][k] for k in range(3)]

parts = {}
# rib cage (weapon cradle): everything hidden around the X-axis cylinder at Y~6.5 Z~33
parts['cage'] = [c['id'] for c in C if hidden(c) and inbox(c, -8, 18, -1.5, 15.5, 22, 42.5)]
# resin cells: the 2x5 tube magazine and its end plates
parts['cells'] = [c['id'] for c in C if hidden(c) and inbox(c, -3.6, 16, -19.6, 0.4, 30.5, 40.5)
                  and not (dims(c)[1] > 15 and dims(c)[2] < 2)]  # skip the flat frame on top
# grille rods: tall thin vertical members under the cells
parts['rods'] = [c['id'] for c in C if hidden(c) and inbox(c, -13, 4, -19.5, -1, 14, 31.5)
                 and dims(c)[2] > 7 and dims(c)[0] < 2.5]
# front logo panel that covers the cage
parts['logo'] = [92]
# roof panel above the cells
parts['lid'] = [12]
json.dump(parts, open('/tmp/u/parts.json', 'w'))
for k, v in parts.items():
    n = sum(C[i]['n'] for i in v)
    print(k, len(v), 'comps', n, 'tris')
