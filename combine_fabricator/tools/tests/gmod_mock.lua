-- Minimal Garry's Mod API mock: enough to run the fabricator's server logic and client mesh split.
T = 0
function CurTime() return T end
function SysTime() return os.clock() end
function FrameTime() return 0.016 end
SERVER, CLIENT = true, false

local VM = {}
VM.__index = VM
function Vector(x, y, z) return setmetatable({x = x or 0, y = y or 0, z = z or 0}, VM) end
VM.__add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
VM.__sub = function(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end
VM.__mul = function(a, b)
	if type(a) == 'number' then a, b = b, a end
	return Vector(a.x * b, a.y * b, a.z * b)
end
VM.__div = function(a, b) return Vector(a.x / b, a.y / b, a.z / b) end
VM.__unm = function(a) return Vector(-a.x, -a.y, -a.z) end
VM.__tostring = function(a) return string.format('(%.2f %.2f %.2f)', a.x, a.y, a.z) end
function VM:Dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
function VM:Cross(b) return Vector(self.y * b.z - self.z * b.y, self.z * b.x - self.x * b.z, self.x * b.y - self.y * b.x) end
function VM:LengthSqr() return self:Dot(self) end
function VM:Length() return math.sqrt(self:Dot(self)) end
function VM:DistToSqr(b) return (self - b):LengthSqr() end
function VM:GetNormalized() local l = self:Length() return l > 0 and self / l or Vector() end
function VM:AngleEx(up) return {fwd = self, up = up} end
function VM:Angle() return {p = math.deg(math.atan2(-self.z, math.sqrt(self.x ^ 2 + self.y ^ 2))), y = math.deg(math.atan2(self.y, self.x)), r = 0} end
vector_origin = Vector() vector_up = Vector(0, 0, 1)
function Angle(p, y, r) return {p = p or 0, y = y or 0, r = r or 0} end
angle_zero = Angle()

function math.Clamp(x, a, b) return math.min(math.max(x, a), b) end
function Lerp(t, a, b) return a + (b - a) * t end
function LerpVector(t, a, b) return a + (b - a) * t end
function math.NormalizeAngle(a) return (a + 180) % 360 - 180 end
function istable(x) return type(x) == 'table' end
function isstring(x) return type(x) == 'string' end

util = {}
function util.IntersectRayWithPlane(o, d, p, n)
	local den = d:Dot(n)
	if math.abs(den) < 1e-9 then return end
	local t = (p - o):Dot(n) / den
	if t < 0 then return end
	return o + d * t
end
function util.AddNetworkString() end

NULL = {IsValid = function() return false end}
function IsValid(x) return x ~= nil and x ~= NULL and (type(x) ~= 'table' or x.IsValid == nil or x:IsValid()) end

HOOKS = {}
hook = {Add = function(ev, id, fn) HOOKS[ev] = HOOKS[ev] or {} HOOKS[ev][id] = fn end, Run = function() end}
function RunHook(ev, ...) for _, fn in pairs(HOOKS[ev] or {}) do fn(...) end end
TIMERS = {}
timer = {Simple = function(d, fn) TIMERS[#TIMERS + 1] = {T + d, fn} end}
function RunTimers()
	for i = #TIMERS, 1, -1 do local t = TIMERS[i] if T >= t[1] then table.remove(TIMERS, i) t[2]() end end
end
net = {Receive = function() end}
concommand = {Add = function() end}
FILES = {}
file = {CreateDir = function() end, Read = function(p) return FILES[p] end, Write = function(p, s) FILES[p] = s end}
IN_USE = 32
SOUNDS = {}

-- entities
local EM = {}
EM.__index = EM
function EM:IsValid() return not self.removed end
function EM:GetPos() return self.pos end
function EM:GetClass() return self.class end
local function yawrot(v, y)
	local c, s = math.cos(math.rad(y)), math.sin(math.rad(y))
	return Vector(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
end
function EM:LocalToWorld(v) return self.pos + yawrot(v, self.yaw) end
function EM:WorldToLocal(v) return yawrot(v - self.pos, -self.yaw) end
function EM:LocalToWorldAngles(a) return {p = a.p, y = a.y + self.yaw, r = a.r} end
function EM:GetUp() return Vector(0, 0, 1) end
function EM:GetForward() return yawrot(Vector(1, 0, 0), self.yaw) end
function EM:EmitSound(s) SOUNDS[#SOUNDS + 1] = string.format('%.2f %s', T, s) end
function EM:StopSound(s) SOUNDS[#SOUNDS + 1] = string.format('%.2f STOP %s', T, s) end
function EM:NetworkVar(kind, i, name)
	local def = (kind == 'String' and '') or (kind == 'Entity' and NULL) or 0
	self['Get' .. name] = function(e) local v = e.nv[name] if v == nil then return def end return v end
	self['Set' .. name] = function(e, v) e.nv[name] = v end
end
function EM:NextThink() end
function EM:SetModel() end function EM:PhysicsInit() end function EM:SetMoveType() end function EM:SetSolid() end
function EM:SetUseType() end function EM:GetPhysicsObject() return NULL end

ENTS = {}
function NewEntity(class, ENT, pos, yaw)
	local e = setmetatable({class = class, pos = pos, yaw = yaw or 0, nv = {}}, {__index = function(t, k) return ENT[k] or EM[k] end})
	ENTS[#ENTS + 1] = e
	return e
end

-- players
local PM = {}
PM.__index = PM
function PM:IsValid() return true end
function PM:Alive() return true end
function PM:GetPos() return self.pos end
function PM:EyePos() return self.pos + Vector(0, 0, 64) end
function PM:GetAimVector() return self.aim end
function PM:KeyDown(k) return self.keys[k] end
function PM:SteamID64() return '76561190000000001' end
function PM:GetNWInt(k, d) return self.nw[k] or d end
function PM:SetNWInt(k, v) self.nw[k] = v end
function PM:HasWeapon(c) return self.weapons[c] end
function PM:Give(c) self.weapons[c] = true return {IsValid = function() return true end} end
function PM:Health() return self.hp end function PM:GetMaxHealth() return 100 end function PM:SetHealth(h) self.hp = h end
function PM:Armor() return self.ap end function PM:SetArmor(a) self.ap = a end
function PM:GiveAmmo(n) return n end
function PM:EmitSound() end
function PM:Nick() return 'Tester' end
function PM:IsAdmin() return true end
PLAYERS = {}
function NewPlayer(pos)
	local p = setmetatable({pos = pos, aim = Vector(-1, 0, 0), keys = {}, nw = {}, weapons = {}, hp = 50, ap = 0}, PM)
	PLAYERS[#PLAYERS + 1] = p
	return p
end
player = {GetAll = function() return PLAYERS end}
ents = {
	FindInSphere = function(p, r) local o = {} for _, e in ipairs(ENTS) do if e.pos:DistToSqr(p) <= r * r then o[#o + 1] = e end end return o end,
	FindByClass = function(c) local o = {} for _, e in ipairs(ENTS) do if e.class == c then o[#o + 1] = e end end return o end,
}
function AddCSLuaFile() end
