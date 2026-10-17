-- The hit of the stunstick (nw_stunstick.lua) switched on: a white-blue flash, a few jagged arcs that
-- jump out from the point and flicker for a moment, hot sparks that fall and bounce, a little smoke
-- and a short blue light around.

local GLOW = Material("sprites/light_glow02_add")
local ARC = Material("trails/electric")

function EFFECT:Init(data)
	self.pos = data:GetOrigin()
	self.normal = data:GetNormal()
	self.born = CurTime()
	self.life = 0.22

	if (self.normal:LengthSqr() < 0.1) then
		self.normal = VectorRand():GetNormalized()
	end

	-- the arcs: jagged lines from the point, rebuilt every frame while they live
	self.arcs = {}

	for i = 1, math.random(4, 6) do
		local direction = (self.normal + VectorRand() * 0.9):GetNormalized()

		self.arcs[i] = {direction = direction, length = math.Rand(10, 26)}
	end

	local emitter = ParticleEmitter(self.pos)

	if (emitter) then
		-- the flash
		local flash = emitter:Add("effects/blueflare1", self.pos)

		if (flash) then
			flash:SetDieTime(0.12)
			flash:SetStartAlpha(255)
			flash:SetEndAlpha(0)
			flash:SetStartSize(math.Rand(28, 38))
			flash:SetEndSize(4)
			flash:SetColor(200, 230, 255)
		end

		-- the sparks
		for _ = 1, math.random(14, 22) do
			local spark = emitter:Add("effects/spark", self.pos)

			if (spark) then
				spark:SetVelocity((self.normal * math.Rand(60, 180)) + VectorRand() * 140)
				spark:SetDieTime(math.Rand(0.25, 0.7))
				spark:SetStartAlpha(255)
				spark:SetEndAlpha(0)
				spark:SetStartSize(math.Rand(0.8, 1.6))
				spark:SetEndSize(0)
				spark:SetStartLength(math.Rand(4, 9))
				spark:SetEndLength(0)
				spark:SetGravity(Vector(0, 0, -500))
				spark:SetCollide(true)
				spark:SetBounce(0.35)
				spark:SetAirResistance(40)
				spark:SetColor(170, 215, 255)
			end
		end

		-- a breath of smoke
		for _ = 1, 2 do
			local smoke = emitter:Add("particle/particle_smokegrenade", self.pos + self.normal * 2)

			if (smoke) then
				smoke:SetVelocity(self.normal * math.Rand(8, 20) + VectorRand() * 6)
				smoke:SetDieTime(math.Rand(0.8, 1.3))
				smoke:SetStartAlpha(40)
				smoke:SetEndAlpha(0)
				smoke:SetStartSize(2)
				smoke:SetEndSize(math.Rand(10, 16))
				smoke:SetRoll(math.Rand(0, 360))
				smoke:SetRollDelta(math.Rand(-1, 1))
				smoke:SetColor(150, 170, 190)
				smoke:SetAirResistance(60)
			end
		end

		emitter:Finish()
	end

	local light = DynamicLight(0)

	if (light) then
		light.pos = self.pos + self.normal * 4
		light.r, light.g, light.b = 120, 180, 255
		light.brightness = 3
		light.decay = 2400
		light.size = 140
		light.dietime = CurTime() + 0.2
	end

	self:SetRenderBounds(Vector(-40, -40, -40), Vector(40, 40, 40))
end

function EFFECT:Think()
	return CurTime() - self.born < self.life
end

-- a jagged line from a in the direction, `length` long
local function Arc(a, direction, length, width, alpha)
	local segments = 6
	local right = direction:Cross(Vector(0, 0, 1))

	if (right:LengthSqr() < 0.01) then
		right = direction:Cross(Vector(1, 0, 0))
	end

	right:Normalize()

	local up = direction:Cross(right)

	render.StartBeam(segments + 1)

	for i = 0, segments do
		local t = i / segments
		local jitter = (i == 0) and 0 or (1 - t * 0.4) * 3.2
		local point = a + direction * length * t + right * math.Rand(-jitter, jitter) + up * math.Rand(-jitter, jitter)

		render.AddBeam(point, width * (1 - t * 0.7), t, Color(190, 225, 255, alpha))
	end

	render.EndBeam()
end

function EFFECT:Render()
	local t = (CurTime() - self.born) / self.life
	local alpha = 255 * (1 - t)

	render.SetMaterial(ARC)

	for _, arc in ipairs(self.arcs) do
		-- each arc blinks
		if (math.random() < 0.8) then
			Arc(self.pos, arc.direction, arc.length * (0.7 + t * 0.5), math.Rand(1.5, 3), alpha)
		end
	end

	render.SetMaterial(GLOW)
	render.DrawSprite(self.pos, 30 * (1 - t), 30 * (1 - t), Color(140, 190, 255, alpha * 0.6))
end
