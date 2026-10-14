-- Small dark controls in the framework's style for the editors (containers, NPCs): a text field,
-- a number field, a drop-down list, a button, a check box, a scroll list. All take a parent and
-- return the Derma panel.

local U = NW.ui
local W = {}

NW.widgets = W

W.ACCENT = Color(232, 196, 72)
W.MUTED = Color(124, 128, 134)
W.FIELD = Color(22, 25, 29, 245)
W.LINE = Color(255, 255, 255, 18)

local function Fonts()
	local h = ScrH()

	surface.CreateFont("nwWidget", {font = "Exo 2", size = math.max(13, math.Round(h * 0.0165)), weight = 500,
		extended = true, antialias = true})
	surface.CreateFont("nwWidgetBold", {font = "Montserrat SemiBold", size = math.max(13, math.Round(h * 0.0165)),
		weight = 600, extended = true, antialias = true})
	surface.CreateFont("nwWidgetLabel", {font = "Montserrat Medium", size = math.max(10, math.Round(h * 0.0122)),
		weight = 500, extended = true, antialias = true})
	surface.CreateFont("nwWidgetTitle", {font = "Montserrat SemiBold", size = math.max(16, math.Round(h * 0.024)),
		weight = 600, extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwWidgetFonts", Fonts)

local function PaintField(self, w, h)
	local focus = self:HasFocus()

	draw.RoundedBox(4, 0, 0, w, h, W.FIELD)
	surface.SetDrawColor(focus and W.ACCENT or W.LINE)
	surface.DrawRect(0, h - 2, w, 2)

	if (self:GetValue() == "" and self.placeholder and !focus) then
		draw.SimpleText(self.placeholder, "nwWidget", 8, h / 2, W.MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	self:DrawTextEntryText(U.color.text, Color(232, 196, 72, 120), W.ACCENT)
end

-- a text field (multiline: a bigger box)
function W.Entry(parent, value, placeholder, multiline)
	local entry = parent:Add("DTextEntry")

	entry:SetFont("nwWidget")
	entry:SetText(value or "")
	entry:SetMultiline(multiline == true)
	entry:SetUpdateOnType(true)
	entry:SetTextInset(8, 0)
	entry.placeholder = placeholder
	entry.Paint = PaintField

	return entry
end

-- a whole number between min and max
function W.Number(parent, value, min, max)
	local entry = W.Entry(parent, tostring(value or 0))

	entry:SetNumeric(true)
	entry.GetNumber = function(self)
		return math.Clamp(math.floor(tonumber(self:GetValue()) or 0), min or 0, max or 1000000)
	end

	return entry
end

-- choices: a list of {value, label}
function W.Combo(parent, choices, selected)
	local combo = parent:Add("DComboBox")

	combo:SetFont("nwWidget")
	combo:SetTextColor(U.color.text)
	combo:SetSortItems(false)

	for _, choice in ipairs(choices) do
		combo:AddChoice(choice[2], choice[1], choice[1] == selected)
	end

	combo.Paint = function(self, w, h)
		draw.RoundedBox(4, 0, 0, w, h, W.FIELD)
		surface.SetDrawColor(self:IsMenuOpen() and W.ACCENT or W.LINE)
		surface.DrawRect(0, h - 2, w, 2)
	end

	combo.GetSelectedValue = function(self)
		local _, data = self:GetSelected()

		return data
	end

	-- the drop-down list in the same colours
	local open = combo.OpenMenu

	combo.OpenMenu = function(self, ...)
		open(self, ...)

		if (IsValid(self.Menu)) then
			self.Menu.Paint = function(_, w, h)
				draw.RoundedBox(4, 0, 0, w, h, Color(16, 18, 21, 250))
			end

			for _, option in ipairs(self.Menu:GetCanvas():GetChildren()) do
				option:SetFont("nwWidget")
				option:SetTextColor(U.color.text)
				option.Paint = function(panel, w, h)
					if (panel:IsHovered()) then
						draw.RoundedBox(3, 2, 0, w - 4, h, Color(46, 50, 56))
					end
				end
			end
		end
	end

	return combo
end

-- a button; accent = the main one (gold)
function W.Button(parent, label, onClick, accent, icon)
	local button = parent:Add("DButton")

	button:SetText("")
	button.label = label
	button.DoClick = function(self)
		surface.PlaySound("network2/ui/click.wav")
		onClick(self)
	end
	button.OnCursorEntered = function()
		surface.PlaySound("network2/ui/hover.wav")
	end
	button.Paint = function(self, w, h)
		local hover = self:IsHovered() and self:IsEnabled()
		local fill = accent and (hover and Color(246, 210, 90) or W.ACCENT) or
			(hover and Color(52, 56, 62) or Color(30, 33, 37))

		if (!self:IsEnabled()) then
			fill = Color(26, 28, 31)
		end

		draw.RoundedBox(4, 0, 0, w, h, fill)

		local color = accent and Color(20, 20, 22) or (self:IsEnabled() and U.color.text or W.MUTED)
		local text = self.label
		local x = w / 2

		if (icon) then
			surface.SetFont("nwWidgetBold")

			local tw = surface.GetTextSize(text)
			local is = math.Round(h * 0.5)

			x = (w - tw - is - 6) / 2
			U.DrawIcon(icon, x, (h - is) / 2, is, color)
			draw.SimpleText(text, "nwWidgetBold", x + is + 6, h / 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			return
		end

		draw.SimpleText(text, "nwWidgetBold", x, h / 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return button
end

function W.Check(parent, label, value)
	local box = parent:Add("DButton")

	box:SetText("")
	box.value = value == true
	box.DoClick = function(self)
		self.value = !self.value
		surface.PlaySound("network2/ui/click.wav")
	end
	box.Paint = function(self, w, h)
		local s = h - 6

		draw.RoundedBox(3, 0, 3, s, s, W.FIELD)

		if (self.value) then
			draw.RoundedBox(2, 4, 7, s - 8, s - 8, W.ACCENT)
		end

		draw.SimpleText(label, "nwWidget", s + 8, h / 2, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	return box
end

-- a label over a field
function W.Label(parent, text, x, y)
	local label = parent:Add("DLabel")

	label:SetFont("nwWidgetLabel")
	label:SetTextColor(W.MUTED)
	label:SetText(U.Upper(text))
	label:SizeToContents()
	label:SetPos(x, y)

	return label
end

-- a scroll panel with a thin bar
function W.Scroll(parent)
	local scroll = parent:Add("DScrollPanel")
	local bar = scroll:GetVBar()

	bar:SetWide(6)
	bar:SetHideButtons(true)
	bar.Paint = function(_, w, h)
		draw.RoundedBox(3, 0, 0, w, h, Color(255, 255, 255, 8))
	end
	bar.btnGrip.Paint = function(_, w, h)
		draw.RoundedBox(3, 0, 0, w, h, Color(255, 255, 255, 40))
	end

	return scroll
end

-- the item choices for the editors: {id, "Название (id)"}, sorted by name
function W.ItemChoices(withNone)
	local out = {}

	for id, item in pairs(NW.items.list) do
		out[#out + 1] = {id, item.name .. "  (" .. id .. ")"}
	end

	table.sort(out, function(a, b)
		return a[2] < b[2]
	end)

	if (withNone) then
		table.insert(out, 1, {"", "— нет —"})
	end

	return out
end

-- a dark full-screen window with a box in the middle; returns frame, box
function W.Window(title, w, h, onClose)
	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame.appear = 0

	local box = frame:Add("EditablePanel")

	box:SetSize(w, h)
	box:SetPos((sw - w) / 2, (sh - h) / 2)
	box.Paint = function(_, bw, bh)
		draw.RoundedBox(8, 0, 0, bw, bh, Color(14, 16, 19, 248))
		draw.RoundedBoxEx(8, 0, 0, bw, math.Round(sh * 0.055), Color(22, 25, 29, 255), true, true, false, false)
		surface.SetDrawColor(W.ACCENT)
		surface.DrawRect(0, math.Round(sh * 0.055), bw, 2)
		draw.SimpleText(title, "nwWidgetTitle", math.Round(sh * 0.02), math.Round(sh * 0.0275), U.color.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local close = W.Button(box, "✕", function()
		frame:Remove()

		if (onClose) then
			onClose()
		end
	end)

	close:SetSize(math.Round(sh * 0.04), math.Round(sh * 0.04))
	close:SetPos(w - math.Round(sh * 0.0475), math.Round(sh * 0.0075))

	frame.Paint = function(self, pw, ph)
		self.appear = math.Approach(self.appear, 1, FrameTime() * 6)
		surface.SetDrawColor(0, 0, 0, 170 * self.appear)
		surface.DrawRect(0, 0, pw, ph)
	end

	box.top = math.Round(sh * 0.07)

	return frame, box
end
