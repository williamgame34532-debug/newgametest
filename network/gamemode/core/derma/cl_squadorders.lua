local PANEL = {}

function PANEL:Init()
	NETWORK.gui.squadOrders = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.reveal = 0
	self.hovered = nil
end

function PANEL:OnRemove()
	if (NETWORK.gui.squadOrders == self) then
		NETWORK.gui.squadOrders = nil
	end
end

function PANEL:Think()
	self.reveal = math.min(self.reveal + FrameTime() * 6, 1)

	local list = NETWORK.squad.orderList
	local x, y = self:CursorPos()
	local centerX, centerY = ScrW() * 0.5, ScrH() * 0.5
	local length = math.sqrt((x - centerX) ^ 2 + (y - centerY) ^ 2)

	if (length < NETWORK.util.Scale(60)) then
		self.hovered = nil

		return
	end

	local angle = math.deg(math.atan2(y - centerY, x - centerX)) + 90

	if (angle < 0) then
		angle = angle + 360
	end

	self.hovered = math.Clamp(math.floor(angle / (360 / #list)) + 1, 1, #list)
end

function PANEL:OnMousePressed()
	self:Confirm()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:Confirm()
	local order = self.hovered and NETWORK.squad.orderList[self.hovered]

	if (order) then
		net.Start("nwSquadOrder")
			net.WriteString(order.id)
		net.SendToServer()

		surface.PlaySound("buttons/button17.wav")
	end

	self:Remove()
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local alpha = util.EaseOut(self.reveal)
	local centerX, centerY = math.Round(width * 0.5), math.Round(height * 0.5)
	local list = NETWORK.squad.orderList
	local radius = Sc(190)

	surface.SetDrawColor(3, 5, 8, 190 * alpha)
	surface.DrawRect(0, 0, width, height)

	local selected = NETWORK.squad.selected
	local target = IsValid(selected) and selected:GetCharacterName() or nil

	local title = util.Upper(L("orderTitle"))
	local titleWidth = util.TextSpacedSize(title, "nwTag", Sc(5))

	util.DrawTextSpaced(title, "nwTag", centerX - math.Round(titleWidth * 0.5),
		centerY - radius - Sc(64), ColorAlpha(theme.accent, 250 * alpha),
		Sc(5), TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(target and L("orderToOne", target) or
		L("orderToAll")), "nwHudSmall", centerX, centerY - radius - Sc(40),
		ColorAlpha(target and Color(240, 200, 90) or theme.textDim,
		240 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	for index, order in ipairs(list) do
		local angle = math.rad((index - 1) * (360 / #list) - 90 +
			(360 / #list) * 0.5)
		local bHover = self.hovered == index
		local push = bHover and Sc(12) or 0
		local x = centerX + math.cos(angle) * (radius + push)
		local y = centerY + math.sin(angle) * (radius + push)
		local boxWidth = Sc(150)
		local boxHeight = Sc(52)

		surface.SetDrawColor(8, 12, 18, (bHover and 240 or 200) * alpha)
		surface.DrawRect(x - boxWidth * 0.5, y - boxHeight * 0.5, boxWidth,
			boxHeight)

		surface.SetDrawColor(order.color.r, order.color.g, order.color.b,
			(bHover and 250 or 120) * alpha)
		surface.DrawRect(x - boxWidth * 0.5, y - boxHeight * 0.5,
			math.max(Sc(3), 2), boxHeight)

		if (bHover) then
			surface.SetDrawColor(order.color.r, order.color.g, order.color.b,
				40 * alpha)
			surface.DrawRect(x - boxWidth * 0.5, y - boxHeight * 0.5,
				boxWidth, boxHeight)
		end

		draw.SimpleText(util.Upper(L(order.name)), "nwField", x, y,
			ColorAlpha(bHover and order.color or theme.text, 250 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	draw.SimpleText(L("orderHint"), "nwHudSmall", centerX,
		centerY + radius + Sc(70), ColorAlpha(theme.textFaint, 230 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("nwSquadOrders", PANEL, "EditablePanel")

NETWORK.squad.incoming = nil

net.Receive("nwSquadOrderShow", function()
	local order = NETWORK.squad.GetOrder(net.ReadString())
	local from = net.ReadString()
	local bPersonal = net.ReadBool()

	if (!order) then
		return
	end

	NETWORK.squad.incoming = {
		order = order,
		from = from,
		personal = bPersonal,
		time = CurTime()
	}

	surface.PlaySound(bPersonal and "buttons/button17.wav" or
		"framework/cmb/hud/squadadd.mp3")
end)

net.Receive("nwSquadSelect", function()
	local target = net.ReadEntity()

	NETWORK.squad.selected = IsValid(target) and target or nil
	NETWORK.squad.selectedAt = CurTime()
end)

hook.Add("HUDPaint", "nwSquadOrderBanner", function()
	local incoming = NETWORK.squad.incoming

	if (!incoming) then
		return
	end

	local left = 5 - (CurTime() - incoming.time)

	if (left <= 0) then
		NETWORK.squad.incoming = nil

		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local alpha = math.Clamp(left, 0, 1) *
		util.EaseOut(math.Clamp((CurTime() - incoming.time) * 5, 0, 1))
	local order = incoming.order
	local text = util.Upper(L(order.name))

	surface.SetFont("nwTag")

	local width = surface.GetTextSize(text) + Sc(80)
	local height = Sc(56)
	local x = math.Round(ScrW() * 0.5 - width * 0.5)
	local y = math.Round(ScrH() * 0.16)

	surface.SetDrawColor(6, 9, 14, 225 * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(order.color.r, order.color.g, order.color.b,
		245 * alpha)
	surface.DrawRect(x, y, width, math.max(Sc(3), 2))

	if (incoming.personal) then
		surface.DrawOutlinedRect(x, y, width, height, math.max(Sc(2), 1))
	end

	util.DrawTextSpaced(text, "nwTag", math.Round(ScrW() * 0.5), y + Sc(24),
		ColorAlpha(order.color, 250 * alpha), Sc(4), TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper((incoming.personal and L("orderYou") .. "  //  "
		or "") .. incoming.from), "nwHudSmall", math.Round(ScrW() * 0.5),
		y + Sc(42), ColorAlpha(NETWORK.theme.textDim, 235 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
