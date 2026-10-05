AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "nw_terminal"
ENT.PrintName = "Бизнес-терминал"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_BOTH

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_business_terminal")
		local angles = trace.HitNormal:Angle()

		angles.p = 0
		angles.r = 0

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or
			(activator.nwNextShop or 0) > CurTime()) then
			return
		end

		activator.nwNextShop = CurTime() + 1

		if (self:GetNWBool("nwBroken", false)) then
			self:EmitSound("framework/cmb/forcefield/sparkle" .. math.random(4) .. ".mp3", 60, 110)
			NETWORK.chat.Notice(activator, "empTerminalBroken")

			return
		end

		if (!NETWORK.terminal.IsUsable(activator, self)) then
			return
		end

		self:EmitSound(NETWORK.terminal.sounds.select, 65)

		local character = activator:GetCharacter()
		local entry = character and NETWORK.business.Get(character)

		if (entry and entry.status == "approved" and !entry.position and
			NETWORK.business.SetPosition) then
			NETWORK.business.SetPosition(tostring(character:GetID()), self:GetPos())
			NETWORK.business.Mark(activator, entry)
		end

		NETWORK.store.Open(activator)
	end

	function ENT:Think()
		self:NextThink(CurTime() + 1)

		return true
	end
else
	local style = {
		brand = "BUSINESS STATION",
		color = Color(196, 160, 246),
		background = Color(18, 10, 34)
	}

	function style.Body(entity, width, height, color)
		local alpha = 130 + math.abs(math.cos(RealTime() * 2)) * 125

		draw.SimpleText(NETWORK.util.Upper(L("bizScreenTitle")), "nwTermScreenBody",
			width * 0.5, height * 0.5, ColorAlpha(color, 245),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(NETWORK.util.Upper(L("bizScreenHint")), "nwTermScreenSmall",
			width * 0.5, height * 0.5 + 44, ColorAlpha(color, alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function ENT:Draw()
		self:DrawModel()

		NETWORK.terminal.DrawScreen(self, style)
	end

	net.Receive("nwShopOpen", function()
		local data = NETWORK.util.ReadTable()

		if (IsValid(NETWORK.gui.shopPanel)) then
			NETWORK.gui.shopPanel:Update(data)

			return
		end

		local panel = vgui.Create("nwShopPanel")

		panel:Update(data)
	end)
end
