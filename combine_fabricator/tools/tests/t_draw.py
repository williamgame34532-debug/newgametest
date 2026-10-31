import sys
sys.path.insert(0,'/tmp/bscripts')
import srcmdl
from lupa import luajit21
A = '/home/user/newgametest/combine_fabricator/lua/'
L = luajit21.LuaRuntime(unpack_returned_tuples=True)
L.execute(open('/tmp/bscripts/gmod_mock.lua').read())
L.execute(r'''
SERVER, CLIENT = false, true
CALLS = {}
local function rec(name) return function(...) CALLS[name] = (CALLS[name] or 0) + 1 end end
local function stubs(names) local t = {} for _, n in ipairs(names) do t[n] = rec(n) end return t end
render = stubs({'SuppressEngineLighting','ResetModelLighting','SetModelLighting','SetMaterial','SetColorModulation','DrawSprite','DrawBeam','MaterialOverride','SetBlend','PushCustomClipPlane','PopCustomClipPlane'})
render.ComputeLighting = function() return Vector(0.2, 0.2, 0.2) end
render.EnableClipping = function() return false end
cam = stubs({'PushModelMatrix','PopModelMatrix','Start3D2D','End3D2D'})
surface = stubs({'SetDrawColor','DrawRect','DrawOutlinedRect','DrawLine','DrawPoly','SetFont','CreateFont'})
surface.GetTextSize = function(s) return #s * 8, 16 end
draw = stubs({'SimpleText','NoTexture','RoundedBox','SimpleTextOutlined'})
TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, TEXT_ALIGN_BOTTOM = 0, 1, 2, 3, 4
function Color(r, g, b, a) return {r = r, g = g, b = b, a = a} end
function Material(p) return {path = p} end
function CreateMaterial(n) return {name = n} end
function Mesh() return {BuildFromTriangles = function() end, Draw = rec('MeshDraw'), Destroy = function() end} end
function Matrix(t) local m = {t = t} setmetatable(m, {__mul = function(a, b) return a end}) return m end
function ClientsideModel(p) return {IsValid = function() return true end, SetNoDraw = function() end, SetModelScale = function() end,
	SetAngles = function() end, SetPos = function() end, SetupBones = function() end, DrawModel = rec('ItemDraw'),
	OBBCenter = function() return Vector() end, GetModelRadius = function() return 8 end, Remove = function() end} end
function LocalToWorld(v) return v end
function ParticleEmitter() return nil end
function DynamicLight() return nil end
function VectorRand() return Vector(0.1, 0.2, 0.3) end
function ScrW() return 1920 end function ScrH() return 1080 end
net = {Start = function() end, SendToServer = function() end, Receive = function() end}
''')
for f in ('sh_math', 'sh_config', 'sh_layout', 'sh_geometry', 'sh_rig', 'sh_station', 'cl_partmap', 'cl_ui', 'cl_parts'):
    L.execute(open(A + 'cf_rework/%s.lua' % f, encoding='utf-8').read())
r = srcmdl.load('/tmp/u/fab/combine_fabricator/models/cf_rework/station.mdl'); V = r['verts']
mk = L.eval('function(x,y,z) return Vector(x,y,z) end'); src = []
for m in r['meshes']:
    if not m['tris']: continue
    tl = [L.table_from({'pos': mk(*V[i][0]), 'normal': mk(*V[i][1]), 'u': V[i][2][0], 'v': V[i][2][1]}) for t in m['tris'] for i in t]
    src.append(L.table_from({'material': m['material'], 'triangles': L.table_from(tl)}))
L.globals().SRC = L.table_from(src)
L.execute("util.GetModelMeshes = function() return SRC end ErrorNoHalt = print")
L.execute('ENT = {} function include() end')
L.execute(open(A + 'entities/sent_combine_fabricator/shared.lua', encoding='utf-8').read())
L.execute(open(A + 'entities/sent_combine_fabricator/cl_init.lua', encoding='utf-8').read())
L.execute(r'''
-- pretend the mesh split is done
local P = CFRework.Parts
P.Prepare() for i = 1, 100000 do RunHook('Think') if P.Ready() then break end end print('ready', P.Ready())
local e = NewEntity('sent_combine_fabricator', ENT, Vector(0, 0, 0), 0)
e:SetupDataTables()
e.GetWorldTransformMatrix = function() return Matrix({}) end
e.WorldSpaceCenter = function(s) return s.pos end
e.EntIndex = function() return 1 end
e.SetRenderBounds = function() end
e.DrawModel = rec and function() end or function() end
e.LocalToWorldAngles = function(s, a) return a end
local me = NewPlayer(Vector(48, -8, 0))
me.aim = Vector(-1, 0, -0.3):GetNormalized()
function LocalPlayer() return me end
function EyePos() return me:EyePos() end
e:Initialize()
-- force P.Draw to run its body: emulate 'ready' state by building directly
local ok = pcall(function() end)
local S = CFRework.State
for _, st in ipairs({S.DORMANT, S.MENU, S.DEPOSIT, S.PRINT, S.DONE}) do
	e:SetStage(st) e:SetSelection(4) e:SetCost(10) e:SetPaid(13) e:SetOperator(me)
	e:SetStageStarted(0) e:SetStageUntil(5)
	for _, n in ipairs(CFRework.ChannelNames) do e['Set' .. n .. 'From'](e, 1) e['Set' .. n .. 'To'](e, 1) end
	T = 2
	e:Draw()
	e:Think()
	print('stage', st, 'ok')
end
RunHook('HUDPaint')
print('3D2D frames', CALLS.Start3D2D, 'text calls', CALLS.SimpleText, 'sprites', CALLS.DrawSprite, 'beams', CALLS.DrawBeam, 'item draws', CALLS.ItemDraw)
''')
