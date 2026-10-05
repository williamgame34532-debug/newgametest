AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Городской щиток"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.BreakMin = 420
ENT.BreakMax = 900

local MODELS = {
	"models/props_junk/wood_crate001a.mdl",
	"models/props_wasteland/prison_breakerbox001a.mdl",
	"models/props_lab/reciever01a.mdl",
	"models/props_c17/consolebox01a.mdl",
	"models/props_lab/servers.mdl",
	"models/props_junk/wood_crate001a.mdl"
}

ENT.Models = MODELS

local defaultModel

function ENT:GetDefaultModel()
	if (defaultModel) then
		return defaultModel
	end

	for _, path in ipairs(MODELS) do
		if (util.IsValidModel(path) or file.Exists(path, "GAME")) then
			defaultModel = path

			return path
		end
	end

	defaultModel = MODELS[#MODELS]

	if (SERVER) then
		NETWORK.util.PrintWarning(
			"Ни одна модель не найдена, используется запасная: " .. defaultModel)
	end

	return defaultModel
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "BreakerModel")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_breaker")

		if (!IsValid(entity)) then
			return
		end

		local normal = trace.HitNormal
		local angles

		if (math.abs(normal.z) <= 0.7) then
			angles = normal:Angle()
			angles.p = 0
			angles.r = 0
		else
			angles = Angle(0, client:EyeAngles().y + 180, 0)
		end

		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		if (NETWORK.entities and NETWORK.entities.Save) then
			NETWORK.entities.Save()
		end

		return entity
	end

	function ENT:Initialize()
		local model = self:GetBreakerModel()

		if (model == "" or !(util.IsValidModel(model) or
			file.Exists(model, "GAME"))) then
			model = self:GetDefaultModel()

			self:SetBreakerModel(model)
		end

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)

		local mins, maxs = self:OBBMins(), self:OBBMaxs()

		self:PhysicsInitBox(mins, maxs)
		self:SetCollisionBounds(mins, maxs)
		self:SetSolid(SOLID_BBOX)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:ScheduleBreak()
	end

	function ENT:Apply()
		local model = self:GetBreakerModel()

		if (model != "" and util.IsValidModel(model)) then
			util.PrecacheModel(model)
			self:SetModel(model)
		end
	end

	function ENT:ScheduleBreak()
		self.nextBreak = CurTime() + math.random(self.BreakMin, self.BreakMax)
	end

	function ENT:Think()
		if (!self:GetNWBool("nwBroken") and (self.nextBreak or 0) < CurTime()) then
			NETWORK.mechanic.Break(self)

			self:EmitSound("ambient/energy/spark6.wav", 65, 90)
		end

		if (!self:GetNWBool("nwBroken") and self.bWasBroken) then
			self:ScheduleBreak()
		end

		self.bWasBroken = self:GetNWBool("nwBroken")

		self:NextThink(CurTime() + 1)

		return true
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		if (self:GetNWBool("nwBroken")) then
			return NETWORK.mechanic.TryRepair(client, self)
		end

		if (client:KeyDown(IN_SPEED) and NETWORK.mechanic.TryMaintain and
			NETWORK.mechanic.TryMaintain(client, self)) then
			return
		end

		NETWORK.chat.Notice(client, "breakerFine")
	end

	NETWORK.command.Register("breakermodel", {
		adminOnly = true,
		description = "cmdBreakerModel",
		usage = "/breakermodel <путь к модели | ->",
		example = "/breakermodel models/props_wasteland/panel_leverwheel001a.mdl",
		OnRun = function(command, client, arguments)
			local entity = client:GetEyeTrace().Entity

			if (!IsValid(entity) or entity:GetClass() != "nw_breaker") then
				return NETWORK.chat.Notice(client, "breakerNoTarget")
			end

			local model = string.lower(arguments[1] or "")

			if (model == "-" or model == "") then
				entity:SetBreakerModel("")
				entity:SetModel(entity:GetDefaultModel())

				return NETWORK.chat.Notice(client, "breakerModelReset")
			end

			if (!util.IsValidModel(model)) then
				return NETWORK.chat.Notice(client, "adminNoModel")
			end

			entity:SetBreakerModel(model)
			entity:SetModel(model)
			entity:PhysicsInit(SOLID_VPHYSICS)
			entity:SetSolid(SOLID_VPHYSICS)

			NETWORK.chat.Notice(client, "breakerModelSet")
		end
	})

	NETWORK.command.Register("breakerbreak", {
		description = "cmdBreakerbreak",
		usage = "/breakerbreak",
		adminOnly = true,
		OnRun = function(command, client)
			local entity = client:GetEyeTrace().Entity

			if (!IsValid(entity) or entity:GetClass() != "nw_breaker") then
				return NETWORK.chat.Notice(client, "breakerNone")
			end

			if (entity:GetNWBool("nwBroken")) then
				return NETWORK.chat.Notice(client, "breakerAlready")
			end

			NETWORK.mechanic.Break(entity)
			NETWORK.chat.Notice(client, "breakerBroken")
		end
	})

	NETWORK.command.Register("breakermodel", {
		description = "cmdBreakermodel",
		usage = "/breakermodel [путь к модели]",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local entity = client:GetEyeTrace().Entity

			if (!IsValid(entity) or entity:GetClass() != "nw_breaker") then
				return NETWORK.chat.Notice(client, "breakerNone")
			end

			local model = string.lower(string.Trim(arguments[1] or ""))

			if (model == "") then
				local current = 1

				for index, path in ipairs(entity.Models) do
					if (path == entity:GetBreakerModel()) then
						current = index
					end
				end

				model = entity.Models[(current % #entity.Models) + 1]
			elseif (!util.IsValidModel(model)) then
				return NETWORK.chat.Notice(client, "junkBadModel")
			end

			entity:SetBreakerModel(model)
			entity:Apply()

			if (NETWORK.entities and NETWORK.entities.Save) then
				NETWORK.entities.Save()
			end

			NETWORK.chat.Notice(client, "breakerModelSet")
		end
	})
else
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
		if (!self:GetNWBool("nwBroken")) then
			return
		end

		local client = LocalPlayer()

		if (client:GetNWString("nwClass", "") != "mechanic" and
			client:GetNWString("nwClass", "") != "factory_electrician" and
			!client:IsAdmin()) then
			return
		end

		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 14)
		local angles = client:EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(position, angles, 0.12)
			local blink = 0.6 + math.abs(math.sin(RealTime() * 3)) * 0.4
			local color = Color(240, 96, 86, 240 * blink)
			local text = NETWORK.util.Upper(L("breakerLabel"))

			local icon = NETWORK.util.GetMaterial(
				"framework/icons/electrical_services.png", "smooth")

			if (icon and !icon:IsError()) then
				surface.SetFont("nwTagDesc")

				local textWidth, textHeight = surface.GetTextSize(text)
				local size = textHeight + 6
				local total = size + 6 + textWidth
				local left = -total * 0.5

				surface.SetMaterial(icon)
				surface.SetDrawColor(color.r, color.g, color.b, color.a)
				surface.DrawTexturedRect(left, -size * 0.5, size, size)

				draw.SimpleText(text, "nwTagDesc", left + size + 6, 0, color,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText("⚠ " .. text, "nwTagDesc", 0, 0, color,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		cam.End3D2D()
	end
end
