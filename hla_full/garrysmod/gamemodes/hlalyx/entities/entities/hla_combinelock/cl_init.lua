include('shared.lua')

local core = Material('sprites/light_glow02_add')
local halo = Material('sprites/light_glow02_add')
local GREEN = Color(60, 255, 120)
local BLUE = Color(60, 150, 255)
local RED = Color(255, 60, 50)
local drawCol = Color(255, 255, 255)

function ENT:Draw()
	self:DrawModel()
end

local function state(self)
	if self:GetDisplayError() then return 'error', RED end
	if self:GetLocked() then return 'locked', BLUE end
	return 'open', GREEN
end

local cvX = CreateClientConVar('hla_lock_lamp_x', '0', true, false, 'Combine lock lamp: shift in depth')
local cvY = CreateClientConVar('hla_lock_lamp_y', '0', true, false, 'Combine lock lamp: shift sideways')
local cvZ = CreateClientConVar('hla_lock_lamp_z', '0', true, false, 'Combine lock lamp: shift up/down')

function ENT:LampPos()
	return self:GetPos() + self:GetForward() * (-1.9 + cvY:GetFloat()) + self:GetRight() * (-6 + cvX:GetFloat()) + self:GetUp() * (-7.7 + cvZ:GetFloat())
end

function ENT:Think()
	local st, col = state(self)
	if st ~= self.lastState then
		if self.lastState then self.burst = RealTime() end
		self.lastState = st
	end
	if EyePos():DistToSqr(self:GetPos()) < 700 * 700 then
		local d = DynamicLight(self:EntIndex())
		if d then
			d.pos = self:LampPos() + self:GetRight() * -4
			d.r, d.g, d.b = col.r, col.g, col.b
			d.brightness = st == 'error' and 1 or 0.35
			d.size = 48
			d.decay = 400
			d.dietime = CurTime() + 0.2
		end
	end
	self:SetNextClientThink(CurTime() + 0.05)
	return true
end

function ENT:DrawTranslucent()
	local st, col = state(self)
	local t = RealTime()
	local k
	if st == 'error' then
		k = math.floor(t * 12) % 2 == 0 and 1 or 0.25
	elseif st == 'locked' then
		k = 0.7 + 0.3 * math.sin(t * 2.4 + self:EntIndex())
	else
		k = 0.85 + 0.15 * math.sin(t * 0.9 + self:EntIndex())
	end
	local burst = self.burst and math.Clamp(1 - (t - self.burst) / 0.45, 0, 1) or 0
	local pos = self:LampPos()
	render.SetMaterial(halo)
	drawCol.r, drawCol.g, drawCol.b, drawCol.a = col.r, col.g, col.b, (110 + 120 * burst) * k
	local hs = 12 + 22 * burst
	render.DrawSprite(pos, hs, hs, drawCol)
	render.SetMaterial(core)
	drawCol.r = math.min(255, col.r + 120)
	drawCol.g = math.min(255, col.g + 120)
	drawCol.b = math.min(255, col.b + 120)
	drawCol.a = 255 * k
	render.DrawSprite(pos, 4 + 2 * k, 4 + 2 * k, drawCol)
end
