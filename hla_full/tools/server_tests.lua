-- Runs the production server entity (init.lua) against minimal engine doubles and the real
-- sequence lengths of hla_station.mdl, and walks the whole station cycle.
local C = CFRework
local S = C.State
local SEQ = assert(loadfile('tools/sequences.lua'))()
local NAMES = {}
for name in pairs(SEQ) do NAMES[#NAMES + 1] = name end
table.sort(NAMES)
local INDEX = {}
for i, n in ipairs(NAMES) do INDEX[n] = i end

local now = 100
CurTime = function() return now end
function AddCSLuaFile() end
function include() end
function IsValid(x) return type(x) == 'table' and not x.invalid end
NULL = false
SOLID_VPHYSICS, MOVETYPE_VPHYSICS, SIMPLE_USE, IN_USE = 6, 6, 3, 32
isfunction = function(f) return type(f) == 'function' end
table.Copy = function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
string.format = string.format
local players = {}
player = {GetAll = function() return players end}
C.SetFocus = function(p, e) p.CFFocus = e end
local refunds = 0
C.Refund = function(_, n) refunds = refunds + n end
local balance = 100
C.Balance = function() return balance end
C.ChangeBalance = function(_, d) if balance + d < 0 then return false end balance = balance + d return true end
C.AimedPart = function() return nil end
util = {IsValidModel = function() return true end}

ENT = {}
assert(loadfile('garrysmod/gamemodes/hlalyx/entities/entities/hla_fabricator/init.lua'))()

local function vec(d) return {DistToSqr = function() return d end} end
local function station()
	local e = setmetatable({}, {__index = ENT})
	for _, name in ipairs({'Stage', 'Tab', 'Selection', 'Paid', 'Cost', 'Operator', 'StatusText', 'StageStarted', 'StageUntil',
		'DeployedAt', 'FeedStarted', 'Deployed', 'TrayReady', 'BayOpen', 'TrayOut'}) do
		e['Get' .. name] = function(s) local v = s['_' .. name] if v == nil then return 0 end return v end
		e['Set' .. name] = function(s, v) s['_' .. name] = v end
	end
	e.GetDeployed = function(s) return s._Deployed == true end
	e.GetTrayReady = function(s) return s._TrayReady == true end
	e.GetBayOpen = function(s) return s._BayOpen == true end
	function e:SetModel() end function e:PhysicsInit() end function e:SetMoveType() end function e:SetSolid() end
	function e:SetUseType() end function e:GetPhysicsObject() return nil end
	function e:EmitSound() end function e:StopSound() end
	function e:LookupSequence(n) return INDEX[n] or -1 end
	function e:ResetSequence(i) self.seq = NAMES[i] self.played = self.played or {} table.insert(self.played, self.seq) end
	function e:SetCycle() end function e:SetPlaybackRate() end
	function e:SequenceDuration(i) local s = SEQ[NAMES[i]] return math.max(0, (s[1] - 1) / s[2]) end
	function e:GetPos() return self.pos end
	function e:NextThink() end
	e.pos = vec(0)
	e:Initialize()
	return e
end

-- run the server think for a while (20 Hz like the entity)
local function run(e, seconds)
	local stop = now + seconds
	while now < stop do now = now + 0.05 e:Think() end
end
local function after(e, list) -- the sequences played since a mark
	local out = {}
	for i = list + 1, #e.played do out[#out + 1] = e.played[i] end
	return table.concat(out, ' ')
end

local p = {SteamID64 = function() return '1' end, HasWeapon = function() return false end, Alive = function() return true end,
	Health = function() return 50 end, GetMaxHealth = function() return 100 end, SetHealth = function(s, n) s.health = n end,
	GetPos = function() return vec(0) end, KeyDown = function() return false end, EmitSound = function() end}
players = {p}

-- wake: eye, then the screen; the terminal is usable only once the screen stands
local e = station()
assert(e.seq == 'dormant' and e:GetStage() == S.DORMANT)
now = now + 0.05 e:Think()
assert(e.seq == 'eye_deploy' and not e:GetDeployed())
run(e, 3) assert(e.seq == 'interface_deploy' and not C.Ready(e))
run(e, 3.6) assert(e.seq == 'menu_idle' and C.Ready(e) and e:GetStage() == S.MENU)
assert(not C.CellsOpen(e), 'no resin tray in the menu')
print('PASS wake: dormant > eye_deploy > interface_deploy > menu_idle')

-- order: hatch, then the tray comes out; resin only once it is presented
local mark = #e.played
e:Order(p, 1) -- 2 resin
assert(e:GetStage() == S.DEPOSIT and e.seq == 'hatch_open' and not C.CellsOpen(e))
e:InsertResin(p) assert(e:GetPaid() == 0, 'cannot load before the tray is out')
run(e, 4) assert(e.seq == 'tray_idle_00' and C.CellsOpen(e) and e:GetTrayOut())
assert(after(e, mark) == 'hatch_open tray_deploy tray_idle_00', after(e, mark))
print('PASS order: hatch_open > tray_deploy > tray_idle_00, tray closed until then')

-- resin: one carousel step each, then retract, open the bay, print, open, deliver
mark = #e.played
e:InsertResin(p) assert(e:GetPaid() == 1 and e.seq == 'tray_cycle_01')
e:InsertResin(p) assert(e:GetPaid() == 1, 'no second resin while the carousel turns')
run(e, 0.5) assert(e.seq == 'tray_idle_01')
e:InsertResin(p) assert(e:GetPaid() == 2 and e.seq == 'tray_cycle_02')
run(e, 0.5) assert(e:GetStage() == S.PRINT and e.seq == 'tray_retract' and not C.CellsOpen(e), e.seq)
run(e, 2.5) assert(e.seq == 'bay_open')
run(e, 3.1) assert(e.seq == 'print' and math.abs(e:GetStageUntil() - e:GetStageStarted() - 7.5) < 0.01)
run(e, 7.6) assert(e.seq == 'bay_open' and e:GetStage() == S.PRINT and not e:GetBayOpen())
run(e, 3.1) assert(e.seq == 'bay_idle' and e:GetStage() == S.DONE and e:GetBayOpen())
assert(after(e, mark) == 'tray_cycle_01 tray_idle_01 tray_cycle_02 tray_retract bay_open print bay_open bay_idle', after(e, mark))
print('PASS print: carousel steps > tray_retract > bay_open > print > bay_open > bay_idle')

-- collect: the bay and the hatch close in the reverse order they opened
mark = #e.played
e:Collect(p) assert(p.health == 60 and e:GetStage() == S.MENU)
run(e, 5) assert(after(e, mark) == 'bay_close hatch_close menu_idle', after(e, mark))
print('PASS collect: bay_close > hatch_close > menu_idle')

-- cancel while loading: tray in, hatch shut, resin back
balance, refunds = 100, 0
e:Order(p, 9) run(e, 4) -- 3 resin
e:InsertResin(p) run(e, 0.5)
mark = #e.played
e:EndSession(true) assert(refunds == 1)
run(e, 4) assert(after(e, mark) == 'tray_retract hatch_close menu_idle', after(e, mark))
print('PASS cancel: tray_retract > hatch_close > menu_idle, resin refunded')

-- a full magazine of ten wraps the carousel back to its first trough
balance, refunds = 100, 0
e:Order(p, 4) run(e, 4) -- pistol, 10 resin
for i = 1, 9 do e:InsertResin(p) run(e, 0.5) end
assert(e.seq == 'tray_idle_09')
mark = #e.played
e:InsertResin(p) assert(e.played[mark + 1] == 'tray_cycle_00')
print('PASS ten resin: tray_cycle_00 turns 09 back to 00')
e:EndSession(true) run(e, 6)

-- walking away mid-order: everything closes, the station folds, resin comes back
balance, refunds = 100, 0
e:Order(p, 9) run(e, 4)
e:InsertResin(p) run(e, 0.5)
mark = #e.played
p.GetPos = function() return vec(1e9) end
run(e, 12)
assert(after(e, mark) == 'tray_retract hatch_close interface_retract eye_retract dormant', after(e, mark))
assert(e:GetStage() == S.DORMANT and not e:GetDeployed() and refunds == 1)
print('PASS walk away: tray_retract > hatch_close > interface_retract > eye_retract > dormant, refunded')

-- walking away during the print cuts it, closes the hatch and folds
p.GetPos = function() return vec(0) end
run(e, 7) assert(e.seq == 'menu_idle')
balance, refunds = 100, 0
e:Order(p, 1) run(e, 4)
e:InsertResin(p) run(e, 0.5) e:InsertResin(p) run(e, 6)
assert(e.seq == 'print')
mark = #e.played
p.GetPos = function() return vec(1e9) end
run(e, 10)
assert(after(e, mark) == 'hatch_close interface_retract eye_retract dormant', after(e, mark))
assert(refunds == 2)
print('PASS walk away while printing: print cut > hatch_close > interface_retract > eye_retract > dormant')
