-- Story NPC on GMod doubles: idle choice, lines per E press and per player, busy while speaking (run by check.py)
local now = 0
CurTime = function() return now end
FrameTime = function() return 0.05 end
math.Clamp = function(v, a, b) return math.max(a, math.min(b, v)) end
AddCSLuaFile = function() end
include = function() end
net = {Receive = function() end}
util = {AddNetworkString = function() end, IsValidModel = function() return true end}
string.Trim = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
math.AngleDifference = function(a, b) return ((a - b + 180) % 360) - 180 end
istable = function(v) return type(v) == 'table' end
table.KeyFromValue = function(t, v) for k, x in pairs(t) do if x == v then return k end end end
IsValid = function(e) return e ~= nil end
Vector = function(x, y, z) return {x = x, y = y, z = z} end
Angle = function(p, y, r) return {p = p, y = y, r = r} end
player = {GetAll = function() return {} end}
timer = {Simple = function() end}
SOLID_BBOX, MOVETYPE_NONE, SIMPLE_USE = 2, 0, 3
local said = {}
HLA = {Chat = {Say = function(e, k, t, o) said[#said + 1] = {t, o.name} return 2 end}, Voice = {Lines = {}},
	Story = {NPCModels = {{model = 'models/x.mdl'}}}}
ENT = {}
dofile(ARG .. '/shared.lua')
dofile(ARG .. '/init.lua')
local seqs = {[0] = {'idle_unarmed', 'ACT_IDLE'}, {'idle_smg1', 'ACT_IDLE_SMG1'}, {'idle_angry_smg1', 'ACT_IDLE_ANGRY_SMG1'}, {'walk_all', 'ACT_WALK'}, {'idletoangry', 'ACT_TRANSITION'}}
local e = setmetatable({nw = {}, ang = {p = 0, y = 90, r = 0}}, {__index = ENT})
function e:SetModel(m) self.model = m end
function e:SetNWString(k, v) self.nw[k] = v end
function e:GetNWString(k, d) return self.nw[k] or d end
function e:SetWeapon(w) self.wep = w end
function e:SetSolid() end function e:SetCollisionBounds() end function e:SetMoveType() end function e:SetUseType() end
function e:GetAngles() return self.ang end
function e:SetAngles(a) self.ang = a end
function e:GetSequenceCount() return 5 end
function e:GetSequenceName(i) return seqs[i][1] end
function e:GetSequenceActivityName(i) return seqs[i][2] end
function e:LookupSequence(n) for i = 0, 4 do if seqs[i][1] == n then return i end end return -1 end
function e:ResetSequence(s) self.seq = s end
function e:GetSequence() return self.seq end
function e:SetCycle() end function e:SetPlaybackRate() end
function e:SequenceDuration() return 3 end
function e:GetSequenceInfo() return {} end
function e:GetPos() return {x = 0, y = 0, z = 0} end
function e:EmitSound() end
function e:NextThink() end
e:ApplyConfig({name = 'ЮНИТ 101', model = 'models/x.mdl', weapon = 'tfa_osips', lines = {'Первая.', 'Вторая.', 'Третья.'}, chatter = false})
e:Initialize()
local armed = {}
for _, s in ipairs(e.Idles) do armed[#armed + 1] = seqs[s][1] end
assert(#e.Idles == 2 and table.concat(armed, ',') == 'idle_smg1,idle_angry_smg1', 'armed idles: ' .. table.concat(armed, ','))
print('PASS NPC idles: the armed idle sequences, no walk / transitions')
local p1 = {IsPlayer = function() return true end, SteamID64 = function() return '1' end, GetPos = function() return {x = 10, y = 0, z = 0} end}
local p2 = {IsPlayer = function() return true end, SteamID64 = function() return '2' end, GetPos = function() return {x = 10, y = 0, z = 0} end}
-- the vector difference / Angle used by Use
local mt = {__sub = function(a, b) return setmetatable({x = a.x - b.x, y = a.y - b.y}, {__index = {Angle = function() return {y = 0} end}}) end}
setmetatable(p1:GetPos(), mt)
p1.GetPos = function() return setmetatable({x = 10, y = 0, z = 0}, mt) end
p2.GetPos = p1.GetPos
e.GetPos = function() return setmetatable({x = 0, y = 0, z = 0}, mt) end
for i = 1, 4 do now = now + 20 e:Use(p1) end
now = now + 20 e:Use(p2)
local got = {}
for _, s in ipairs(said) do got[#got + 1] = s[1] end
assert(table.concat(got, '|') == 'Первая.|Вторая.|Третья.|Третья.|Первая.', table.concat(got, '|'))
assert(said[1][2] == 'ЮНИТ 101')
print('PASS NPC lines: 1st, 2nd, 3rd, then the last repeats; counted per player; spoken with its name')
local n0 = #said
now = now + 0.5 e:Use(p2)
assert(#said == n0, 'busy while it speaks')
now = now + 3 e:Use(p2)
assert(#said == n0 + 1 and said[#said][1] == 'Вторая.', 'next line after it finished')
print('PASS NPC is busy while it speaks')
