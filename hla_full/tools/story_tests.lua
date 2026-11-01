-- Story / rounds on GMod doubles: vote, chapters, triggers, spectators, PvP, late join, kill callouts (run by check.py)
-- minimal GMod doubles for sv_story.lua
local now = 0
CurTime = function() return now end
SERVER, CLIENT = true, false
local hooks = {}
hook = {Add = function(ev, id, fn) hooks[ev] = hooks[ev] or {} hooks[ev][id] = fn end,
	Run = function(ev, ...) for _, fn in pairs(hooks[ev] or {}) do local r = fn(...) if r ~= nil then return r end end end}
local timers, simple = {}, {}
CreateConVar = CreateConVar or function(_, v) return {GetBool = function() return v == "1" end, GetInt = function() return tonumber(v) or 0 end} end
GetConVar = GetConVar or function() return {GetBool = function() return true end} end
engine = engine or {LightStyle = function() end}
timer = {Create = function(id, d, r, fn) timers[id] = {d = d, fn = fn, next = now + d, rep = r} end, Remove = function(id) timers[id] = nil end,
	Simple = function(d, fn) simple[#simple + 1] = {at = now + d, fn = fn} end}
local function advance(sec)
	local stop = now + sec
	while now < stop do
		now = now + 0.1
		for id, t in pairs(timers) do if now >= t.next then t.next = now + t.d t.fn() if t.rep == 1 then timers[id] = nil end end end
		local due = {}
		for i = #simple, 1, -1 do if now >= simple[i].at then due[#due + 1] = table.remove(simple, i) end end
		for i = #due, 1, -1 do due[i].fn() end
	end
end
local G = {}
for _, k in ipairs({'String', 'Int', 'Float'}) do
	_G['SetGlobal2' .. k] = function(n, v) G[n] = v end
	_G['GetGlobal2' .. k] = function(n, d) if G[n] == nil then return d end return G[n] end
end
net = setmetatable({}, {__index = function() return function() return 0 end end})
util = {AddNetworkString = function() end, JSONToTable = function() return nil end, TableToJSON = function() return '{}' end}
file = {CreateDir = function() end, Read = function() return nil end, Write = function() end}
game = {GetMap = function() return 'testmap' end}
RunConsoleCommand = function() end
concommand = {Add = function() end}
ents = {FindByClass = function() return {} end, Create = function() return nil end}
math.Rand = function(a, b) return a end
math.Clamp = function(v, a, b) return math.max(a, math.min(b, v)) end
istable = function(v) return type(v) == 'table' end
Color = function(r, g, b, a) return {r = r, g = g, b = b, a = a} end
team = {SetUp = function() end}
TEAM_UNASSIGNED = 1001
OBS_MODE_CHASE, OBS_MODE_IN_EYE, OBS_MODE_ROAMING = 5, 4, 6
IN_ATTACK, IN_ATTACK2, IN_JUMP = 1, 2048, 2
local function V3(x, y, z) return setmetatable({x = x or 0, y = y or 0, z = z or 0}, {
	__add = function(a, b) return V3(a.x + b.x, a.y + b.y, a.z + b.z) end,
	__unm = function(a) return V3(-a.x, -a.y, -a.z) end,
	__index = {DistToSqr = function(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2 end}}) end
Vector = V3
Angle = function() return {} end
local players = {}
player = {GetAll = function() return players end}
IsValid = function(e) return e ~= nil and (type(e) ~= 'table' or not e.removed) end
local said = {}
local function newPlayer(name)
	local p = {name = name, alive = false, team = TEAM_UNASSIGNED, pos = V3(0, 0, 0), frags = 0, obs = 0, nw = {}}
	function p:Alive() return self.alive end
	function p:Spawn() self.alive = true self.spawns = (self.spawns or 0) + 1 hook.Run('PlayerSpawn', self) end
	function p:KillSilent() self.alive = false end
	function p:Kill() self.alive = false hook.Run('PlayerDeath', self, nil, self) end
	function p:UnSpectate() self.obs = 0 end
	function p:Spectate(m) self.obs = m end
	function p:SpectateEntity(e) self.obsTarget = e end
	function p:GetObserverTarget() return self.obsTarget end
	function p:GetObserverMode() return self.obs end
	function p:Team() return self.team end
	function p:SetTeam(t) self.team = t end
	function p:SetFrags(n) self.frags = n end
	function p:SetDeaths() end
	function p:Frags() return self.frags end
	function p:GetPos() return self.pos end
	function p:SetPos(v) self.pos = v end
	function p:SetEyeAngles() end
	function p:SetVelocity() end
	function p:GetVelocity() return V3() end
	function p:EmitSound() end
	function p:ChatPrint() end
	function p:IsAdmin() return true end
	function p:IsPlayer() return true end
	function p:Nick() return self.name end
	function p:GetNWString(k, d) return self.nw[k] or d end
	function p:SetNW2Int(k, v) self.nw[k] = v end
	return p
end
HLA = {Chat = {Say = function(p, k, t) said[#said + 1] = t end, Dispatch = function() end}}
dofile(ARG_DIR .. '/sh_dispatch.lua')
dofile(ARG_DIR .. '/sh_radiovoice.lua')
dofile(ARG_DIR .. '/sh_story.lua')
dofile(ARG_DIR .. '/sv_story.lua')
local S = HLA.Story
hook.Run('InitPostEntity')
-- two chapters with spawns, chapter 1 has a trigger far away
S.Config.chapters = {
	{title = 'ГЛАВА 1', name = 'А', sub = '', spawns = {{p = {0, 0, 0}, y = 0}, {p = {100, 0, 0}, y = 0}}, dispatch = '', trigger = {a = {1000, 1000, 0}, b = {1100, 1100, 100}}},
	{title = 'ГЛАВА 2', name = 'Б', sub = '', spawns = {{p = {5000, 0, 0}, y = 0}}, dispatch = '', trigger = {a = {6000, 0, 0}, b = {6100, 100, 100}}},
}
local a, b = newPlayer('A'), newPlayer('B')
players = {a, b}
for _, p in ipairs(players) do p.HLACharID = 1 p:Spawn() hook.Run('HLAPlayerEnteredGame', p) end
advance(6)
assert(S.State() == S.VOTE, 'vote after enough players: ' .. S.State())
print('PASS 2 players: vote starts')
-- votes: both for teams PvP? first test story: A story, B ffa -> tie -> story (first)
net.ReadUInt = function() return 1 end
S.Votes = {[a] = 1, [b] = 3}
for i = 1, 3 do SetGlobal2Int('hla_vote_' .. i, 0) end
SetGlobal2Int('hla_vote_1', 1) SetGlobal2Int('hla_vote_3', 1)
advance(21)
assert(S.State() == S.STORY and S.Chapter == 1, 'story chapter 1')
advance(0.2)
assert(a.alive and b.alive and (a.pos.x < 200 and b.pos.x < 200), 'spawned at chapter 1')
print('PASS vote tie -> story, chapter 1 spawns')
-- B dies: out, spectates A, cannot respawn
b:Kill()
advance(3)
assert(b.HLAOut and not b.alive and b.obs == OBS_MODE_CHASE and b.obsTarget == a, 'B spectates A')
assert(hook.Run('PlayerDeathThink', b) == false, 'no respawn in a round')
print('PASS death -> spectator of the living, no respawn')
-- A enters the trigger: chapter 2, both alive again at chapter 2
a.pos = V3(1050, 1050, 10)
advance(1)
advance(0.2)
assert(S.Chapter == 2 and a.alive and b.alive and not b.HLAOut and b.pos.x >= 5000, 'chapter 2, all respawned')
print('PASS trigger -> chapter 2, the dead respawn, everyone at the new spawns')
-- all dead -> chapter restarts
a:Kill() b:Kill()
advance(8)
assert(S.Chapter == 2 and a.alive and b.alive, 'chapter restarted after all dead')
print('PASS all dead -> the chapter starts again')
-- last trigger -> end -> wait -> new vote
a.pos = V3(6050, 50, 10)
advance(1)
assert(S.State() == S.END, 'story ends')
advance(11)
assert(S.State() == S.WAIT, 'back to wait')
advance(6)
assert(S.State() == S.VOTE, 'new vote')
print('PASS last chapter trigger -> end -> wait -> new vote')
-- PvP teams: one team dies -> win
SetGlobal2Int('hla_vote_1', 0) SetGlobal2Int('hla_vote_2', 2) SetGlobal2Int('hla_vote_3', 0)
advance(21)
assert(S.State() == S.PVP and S.Mode() == 'teams' and a:Team() ~= b:Team(), 'teams pvp')
assert(hook.Run('PlayerShouldTakeDamage', a, b) == true, 'enemies hurt each other')
local loser = a:Team() == S.TEAM2 and a or b
loser:Kill()
advance(1)
assert(S.State() == S.END, 'pvp ended when a team is out')
print('PASS PvP teams: different teams, damage between them, round ends when a team is out')
-- late joiner during a round watches
advance(11) advance(6)
SetGlobal2Int('hla_vote_2', 0) SetGlobal2Int('hla_vote_1', 2)
advance(21)
local c = newPlayer('C')
players[3] = c
c.HLACharID = 3
c:Spawn() hook.Run('HLAPlayerEnteredGame', c)
advance(3)
assert(c.HLAOut and not c.alive, 'late joiner spectates')
print('PASS a player entering during a round watches until the next chapter')
-- kill callout
said = {}
hook.Run('OnNPCKilled', {}, a)
advance(1)
assert(#said == 1, 'callout said')
print('PASS kill callout')
