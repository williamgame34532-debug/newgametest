NETWORK.rebels = NETWORK.rebels or {}

local R = NETWORK.rebels

R.graffitiFont = "nwRebelGraffiti"

surface.CreateFont(R.graffitiFont, {
	font = (NETWORK.fonts and NETWORK.fonts.display) or "Roboto",
	size = 46,
	weight = 900,
	extended = true,
	antialias = true
})

R.graffitiArt = {
	ru = {"СВОБОДУ!", "ДОЛОЙ АЛЬЯНС", "МЫ ПОМНИМ", "СОПРОТИВЛЯЙСЯ", "ФРИМЕН ЖИВ",
		"ГОРОД НАШ"},
	en = {"FREEDOM!", "DOWN WITH THE ALLIANCE", "WE REMEMBER", "RESIST", "FREEMAN LIVES",
		"THE CITY IS OURS"}
}

surface.CreateFont("nwRebelSign", {
	font = (NETWORK.fonts and (NETWORK.fonts.mono or NETWORK.fonts.display)) or "Roboto",
	size = 34,
	weight = 800,
	extended = true,
	antialias = true
})

local function UseDown()
	return input.IsKeyDown(input.GetKeyCode(input.LookupBinding("+use") or "e"))
end

local function UseKeyName()
	return string.upper(input.LookupBinding("+use", true) or "E")
end

local hold = {
	start = nil,
	sent = false,
	entity = nil,
	action = 0,
	label = nil,
	nextScan = 0,
	alpha = 0
}

local function Scan(client)
	if (R.Is(client)) then
		local entity, kind = R.FindSabotageTarget(client)

		if (IsValid(entity)) then
			return entity, 1, L("rebelHintSabotage", L(R.kindNames[kind] or kind))
		end

		return
	end

	if (R.CanClean(client)) then
		local entity = R.FindGraffiti(client)

		if (IsValid(entity)) then
			return entity, 2, L("rebelHintClean")
		end
	end
end

local function Blocked(client)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return true
	end

	if (vgui.CursorVisible() or IsValid(NETWORK.gui.menu) or
		(NETWORK.hud and NETWORK.hud.IsHidden and NETWORK.hud.IsHidden())) then
		return true
	end

	return false
end

hook.Add("Think", "nwRebelHold", function()
	local client = LocalPlayer()

	if (Blocked(client)) then
		hold.entity = nil
		hold.start = nil

		return
	end

	if (hold.nextScan < RealTime() and !hold.start) then
		hold.nextScan = RealTime() + 0.1
		hold.entity, hold.action, hold.label = Scan(client)
	end

	if (!UseDown()) then
		hold.start = nil
		hold.sent = false

		return
	end

	if (hold.sent or !IsValid(hold.entity)) then
		return
	end

	hold.start = hold.start or RealTime()

	if (RealTime() - hold.start < R.sabotage.holdTime) then
		return
	end

	hold.sent = true

	net.Start("nwRebelAction")
		net.WriteUInt(hold.action, 2)
		net.WriteEntity(hold.entity)
	net.SendToServer()
end)

hook.Add("HUDPaint", "nwRebelHold", function()
	local client = LocalPlayer()
	local bShow = !Blocked(client) and IsValid(hold.entity) and !hold.sent

	hold.alpha = NETWORK.util.Approach(hold.alpha or 0, bShow and 1 or 0, bShow and 10 or 6)

	if (hold.alpha < 0.02 or !hold.label) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local alpha = hold.alpha
	local text = hold.label
	local key = UseKeyName()
	local thin = math.max(Sc(1), 1)
	local accent = hold.action == 1 and R.color or theme.combine

	surface.SetFont("nwLabel")

	local textWidth = surface.GetTextSize(text)
	local keySize = Sc(20)
	local padding = Sc(8)
	local width = keySize + Sc(8) + textWidth + padding * 2
	local height = Sc(28)
	local x = math.Round((ScrW() - width) * 0.5)
	local y = math.Round(ScrH() * 0.5) + Sc(64)

	surface.SetDrawColor(0, 0, 0, 190 * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 110 * alpha)
	surface.DrawOutlinedRect(x, y, width, height, thin)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 220 * alpha)
	surface.DrawRect(x, y + height - thin * 2, width, thin * 2)

	local keyX = x + padding
	local keyY = y + math.Round((height - keySize) * 0.5)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 200 * alpha)
	surface.DrawOutlinedRect(keyX, keyY, keySize, keySize, thin)

	draw.SimpleText(key, "nwLabelBold", keyX + keySize * 0.5, keyY + keySize * 0.5,
		ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "nwLabel", keyX + keySize + Sc(8), y + height * 0.5,
		ColorAlpha(theme.text, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (hold.start and !hold.sent) then
		local fraction = math.Clamp((RealTime() - hold.start) / R.sabotage.holdTime, 0, 1)
		local barWidth = width
		local fill = math.max(math.Round(barWidth * fraction), 2)

		surface.SetDrawColor(0, 0, 0, 180 * alpha)
		surface.DrawRect(x, y + height + Sc(4), barWidth, math.max(Sc(3), 2))

		surface.SetDrawColor(accent.r, accent.g, accent.b, 250 * alpha)
		surface.DrawRect(x, y + height + Sc(4), fill, math.max(Sc(3), 2))
	end
end)

local SABOTAGE_CLASSES = {
	"npc_turret_floor", "npc_turret_ceiling", "npc_cscanner", "nw_scanner",
	"nw_forcefield", "nw_lock", "nw_cmbterminal", "nw_dispenser"
}

local sabotaged = {}
local nextCollect = 0

local function Collect()
	sabotaged = {}

	for _, class in ipairs(SABOTAGE_CLASSES) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (entity:GetNWBool("nwSabotaged", false)) then
				sabotaged[#sabotaged + 1] = entity
			end
		end
	end
end

hook.Add("PostDrawTranslucentRenderables", "nwRebelSabotage", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	if (nextCollect < RealTime()) then
		nextCollect = RealTime() + 0.5

		Collect()
	end

	if (#sabotaged == 0) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local eye = EyePos()
	local angles = Angle(0, EyeAngles().y - 90, 90)
	local blink = math.abs(math.sin(RealTime() * 5))

	for _, entity in ipairs(sabotaged) do
		if (!IsValid(entity) or eye:DistToSqr(entity:GetPos()) > 700 * 700) then
			continue
		end

		local kind = entity:GetNWString("nwSabotageKind", "")
		local bTerminal = kind == "terminal" or kind == "dispenser"
		local text = NETWORK.util.Upper(L(bTerminal and "rebelSysError" or "rebelDeviceFault"))
		local top = entity:OBBMaxs().z
		local position = entity:LocalToWorld(Vector(0, 0, top + 10))

		if (entity:GetClass() == "nw_lock") then
			position = entity:WorldSpaceCenter() + Vector(0, 0, 14)
		end

		local color = Color(232, 84, 76, 140 + 115 * blink)

		cam.Start3D2D(position, angles, bTerminal and 0.1 or 0.07)
			surface.SetFont("nwRebelSign")

			local width, height = surface.GetTextSize(text)
			local padX, padY = 14, 6

			surface.SetDrawColor(0, 0, 0, 190)
			surface.DrawRect(-width * 0.5 - padX, -height * 0.5 - padY, width + padX * 2,
				height + padY * 2)

			surface.SetDrawColor(color.r, color.g, color.b, color.a)
			surface.DrawOutlinedRect(-width * 0.5 - padX, -height * 0.5 - padY, width + padX * 2,
				height + padY * 2, 2)

			draw.SimpleText(text, "nwRebelSign", 0, 0, color, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end)

local graffitiCount = 0
local nextCount = 0

hook.Add("HUDPaint", "nwRebelGraffitiHud", function()
	local client = LocalPlayer()

	if (!R.CanClean(client) or (NETWORK.hud and NETWORK.hud.IsHidden and
		NETWORK.hud.IsHidden())) then
		return
	end

	if (nextCount < RealTime()) then
		nextCount = RealTime() + 1
		graffitiCount = R.GetGraffitiCountAt(client:GetPos())
	end

	if (graffitiCount <= 0) then
		return
	end

	local Sc = NETWORK.util.Scale
	local text = NETWORK.util.Upper(L("rebelGraffitiHud", graffitiCount))

	surface.SetFont("nwLabelBold")

	local width, height = surface.GetTextSize(text)
	local x = math.Round((ScrW() - width) * 0.5) - Sc(10)
	local y = Sc(96)
	local color = NETWORK.theme.warning

	surface.SetDrawColor(0, 0, 0, 170)
	surface.DrawRect(x, y, width + Sc(20), height + Sc(8))

	surface.SetDrawColor(color.r, color.g, color.b, 220)
	surface.DrawRect(x, y + height + Sc(8) - math.max(Sc(2), 2), width + Sc(20),
		math.max(Sc(2), 2))

	draw.SimpleText(text, "nwLabelBold", x + Sc(10), y + Sc(4), color, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)
end)

R.pocketState = R.pocketState or {slots = 2, items = {}, bAllowed = false}

local function SendMove(bIn, index)
	net.Start("nwRebelPocketMove")
		net.WriteBool(bIn)
		net.WriteUInt(math.Clamp(tonumber(index) or 0, 0, 65535), 16)
	net.SendToServer()
end

function R.OpenPocketPanel()
	if (IsValid(R.pocketPanel)) then
		R.pocketPanel:Remove()
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local thin = math.max(Sc(1), 1)
	local panel = vgui.Create("EditablePanel")

	R.pocketPanel = panel

	panel:SetSize(Sc(380), Sc(440))
	panel:Center()
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(false)
	panel.OnKeyCodePressed = function(this, key)
		if (key == KEY_ESCAPE) then
			this:Remove()
		end
	end
	panel.Think = function(this)
		if (input.IsKeyDown(KEY_ESCAPE)) then
			this:Remove()
		end
	end
	panel.Paint = function(this, width, height)
		NETWORK.util.DrawBlur(this, 4)

		surface.SetDrawColor(6, 7, 8, 235)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 160)
		surface.DrawOutlinedRect(0, 0, width, height, thin)

		surface.SetDrawColor(R.color.r, R.color.g, R.color.b, 230)
		surface.DrawRect(0, 0, width, math.max(Sc(2), 2))

		draw.SimpleText(NETWORK.util.Upper(L("rebelPocketTitle")), "nwInvTitle", Sc(18), Sc(24),
			theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(L("rebelPocketSub"), "nwLabel", Sc(18), Sc(46), theme.textDim,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(NETWORK.util.Upper(L("rebelPocketInventory")), "nwLabelBold", Sc(18),
			Sc(176), theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawRect(Sc(18), Sc(188), width - Sc(36), thin)
	end

	local close = panel:Add("DButton")

	close:SetText("")
	close:SetSize(Sc(28), Sc(28))
	close:SetPos(panel:GetWide() - Sc(40), Sc(12))
	close.DoClick = function()
		panel:Remove()
	end
	close.Paint = function(this, width, height)
		local color = this:IsHovered() and theme.danger or theme.textDim

		surface.SetDrawColor(color.r, color.g, color.b, 200)
		surface.DrawOutlinedRect(0, 0, width, height, thin)

		draw.SimpleText("×", "nwInvName", width * 0.5, height * 0.5 - Sc(1), color,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local cells = panel:Add("Panel")

	cells:SetPos(Sc(18), Sc(64))
	cells:SetSize(panel:GetWide() - Sc(36), Sc(96))

	local list = panel:Add("DScrollPanel")

	list:SetPos(Sc(18), Sc(196))
	list:SetSize(panel:GetWide() - Sc(36), panel:GetTall() - Sc(214))

	local bar = list:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function(_, width, height)
		surface.SetDrawColor(255, 255, 255, 10)
		surface.DrawRect(0, 0, width, height)
	end
	bar.btnGrip.Paint = function(_, width, height)
		surface.SetDrawColor(R.color.r, R.color.g, R.color.b, 150)
		surface.DrawRect(0, 0, width, height)
	end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end

	local function Cell(parent, x, y, size, item, onClick)
		local button = parent:Add("DButton")

		button:SetText("")
		button:SetPos(x, y)
		button:SetSize(size, size)
		button.DoClick = onClick
		button.Paint = function(this, width, height)
			surface.SetDrawColor(15, 16, 18, 240)
			surface.DrawRect(0, 0, width, height)

			local color = (this:IsHovered() and item) and R.color or theme.line

			surface.SetDrawColor(color.r, color.g, color.b, this:IsHovered() and 220 or 120)
			surface.DrawOutlinedRect(0, 0, width, height, thin)

			if (!item) then
				draw.SimpleText(L("rebelPocketEmpty"), "nwLabel", width * 0.5, height * 0.5,
					theme.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			elseif ((item.amount or 1) > 1) then
				draw.SimpleText("x" .. item.amount, "nwLabelBold", width - Sc(5), height - Sc(4),
					theme.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
			end
		end

		if (item) then
			local icon = button:Add("nwItemIcon")

			icon:SetPos(Sc(6), Sc(6))
			icon:SetSize(size - Sc(12), size - Sc(12))
			icon:SetMouseInputEnabled(false)
			icon:SetItem(item)

			button:SetTooltip(NETWORK.item.GetName(item))
		end

		return button
	end

	function panel:Rebuild()
		cells:Clear()
		list:Clear()

		local state = R.pocketState
		local size = Sc(88)

		for slot = 1, state.slots or 2 do
			local item = state.items[slot]
			local x = (slot - 1) * (size + Sc(12))

			Cell(cells, x, 0, size, item, function()
				if (item) then
					surface.PlaySound("buttons/lightswitch2.wav")
					SendMove(false, slot)
				end
			end)
		end

		if (!state.bAllowed) then
			local label = list:Add("DLabel")

			label:Dock(TOP)
			label:SetTall(Sc(40))
			label:SetFont("nwLabel")
			label:SetTextColor(theme.textDim)
			label:SetWrap(true)
			label:SetText(L("rebelPocketNotRebel"))

			return
		end

		local inventory = NETWORK.inventory.state
		local indices = {}

		for index, item in pairs(inventory and inventory.items or {}) do
			if (istable(item) and R.CanPocket(item)) then
				indices[#indices + 1] = index
			end
		end

		table.sort(indices, function(a, b)
			return (tonumber(a) or 0) < (tonumber(b) or 0)
		end)

		if (#indices == 0) then
			local label = list:Add("DLabel")

			label:Dock(TOP)
			label:SetTall(Sc(32))
			label:SetFont("nwLabel")
			label:SetTextColor(theme.textFaint)
			label:SetText(L("rebelPocketNothing"))

			return
		end

		for _, index in ipairs(indices) do
			local item = inventory.items[index]
			local row = list:Add("DButton")

			row:SetText("")
			row:Dock(TOP)
			row:DockMargin(0, 0, Sc(6), Sc(4))
			row:SetTall(Sc(40))
			row.DoClick = function()
				surface.PlaySound("buttons/lightswitch2.wav")
				SendMove(true, index)
			end
			row.Paint = function(this, width, height)
				surface.SetDrawColor(this:IsHovered() and 24 or 15, this:IsHovered() and 22 or 16,
					this:IsHovered() and 20 or 18, 235)
				surface.DrawRect(0, 0, width, height)

				if (this:IsHovered()) then
					surface.SetDrawColor(R.color.r, R.color.g, R.color.b, 220)
					surface.DrawRect(0, 0, math.max(Sc(2), 2), height)
				end

				local name = NETWORK.item.GetName(item)

				if ((item.amount or 1) > 1) then
					name = name .. "  x" .. item.amount
				end

				draw.SimpleText(name, "nwLabel", Sc(46), height * 0.5, theme.text,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(L("rebelPocketHideShort"), "nwLabel", width - Sc(10),
					height * 0.5, this:IsHovered() and R.color or theme.textFaint,
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end

			local icon = row:Add("nwItemIcon")

			icon:SetPos(Sc(6), Sc(4))
			icon:SetSize(Sc(32), Sc(32))
			icon:SetMouseInputEnabled(false)
			icon:SetItem(item)
		end
	end

	panel:Rebuild()

	return panel
end

net.Receive("nwRebelPocket", function()
	local bOpen = net.ReadBool()
	local bAllowed = net.ReadBool()
	local data = NETWORK.util.ReadTable() or {}
	local items = {}

	for _, entry in ipairs(data.list or {}) do
		local slot = tonumber(entry.slot)

		if (slot and istable(entry.item)) then
			items[slot] = entry.item
		end
	end

	R.pocketState = {
		slots = tonumber(data.slots) or 2,
		items = items,
		bAllowed = bAllowed
	}

	if (bOpen) then
		R.OpenPocketPanel()
	elseif (IsValid(R.pocketPanel)) then
		R.pocketPanel:Rebuild()
	end
end)

hook.Add("NetworkInventoryUpdated", "nwRebelPocket", function()
	if (IsValid(R.pocketPanel)) then
		R.pocketPanel:Rebuild()
	end
end)

local function ItemMenuWrapper(slot, ...)
	local menu = R.baseOpenItemMenu(slot, ...)

	if (!IsValid(menu)) then
		return menu
	end

	local client = LocalPlayer()
	local item = slot.GetItem and slot:GetItem()
	local source = slot.GetSource and slot:GetSource()
	local bRebel = R.Is(client)
	local bAdded = false

	if (bRebel and item and source and source.list == "items" and R.CanPocket(item)) then
		menu:AddOption(L("rebelPocketHide"), function()
			SendMove(true, source.index)
		end, R.color, "down")

		bAdded = true
	end

	local bHasPocket = next(R.pocketState.items or {}) != nil

	if (bRebel or bHasPocket) then
		menu:AddOption(L("rebelPocketOpen"), function()
			R.OpenPocketPanel()
		end, R.color, "up")

		bAdded = true
	end

	if (bAdded) then
		menu:OpenAt(menu:GetPos())
	end

	return menu
end

local function WrapItemMenu()
	if (!NETWORK.gui or !NETWORK.gui.OpenItemMenu or
		NETWORK.gui.OpenItemMenu == ItemMenuWrapper) then
		return
	end

	R.baseOpenItemMenu = NETWORK.gui.OpenItemMenu
	NETWORK.gui.OpenItemMenu = ItemMenuWrapper
end

WrapItemMenu()
hook.Add("InitPostEntity", "nwRebelItemMenu", WrapItemMenu)
hook.Add("NetworkCharacterLoaded", "nwRebelItemMenu", WrapItemMenu)
