import sys
sys.path.insert(0, '/tmp/bscripts')
import srcmdl
from lupa import luajit21
A = '/home/user/newgametest/combine_fabricator/lua/'
r = srcmdl.load('/tmp/u/fab/combine_fabricator/models/cf_rework/station.mdl'); V = r['verts']
for rotated in (False, True):
    L = luajit21.LuaRuntime(unpack_returned_tuples=True)
    L.execute(open('/tmp/bscripts/gmod_mock.lua').read())
    L.execute('''
      SERVER, CLIENT = false, true
      MESHES = 0 TRIS = 0
      function Mesh() return {BuildFromTriangles = function(_, t) MESHES = MESHES + 1 TRIS = TRIS + #t / 3 end, Destroy = function() end} end
      function Material(p) return {path = p} end
      function CreateMaterial(n) return {name = n} end
      function ErrorNoHalt(s) print('ERROR', s) end
      util.GetModelMeshes = function() return SRC end
    ''')
    for f in ('sh_math', 'sh_config', 'sh_layout', 'sh_geometry', 'sh_rig', 'sh_station', 'cl_partmap', 'cl_ui', 'cl_parts'):
        L.execute(open(A + 'cf_rework/%s.lua' % f, encoding='utf-8').read())
    mk = L.eval('function(x,y,z) return Vector(x,y,z) end')
    src = []
    for m in r['meshes']:
        if not m['tris']: continue
        tl = []
        for t in m['tris']:
            for i in t:
                p, n, uv = V[i]
                if rotated: p = (-p[1], p[0], p[2]); n = (-n[1], n[0], n[2])
                tl.append(L.table_from({'pos': mk(*p), 'normal': mk(*n), 'u': uv[0], 'v': uv[1]}))
        src.append(L.table_from({'material': 'cf_rework/station/' + m['material'], 'triangles': L.table_from(tl)}))
    L.globals().SRC = L.table_from(src)
    L.execute('''
      CFRework.Parts.Prepare()
      local n = 0
      while CFRework.Parts.Ready() == false and n < 100000 do RunHook('Think') n = n + 1 if not HOOKS.Think then break end end
      print('rotated input:', ROT, 'ready:', CFRework.Parts.Ready(), 'matched components:', CFRework.Parts.Matched, 'meshes:', MESHES, 'tris:', TRIS)
    '''.replace('ROT', 'true' if rotated else 'false'))
