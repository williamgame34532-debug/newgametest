AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Почтовый ящик"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "OwnerName")
	self:NetworkVar("Bool", 0, "HasMail")
end

if (SERVER) then

	for _, path in ipairs(ENT.Models or {"models/props_junk/wood_crate001a.mdl"}) do
		util.PrecacheModel(path)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_mailbox")

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

		if (!util.IsValidModel(model)) then
			model = "models/props_junk/wood_crate001a.mdl"
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

		if (self:GetOwnerName() == "") then
			self:SetOwnerName("")
		end
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer()) then
			return
		end

		if (self:GetOwnerName() == "") then
			if (!activator:HasCharacter()) then
				return
			end

			NETWORK.mail.Bind(activator, self)

			return
		end

		NETWORK.mail.Open(activator, self)
	end

	return
end

function ENT:Draw()
	self:DrawModel()

	if (!self:GetHasMail()) then
		return
	end

	local position = self:GetPos() + self:OBBCenter() + Vector(0, 0, self:OBBMaxs().z + 8)
	local angles = (LocalPlayer():EyePos() - position):Angle()

	angles:RotateAroundAxis(angles:Up(), -90)
	angles:RotateAroundAxis(angles:Forward(), 90)

	cam.Start3D2D(position, angles, 0.08)
		draw.SimpleText("✉", "nwTermTitle", 0, 0, Color(255, 220, 120,
			200 + math.sin(RealTime() * 3) * 55), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
