AddCSLuaFile()

ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.PrintName = "Верстак"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.DefaultModel = "models/props_c17/FurnitureTable002a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "TableName")
	self:NetworkVar("String", 1, "TableModel")
end

function ENT:GetDisplayName()
	local name = self:GetTableName()

	return name != "" and name or "Верстак"
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_crafttable")

		if (!IsValid(entity)) then
			return
		end

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:Apply()

		self:SetUseType(SIMPLE_USE)

		self.recipes = self.recipes or {}
	end

	function ENT:Apply()
		local model = self:GetTableModel()

		if (model == "" or !util.IsValidModel(model)) then
			model = self.DefaultModel
		end

		util.PrecacheModel(model)

		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.4

		NETWORK.craft.Open(client, self)
	end
else
	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (!IsValid(client) or
			client:GetPos():DistToSqr(self:GetPos()) > 220 * 220) then
			return
		end

		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 8)
		local direction = position - EyePos()

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			return
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local theme = NETWORK.theme
		local text = NETWORK.util.Upper(self:GetDisplayName())

		surface.SetFont("nwChat")

		local width = math.max(surface.GetTextSize(text), 150) + 44

		cam.Start3D2D(position, angles, 0.1)
			NETWORK.label.Frame(-width * 0.5, -26, width, 52, theme.accent, 1)

			draw.SimpleText(text, "nwChat", 0, -10, theme.text,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(L("craftHint"), "nwHudSmall", 0, 12,
				theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
