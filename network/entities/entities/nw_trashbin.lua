AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Мусорный бак"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.Models = {
	"models/props_junk/wood_crate001a.mdl",
	"models/props_junk/TrashDumpster01a.mdl",
	"models/props_trainstation/trashcan_indoor001b.mdl",
	"models/props_junk/TrashBin01a.mdl",
	"models/props_junk/wood_crate002a.mdl"
}

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Trash")
end

if (SERVER) then

	for _, path in ipairs(ENT.Models or {"models/props_junk/wood_crate001a.mdl"}) do
		util.PrecacheModel(path)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_trashbin")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		NETWORK.util.Print(string.format("%s поставлен %s: модель %s, позиция %s",
			entity:GetClass(), client:SteamID(), tostring(entity:GetModel()), tostring(entity:GetPos())))

		return entity
	end

	function ENT:Initialize()

		local model = self:GetModel() or ""

		if (string.find(string.lower(model), "error", 1, true)) then
			model = ""
		end

		if (model == "" or !(util.IsValidModel(model) or file.Exists(model, "GAME"))) then
			model = "models/props_junk/wood_crate001a.mdl"
		end

		util.PrecacheModel(model)

		if (!util.IsValidModel(model)) then
			NETWORK.util.PrintWarning(self:GetClass() .. ": модель " .. model ..
				" не прошла проверку (файл " .. (file.Exists(model, "GAME") and "есть" or "НЕТ") .. ")")
		end

		self:SetModel(model)

		if (string.find(self:GetModel() or "", "error", 1, true)) then
			NETWORK.util.PrintWarning(self:GetClass() .. ": SetModel(" .. model .. ") дал " ..
				tostring(self:GetModel()) .. " — модель не загрузилась (переполнен прекэш моделей?" ..
				" файл " .. (file.Exists(model, "GAME") and "есть" or "НЕТ") .. ")")
		end

		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		NETWORK.trash.Open(activator, self)
	end

	return
end

function ENT:Draw()
	self:DrawModel()

	local client = LocalPlayer()

	if (client:GetPos():DistToSqr(self:GetPos()) > 400 * 400) then
		return
	end

	local position = self:GetPos() + self:OBBCenter() + Vector(0, 0, self:OBBMaxs().z + 6)
	local angles = (client:EyePos() - position):Angle()

	angles:RotateAroundAxis(angles:Up(), -90)
	angles:RotateAroundAxis(angles:Forward(), 90)

	local fraction = math.Clamp(self:GetTrash() / NETWORK.trash.binMax, 0, 1)

	cam.Start3D2D(position, angles, 0.08)
		NETWORK.label.Frame(-110, -20, 220, 40, NETWORK.theme.combine, 1)
		draw.SimpleText(NETWORK.util.Upper(L("trashTitle")), "nwInvKey", 0, -8, NETWORK.theme.text,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(255, 255, 255, 30)
		surface.DrawRect(-90, 6, 180, 4)
		surface.SetDrawColor(NETWORK.theme.combine.r, NETWORK.theme.combine.g,
			NETWORK.theme.combine.b, 230)
		surface.DrawRect(-90, 6, math.Round(180 * fraction), 4)
	cam.End3D2D()
end
