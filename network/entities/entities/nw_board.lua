AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Доска объявлений"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.Models = {
	"models/props_junk/wood_crate001a.mdl",
	"models/props_lab/corkboard001.mdl",
	"models/props_lab/corkboard002.mdl",
	"models/props_c17/FurnitureDrawer001a.mdl"
}
ENT.maxNotices = 12

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Count")
end

if (SERVER) then

	for _, path in ipairs(ENT.Models or {"models/props_junk/wood_crate001a.mdl"}) do
		util.PrecacheModel(path)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_board")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		NETWORK.util.Print(string.format("%s поставлен %s: модель %s, позиция %s",
			entity:GetClass(), client:SteamID(), tostring(entity:GetModel()), tostring(entity:GetPos())))

		return entity
	end

	function ENT:SetupPhysics()
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (!IsValid(physics)) then
			local mins, maxs = self:OBBMins(), self:OBBMaxs()

			self:PhysicsInitBox(mins, maxs)
			self:SetCollisionBounds(mins, maxs)
			self:SetSolid(SOLID_BBOX)

			physics = self:GetPhysicsObject()
		else
			self:SetSolid(SOLID_VPHYSICS)
		end

		self:SetMoveType(MOVETYPE_NONE)

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	function ENT:Apply()
		self:SetupPhysics()
	end

	function ENT:Initialize()

		local model = self:GetModel() or ""

		if (string.find(string.lower(model), "error", 1, true)) then
			model = ""
		end

		if (model == "" or !(util.IsValidModel(model) or file.Exists(model, "GAME"))) then
			model = ""

			local configured = NETWORK.config and NETWORK.config.Get and NETWORK.config.Get("boardModel")

			if (isstring(configured) and configured != "" and file.Exists(configured, "GAME")) then
				model = configured
			end

			for _, path in ipairs(model == "" and self.Models or {}) do
				if (file.Exists(path, "GAME")) then
					model = path

					break
				end
			end
		end

		if (model == "") then
			model = "models/props_junk/wood_crate001a.mdl"
		end

		util.PrecacheModel(model)

		self:SetModel(model)

		if (string.find(self:GetModel() or "", "error", 1, true)) then
			NETWORK.util.PrintWarning(self:GetClass() .. ": SetModel(" .. model .. ") дал " ..
				tostring(self:GetModel()) .. " — модель не загрузилась (переполнен прекэш моделей?" ..
				" файл " .. (file.Exists(model, "GAME") and "есть" or "НЕТ") .. ")")
		end

		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:SetupPhysics()

		self.notices = self.notices or {}
		self:SetCount(#self.notices)
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		NETWORK.board.Open(activator, self)
	end

	return
end

function ENT:Draw()
	self:DrawModel()

	local client = LocalPlayer()

	if (!IsValid(client) or client:GetPos():DistToSqr(self:GetPos()) > 260 * 260) then
		return
	end

	local theme = NETWORK.theme
	local mins, maxs = self:GetRotatedAABB(self:OBBMins(), self:OBBMaxs())
	local position = self:GetPos() + Vector(0, 0, maxs.z + 8)
	local direction = position - EyePos()

	direction.z = 0

	if (direction:LengthSqr() < 0.01) then
		return
	end

	local angles = direction:Angle()

	angles:RotateAroundAxis(angles:Up(), -90)
	angles:RotateAroundAxis(angles:Forward(), 90)

	cam.Start3D2D(position, angles, 0.1)
		local text = NETWORK.util.Upper(L("boardTitle"))
		local hint = L("boardHint", self:GetCount())

		surface.SetFont("nwChat")

		local width = math.max(surface.GetTextSize(text), 160) + 40

		NETWORK.label.Frame(-width * 0.5, -26, width, 52, theme.combine, 1)

		draw.SimpleText(text, "nwChat", 0, -10, theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(hint, "nwHudSmall", 0, 12, theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
