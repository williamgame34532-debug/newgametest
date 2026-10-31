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
assert(M.ValidName('Иван') and M.ValidName('Alyx') and M.ValidName("O'Neil") and M.ValidName('Анна-Мария'))
assert(not M.ValidName('A') and not M.ValidName('Ivan1') and not M.ValidName('Иван Петров') and not M.ValidName(string.rep('я', 25)) and M.ValidName(string.rep('я', 24)))
assert(M.ModelLabel('models/player/Group03/female_04.mdl') == 'ЖЕНЩИНА 04' and M.ModelLabel(M.Models[1]) == 'МУЖЧИНА 01')
assert(#M.Models == 16 and M.ValidModel(M.Models[9]) and not M.ValidModel('models/player/gman_high.mdl'))
print('PASS menu: names (Cyrillic/Latin, 2-24 letters), model whitelist and labels')
""", 'menu rules')
run(pathlib.Path('tools/server_tests.lua').read_text(),'server lifecycle')
