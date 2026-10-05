AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Холодильник лавки"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.MaxGoods = 10
ENT.MaxPrice = 5
ENT.Commission = 1.1

ENT.Stock = {
	{id = "water", cost = 1},
	{id = "dry_ration", cost = 1},
	{id = "bread", cost = 2},
	{id = "ration_basic", cost = 3}
}

if (SERVER) then
	util.AddNetworkString("nwFridgeMenu")
	util.AddNetworkString("nwFridgeBuy")

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_fridge")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = "models/props_wasteland/kitchen_fridge001a.mdl"

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	function ENT:CountGoods()
		local count = 0

		for _, entity in ipairs(ents.FindInSphere(self:GetPos(), 600)) do
			if (entity:GetClass() == "nw_shopitem" and
				entity.nwFridge == self) then
				count = count + 1
			end
		end

		return count
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

		local character = client:GetCharacter()
		local business = NETWORK.business and NETWORK.business.Get(character)

		if (!business or business.status != "approved") then
			return NETWORK.chat.Notice(client, "fridgeNoBusiness")
		end

		if (!IsValid(self.door)) then
			for _, entity in ipairs(ents.FindInSphere(self:GetPos(), 250)) do
				if (NETWORK.door.IsDoor(entity)) then
					self.door = entity

					break
				end
			end

			if (!IsValid(self.door)) then
				return NETWORK.chat.Notice(client, "fridgeNoDoor")
			end
		end

		net.Start("nwFridgeMenu")
			net.WriteEntity(self)
			net.WriteUInt(#self.Stock, 4)

			for _, entry in ipairs(self.Stock) do
				net.WriteString(entry.id)
				net.WriteUInt(math.ceil(entry.cost * self.Commission), 6)
			end
		net.Send(client)
	end

	net.Receive("nwFridgeBuy", function(_, client)
		local fridge = net.ReadEntity()
		local index = net.ReadUInt(4)
		local amount = math.Clamp(net.ReadUInt(4), 1, 10)
		local price = math.Clamp(net.ReadUInt(4), 1, 5)

		if (!IsValid(fridge) or fridge:GetClass() != "nw_fridge" or
			client:GetPos():Distance(fridge:GetPos()) > 160) then
			return
		end

		local character = client:GetCharacter()
		local business = NETWORK.business and character and
			NETWORK.business.Get(character)

		if (!business or business.status != "approved") then
			return
		end

		local entry = fridge.Stock[index]

		if (!entry) then
			return
		end

		amount = math.min(amount, fridge.MaxGoods - fridge:CountGoods())

		if (amount <= 0) then
			return NETWORK.chat.Notice(client, "fridgeFull")
		end

		local cost = math.ceil(entry.cost * fridge.Commission) * amount

		if (client:GetTokens() < cost) then
			return NETWORK.chat.Notice(client, "shopNoTokens")
		end

		NETWORK.currency.Add(client, -cost)

		for i = 1, amount do
			local goods = ents.Create("nw_shopitem")

			if (IsValid(goods)) then
				goods:SetPos(fridge:GetPos() + fridge:GetForward() *
					(40 + i * 6) + Vector(0, 0, 40))
				goods:Spawn()
				goods:Activate()
				goods:Setup(entry.id, price, tostring(character:GetID()),
					client:SteamID64())
				goods.nwFridge = fridge
			end
		end

		fridge:EmitSound("items/ammocrate_open.wav", 60)
		NETWORK.chat.Notice(client, "fridgeStocked")

		if ((fridge.nwMaintainedUntil or 0) <= CurTime() and
			math.random() <= math.Rand(0.4, 0.5)) then
			timer.Simple(1, function()
				if (IsValid(fridge)) then
					NETWORK.mechanic.Break(fridge)
				end
			end)
		end
	end)
else
	function ENT:Draw()
		self:DrawModel()

		local bBroken = self:GetNWBool("nwBroken", false)

		NETWORK.label.Draw(self, L("entFridge"),
			bBroken and L("labelBroken") or nil,
			bBroken and NETWORK.theme.danger or nil)
	end

	function ENT:DrawTranslucent()
		if (!self:GetNWBool("nwBroken")) then
			return
		end

		local client = LocalPlayer()

		if (client:GetNWString("nwClass", "") != "mechanic" and
			!client:IsAdmin()) then
			return
		end

		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 14)
		local angles = client:EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(position, angles, 0.12)
			local blink = 0.6 + math.abs(math.sin(RealTime() * 3)) * 0.4

			draw.SimpleText("⚠ НЕИСПРАВНОСТЬ", "nwTagDesc", 0, 0,
				Color(240, 96, 86, 240 * blink), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end

	net.Receive("nwFridgeMenu", function()
		local fridge = net.ReadEntity()
		local count = net.ReadUInt(4)
		local stock = {}

		for i = 1, count do
			stock[i] = {id = net.ReadString(), cost = net.ReadUInt(6)}
		end

		local Sc = NETWORK.util.Scale
		local theme = NETWORK.theme
		local frame = vgui.Create("DPanel")

		frame:SetSize(Sc(420), Sc(120 + count * 46))
		frame:SetPos((ScrW() - frame:GetWide()) * 0.5,
			(ScrH() - frame:GetTall()) * 0.5)
		frame:MakePopup()

		frame.Paint = function(_, width, height)
			surface.SetDrawColor(theme.plateDeep.r, theme.plateDeep.g,
				theme.plateDeep.b, 245)
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 190)
			surface.DrawOutlinedRect(0, 0, width, height, 1)

			draw.SimpleText("/// СНАБЖЕНИЕ ЛАВКИ", "nwTagDesc", Sc(16), Sc(16),
				theme.value, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText("Цена продажи (1-5 ткн) и количество:", "nwTagDesc",
				Sc(16), Sc(38), theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		frame.OnKeyCodePressed = function(_, key)
			if (key == KEY_ESCAPE) then
				frame:Remove()
			end
		end

		local closeButton = frame:Add("DButton")
		closeButton:SetText("")
		closeButton:SetPos(frame:GetWide() - Sc(36), Sc(6))
		closeButton:SetSize(Sc(30), Sc(30))
		closeButton.Paint = function(this, width, height)
			draw.SimpleText("✕", "nwTagDesc", width * 0.5, height * 0.5,
				this:IsHovered() and Color(240, 96, 86) or theme.textDim,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		closeButton.DoClick = function()
			frame:Remove()
		end

		local price = frame:Add("DNumSlider")
		price:SetPos(Sc(16), Sc(52))
		price:SetSize(Sc(388), Sc(28))
		price:SetMinMax(1, 5)
		price:SetDecimals(0)
		price:SetValue(2)
		price:SetText("Цена")

		for i, entry in ipairs(stock) do
			local base = NETWORK.item.Get(entry.id)
			local row = frame:Add("DButton")

			row:SetText("")
			row:SetPos(Sc(16), Sc(84 + (i - 1) * 46))
			row:SetSize(Sc(388), Sc(38))
			row.Paint = function(this, width, height)
				surface.SetDrawColor(theme.plate.r, theme.plate.g,
					theme.plate.b, this:IsHovered() and 250 or 220)
				surface.DrawRect(0, 0, width, height)

				draw.SimpleText((base and base.name or entry.id) ..
					"  //  опт " .. entry.cost .. " ткн/шт (с комиссией)",
					"nwTagDesc", Sc(10), height * 0.5, theme.text,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText("КУПИТЬ x3", "nwTagDesc", width - Sc(10),
					height * 0.5, theme.accentSoft, TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)
			end
			row.DoClick = function()
				net.Start("nwFridgeBuy")
					net.WriteEntity(fridge)
					net.WriteUInt(i, 4)
					net.WriteUInt(3, 4)
					net.WriteUInt(math.Round(price:GetValue()), 4)
				net.SendToServer()
			end
		end
	end)
end
