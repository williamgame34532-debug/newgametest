-- The printing of the fabricator (sh_fabricator.lua): a thing grows out of light.
--   the nanites     cold blue points stream in from around and gather at the point of the printing
--   the scan        two thin rings run up and down the column where the thing grows
--   the core        a glow that swells as the work goes on
--   the end         a white-blue flash and a short burst of sparks
-- data: origin - the point, entity - the fabricator, magnitude - how long (seconds).

local GLOW = Material("sprites/light_glow02_add")
local BEAM = Material("trails/laser")
local DOT = "sprites/light_glow02_add"
local COLOR = Color(120, 200, 255)

function EFFECT:Init(data)
	self.origin = data:GetOrigin()
	self.life = math.max(data:GetMagnitude(), 0.5)
	self.born = CurTime()
	self.emitter = ParticleEmitter(self.origin)
	self.nextDot = 0
	self.burst = false

	self:SetRenderBoundsWS(self.origin - Vector(48, 48, 48), self.origin + Vector(48, 48, 48))
end

function EFFECT:Think()
	local age = CurTime() - self.born
	local t = age / self.life

	if (t >= 1.25) then
		if (self.emitter) then
			self.emitter:Finish()
		end

		return false
	end

	if (!self.emitter) then
		return true
	end

	-- the nanites: in from a sphere around, faster near the end
	if (t < 1 and CurTime() > self.nextDot) then
		self.nextDot = CurTime() + 0.012

		for _ = 1, 2 do
			local dir = VectorRand():GetNormalized()
			local from = self.origin + dir * math.Rand(18, 30)
			local dot = self.emitter:Add(DOT, from)

			if (dot) then
				local time = math.Rand(0.35, 0.6)

				dot:SetVelocity((self.origin - from) / time)
				dot:SetDieTime(time)
				dot:SetStartAlpha(0)
				dot:SetEndAlpha(255)
				dot:SetStartSize(math.Rand(0.6, 1.2))
				dot:SetEndSize(0.2)
				dot:SetColor(COLOR.r, COLOR.g, COLOR.b)
			end
		end
	end

	-- the end: a burst of sparks
	if (t >= 1 and !self.burst) then
		self.burst = true

		for _ = 1, 24 do
			local spark = self.emitter:Add("effects/spark", self.origin)

			if (spark) then
				spark:SetVelocity(VectorRand() * math.Rand(40, 110) + Vector(0, 0, 30))
				spark:SetDieTime(math.Rand(0.3, 0.6))
				spark:SetStartAlpha(255)
				spark:SetEndAlpha(0)
				spark:SetStartSize(1.2)
				spark:SetEndSize(0)
				spark:SetStartLength(6)
				spark:SetEndLength(1)
				spark:SetGravity(Vector(0, 0, -300))
				spark:SetColor(170, 220, 255)
			end
		end
	end

	return true
end

-- a horizontal ring of beams at the height h around the point
local function Ring(center, radius, alpha)
	local last

	for step = 0, 16 do
		local angle = step / 16 * math.pi * 2
		local point = center + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)

		if (last) then
			render.DrawBeam(last, point, 0.6, 0, 1, ColorAlpha(COLOR, alpha))
		end

		last = point
	end
end

function EFFECT:Render()
	local age = CurTime() - self.born
	local t = math.Clamp(age / self.life, 0, 1)
	local after = math.Clamp((age - self.life) / (self.life * 0.25), 0, 1)
	local fade = 1 - after

	-- the scan: two rings, up and down the column
	if (t < 1) then
		render.SetMaterial(BEAM)

		local wave = math.abs(math.sin(age * 3.2))

		Ring(self.origin + Vector(0, 0, -10 + wave * 20), 7 + 2 * t, 160 * fade)
		Ring(self.origin + Vector(0, 0, 10 - wave * 20), 6 + 2 * t, 110 * fade)
	end

	-- the core: grows with the work, flashes at the end
	local flash = age > self.life and (1 - after) or 0
	local size = 4 + 14 * t + flash * 40

	render.SetMaterial(GLOW)
	render.DrawSprite(self.origin, size, size, ColorAlpha(COLOR, (90 + 120 * t) * fade + flash * 120))
	render.DrawSprite(self.origin, size * 0.35, size * 0.35, Color(230, 245, 255, 220 * fade))
end
