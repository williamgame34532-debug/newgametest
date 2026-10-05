AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"
ENT.PrintName = "Вербовщик"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "NPCName")
	self:NetworkVar("String", 1, "NPCModel")
	self:NetworkVar("String", 2, "NPCSequence")

	self:NetworkVar("String", 3, "ConfigID")
end

function ENT:GetDisplayName()
	local name = self:GetNPCName()

	return name != "" and name or "Вербовщик"
end

if (SERVER) then

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_recruiter")

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		if (self:GetNPCModel() == "") then
			self:SetNPCModel("models/humans/group01/male_07.mdl")
		end

		if (self:GetConfigID() == "") then
			self:SetConfigID("default")
		end

		self:Apply()
	end

	function ENT:Apply()
		local model = self:GetNPCModel()

		if (!util.IsValidModel(model)) then
			model = "models/humans/group01/male_07.mdl"
		end

		local body = NETWORK.entities and NETWORK.entities.CollectBody and
			string.lower(self:GetModel() or "") == string.lower(model) and
			NETWORK.entities.CollectBody(self)

		self:SetModel(model)

		if (body) then
			NETWORK.entities.ApplyBody(self, body)
		end

		self:SetHullType(HULL_HUMAN)
		self:SetHullSizeNormal()
		self:SetSolid(SOLID_BBOX)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:CapabilitiesClear()
		self:SetNPCState(NPC_STATE_IDLE)
		self:SetMaxYawSpeed(0)
		self:AddFlags(FL_NPC)
		self:SetMaxHealth(1000)
		self:SetHealth(1000)
		self:DropToFloor()

		self.baseSequence = self:LookupSequence(self:GetNPCSequence() != "" and
			self:GetNPCSequence() or "idle_all_01")

		if (!self.baseSequence or self.baseSequence <= 0) then
			self.baseSequence = self:LookupSequence("idle_subtle")
		end

		if (self.baseSequence and self.baseSequence > 0) then
			self:ResetSequence(self.baseSequence)
			self:SetCycle(0)
		end
	end

	function ENT:SelectSchedule()
		self:SetSchedule(SCHED_IDLE_STAND)
	end

	function ENT:OnTakeDamage()
		return 0
	end

	function ENT:Think()
		if (self.baseSequence and self.baseSequence > 0 and
			self:GetSequence() != self.baseSequence) then
			self:ResetSequence(self.baseSequence)
		end

		self:NextThink(CurTime() + 0.1)

		return true
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or
			!activator:HasCharacter()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.5

		NETWORK.recruiter.Open(activator, self)
	end
else
	function ENT:Draw()

		if (NETWORK.npclook) then
			NETWORK.npclook.Update(self)
		end

		self:DrawModel()

		local client = LocalPlayer()

		if (!IsValid(client) or client:GetPos():DistToSqr(self:GetPos()) > 260 * 260) then
			return
		end

		local theme = NETWORK.theme
		local _, maxs = self:GetRotatedAABB(self:OBBMins(), self:OBBMaxs())
		local position = self:GetPos() + Vector(0, 0, maxs.z + 10)
		local direction = position - EyePos()

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			return
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local config = NETWORK.recruiter.Get(self:GetConfigID())
		local entry = config and config.entries and config.entries[1]
		local faction = entry and NETWORK.factions.Get(entry.faction)
		local accent = faction and faction.color or theme.accent
		local icon = faction and faction.icon and
			NETWORK.util.GetMaterial(faction.icon, "smooth")

		cam.Start3D2D(position, angles, 0.1)
			local text = NETWORK.util.Upper(self:GetDisplayName())
			local sub = faction and NETWORK.util.Upper(L(faction.name)) or
				NETWORK.util.Upper(L("recruiterHint"))

			surface.SetFont("nwChat")

			local textWidth = surface.GetTextSize(text)

			surface.SetFont("nwHudSmall")

			local subWidth = surface.GetTextSize(sub)
			local box = 40
			local pad = 16
			local width = math.max(textWidth, subWidth) + box + pad * 3
			local height = 56
			local left = -width * 0.5
			local top = -height * 0.5
			local cut = 8

			draw.NoTexture()
			surface.SetDrawColor(6, 9, 13, 216)
			surface.DrawPoly({
				{x = left + cut, y = top},
				{x = left + width - cut, y = top},
				{x = left + width, y = top + cut},
				{x = left + width, y = top + height - cut},
				{x = left + width - cut, y = top + height},
				{x = left + cut, y = top + height},
				{x = left, y = top + height - cut},
				{x = left, y = top + cut}
			})

			surface.SetDrawColor(accent.r, accent.g, accent.b, 240)
			surface.DrawRect(left + cut, top, width - cut * 2, 2)
			surface.DrawRect(left + cut, top + height - 2, width - cut * 2, 2)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 130)
			surface.DrawRect(left, top + cut, 2, 12)
			surface.DrawRect(left + width - 2, top + cut, 2, 12)
			surface.DrawRect(left, top + height - cut - 12, 2, 12)
			surface.DrawRect(left + width - 2, top + height - cut - 12, 2, 12)

			local textX = left + pad

			if (icon and !icon:IsError()) then

				surface.SetDrawColor(255, 255, 255, 245)
				surface.SetMaterial(icon)
				surface.DrawTexturedRect(textX, top + (height - box) * 0.5,
					box, box)

				textX = textX + box + pad * 0.5

				surface.SetDrawColor(accent.r, accent.g, accent.b, 70)
				surface.DrawRect(textX - pad * 0.25, top + 12, 1, height - 24)
			end

			draw.SimpleText(text, "nwChat", textX, top + 20, theme.text,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(sub, "nwHudSmall", textX, top + 38,
				ColorAlpha(accent, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
