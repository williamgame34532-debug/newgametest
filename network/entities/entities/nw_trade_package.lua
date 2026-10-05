AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Посылка (торговля АГ)"
ENT.Category = "Network"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "OfferID")
	self:NetworkVar("String", 0, "Goods")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_junk/wood_crate001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:SetMass(80)
		end
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer()) then
			return
		end

		if (!NETWORK.admincomp.CanUse(activator)) then
			return NETWORK.notice.Send(activator, "tradeOnlyAdmin", "bad")
		end

		net.Start("nwParcelShipOpen")
			net.WriteEntity(self)
		net.Send(activator)
	end
else
	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (client:GetPos():DistToSqr(self:GetPos()) > 400 * 400) then
			return
		end

		local angles = client:EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 14), angles, 0.1)
			NETWORK.label.Frame(-130, -24, 260, 48, NETWORK.theme.combine, 1)
			draw.SimpleText(L("tradeMenuTitle"), "nwChat", 4, -8, NETWORK.theme.text, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(self:GetGoods(), "nwInvKey", 4, 10, NETWORK.theme.combine,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end

	net.Receive("nwParcelShipOpen", function()
		local package = net.ReadEntity()

		if (IsValid(NETWORK.gui.tradeShip)) then
			NETWORK.gui.tradeShip:Remove()
		end

		local Sc = NETWORK.util.Scale
		local theme = NETWORK.theme
		local util = NETWORK.util
		local T = NETWORK.parcel
		local panel = vgui.Create("EditablePanel")
		local accent = theme.combine

		NETWORK.gui.tradeShip = panel
		panel:SetSize(Sc(480), Sc(330))
		panel:Center()
		panel:MakePopup()
		panel.city = T.cities[1].id
		panel.mode = "menu"
		panel.alpha = 0

		panel.Think = function(this)
			this.alpha = util.Approach(this.alpha, 1, 8)
			this:SetAlpha(math.Round(this.alpha * 255))

			if (!IsValid(package)) then
				this:Remove()
			end
		end

		panel.OnKeyCodePressed = function(this, key)
			if (key == KEY_ESCAPE) then
				if (this.mode == "ship") then
					this:SetMode("menu")
				else
					this:Remove()
				end
			end
		end

		panel.Paint = function(this, width, height)
			local radius = math.max(Sc(10), 6)

			util.DrawBlurRounded(this, 0, 0, width, height, radius, 4)

			draw.RoundedBox(radius, 0, 0, width, height, Color(8, 9, 10, 236))
			util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
				Color(255, 255, 255, 26))

			draw.SimpleText(util.Upper(L("tradeMenuTitle")), "nwInvKey", Sc(22), Sc(22),
				ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(IsValid(package) and package:GetGoods() or "", "nwInvTitle", Sc(22),
				Sc(46), theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			surface.SetDrawColor(255, 255, 255, 14)
			surface.DrawRect(Sc(22), Sc(68), width - Sc(44), 1)

			if (this.mode == "ship") then
				draw.SimpleText(util.Upper(L("tradeCity")), "nwInvKey", Sc(22), Sc(88),
					ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(util.Upper(L("tradePrice", T.priceMax)), "nwInvKey", Sc(22), Sc(200),
					ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(L("tradeShipNote"), "nwHudSmall", Sc(22), height - Sc(20),
					theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText(L("tradeMenuHint"), "nwHudSmall", Sc(22), height - Sc(20),
					theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		local close = panel:Add("DButton")

		close:SetText("")
		close:SetCursor("hand")
		close:SetSize(Sc(30), Sc(30))
		close:SetPos(Sc(480) - Sc(40), Sc(12))
		close.DoClick = function()
			NETWORK.sound.Click()
			panel:Remove()
		end
		close.Paint = function(this, width, height)
			local bHover = this:IsHovered()
			local inset = Sc(10)
			local color = bHover and theme.danger or theme.textDim

			draw.RoundedBox(math.max(Sc(6), 4), 0, 0, width, height,
				Color(255, 255, 255, bHover and 16 or 6))
			util.DrawThickLine(inset, inset, width - inset, height - inset, math.max(Sc(1), 1), color)
			util.DrawThickLine(width - inset, inset, inset, height - inset, math.max(Sc(1), 1), color)
		end

		local function Row(y, label, hint, glyph, callback, bDanger)
			local button = panel:Add("DButton")

			button:SetText("")
			button:SetCursor("hand")
			button:SetPos(Sc(22), y)
			button:SetSize(Sc(480) - Sc(44), Sc(50))
			button.hover = 0
			button.Think = function(this)
				this.hover = util.Approach(this.hover, this:IsHovered() and 1 or 0, 12)
			end
			button.DoClick = function()
				NETWORK.sound.Click()
				callback()
			end
			button.Paint = function(this, width, height)
				local hover = util.EaseInOut(this.hover)
				local tint = bDanger and theme.danger or accent
				local radius = math.max(Sc(6), 4)

				draw.RoundedBox(radius, 0, 0, width, height, Color(12, 13, 15, 220))

				if (hover > 0.01) then
					draw.RoundedBox(radius, 0, 0, width, height, ColorAlpha(tint, 26 * hover))
				end

				util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
					hover > 0.01 and ColorAlpha(tint, 40 + 160 * hover) or Color(255, 255, 255, 26))

				NETWORK.gui.DrawGlyph(glyph, Sc(14), math.Round(height * 0.5) - Sc(8), Sc(16),
					ColorAlpha(hover > 0.5 and tint or theme.textDim, 240))

				draw.SimpleText(label, "nwInvName", Sc(40), Sc(17), theme.text, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
				draw.SimpleText(hint, "nwInvKey", Sc(40), Sc(34), ColorAlpha(theme.textFaint, 230),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			return button
		end

		panel.SetMode = function(this, mode)
			this.mode = mode

			for _, child in ipairs(this:GetChildren()) do
				if (child != close) then
					child:Remove()
				end
			end

			if (mode == "menu") then
				Row(Sc(86), L("tradeUnpack"), L("tradeUnpackHint"), "down", function()
					net.Start("nwParcelUnpack")
						net.WriteEntity(package)
					net.SendToServer()

					this:Remove()
				end)

				Row(Sc(146), L("tradeForward"), L("tradeForwardHint"), "up", function()
					this:SetMode("ship")
				end)

				Row(Sc(206), L("tradeLeave"), L("tradeLeaveHint"), "back", function()
					this:Remove()
				end, true)

				return
			end

			local buttonWidth = math.floor((Sc(480) - Sc(44) - Sc(8) * 2) / 3)

			for index, city in ipairs(T.cities) do
				local button = this:Add("DButton")
				local column = (index - 1) % 3
				local row = math.floor((index - 1) / 3)

				button:SetText("")
				button:SetCursor("hand")
				button:SetSize(buttonWidth, Sc(32))
				button:SetPos(Sc(22) + column * (buttonWidth + Sc(8)), Sc(102) + row * Sc(38))
				button.DoClick = function()
					this.city = city.id
					NETWORK.sound.Click()
				end
				button.Paint = function(that, width, height)
					local bActive = this.city == city.id
					local radius = math.max(Sc(6), 4)

					draw.RoundedBox(radius, 0, 0, width, height, Color(12, 13, 15, 220))

					if (bActive) then
						draw.RoundedBox(radius, 0, 0, width, height, ColorAlpha(accent, 34))
					elseif (that:IsHovered()) then
						draw.RoundedBox(radius, 0, 0, width, height, Color(255, 255, 255, 10))
					end

					util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
						bActive and ColorAlpha(accent, 210) or Color(255, 255, 255, 30))
					draw.SimpleText(city.name, "nwInvBody", width * 0.5, height * 0.5,
						bActive and theme.text or theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end

			local price = this:Add("DTextEntry")

			price:SetPos(Sc(22), Sc(214))
			price:SetSize(Sc(160), Sc(32))
			price:SetFont("nwInvBody")
			price:SetNumeric(true)
			price:SetValue("500")
			price:SetPaintBackground(false)
			price:SetTextColor(theme.text)
			price:SetTextInset(Sc(10), 0)
			price.Paint = function(that, width, height)
				local radius = math.max(Sc(6), 4)

				draw.RoundedBox(radius, 0, 0, width, height, Color(12, 13, 15, 230))
				util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
					that:HasFocus() and ColorAlpha(accent, 210) or Color(255, 255, 255, 30))
				that:DrawTextEntryText(theme.text, theme.combineDeep, accent)
			end

			local send = this:Add("nwInvButton")

			send:SetSize(Sc(200), Sc(32))
			send:SetPos(Sc(480) - Sc(222), Sc(214))
			send:Setup(L("tradeSendTrain"), "up", true)
			send.DoClick = function()
				net.Start("nwParcelShip")
					net.WriteEntity(package)
					net.WriteString(this.city)
					net.WriteUInt(math.Clamp(tonumber(price:GetValue()) or 0, 0, 65535), 16)
				net.SendToServer()

				this:Remove()
			end

			local back = this:Add("nwInvButton")

			back:SetSize(Sc(120), Sc(28))
			back:SetPos(Sc(22), Sc(258))
			back:Setup(L("pmBack"), "back", false)
			back.DoClick = function()
				this:SetMode("menu")
			end
		end

		panel:SetMode("menu")
	end)
end
