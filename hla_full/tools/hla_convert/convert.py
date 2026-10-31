# Rebuild modelsrc/hla_station from the Half-Life: Alyx files:
#   python tools/hla_convert/convert.py <folder with combine_crafting_station.vmdl_c> <selfillum .vtex_c> <out modelsrc dir> <content addon dir>
import sys, os, pickle, subprocess
import numpy as np
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from kv3 import read_resource, kv3
from mbuf import read_mbuf
from meshopt import decode_index_buffer, decode_vertex_buffer
from anim import build
from vtex import read_vtex, write_vtf

src, selfillum, out, content = sys.argv[1:5]
work = os.path.join(out, '_work'); os.makedirs(work, exist_ok=True)
b, bl = read_resource(os.path.join(src, 'combine_crafting_station.vmdl_c'))
K = {n: kv3(b, *bl[n][0]) for n in ['DATA', 'MDAT', 'ASEQ', 'AGRP', 'ANIM']}
pickle.dump(K, open(os.path.join(work, 'station_kv.pkl'), 'wb'))
m = read_mbuf(b, bl['MBUF'][0][0])
ib, vb = m['ib'][0], m['vb'][0]
np.savez(os.path.join(work, 'station_mesh.npz'), idx=decode_index_buffer(ib['count'], ib['esize'], ib['raw']),
         v=decode_vertex_buffer(vb['count'], vb['esize'], vb['raw']))
pickle.dump(build(K), open(os.path.join(work, 'station_anims.pkl'), 'wb'))
subprocess.check_call([sys.executable, os.path.join(here, 'export_smd.py'), work, out])
write_vtf(os.path.join(content, 'materials/models/cf_rework/hla/crafting_1002_selfillum.vtf'),
          read_vtex(selfillum).resize((1024, 1024)), 'BGR888', flags=0)
print('done:', out)
