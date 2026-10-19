AddCSLuaFile()

-- The force field of the Alliance (after the Helix ix_forcefield). Spawned: a post where you look and
-- its pair up to 480 units to the side (on the wall); between them the field. E (the Alliance) -
-- the next mode:
--   1  CID        passes who carries a CID card (blue)
--   2  Сотрудники passes the Alliance and the CWU (orange)
--   3  Юниты      passes only the Alliance (red)
--   0  Выключено  no field (the shutdown sound; turned on again - the startup)
-- Who may not pass is stopped by it (it is solid for them only); touching it - the buzz, sparks
-- and a push back. The field hums (a loop with a cue point). Kept with the map (sv_persist.lua).
-- The look (branding/make_forcefield.py): two layers of glowing mist drifting different ways and
-- the glow along the ground and the posts, in the colour of the mode, seen from both sides.

ENT.Type = "anim"
ENT.PrintName = "Силовое поле"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.PhysgunDisabled = true

ENT.PostModel = "models/network_force/combine_fence01b.mdl"
ENT.PairModel = "models/network_force/combine_fence01a.mdl"
ENT.PostFallback = "models/props_combine/combine_fence01b.mdl"
ENT.PairFallback = "models/props_combine/combine_fence01a.mdl"

local HEIGHT = 150

local MODES = {
	[0] = {name = "Выключено", color = Color(0, 0, 0), skin = 0},
	[1] = {name = "Режим: CID-карты", color = Color(70, 165, 255), skin = 0},
	[2] = {name = "Режим: сотрудники Альянса", color = Color(255, 150, 50), skin = 1},
	[3] = {name = "Режим: только юниты", color = Color(255, 64, 56), skin = 2}
}

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Mode")
	self:NetworkVar("Entity", 0, "Pair")
end

local function CanPass(client, mode)
	if (mode == 0 or !IsValid(client) or !client:IsPlayer() or client:GetNW2Bool("nwObserver", false)) then
		return true
	end

	local alliance = NW.zones.IsAlliance(client)

	if (mode == 1) then
		return alliance or client:GetFaction() == "cwu" or client:GetNW2Bool("nwHasCID", false)
	elseif (mode == 2) then
		return alliance or client:GetFaction() == "cwu"
	end

	return alliance
end

hook.Add("ShouldCollide", "nwForcefield", function(a, b)
	local client, field

	if (a:IsPlayer() and b:GetClass() == "nw_forcefield") then
		client, field = a, b
	elseif (b:IsPlayer() and a:GetClass() == "nw_forcefield") then
		client, field = b, a
	end

	-- not set up yet (the data tables come after the creation)
	if (!field or !field.GetMode) then
		return
	end

	return !CanPass(client, field:GetMode())
end)

if (SERVER) then
	-- carrying a CID card (mode 1), known to both sides for the collisions
	local function CardCheck(client)
		client:SetNW2Bool("nwHasCID", NW.inventory.Has(client, "cid"))
	end

	hook.Add("NWInventoryChanged", "nwForcefieldCID", CardCheck)
	hook.Add("NWCharacterLoaded", "nwForcefieldCID", function(client)
		timer.Simple(0.5, function()
			if (IsValid(client)) then
				CardCheck(client)
			end
		end)
	end)

	function ENT:SpawnFunction(client, trace)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0
		angles:RotateAroundAxis(angles:Up(), 270)

		local entity = ents.Create("nw_forcefield")

		entity:SetPos(trace.HitPos + Vector(0, 0, 40))
		entity:SetAngles(angles:SnapTo("y", 90))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel(util.IsValidModel(self.PostModel) and self.PostModel or self.PostFallback)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local trace = util.TraceLine({start = self:GetPos() + self:GetRight() * -16,
			endpos = self:GetPos() + self:GetRight() * -480, filter = self})
		local pair = ents.Create("prop_physics")

		pair:SetModel(util.IsValidModel(self.PairModel) and self.PairModel or self.PairFallback)
		pair:SetPos(trace.HitPos)
		pair:SetAngles(self:GetAngles())
		pair:Spawn()
		pair.PhysgunDisabled = true
		pair.nwForcefieldPair = true
		self:DeleteOnRemove(pair)
		self:SetPair(pair)

		local pairPhysics = pair:GetPhysicsObject()

		if (IsValid(pairPhysics)) then
			pairPhysics:EnableMotion(false)
		end

		-- the field itself: a thin wall between the posts
		local corner = self:WorldToLocal(pair:GetPos())

		self:PhysicsFromMesh({
			{pos = Vector(0, 0, -25)}, {pos = Vector(0, 0, HEIGHT)}, {pos = corner + Vector(0, 0, HEIGHT)},
			{pos = corner + Vector(0, 0, HEIGHT)}, {pos = corner - Vector(0, 0, 25)}, {pos = Vector(0, 0, -25)}
		})

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:SetCustomCollisionCheck(true)
		self:EnableCustomCollisions(true)
		self:SetMoveType(MOVETYPE_NOCLIP)
		self:SetMoveType(MOVETYPE_PUSH)
		self:MakePhysicsObjectAShadow()

		self:SetMode(1)
		self.hum = CreateSound(self, "network2/forcefield/shield_hum_loop.wav")
		self.hum:SetSoundLevel(70)
		self.hum:PlayEx(0.55, 100)
		self:NextThink(CurTime() + 0.3)
	end

	function ENT:ApplyMode(mode, bQuiet)
		local old = self:GetMode()

		self:SetMode(mode)

		local data = MODES[mode]

		self:SetSkin(data.skin)

		if (IsValid(self:GetPair())) then
			self:GetPair():SetSkin(data.skin)
		end

		if (!bQuiet) then
			if (mode == 0) then
				self:EmitSound("network2/forcefield/shield_shutdown" .. (math.random(2) == 1 and "" or "2") .. ".mp3", 75)
			elseif (old == 0) then
				self:EmitSound("network2/forcefield/shield_startup.mp3", 75)
			else
				self:EmitSound("network2/forcefield/power_surge_" .. math.random(1, 3) .. ".mp3", 70)
			end
		end

		if (self.hum) then
			if (mode == 0) then
				self.hum:FadeOut(1)
			else
				self.hum:PlayEx(0.55, 100)
			end
		end
	end

	function ENT:Use(client)
		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 1.2

		if (!NW.zones.IsAlliance(client) and !client:IsAdmin()) then
			self:EmitSound("buttons/combine_button3.wav", 65)

			return
		end

		local mode = (self:GetMode() + 1) % 4

		self:ApplyMode(mode)
		NW.Notify(client, MODES[mode].name)
		NW.persist.Save("nw_forcefield")
	end

	-- who is pressed against it and may not pass: the buzz, the sparks, a push back
	function ENT:Think()
		local mode = self:GetMode()
		local pair = self:GetPair()

		if (mode != 0 and IsValid(pair)) then
			local a, b = self:GetPos(), pair:GetPos()
			local along = (b - a):GetNormalized()
			local normal = along:Cross(Vector(0, 0, 1)):GetNormalized()
			local length = a:Distance(b)

			for _, client in ipairs(player.GetAll()) do
				if (client:Alive() and !CanPass(client, mode)) then
					local pos = client:WorldSpaceCenter()
					local t = (pos - a):Dot(along)
					local side = (pos - a):Dot(normal)
					local height = pos.z - a.z

					if (t > 0 and t < length and math.abs(side) < 26 and height > -40 and height < HEIGHT) then
						if ((client.nwFieldTouch or 0) < CurTime()) then
							client.nwFieldTouch = CurTime() + 1.4
							client:EmitSound("network2/forcefield/shield_touch" .. math.random(1, 3) .. ".mp3", 70)

							local effect = EffectData()

							effect:SetOrigin(a + along * t + Vector(0, 0, height))
							effect:SetNormal(normal * (side > 0 and 1 or -1))
							effect:SetMagnitude(2)
							effect:SetScale(1)
							effect:SetRadius(3)
							util.Effect("ElectricSpark", effect, true, true)
							self:EmitSound("network2/forcefield/spark_sparkles_" .. math.random(1, 14) .. ".mp3", 60)
						end

						client:SetVelocity(normal * (side > 0 and 1 or -1) * 120)
					end
				end
			end
		end

		self:NextThink(CurTime() + 0.15)

		return true
	end

	function ENT:OnRemove()
		if (self.hum) then
			self.hum:Stop()
		end
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_forcefield", {
			Save = function(entity)
				return {mode = entity:GetMode()}
			end,
			Load = function(entity, data)
				entity:ApplyMode(math.Clamp(tonumber(data.mode) or 1, 0, 3), true)
			end
		})
	end)

	return
end

-- ------------------------------------------------------------------ client --
local MIST_A = Material("network2/forcefield/mist_a")
local MIST_B = Material("network2/forcefield/mist_b")
local EDGE = Material("network2/forcefield/edge")

function ENT:Initialize()
	self:SetRenderBounds(Vector(-16, -500, -40), Vector(16, 500, HEIGHT + 40))
end

-- a quad from the post to the pair, HEIGHT high (texture tiles: tile across, rows up)
local function Quad(a, b, height, tile, color)
	local up = Vector(0, 0, height)
	local length = a:Distance(b)
	local tu = tile and length / 192 or 1
	local tv = tile and height / 192 or 1

	mesh.Begin(MATERIAL_QUADS, 1)
		mesh.Position(a + up)
		mesh.TexCoord(0, 0, 0)
		mesh.Color(color.r, color.g, color.b, color.a)
		mesh.AdvanceVertex()

		mesh.Position(b + up)
		mesh.TexCoord(0, tu, 0)
		mesh.Color(color.r, color.g, color.b, color.a)
		mesh.AdvanceVertex()

		mesh.Position(b)
		mesh.TexCoord(0, tu, tv)
		mesh.Color(color.r, color.g, color.b, color.a)
		mesh.AdvanceVertex()

		mesh.Position(a)
		mesh.TexCoord(0, 0, tv)
		mesh.Color(color.r, color.g, color.b, color.a)
		mesh.AdvanceVertex()
	mesh.End()
end

function ENT:DrawTranslucent()
	local mode = self:GetMode()
	local pair = self:GetPair()

	if (mode == 0 or !IsValid(pair)) then
		return
	end

	local color = MODES[mode] and MODES[mode].color or MODES[1].color
	local a = self:GetPos() - Vector(0, 0, 40)
	local b = pair:GetPos() - Vector(0, 0, 40)
	local height = HEIGHT + 40

	-- a flicker now and then, like the shields of the city
	local flicker = math.random() < 0.01 and 0.6 or 1

	render.SetMaterial(MIST_A)
	Quad(a, b, height, true, ColorAlpha(color, 255 * flicker))
	render.SetMaterial(MIST_B)
	Quad(a, b, height, true, ColorAlpha(color, 255 * flicker))
	render.SetMaterial(EDGE)
	Quad(a, b, height, false, ColorAlpha(color, 255 * flicker))
end

function ENT:Draw()
	self:DrawModel()
end

-- a soft light of the field on the ground
function ENT:Think()
	local pair = self:GetPair()

	if (self:GetMode() == 0 or !IsValid(pair) or LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 1500 * 1500) then
		return
	end

	local light = DynamicLight(self:EntIndex())

	if (light) then
		local color = MODES[self:GetMode()].color

		light.pos = (self:GetPos() + pair:GetPos()) / 2 + Vector(0, 0, 10)
		light.r, light.g, light.b = color.r, color.g, color.b
		light.brightness = 1.2
		light.decay = 1000
		light.size = math.min(self:GetPos():Distance(pair:GetPos()) * 0.8, 380)
		light.dietime = CurTime() + 0.25
	end
end
