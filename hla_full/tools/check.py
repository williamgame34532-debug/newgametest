import ctypes, pathlib
lib=ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
L=lib.luaL_newstate();lib.luaL_openlibs.argtypes=[ctypes.c_void_p];lib.luaL_openlibs(L)
lib.luaL_loadbufferx.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p,ctypes.c_char_p]
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_settop.argtypes=[ctypes.c_void_p,ctypes.c_int]
def run(s,name='test',execute=True):
 b=s.encode();rc=lib.luaL_loadbufferx(L,b,len(b),name.encode(),None)
 if not rc and execute: rc=lib.lua_pcallk(L,0,0,0,0,None)
 if rc: raise RuntimeError(name+': '+lib.lua_tolstring(L,-1,None).decode())
 lib.lua_settop(L,0)
for p in pathlib.Path('garrysmod/gamemodes/hlalyx').rglob('*.lua'):run(p.read_text(),str(p),False)
print('PASS syntax: all Lua files (Lua 5.4 parser; engine API validation still requires GMod)')
run("""
Vector = function(x, y, z) return {x = x, y = y, z = z} end
math.Clamp = function(v, a, b) return math.max(a, math.min(b, v)) end
""", 'engine doubles')
for f in ['sh_math','sh_config','sh_layout','sh_station','cl_ui']:
 run(pathlib.Path('garrysmod/gamemodes/hlalyx/gamemode/fabricator/'+f+'.lua').read_text(),f)
run('''
local C = CFRework
for cat=1,3 do
 for _,b in ipairs(C.Layout.Buttons(C.State.MENU,cat)) do
  local hit = C.Layout.ButtonAt(C.State.MENU,cat,b.x+b.w/2,b.y+b.h/2)
  assert(hit and hit.id==b.id)
  assert(b.x>=0 and b.y>=0 and b.x+b.w<=1024 and b.y+b.h<=512)
 end
end
print('PASS shared click regions')
''')
run("""
string.Trim = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
util = util or {}; util.IsValidModel = function() return true end
file = file or {}; file.Exists = function(p) return not p:find('gman') end
isstring = function(v) return type(v) == 'string' end
""", 'menu doubles')
run(pathlib.Path('garrysmod/gamemodes/hlalyx/gamemode/sh_menu.lua').read_text(), 'sh_menu')
run("""
local M = HLA.Menu
assert(M.ValidNum('443') and M.ValidNum('007') and not M.ValidNum('44') and not M.ValidNum('4433') and not M.ValidNum('a43'))
assert(M.DisplayName({num = '443'}) == 'ЮНИТ 443')
assert(#M.Models == #M.Classes and M.ModelLabel(M.Classes[1].model) == M.Classes[1].label and not M.ValidModel('models/player/gman_high.mdl'))
print('PASS menu: unit numbers (3 digits), class models and labels')
""", 'menu rules')
run(pathlib.Path('tools/server_tests.lua').read_text(),'server lifecycle')
run("ARG_DIR = 'garrysmod/gamemodes/hlalyx/gamemode'\n" + pathlib.Path('tools/story_tests.lua').read_text(), 'story rounds')
run("ARG = 'garrysmod/gamemodes/hlalyx/entities/entities/hla_npc'\n" + pathlib.Path('tools/npc_tests.lua').read_text(), 'story npc')
