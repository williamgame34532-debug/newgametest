AddCSLuaFile()

-- A station of the factory (sh_cwu.lua NW.cwu.stations): E - the work of the station (sv_cwu.lua
-- NW.cwu.Work). Over it: the name and what it does. The model can be changed: /entmodel.

ENT.Type = "anim"
ENT.PrintName = "Станция завода"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.Station = "intake"
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Worker")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0

		local entity = ents.Create(self.ClassName)

		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		-- the instruction once for the admin who builds the first station
		if (client:GetPData("nw_factory_help", "0") != "1") then
			client:SetPData("nw_factory_help", "1")
			NW.cwu.OpenInstruction(client)
		end

		return entity
	end

	function ENT:Initialize()
		local station = NW.cwu.stations[self.Station]

		self:SetModel(self.nwModel or station.model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(client)
		if (IsValid(client) and client:IsPlayer()) then
			NW.cwu.Work(client, self)
		end
	end

	return
end

surface.CreateFont("nwFactoryTitle", {font = "Montserrat SemiBold", size = 42, weight = 600, extended = true,
	antialias = true})
surface.CreateFont("nwFactoryText", {font = "Exo 2", size = 30, weight = 500, extended = true, antialias = true})

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local distance = EyePos():DistToSqr(self:GetPos())

	if (distance > 420 * 420) then
		return
	end

	local station = NW.cwu.stations[self.Station]
	local alpha = math.Clamp((420 - math.sqrt(distance)) / 120, 0, 1)
	local top = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 14))
	local angle = Angle(0, EyeAngles().y - 90, 90)
	local rank = NW.cwu.ranks[station.rank]

	cam.Start3D2D(top, angle, 0.08)
		draw.RoundedBox(10, -230, -60, 460, 112, Color(14, 16, 20, 210 * alpha))
		draw.RoundedBox(2, -230, -60, 460, 4, Color(232, 170, 64, 255 * alpha))
		draw.SimpleText(station.name, "nwFactoryTitle", 0, -24, Color(236, 238, 242, 255 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(station.hint .. "  ·  от ранга «" .. rank.name .. "»", "nwFactoryText", 0, 20,
			Color(180, 184, 190, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
