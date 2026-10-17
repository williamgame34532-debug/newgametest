AddCSLuaFile()

-- A crafting table (sh_craft.lua): E - the window of its recipes. The kind of the station (Верстак,
-- Кухня, Химический стол): admins Alt + E. The model: /entmodel. Kept with the map.

ENT.Type = "anim"
ENT.PrintName = "Крафтовый стол"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.DefaultModel = "models/props_wasteland/controlroom_desk001a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Station")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0

		local entity = ents.Create("nw_craft_table")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		if (self:GetStation() == "") then
			self:SetStation("workbench")
		end

		self:ApplyModel()
		self:SetUseType(SIMPLE_USE)
	end

	function ENT:ApplyModel()
		local model = self.nwModel or self.DefaultModel

		self:SetModel(util.IsValidModel(model) and model or "models/props_c17/FurnitureTable002a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer() or client:GetCharacterID() == 0) then
			return
		end

		if (client:IsAdmin() and client:KeyDown(IN_WALK)) then
			local list = NW.craft.stations
			local index = 1

			for i, station in ipairs(list) do
				if (station.id == self:GetStation()) then
					index = i
				end
			end

			self:SetStation(list[index % #list + 1].id)
			NW.persist.Save("nw_craft_table")

			return NW.Notify(client, "Станция: " .. list[index % #list + 1].name)
		end

		NW.craft.Open(client, self)
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_craft_table", {
			Save = function(entity)
				return {station = entity:GetStation(), model = entity.nwModel}
			end,
			Load = function(entity, data)
				entity:SetStation(NW.craft.stationByID[data.station or ""] and data.station or "workbench")
				entity.nwModel = data.model
				entity:ApplyModel()
			end
		})
	end)

	return
end

surface.CreateFont("nwCraftTag", {font = "Montserrat SemiBold", size = 40, weight = 600, extended = true,
	antialias = true})

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local distance = EyePos():DistToSqr(self:GetPos())

	if (distance > 320 * 320) then
		return
	end

	local station = NW.craft.stationByID[self:GetStation()] or NW.craft.stations[1]
	local alpha = math.Clamp((320 - math.sqrt(distance)) / 90, 0, 1)
	local top = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 12))

	cam.Start3D2D(top, Angle(0, EyeAngles().y - 90, 90), 0.07)
		draw.SimpleTextOutlined(station.name, "nwCraftTag", 0, 0, Color(236, 220, 190, 255 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 180 * alpha))
	cam.End3D2D()
end
