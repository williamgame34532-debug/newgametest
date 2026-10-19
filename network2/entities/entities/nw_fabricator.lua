AddCSLuaFile()

-- The fabricator of the Alliance (sh_fabricator.lua): E - a unit opens the station of acquisition; anyone
-- carrying the packed cargo of the factory loads it into the reservoir. While it prints: a light, the
-- sound of the machine. Over it the level of the resin. The model: the C menu → «Настройки».

ENT.Type = "anim"
ENT.PrintName = "Фабрикатор Альянса"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/hla_prop/fabricator.mdl"

-- where a thing is printed: in front of the machine, at the middle of its height
function ENT:PrintPoint()
	local mins, maxs = self:OBBMins(), self:OBBMaxs()

	return self:LocalToWorld(Vector(maxs.x + 6, 0, (mins.z + maxs.z) * 0.55))
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Resin")
	self:NetworkVar("Float", 0, "Printed")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create(self.ClassName)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0
		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()
		entity:SetResin(NW.fabricator.max:GetInt())

		return entity
	end

	function ENT:Initialize()
		local model = self.nwModel or self.Model

		self:SetModel(util.IsValidModel(model) and model or "models/props_combine/combine_interface001.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer() or client:GetCharacterID() == 0) then
			return
		end

		-- the cargo of the factory first: it goes into the reservoir
		if (NW.fabricator.Load(client, self)) then
			return
		end

		if (!NW.zones.IsAlliance(client)) then
			self:EmitSound("buttons/combine_button_locked.wav", 60)

			return NW.Notify(client, "Доступ только для Альянса. Груз завода можно сдать сюда")
		end

		NW.fabricator.Open(client, self)
	end

	-- the printing: the chamber opens, the thing is printed (a weapon - assembled), the work is done;
	-- the effect of the printing (entities/effects/nw_fabprint.lua) runs on the clients
	function ENT:Print(bWeapon)
		self:SetPrinted(CurTime())
		self:EmitSound("network2/fabricator/chamber_open.wav", 66)

		timer.Simple(0.5, function()
			if (IsValid(self)) then
				self:EmitSound(bWeapon and "network2/fabricator/gun_attach_print.wav" or "network2/fabricator/print_item.wav", 68)
			end
		end)

		if (bWeapon) then
			timer.Simple(1.1, function()
				if (IsValid(self)) then
					self:EmitSound("network2/fabricator/upgrading.wav", 60, 100, 0.5)
				end
			end)
		end

		timer.Simple(NW.fabricator.printTime - 0.4, function()
			if (IsValid(self)) then
				self:StopSound("network2/fabricator/upgrading.wav")
				self:EmitSound("network2/fabricator/work_complete.wav", 68)
			end
		end)

		local effect = EffectData()

		effect:SetEntity(self)
		effect:SetOrigin(self:PrintPoint())
		effect:SetMagnitude(NW.fabricator.printTime)
		util.Effect("nw_fabprint", effect, true, true)
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_fabricator", {
			Save = function(entity)
				return {resin = entity:GetResin(), model = entity.nwModel}
			end,
			Load = function(entity, data)
				entity:SetResin(math.Clamp(tonumber(data.resin) or 0, 0, NW.fabricator.max:GetInt()))

				if (isstring(data.model) and util.IsValidModel(data.model)) then
					entity.nwModel = data.model
					entity:SetModel(data.model)
					entity:PhysicsInit(SOLID_VPHYSICS)

					local physics = entity:GetPhysicsObject()

					if (IsValid(physics)) then
						physics:EnableMotion(false)
					end
				end
			end
		})
	end)

	return
end

surface.CreateFont("nwFabSign", {font = "Exo 2", size = 34, weight = 600, extended = true, antialias = true})

function ENT:Draw()
	self:DrawModel()
end

function ENT:Think()
	-- printing: a cold light for a moment
	if (CurTime() - self:GetPrinted() < NW.fabricator.printTime) then
		local light = DynamicLight(self:EntIndex())

		if (light) then
			light.pos = self:PrintPoint()
			light.r, light.g, light.b = 120, 200, 255
			light.brightness = 1.4 + math.sin(CurTime() * 20) * 0.4
			light.decay = 1000
			light.size = 140
			light.dietime = CurTime() + 0.2
		end
	end
end

function ENT:DrawTranslucent()
	local distance = EyePos():DistToSqr(self:GetPos())

	if (distance > 400 * 400) then
		return
	end

	local alpha = math.Clamp((400 - math.sqrt(distance)) / 100, 0, 1)
	local top = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 12))
	local angle = Angle(0, EyeAngles().y - 90, 90)
	local max = NW.fabricator.max:GetInt()
	local level = math.Clamp(self:GetResin() / max, 0, 1)

	cam.Start3D2D(top, angle, 0.07)
		draw.RoundedBox(6, -200, -44, 400, 88, Color(12, 14, 16, 215 * alpha))
		draw.SimpleText("ФАБРИКАТОР  ·  СМОЛА " .. self:GetResin() .. "/" .. max, "nwFabSign", 0, -14,
			Color(226, 230, 232, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(60, 62, 64, 255 * alpha)
		surface.DrawRect(-180, 18, 360, 8)
		surface.SetDrawColor(120, 200, 255, 255 * alpha)
		surface.DrawRect(-180, 18, 360 * level, 8)
	cam.End3D2D()
end
