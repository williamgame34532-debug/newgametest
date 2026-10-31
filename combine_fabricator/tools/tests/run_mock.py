import sys
from lupa import luajit21
A = '/home/user/newgametest/combine_fabricator/lua/'
L = luajit21.LuaRuntime(unpack_returned_tuples=True)
def run(path): L.execute(open(path, encoding='utf-8').read())
run('/tmp/bscripts/gmod_mock.lua')
for f in ('sh_math', 'sh_config', 'sh_layout', 'sh_geometry', 'sh_rig', 'sh_station', 'sv_resin'):
    run(A + 'cf_rework/%s.lua' % f)
# entity: ENT table with include('shared.lua')
L.execute("ENT = {} function include() end")
run(A + 'entities/sent_combine_fabricator/shared.lua')
run(A + 'entities/sent_combine_fabricator/init.lua')
L.execute("ENT_FAB = ENT")
run(sys.argv[1])
