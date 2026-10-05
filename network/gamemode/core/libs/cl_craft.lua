NETWORK.craft = NETWORK.craft or {}
NETWORK.gui = NETWORK.gui or {}

local CATEGORY_ORDER = {"weapon", "ammo", "armour", "clothing", "medical", "food",
	"rations", "junk", "factory", "module", "container", "documents", "misc"}

local CATEGORY_RANK = {}

for index, id in ipairs(CATEGORY_ORDER) do
	CATEGORY_RANK[id] = index
end

function NETWORK.craft.GetCategory(id)
	local base = NETWORK.item.Get(id)

	return base and base.category or "misc"
end

function NETWORK.craft.CategoryName(id)
	local key = "craftCat" .. string.upper(string.sub(id, 1, 1)) .. string.sub(id, 2)
	local text = L(key)

	return text != key and text or id
end

local function SortCategories(set)
	local list = {}

	for id in pairs(set) do
		list[#list + 1] = id
	end

	table.sort(list, function(a, b)
		local rankA, rankB = CATEGORY_RANK[a] or 99, CATEGORY_RANK[b] or 99

		if (rankA != rankB) then
			return rankA < rankB
		end

		return a < b
	end)

	return list
end

local function ItemName(id)
	local base = NETWORK.item.Get(id)

	return base and base.name or id
end

local function TooltipItem(id, amount)
	return {id = id, uniqueID = id, amount = amount or 1, data = {}}
end

local STYLE = {}

local function Rect(x, y, width, height, color, alpha)
	surface.SetDrawColor(color.r, color.g, color.b, alpha or color.a or 255)
	surface.DrawRect(x, y, width, height)
end

local function Outline(x, y, width, height, color, alpha)
	surface.SetDrawColor(color.r, color.g, color.b, alpha or color.a or 255)
	surface.DrawOutlinedRect(x, y, width, height, 1)
end

local WHITE = Color(255, 255, 255)

function STYLE.Frame(panel, x, y, width, height, alpha, title, subtitle)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	NETWORK.util.DrawBlurRect(panel, x, y, width, height, 4 * alpha)

	Rect(x, y, width, height, Color(7, 8, 10), 238 * alpha)
	Outline(x, y, width, height, WHITE, 26 * alpha)
	Rect(x + 1, y + Sc(56), width - 2, 1, WHITE, 16 * alpha)

	Rect(x + Sc(18), y + Sc(14), math.max(Sc(3), 2), Sc(30), theme.combine, 240 * alpha)

	if (subtitle and subtitle != "") then
		draw.SimpleText(NETWORK.util.Upper(subtitle), "nwInvKey", x + Sc(30), y + Sc(20),
			ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(title, "nwInvTitle", x + Sc(30), y + Sc(37),
			ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText(title, "nwInvTitle", x + Sc(30), y + Sc(29),
			ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function STYLE.PaintButton(panel, width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local bOff = panel:IsOff()
	local bOn = panel.IsActiveFn and panel.IsActiveFn() or false
	local bDanger = panel.DangerFn and panel.DangerFn() or panel.danger
	local hover = panel.hover or 0
	local accent = bDanger and theme.danger or theme.combine
	local label = panel.label

	if (isfunction(label)) then
		label = label()
	end

	if (bOff) then
		Rect(0, 0, width, height, WHITE, 4)
		Outline(0, 0, width, height, WHITE, 14)
	elseif (panel.primary or bOn or bDanger) then
		Rect(0, 0, width, height, accent, 30 + 40 * hover)
		Outline(0, 0, width, height, accent, 150 + 90 * hover)
	else
		Rect(0, 0, width, height, WHITE, 6 + 12 * hover)
		Outline(0, 0, width, height, WHITE, 26 + 50 * hover)
	end

	local color = theme.text

	if (bOff) then
		color = theme.textFaint
	elseif (!panel.primary and !bOn and !bDanger) then
		color = Color(Lerp(hover, theme.textDim.r, theme.text.r),
			Lerp(hover, theme.textDim.g, theme.text.g),
			Lerp(hover, theme.textDim.b, theme.text.b))
	end

	local centerX, centerY = math.Round(width * 0.5), math.Round(height * 0.5)

	if (panel.arrow) then
		local size = math.max(Sc(5), 3)

		draw.NoTexture()
		surface.SetDrawColor(color.r, color.g, color.b, 240)

		if (panel.arrow == "up") then
			surface.DrawPoly({
				{x = centerX, y = centerY - size},
				{x = centerX + size, y = centerY + math.Round(size * 0.6)},
				{x = centerX - size, y = centerY + math.Round(size * 0.6)}
			})
		else
			surface.DrawPoly({
				{x = centerX - size, y = centerY - math.Round(size * 0.6)},
				{x = centerX + size, y = centerY - math.Round(size * 0.6)},
				{x = centerX, y = centerY + size}
			})
		end

		return
	end

	if (panel.cross) then
		local inset = math.Round(math.min(width, height) * 0.32)

		NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
			math.max(Sc(2), 2), color)
		NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
			math.max(Sc(2), 2), color)

		return
	end

	draw.SimpleText(panel.bKeepCase and label or NETWORK.util.Upper(label or ""),
		panel.font or "nwInvButton", centerX, centerY, color, TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

function STYLE.Button(parent, label, onPress)
	local button = parent:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.label = label
	button.hover = 0
	button.OnPress = onPress
	button.IsOff = function(panel)
		return panel.IsDisabledFn and panel.IsDisabledFn() or false
	end
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover,
			(panel:IsHovered() and !panel:IsOff()) and 1 or 0, 14)
	end
	button.DoClick = function(panel)
		if (panel:IsOff()) then
			surface.PlaySound("buttons/button10.wav")

			return
		end

		NETWORK.sound.Click()

		if (panel.OnPress) then
			panel.OnPress(panel)
		end
	end
	button.Paint = STYLE.PaintButton

	return button
end

function STYLE.Close(parent, onPress)
	local button = STYLE.Button(parent, "", onPress)

	button.cross = true

	return button
end

function STYLE.Entry(parent, placeholder, font)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local entry = parent:Add("DTextEntry")

	entry:SetFont(font or "nwInvBody")
	entry:SetDrawLanguageID(false)
	entry:SetPaintBackground(false)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(theme.combine)
	entry:SetHighlightColor(theme.combineDeep)
	entry:SetUpdateOnType(true)
	entry:SetTextInset(Sc(8), 0)
	entry.placeholder = placeholder
	entry.fontName = font or "nwInvBody"
	entry.Paint = function(panel, width, height)
		local bFocus = panel:HasFocus()

		Rect(0, 0, width, height, Color(10, 11, 13), 240)

		if (panel.bError) then
			Outline(0, 0, width, height, theme.danger, 200)
		elseif (bFocus) then
			Outline(0, 0, width, height, theme.combine, 210)
		else
			Outline(0, 0, width, height, WHITE, 28)
		end

		panel:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)

		if (panel.placeholder and panel:GetValue() == "" and !bFocus) then
			draw.SimpleText(panel.placeholder, panel.fontName, Sc(10),
				math.Round(height * 0.5), theme.textFaint, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end
	end

	return entry
end

function STYLE.Scroll(parent)
	local Sc = NETWORK.util.Scale
	local scroll = parent:Add("DScrollPanel")
	local bar = scroll:GetVBar()

	bar:SetWide(math.max(Sc(5), 3))
	bar:SetHideButtons(true)
	bar.Paint = function(_, width, height)
		Rect(0, 0, width, height, WHITE, 6)
	end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		Rect(0, 0, width, height, WHITE, panel:IsHovered() and 110 or 60)
	end

	return scroll
end

function STYLE.Stepper(parent, options)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local panel = parent:Add("DPanel")
	local step = options.step or 1

	local function Clamp(value)
		value = math.Clamp(tonumber(value) or options.min, options.min, options.max)

		if (options.decimals) then
			return math.Round(value * 10) / 10
		end

		return math.floor(value + 0.5)
	end

	local function Text(value)
		if (value == 0 and options.zeroText) then
			return ""
		end

		return tostring(value)
	end

	local entry

	local function Set(value)
		options.set(Clamp(value))

		if (IsValid(entry)) then
			entry:SetText(Text(options.get()))
		end
	end

	panel.Paint = function(_, width, height)
		Rect(0, 0, width, height, Color(10, 11, 13), 240)
		Outline(0, 0, width, height, WHITE, 26)
	end

	local minus = STYLE.Button(panel, "-", function()
		Set(options.get() - step * (input.IsShiftDown() and 10 or 1))
	end)
	local plus = STYLE.Button(panel, "+", function()
		Set(options.get() + step * (input.IsShiftDown() and 10 or 1))
	end)

	minus.font = "nwInvName"
	plus.font = "nwInvName"
	minus.IsDisabledFn = function()
		return options.get() <= options.min
	end
	plus.IsDisabledFn = function()
		return options.get() >= options.max
	end

	entry = panel:Add("DTextEntry")
	entry:SetFont("nwInvName")
	entry:SetNumeric(true)
	entry:SetDrawLanguageID(false)
	entry:SetPaintBackground(false)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(theme.combine)
	entry:SetText(Text(options.get()))
	entry.Paint = function(this, width, height)
		if (this:HasFocus()) then
			this:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)

			return
		end

		local value = options.get()

		draw.SimpleText(value == 0 and options.zeroText or tostring(value),
			value == 0 and options.zeroText and "nwInvKey" or "nwInvName",
			math.Round(width * 0.5), math.Round(height * 0.5),
			value == 0 and options.zeroText and theme.textFaint or theme.text,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	entry.OnGetFocus = function(this)
		this:SetText(Text(options.get()))
	end
	entry.OnEnter = function(this)
		Set(this:GetValue() != "" and this:GetValue() or options.min)
	end
	entry.OnLoseFocus = function(this)
		Set(this:GetValue() != "" and this:GetValue() or options.min)
	end

	panel.OnMouseWheeled = function(_, delta)
		Set(options.get() + (delta > 0 and step or -step) * (input.IsShiftDown() and 10 or 1))

		return true
	end
	entry.OnMouseWheeled = panel.OnMouseWheeled

	panel.PerformLayout = function(_, width, height)
		minus:SetPos(0, 0)
		minus:SetSize(height, height)
		plus:SetPos(width - height, 0)
		plus:SetSize(height, height)
		entry:SetPos(height, 0)
		entry:SetSize(width - height * 2, height)
	end

	return panel
end

local function ConsumeEscape(panel)
	if (!gui.IsGameUIVisible()) then
		return false
	end

	if ((NETWORK.craft.escapeAt or 0) > RealTime() - 0.25) then
		gui.HideGameUI()

		return false
	end

	for _, other in ipairs({NETWORK.gui.craftPicker, NETWORK.gui.craftEditor,
		NETWORK.gui.craft}) do
		if (other == panel) then
			break
		end

		if (IsValid(other)) then
			return false
		end
	end

	gui.HideGameUI()

	NETWORK.craft.escapeAt = RealTime()

	return true
end

local PICKER = {}

function PICKER:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.craftPicker = self

	self.alpha = 0
	self.text = ""
	self.category = "all"
	self.marked = {}
	self.flash = {}
	self.results = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.frameW = math.min(Sc(800), ScrW() - Sc(60))
	self.frameH = math.min(Sc(660), ScrH() - Sc(40))
	self.frameX = math.floor((ScrW() - self.frameW) * 0.5)
	self.frameY = math.floor((ScrH() - self.frameH) * 0.5)
end

function PICKER:OnRemove()
	if (NETWORK.gui.craftPicker == self) then
		NETWORK.gui.craftPicker = nil
	end
end

function PICKER:Setup(options)
	local Sc = NETWORK.util.Scale
	local x, y, width, height = self.frameX, self.frameY, self.frameW, self.frameH

	self.options = options or {}
	self.marked = table.Copy(self.options.marked or {})

	local close = STYLE.Close(self, function()
		self:Remove()
	end)

	close:SetPos(x + width - Sc(46), y + Sc(12))
	close:SetSize(Sc(32), Sc(32))

	self.search = STYLE.Entry(self, L("craftSearchItems"))
	self.search:SetPos(x + Sc(18), y + Sc(68))
	self.search:SetSize(width - Sc(36), Sc(32))
	self.search.OnValueChange = function(_, value)
		self.text = NETWORK.util.Lower(string.Trim(value or ""))
		self.rebuildAt = RealTime() + 0.08
	end

	self.search.OnEnter = function()
		if (#self.results == 1) then
			self:Pick(self.results[1], false)
		end
	end

	local present = {}

	for _, base in ipairs(NETWORK.item.GetAll()) do
		present[base.category or "misc"] = true
	end

	local chips = {"all"}

	for _, id in ipairs(SortCategories(present)) do
		chips[#chips + 1] = id
	end

	local cursorX, cursorY = x + Sc(18), y + Sc(110)
	local chipHeight = Sc(24)

	for _, id in ipairs(chips) do
		local label = id == "all" and L("craftCatAll") or NETWORK.craft.CategoryName(id)

		surface.SetFont("nwInvKey")

		local chipWidth = surface.GetTextSize(NETWORK.util.Upper(label)) + Sc(20)

		if (cursorX + chipWidth > x + width - Sc(18)) then
			cursorX = x + Sc(18)
			cursorY = cursorY + chipHeight + Sc(6)
		end

		local chip = STYLE.Button(self, label, function()
			self.category = id
			self.rebuildAt = RealTime()
		end)

		chip.font = "nwInvKey"
		chip.IsActiveFn = function()
			return self.category == id
		end
		chip:SetPos(cursorX, cursorY)
		chip:SetSize(chipWidth, chipHeight)

		cursorX = cursorX + chipWidth + Sc(6)
	end

	local top = cursorY + chipHeight + Sc(10)

	self.scroll = STYLE.Scroll(self)
	self.scroll:SetPos(x + Sc(18), top)
	self.scroll:SetSize(width - Sc(36), y + height - Sc(40) - top)

	self.grid = self.scroll:Add("DIconLayout")
	self.grid:Dock(TOP)
	self.grid:SetSpaceX(Sc(6))
	self.grid:SetSpaceY(Sc(6))

	self:RebuildGrid()

	self.search:RequestFocus()
end

function PICKER:RebuildGrid()
	local Sc = NETWORK.util.Scale

	self.rebuildAt = nil
	self.grid:Clear()
	self.results = {}

	local list = {}

	for _, base in ipairs(NETWORK.item.GetAll()) do
		local category = base.category or "misc"

		if (self.category != "all" and category != self.category) then
			continue
		end

		if (self.text != "" and !string.find(base.id, self.text, 1, true) and
			!string.find(NETWORK.util.Lower(base.name or ""), self.text, 1, true)) then
			continue
		end

		list[#list + 1] = {
			base = base,
			rank = CATEGORY_RANK[category] or 99,
			name = NETWORK.util.Lower(base.name or base.id)
		}
	end

	table.sort(list, function(a, b)
		if (a.rank != b.rank) then
			return a.rank < b.rank
		end

		return a.name < b.name
	end)

	local gap = Sc(6)
	local available = self.scroll:GetWide() - Sc(10)
	local columns = math.max(math.floor((available + gap) / (Sc(98) + gap)), 3)
	local size = math.floor((available - gap * (columns - 1)) / columns)

	for _, entry in ipairs(list) do
		self.results[#self.results + 1] = entry.base.id
		self:AddCell(entry.base, size, size + Sc(34))
	end

	self.scroll:GetVBar():SetScroll(0)
end

function PICKER:AddCell(base, size, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local id = base.id
	local cell = self.grid:Add("DButton")
	local padding = Sc(8)

	cell:SetSize(size, height)
	cell:SetText("")
	cell:SetCursor("hand")
	cell.hover = 0

	local icon = cell:Add("nwItemIcon")

	icon:SetMouseInputEnabled(false)
	icon:SetPos(padding, padding)
	icon:SetSize(size - padding * 2, size - padding * 2)
	icon:SetItem({id = id, amount = 1})

	cell.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 14)

		local scroll = self.scroll:GetVBar():GetScroll()
		local _, cellY = panel:GetPos()
		local bVisible = cellY + height >= scroll - height and
			cellY <= scroll + self.scroll:GetTall() + height

		if (icon:IsVisible() != bVisible) then
			icon:SetVisible(bVisible)
		end
	end
	cell.OnCursorEntered = function(panel)
		NETWORK.gui.SetItemTooltip(panel, TooltipItem(id))
	end
	cell.OnCursorExited = function(panel)
		NETWORK.gui.ClearTooltip(panel)
	end
	cell.DoClick = function()
		self:Pick(id, input.IsShiftDown())
	end
	cell.Paint = function(panel, width, cellHeight)
		local marked = self.marked[id]
		local bCurrent = self.options.current == id
		local flash = math.Clamp(1 - (RealTime() - (self.flash[id] or 0)) / 0.4, 0, 1)

		Rect(0, 0, width, cellHeight, Color(14, 15, 17), 235)
		Rect(0, 0, width, cellHeight, WHITE, 8 * panel.hover)

		if (flash > 0) then
			Rect(0, 0, width, cellHeight, theme.combine, 70 * flash)
		end

		if (marked or bCurrent) then
			Outline(0, 0, width, cellHeight, theme.combine, 230)
		else
			Outline(0, 0, width, cellHeight, WHITE, 20 + 60 * panel.hover)
		end

		draw.SimpleText(NETWORK.util.TruncateWidth(base.name or id, "nwInvBody",
			width - Sc(8)), "nwInvBody", math.Round(width * 0.5), size + Sc(4),
			theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(NETWORK.util.TruncateWidth(id, "nwInvKey", width - Sc(8)),
			"nwInvKey", math.Round(width * 0.5), size + Sc(20), theme.textFaint,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (marked) then
			local text = "×" .. marked

			surface.SetFont("nwInvKey")

			local badge = surface.GetTextSize(text) + Sc(10)

			Rect(width - badge - Sc(3), Sc(3), badge, Sc(16), theme.combine, 220)
			draw.SimpleText(text, "nwInvKey", width - Sc(3) - math.Round(badge * 0.5),
				Sc(11), theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

function PICKER:Pick(id, bKeep)
	if (self.options.callback) then
		self.options.callback(id)
	end

	if (self.options.bMulti and bKeep) then
		self.marked[id] = (self.marked[id] or 0) + 1
		self.flash[id] = RealTime()

		return
	end

	self:Remove()
end

function PICKER:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)

	if (self.rebuildAt and RealTime() >= self.rebuildAt) then
		self:RebuildGrid()
	end

	if (ConsumeEscape(self)) then
		self:Remove()
	end
end

function PICKER:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PICKER:OnMousePressed()

	local x, y = self:CursorPos()

	if (x < self.frameX or y < self.frameY or x > self.frameX + self.frameW or
		y > self.frameY + self.frameH) then
		self:Remove()
	end
end

function PICKER:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local x, y, frameW, frameH = self.frameX, self.frameY, self.frameW, self.frameH

	Rect(0, 0, width, height, Color(0, 0, 0), 120 * self.alpha)

	STYLE.Frame(self, x, y, frameW, frameH, self.alpha,
		self.options and self.options.title or L("craftPickResult"), L("craftPicker"))

	draw.SimpleText(self.options and self.options.bMulti and L("craftPickerHintMulti") or
		L("craftPickerHint"), "nwInvKey", x + Sc(18), y + frameH - Sc(20),
		theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(L("craftPickerCount", #self.results), "nwInvKey",
		x + frameW - Sc(18), y + frameH - Sc(20), theme.textFaint, TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)
end

vgui.Register("nwCraftPicker", PICKER, "EditablePanel")

function NETWORK.gui.OpenCraftPicker(options)
	if (IsValid(NETWORK.gui.craftPicker)) then
		NETWORK.gui.craftPicker:Remove()
	end

	local panel = vgui.Create("nwCraftPicker")

	panel:Setup(options)

	return panel
end

local function Problems(recipe)
	local problems = {cost = {}, tools = {}}

	if (!recipe.result) then
		problems.result = "none"
	elseif (!NETWORK.item.Get(recipe.result.id)) then
		problems.result = "unknown"
	end

	if (#recipe.cost == 0) then
		problems.noCost = true
	end

	for _, key in ipairs({"cost", "tools"}) do
		for index, entry in ipairs(recipe[key]) do
			if (!NETWORK.item.Get(entry.id)) then
				problems[key][index] = true
				problems.bad = true
			end
		end
	end

	problems.any = problems.result != nil or problems.noCost or problems.bad or false

	return problems
end

local function Export(recipe)
	if (!recipe.result) then
		return
	end

	return {
		result = {id = recipe.result.id, amount = recipe.result.amount},
		cost = table.Copy(recipe.cost),
		tools = table.Copy(recipe.tools),
		time = recipe.time,
		skill = recipe.skill,
		xp = recipe.xp
	}
end

local function CopyEntries(list)
	local copy = {}

	for _, entry in ipairs(list or {}) do
		copy[#copy + 1] = {id = entry.id, amount = entry.amount}
	end

	return copy
end

local function CopyRecipe(recipe)
	return {
		result = recipe.result and {id = recipe.result.id, amount = recipe.result.amount} or nil,
		cost = CopyEntries(recipe.cost),
		tools = CopyEntries(recipe.tools),
		time = recipe.time,
		skill = recipe.skill,
		xp = recipe.xp
	}
end

local EDITOR = {}

function EDITOR:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.craftEditor = self

	self.alpha = 0
	self.recipes = {}
	self.selected = nil
	self.dirty = false

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.frameW = math.min(Sc(1120), ScrW() - Sc(40))
	self.frameH = math.min(Sc(720), ScrH() - Sc(40))
	self.frameX = math.floor((ScrW() - self.frameW) * 0.5)
	self.frameY = math.floor((ScrH() - self.frameH) * 0.5)
end

function EDITOR:OnRemove()
	if (NETWORK.gui.craftEditor == self) then
		NETWORK.gui.craftEditor = nil
	end

	if (IsValid(NETWORK.gui.craftPicker)) then
		NETWORK.gui.craftPicker:Remove()
	end
end

function EDITOR:Setup(entity, data)
	local Sc = NETWORK.util.Scale
	local x, y, width, height = self.frameX, self.frameY, self.frameW, self.frameH

	self.entity = entity
	self.textLimit = data.textLimit

	for _, recipe in ipairs(data.recipes or {}) do
		self.recipes[#self.recipes + 1] = CopyRecipe(recipe)
	end

	self.selected = #self.recipes > 0 and 1 or nil

	local close = STYLE.Close(self, function()
		self:Close()
	end)

	close:SetPos(x + width - Sc(46), y + Sc(12))
	close:SetSize(Sc(32), Sc(32))

	local inner = width - Sc(36)

	self.nameEntry = STYLE.Entry(self, L("craftFieldName"))
	self.nameEntry:SetPos(x + Sc(18), y + Sc(86))
	self.nameEntry:SetSize(math.floor(inner * 0.36), Sc(30))
	self.nameEntry:SetValue(data.name or "")
	self.nameEntry.OnValueChange = function()
		self.dirty = true
	end

	self.modelEntry = STYLE.Entry(self, L("craftFieldModel"))
	self.modelEntry:SetPos(x + Sc(18) + math.floor(inner * 0.36) + Sc(12), y + Sc(86))
	self.modelEntry:SetSize(inner - math.floor(inner * 0.36) - Sc(12), Sc(30))
	self.modelEntry:SetValue(data.model or "")
	self.modelEntry.OnValueChange = function(panel, value)
		self.dirty = true

		value = string.Trim(value or "")
		panel.bError = value != "" and !util.IsValidModel(value)
	end
	self.modelEntry:OnValueChange(data.model or "")
	self.dirty = false

	local bodyY = y + Sc(136)
	local footerH = Sc(56)
	local bodyH = y + height - footerH - bodyY
	local leftW = math.floor(inner * 0.36)
	local rowH = Sc(30)
	local gap = Sc(6)

	self.leftX, self.leftW = x + Sc(18), leftW
	self.bodyY = bodyY

	self.list = STYLE.Scroll(self)
	self.list:SetPos(x + Sc(18), bodyY + Sc(24))
	self.list:SetSize(leftW, bodyH - Sc(24) - rowH * 2 - gap * 2 - Sc(4))

	local buttonsY = bodyY + bodyH - rowH * 2 - gap
	local unit = math.floor((leftW - gap * 4) / 8)
	local left = x + Sc(18)
	local deleteW = leftW - unit * 6 - gap * 4

	local add = STYLE.Button(self, "+ " .. L("craftNew"), function()
		self:AddRecipe()
	end)

	add.primary = true
	add.IsDisabledFn = function()
		return #self.recipes >= NETWORK.craft.maxRecipes
	end
	add:SetPos(left, buttonsY)
	add:SetSize(unit * 2, rowH)

	local duplicate = STYLE.Button(self, L("craftDuplicate"), function()
		self:DuplicateRecipe()
	end)

	duplicate.IsDisabledFn = function()
		return !self.recipes[self.selected or 0] or #self.recipes >= NETWORK.craft.maxRecipes
	end
	duplicate:SetPos(left + unit * 2 + gap, buttonsY)
	duplicate:SetSize(unit * 2, rowH)

	local delete = STYLE.Button(self, L("craftDelete"), function()
		self:DeleteRecipe()
	end)

	delete.danger = true
	delete.IsDisabledFn = function()
		return !self.recipes[self.selected or 0]
	end
	delete:SetPos(left + unit * 4 + gap * 2, buttonsY)
	delete:SetSize(deleteW, rowH)

	local up = STYLE.Button(self, "", function()
		self:MoveRecipe(-1)
	end)

	up.arrow = "up"
	up.IsDisabledFn = function()
		return (self.selected or 1) <= 1
	end
	up:SetPos(left + unit * 4 + gap * 3 + deleteW, buttonsY)
	up:SetSize(unit, rowH)

	local down = STYLE.Button(self, "", function()
		self:MoveRecipe(1)
	end)

	down.arrow = "down"
	down.IsDisabledFn = function()
		return !self.selected or self.selected >= #self.recipes
	end
	down:SetPos(left + leftW - unit, buttonsY)
	down:SetSize(unit, rowH)

	local copyAll = STYLE.Button(self, L("craftCopyAll"), function()
		self:CopyAll()
	end)

	copyAll.IsDisabledFn = function()
		return #self.recipes == 0
	end
	copyAll:SetPos(x + Sc(18), buttonsY + rowH + gap)
	copyAll:SetSize(math.floor((leftW - gap) * 0.5), rowH)

	local paste = STYLE.Button(self, L("craftPasteLine"), function()
		self:PasteLine()
	end)

	paste.IsDisabledFn = function()
		return #self.recipes >= NETWORK.craft.maxRecipes
	end
	paste:SetPos(x + Sc(18) + copyAll:GetWide() + gap, buttonsY + rowH + gap)
	paste:SetSize(leftW - copyAll:GetWide() - gap, rowH)

	self.formX = x + Sc(18) + leftW + Sc(16)
	self.formW = x + width - Sc(18) - self.formX

	self.form = STYLE.Scroll(self)
	self.form:SetPos(self.formX, bodyY)
	self.form:SetSize(self.formW, bodyH)

	local save = STYLE.Button(self, L("craftSave"), function()
		self:Save()
	end)

	save.primary = true
	save:SetSize(Sc(170), Sc(34))
	save:SetPos(x + width - Sc(18) - Sc(170), y + height - Sc(46))

	local cancel = STYLE.Button(self, L("craftCancel"), function()
		self:Close()
	end)

	cancel:SetSize(Sc(130), Sc(34))
	cancel:SetPos(save:GetPos() - Sc(130) - Sc(8), y + height - Sc(46))

	self:RebuildList()
	self:BuildForm()
end

function EDITOR:MarkDirty()
	self.dirty = true
	self.storageCache = nil
end

function EDITOR:RebuildList()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	self.list:Clear()

	for index, recipe in ipairs(self.recipes) do
		local row = self.list:Add("DButton")
		local iconSize = Sc(38)
		local textX = Sc(10) + iconSize + Sc(10)

		row:Dock(TOP)
		row:DockMargin(0, 0, Sc(8), Sc(4))
		row:SetTall(Sc(52))
		row:SetText("")
		row:SetCursor("hand")
		row.hover = 0
		row.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 14)
		end
		row.DoClick = function()
			NETWORK.sound.Click()

			self:Select(index)
		end

		if (recipe.result) then
			local icon = row:Add("nwItemIcon")

			icon:SetMouseInputEnabled(false)
			icon:SetPos(Sc(10), Sc(7))
			icon:SetSize(iconSize, iconSize)
			icon:SetItem({id = recipe.result.id, amount = recipe.result.amount})
		end

		row.Paint = function(panel, width, height)
			local bSelected = self.selected == index
			local problems = Problems(recipe)

			if (bSelected) then
				Rect(0, 0, width, height, theme.combine, 30)
				Outline(0, 0, width, height, theme.combine, 190)
			else
				Rect(0, 0, width, height, WHITE, 4 + 8 * panel.hover)
				Outline(0, 0, width, height, WHITE, 16 + 30 * panel.hover)
			end

			if (problems.any) then
				Rect(0, 0, math.max(Sc(3), 2), height, theme.danger, 240)
			end

			if (!recipe.result) then
				Outline(Sc(10), Sc(7), iconSize, iconSize, theme.danger, 160)
			end

			local name = recipe.result and ItemName(recipe.result.id) or L("craftNoResult")

			if (recipe.result and recipe.result.amount > 1) then
				name = name .. " ×" .. recipe.result.amount
			end

			draw.SimpleText(NETWORK.util.TruncateWidth(name, "nwInvName",
				width - textX - Sc(34)), "nwInvName", textX, Sc(17),
				problems.result and theme.danger or theme.text, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText("#" .. index, "nwInvKey", width - Sc(8), Sc(17),
				theme.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			local summary

			if (#recipe.cost == 0) then
				summary = L("craftNoCost")
			else
				local parts = {}

				for _, entry in ipairs(recipe.cost) do
					parts[#parts + 1] = ItemName(entry.id) .. (entry.amount > 1 and
						(" ×" .. entry.amount) or "")
				end

				summary = table.concat(parts, ", ")
			end

			draw.SimpleText(NETWORK.util.TruncateWidth(summary, "nwInvKey",
				width - textX - Sc(10)), "nwInvKey", textX, Sc(36),
				(problems.noCost or problems.bad) and theme.danger or theme.textDim,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
end

function EDITOR:Select(index)
	self.selected = self.recipes[index] and index or nil

	self:BuildForm()
end

function EDITOR:AddRecipe()
	if (#self.recipes >= NETWORK.craft.maxRecipes) then
		return
	end

	local recipe = {cost = {}, tools = {}}
	local index = (self.selected or #self.recipes) + 1

	table.insert(self.recipes, index, recipe)

	self.selected = index

	self:MarkDirty()
	self:RebuildList()
	self:BuildForm()
	self:PickResult(recipe)
end

function EDITOR:DuplicateRecipe()
	local recipe = self.recipes[self.selected or 0]

	if (!recipe or #self.recipes >= NETWORK.craft.maxRecipes) then
		return
	end

	table.insert(self.recipes, self.selected + 1, CopyRecipe(recipe))

	self.selected = self.selected + 1

	self:MarkDirty()
	self:RebuildList()
	self:BuildForm()
end

function EDITOR:DeleteRecipe()
	if (!self.recipes[self.selected or 0]) then
		return
	end

	table.remove(self.recipes, self.selected)

	if (#self.recipes == 0) then
		self.selected = nil
	else
		self.selected = math.min(self.selected, #self.recipes)
	end

	self:MarkDirty()
	self:RebuildList()
	self:BuildForm()
end

function EDITOR:MoveRecipe(direction)
	local index = self.selected
	local target = index and index + direction

	if (!index or !self.recipes[target]) then
		return
	end

	self.recipes[index], self.recipes[target] = self.recipes[target], self.recipes[index]
	self.selected = target

	self:MarkDirty()
	self:RebuildList()
	self:BuildForm()
end

function EDITOR:CopyAll()
	local lines = {}

	for _, recipe in ipairs(self.recipes) do
		local exported = Export(recipe)

		if (exported) then
			lines[#lines + 1] = NETWORK.craft.ToLine(exported)
		end
	end

	SetClipboardText(table.concat(lines, "\n"))

	NETWORK.gui.Notify(L("craftCopied", #lines), NETWORK.theme.positive)
end

function EDITOR:PasteLine()
	if (IsValid(self.dialog)) then
		return
	end

	self.dialog = NETWORK.gui.Prompt(L("craftPasteTitle"), L("craftPasteText"), "", function(value)
		if (!IsValid(self) or !isstring(value) or string.Trim(value) == "") then
			return
		end

		local recipe, reason, extra

		if (string.find(value, "=", 1, true)) then
			recipe, reason, extra = NETWORK.craft.Parse(value)
		else
			recipe, reason = NETWORK.craft.ParseWorkbenchLine(value)
		end

		if (!recipe) then
			NETWORK.gui.Notify(L(reason or "craftBadFormat", extra or ""), NETWORK.theme.danger)

			return
		end

		local index = (self.selected or #self.recipes) + 1

		table.insert(self.recipes, index, CopyRecipe(recipe))

		self.selected = index

		self:MarkDirty()
		self:RebuildList()
		self:BuildForm()
	end)
end

function EDITOR:PickResult(recipe)
	NETWORK.gui.OpenCraftPicker({
		title = L("craftPickResult"),
		current = recipe.result and recipe.result.id,
		callback = function(id)
			if (!IsValid(self)) then
				return
			end

			recipe.result = recipe.result or {amount = 1}
			recipe.result.id = id

			self:MarkDirty()
			self:RebuildList()
			self:BuildForm()
		end
	})
end

function EDITOR:AddEntry(recipe, key, id)
	local list = recipe[key]

	for _, entry in ipairs(list) do
		if (entry.id == id) then
			entry.amount = math.min(entry.amount + 1, NETWORK.craft.maxAmount)

			self:MarkDirty()
			self:BuildForm()

			return
		end
	end

	local limit = key == "cost" and NETWORK.craft.maxCost or NETWORK.craft.maxTools

	if (#list >= limit) then
		NETWORK.gui.Notify(L("craftListFull", limit), NETWORK.theme.warning)

		return
	end

	list[#list + 1] = {id = id, amount = 1}

	self:MarkDirty()
	self:BuildForm()
end

function EDITOR:ReplaceEntry(recipe, key, index, id)
	local list = recipe[key]
	local entry = list[index]

	if (!entry) then
		return
	end

	for other, existing in ipairs(list) do
		if (other != index and existing.id == id) then
			existing.amount = math.min(existing.amount + entry.amount, NETWORK.craft.maxAmount)

			table.remove(list, index)

			self:MarkDirty()
			self:BuildForm()

			return
		end
	end

	entry.id = id

	self:MarkDirty()
	self:BuildForm()
end

function EDITOR:FormSection(text, right)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local panel = self.form:Add("DPanel")

	panel:Dock(TOP)
	panel:DockMargin(0, Sc(4), Sc(10), Sc(4))
	panel:SetTall(Sc(22))
	panel.Paint = function(_, width, height)
		draw.SimpleText(NETWORK.util.Upper(text), "nwInvHeader", 0, math.Round(height * 0.5),
			theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (right) then
			local value, color = right()

			draw.SimpleText(value, "nwInvKey", width, math.Round(height * 0.5),
				color or theme.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		Rect(0, height - 1, width, 1, WHITE, 14)
	end

	return panel
end

function EDITOR:FormEntryRow(recipe, key, index, problems)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local entry = recipe[key][index]
	local base = NETWORK.item.Get(entry.id)
	local row = self.form:Add("DButton")
	local iconSize = Sc(36)
	local textX = Sc(8) + iconSize + Sc(10)

	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(10), Sc(4))
	row:SetTall(Sc(46))
	row:SetText("")
	row:SetCursor("hand")
	row.hover = 0
	row.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 14)
	end
	row.OnCursorEntered = function(panel)
		if (base) then
			NETWORK.gui.SetItemTooltip(panel, TooltipItem(entry.id, entry.amount))
		end
	end
	row.OnCursorExited = function(panel)
		NETWORK.gui.ClearTooltip(panel)
	end

	row.DoClick = function()
		NETWORK.sound.Click()
		NETWORK.gui.OpenCraftPicker({
			title = L("craftPickReplace"),
			current = entry.id,
			callback = function(id)
				if (IsValid(self)) then
					self:ReplaceEntry(recipe, key, index, id)
				end
			end
		})
	end

	local icon = row:Add("nwItemIcon")

	icon:SetMouseInputEnabled(false)
	icon:SetPos(Sc(8), Sc(5))
	icon:SetSize(iconSize, iconSize)
	icon:SetItem({id = entry.id, amount = entry.amount})

	local stepper = STYLE.Stepper(row, {
		min = 1,
		max = NETWORK.craft.maxAmount,
		get = function()
			return entry.amount
		end,
		set = function(value)
			entry.amount = value

			self:MarkDirty()
		end
	})

	local remove = STYLE.Close(row, function()
		table.remove(recipe[key], index)

		self:MarkDirty()
		self:RebuildList()
		self:BuildForm()
	end)

	row.PerformLayout = function(_, width, height)
		remove:SetSize(Sc(28), Sc(28))
		remove:SetPos(width - Sc(36), math.Round((height - Sc(28)) * 0.5))
		stepper:SetSize(Sc(112), Sc(28))
		stepper:SetPos(width - Sc(36) - Sc(8) - Sc(112), math.Round((height - Sc(28)) * 0.5))
	end
	row.Paint = function(panel, width, height)
		local bBad = problems and problems[key][index]

		Rect(0, 0, width, height, WHITE, 4 + 8 * panel.hover)
		Outline(0, 0, width, height, bBad and theme.danger or WHITE,
			bBad and 170 or (16 + 30 * panel.hover))

		local limit = width - textX - Sc(170)

		draw.SimpleText(NETWORK.util.TruncateWidth(base and base.name or L("craftUnknown"),
			"nwInvName", limit), "nwInvName", textX, Sc(16),
			bBad and theme.danger or theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(NETWORK.util.TruncateWidth(entry.id, "nwInvKey", limit), "nwInvKey",
			textX, Sc(32), bBad and theme.danger or theme.textFaint, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
end

function EDITOR:FormParam(title, hint, options)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local row = self.form:Add("DPanel")

	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(10), Sc(4))
	row:SetTall(Sc(44))
	row.Paint = function(_, width, height)
		Rect(0, 0, width, height, WHITE, 4)
		Outline(0, 0, width, height, WHITE, 16)

		draw.SimpleText(title, "nwInvName", Sc(12), Sc(15), theme.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(NETWORK.util.TruncateWidth(hint, "nwInvKey", width - Sc(200)),
			"nwInvKey", Sc(12), Sc(31), theme.textFaint, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	local stepper = STYLE.Stepper(row, options)

	row.PerformLayout = function(_, width, height)
		stepper:SetSize(Sc(160), Sc(28))
		stepper:SetPos(width - Sc(8) - Sc(160), math.Round((height - Sc(28)) * 0.5))
	end
end

function EDITOR:BuildForm()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local scroll = self.form:GetVBar():GetScroll()

	self.form:Clear()

	local recipe = self.recipes[self.selected or 0]

	if (!recipe) then
		local empty = self.form:Add("DPanel")

		empty:Dock(TOP)
		empty:SetTall(Sc(120))
		empty.Paint = function(_, width, height)
			draw.SimpleText(L("craftEditorEmpty"), "nwInvName", math.Round(width * 0.5),
				math.Round(height * 0.5), theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		return
	end

	local problems = Problems(recipe)
	local info = NETWORK.craft.GetClassInfo(self.entity)
	local defaultTime = info and info.defaultTime or NETWORK.craft.time

	self:FormSection(L("craftResult"))

	local row = self.form:Add("DPanel")

	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(10), Sc(10))
	row:SetTall(Sc(70))
	row.Paint = function(_, width, height)
		Rect(0, 0, width, height, WHITE, 5)
		Outline(0, 0, width, height, problems.result and theme.danger or WHITE,
			problems.result and 170 or 22)

		draw.SimpleText(NETWORK.util.Upper(L("craftAmount")), "nwInvKey",
			width - Sc(12) - Sc(124), Sc(14), theme.textFaint, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	local pick = row:Add("DButton")

	pick:SetText("")
	pick:SetCursor("hand")
	pick.hover = 0
	pick.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 14)
	end
	pick.DoClick = function()
		NETWORK.sound.Click()

		self:PickResult(recipe)
	end
	pick.OnCursorEntered = function(panel)
		if (recipe.result and NETWORK.item.Get(recipe.result.id)) then
			NETWORK.gui.SetItemTooltip(panel, TooltipItem(recipe.result.id, recipe.result.amount))
		end
	end
	pick.OnCursorExited = function(panel)
		NETWORK.gui.ClearTooltip(panel)
	end

	local iconSize = Sc(54)

	if (recipe.result) then
		local icon = pick:Add("nwItemIcon")

		icon:SetMouseInputEnabled(false)
		icon:SetPos(Sc(8), Sc(8))
		icon:SetSize(iconSize, iconSize)
		icon:SetItem({id = recipe.result.id, amount = recipe.result.amount})
	end

	pick.Paint = function(panel, width, height)
		local textX = Sc(8) + iconSize + Sc(12)

		Rect(0, 0, width, height, WHITE, 8 * panel.hover)

		if (!recipe.result) then
			Outline(Sc(8), Sc(8), iconSize, iconSize, theme.danger, 180)

			draw.SimpleText("+", "nwInvTitle", Sc(8) + math.Round(iconSize * 0.5),
				Sc(8) + math.Round(iconSize * 0.5), theme.danger, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(L("craftPickHint"), "nwInvName", textX, math.Round(height * 0.5),
				theme.danger, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			return
		end

		local base = NETWORK.item.Get(recipe.result.id)

		draw.SimpleText(NETWORK.util.TruncateWidth(base and base.name or L("craftUnknown"),
			"nwField", width - textX - Sc(8)), "nwField", textX, Sc(20),
			base and theme.text or theme.danger, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(recipe.result.id, "nwInvKey", textX, Sc(39),
			base and theme.textFaint or theme.danger, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(L("craftChange"), "nwInvKey", textX, Sc(54),
			ColorAlpha(theme.combine, 120 + 120 * panel.hover), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	local amount = STYLE.Stepper(row, {
		min = 1,
		max = NETWORK.craft.maxAmount,
		get = function()
			return recipe.result and recipe.result.amount or 1
		end,
		set = function(value)
			if (recipe.result) then
				recipe.result.amount = value

				self:MarkDirty()
			end
		end
	})

	row.PerformLayout = function(_, width, height)
		pick:SetPos(0, 0)
		pick:SetSize(width - Sc(150), height)
		amount:SetSize(Sc(124), Sc(30))
		amount:SetPos(width - Sc(12) - Sc(124), Sc(28))
	end

	local lists = {
		{key = "cost", title = L("craftIngredients"), add = L("craftAddIngredient"),
			pick = L("craftPickIngredient"), limit = NETWORK.craft.maxCost},
		{key = "tools", title = L("craftTools"), add = L("craftAddTool"),
			pick = L("craftPickTool"), limit = NETWORK.craft.maxTools}
	}

	for _, list in ipairs(lists) do
		self:FormSection(list.title, function()
			local count = #recipe[list.key]

			if (list.key == "cost" and count == 0) then
				return L("craftNoCost"), theme.danger
			end

			return count .. " / " .. list.limit
		end)

		for index in ipairs(recipe[list.key]) do
			self:FormEntryRow(recipe, list.key, index, problems)
		end

		local add = STYLE.Button(self.form, "+ " .. list.add, function()
			local marked = {}

			for _, entry in ipairs(recipe[list.key]) do
				marked[entry.id] = entry.amount
			end

			NETWORK.gui.OpenCraftPicker({
				title = list.pick,
				bMulti = true,
				marked = marked,
				callback = function(id)
					if (IsValid(self)) then
						self:AddEntry(recipe, list.key, id)
						self:RebuildList()
					end
				end
			})
		end)

		add:Dock(TOP)
		add:DockMargin(0, 0, Sc(10), Sc(12))
		add:SetTall(Sc(32))
		add.IsDisabledFn = function()
			return #recipe[list.key] >= list.limit
		end
	end

	self:FormSection(L("craftParams"))

	self:FormParam(L("craftTime"), L("craftTimeHint"), {
		min = 0,
		max = NETWORK.craft.maxTime,
		step = 0.5,
		decimals = true,
		zeroText = L("craftTimeDefault", defaultTime),
		get = function()
			return recipe.time or 0
		end,
		set = function(value)
			recipe.time = value > 0 and math.max(value, 0.5) or nil

			self:MarkDirty()
		end
	})

	self:FormParam(L("craftSkill"), L("craftSkillHint"), {
		min = 0,
		max = NETWORK.skills and NETWORK.skills.maxLevel or 10,
		zeroText = L("craftSkillNone"),
		get = function()
			return recipe.skill or 0
		end,
		set = function(value)
			recipe.skill = value > 0 and value or nil

			self:MarkDirty()
		end
	})

	self:FormParam(L("craftXP"), L("craftXPHint"), {
		min = 0,
		max = NETWORK.craft.maxXP,
		step = 5,
		zeroText = L("craftXPNone"),
		get = function()
			return recipe.xp or 0
		end,
		set = function(value)
			recipe.xp = value > 0 and value or nil

			self:MarkDirty()
		end
	})

	self:FormSection(L("craftLine"))

	local line = self.form:Add("DPanel")

	line:Dock(TOP)
	line:DockMargin(0, 0, Sc(10), Sc(10))
	line:SetTall(Sc(36))

	local copy = STYLE.Button(line, L("craftCopy"), function()
		local exported = Export(recipe)

		if (exported) then
			SetClipboardText(NETWORK.craft.ToLine(exported))
			NETWORK.gui.Notify(L("craftCopied", 1), NETWORK.theme.positive)
		end
	end)

	copy.IsDisabledFn = function()
		return !recipe.result
	end

	line.PerformLayout = function(_, width, height)
		copy:SetSize(Sc(110), height - Sc(8))
		copy:SetPos(width - Sc(114), Sc(4))
	end
	line.Paint = function(_, width, height)
		Rect(0, 0, width, height, Color(10, 11, 13), 240)
		Outline(0, 0, width, height, WHITE, 16)

		local exported = Export(recipe)

		draw.SimpleText(NETWORK.util.TruncateWidth(exported and NETWORK.craft.ToLine(exported) or
			"—", "nwInvKey", width - Sc(140)), "nwInvKey", Sc(10), math.Round(height * 0.5),
			theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	timer.Simple(0, function()
		if (IsValid(self) and IsValid(self.form)) then
			self.form:InvalidateLayout(true)
			self.form:GetVBar():SetScroll(scroll)
		end
	end)
end

function EDITOR:CountProblems()
	local count = 0

	for _, recipe in ipairs(self.recipes) do
		if (Problems(recipe).any) then
			count = count + 1
		end
	end

	return count
end

function EDITOR:GetStorage()
	if (!self.textLimit) then
		return
	end

	if (self.storageCache) then
		return self.storageCache
	end

	local list = {}

	for _, recipe in ipairs(self.recipes) do
		local exported = Export(recipe)
		local normalized = exported and NETWORK.craft.Normalize(exported)

		if (normalized and NETWORK.craft.Validate(normalized)) then
			list[#list + 1] = normalized
		end
	end

	self.storageCache = string.len((NETWORK.craft.ToWorkbenchText(list, math.huge)))

	return self.storageCache
end

function EDITOR:Save()
	if (!IsValid(self.entity)) then
		return self:Remove()
	end

	local list = {}

	for _, recipe in ipairs(self.recipes) do
		local exported = Export(recipe)

		if (exported) then
			list[#list + 1] = exported
		end
	end

	net.Start("nwCraftConfig")
		net.WriteEntity(self.entity)
		NETWORK.util.WriteTable({
			name = self.nameEntry:GetValue(),
			model = string.Trim(self.modelEntry:GetValue() or ""),
			recipes = list
		})
	net.SendToServer()

	self.dirty = false

	self:Remove()
end

function EDITOR:Close()
	if (!self.dirty) then
		return self:Remove()
	end

	if (IsValid(self.dialog)) then
		return
	end

	self.dialog = NETWORK.gui.Confirm(L("craftUnsavedTitle"), L("craftUnsavedText"), function()
		if (IsValid(self)) then
			self:Remove()
		end
	end)
end

function EDITOR:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)

	if (!IsValid(self.entity)) then
		self:Remove()

		return
	end

	if (IsValid(self.dialog)) then
		return
	end

	if (ConsumeEscape(self)) then
		self:Close()
	end
end

function EDITOR:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Close()
	end
end

function EDITOR:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local x, y, frameW, frameH = self.frameX, self.frameY, self.frameW, self.frameH

	Rect(0, 0, width, height, Color(0, 0, 0), 130 * self.alpha)

	STYLE.Frame(self, x, y, frameW, frameH, self.alpha, IsValid(self.entity) and
		NETWORK.craft.GetDisplayName(self.entity) or L("craftTitle"), L("craftEditorTitle"))

	if (!IsValid(self.modelEntry)) then
		return
	end

	draw.SimpleText(NETWORK.util.Upper(L("craftFieldName")), "nwInvKey", x + Sc(18),
		y + Sc(74), theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(NETWORK.util.Upper(L("craftFieldModel")), "nwInvKey",
		self.modelEntry:GetPos(), y + Sc(74), theme.textFaint, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	draw.SimpleText(NETWORK.util.Upper(L("craftRecipes")), "nwInvHeader", self.leftX,
		self.bodyY + Sc(10), theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(#self.recipes .. " / " .. NETWORK.craft.maxRecipes, "nwInvKey",
		self.leftX + self.leftW, self.bodyY + Sc(10), theme.textFaint, TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	Rect(x + 1, y + frameH - Sc(56), frameW - 2, 1, WHITE, 14 * self.alpha)

	local problems = self:CountProblems()
	local footerY = y + frameH - Sc(29)
	local text, color = L("craftAllGood"), theme.positive

	if (problems > 0) then
		text, color = L("craftProblems", problems), theme.danger
	end

	draw.SimpleText(text, "nwInvName", x + Sc(18), footerY, color, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	local storage = self:GetStorage()

	if (storage) then
		surface.SetFont("nwInvName")

		local offset = surface.GetTextSize(text) + Sc(24)

		draw.SimpleText(L("craftStorage", storage, self.textLimit), "nwInvKey",
			x + Sc(18) + offset, footerY, storage > self.textLimit and theme.danger or
			theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwCraftEditor", EDITOR, "EditablePanel")

local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.craft = self

	self.alpha = 0
	self.text = ""
	self.category = "all"
	self.bOnlyReady = false
	self.cards = {}
	self.nextFilter = 0

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.frameW = math.min(Sc(1000), ScrW() - Sc(40))
	self.frameH = math.min(Sc(720), ScrH() - Sc(40))
	self.frameX = math.floor((ScrW() - self.frameW) * 0.5)
	self.frameY = math.floor((ScrH() - self.frameH) * 0.5)
end

function PANEL:OnRemove()
	if (NETWORK.gui.craft == self) then
		NETWORK.gui.craft = nil
	end
end

function PANEL:GetTask()
	local task = NETWORK.craft.task

	if (task and IsValid(self.entity) and task.entity == self.entity) then
		return task
	end
end

function PANEL:MaxFor(recipe)
	if (!NETWORK.craft.HasSkill(LocalPlayer(), recipe)) then
		return 0
	end

	return NETWORK.craft.MaxBatch(NETWORK.inventory.state, recipe)
end

function PANEL:CountFor(card)
	local max = self:MaxFor(card.recipe)

	if (card.batch == "max") then
		return max
	end

	return math.min(card.batch, max)
end

function PANEL:Setup(entity, recipes)
	local Sc = NETWORK.util.Scale
	local x, y, width, height = self.frameX, self.frameY, self.frameW, self.frameH

	for _, child in ipairs(self:GetChildren()) do
		child:Remove()
	end

	self.entity = entity
	self.recipes = recipes
	self.cards = {}

	local close = STYLE.Close(self, function()
		self:Remove()
	end)

	close:SetPos(x + width - Sc(46), y + Sc(12))
	close:SetSize(Sc(32), Sc(32))

	if (LocalPlayer():IsAdmin()) then
		local configure = STYLE.Button(self, L("craftConfigure"), function()
			NETWORK.craft.RequestConfig(entity)
			self:Remove()
		end)

		configure:SetSize(Sc(130), Sc(30))
		configure:SetPos(x + width - Sc(54) - Sc(130), y + Sc(13))
	end

	self.search = STYLE.Entry(self, L("craftSearch"))
	self.search:SetPos(x + Sc(18), y + Sc(68))
	self.search:SetSize(math.min(Sc(300), math.floor(width * 0.4)), Sc(32))
	self.search.OnValueChange = function(_, value)
		self.text = NETWORK.util.Lower(string.Trim(value or ""))

		self:ApplyFilter()
	end

	local ready = STYLE.Button(self, L("craftOnlyReady"), function()
		self.bOnlyReady = !self.bOnlyReady

		self:ApplyFilter()
	end)

	ready.IsActiveFn = function()
		return self.bOnlyReady
	end
	ready:SetSize(Sc(180), Sc(32))
	ready:SetPos(x + width - Sc(18) - Sc(180), y + Sc(68))

	local present = {}

	for _, recipe in ipairs(recipes) do
		present[NETWORK.craft.GetCategory(recipe.result.id)] = true
	end

	local categories = SortCategories(present)
	local top = y + Sc(110)

	if (#categories > 1) then
		local cursorX = x + Sc(18)
		local chipHeight = Sc(24)

		table.insert(categories, 1, "all")

		for _, id in ipairs(categories) do
			local label = id == "all" and L("craftCatAll") or NETWORK.craft.CategoryName(id)

			surface.SetFont("nwInvKey")

			local chipWidth = surface.GetTextSize(NETWORK.util.Upper(label)) + Sc(20)

			if (cursorX + chipWidth > x + width - Sc(18)) then
				break
			end

			local chip = STYLE.Button(self, label, function()
				self.category = id

				self:ApplyFilter()
			end)

			chip.font = "nwInvKey"
			chip.IsActiveFn = function()
				return self.category == id
			end
			chip:SetPos(cursorX, top)
			chip:SetSize(chipWidth, chipHeight)

			cursorX = cursorX + chipWidth + Sc(6)
		end

		top = top + chipHeight + Sc(10)
	end

	self.listY = top

	self.scroll = STYLE.Scroll(self)
	self.scroll:SetPos(x + Sc(18), top)
	self.scroll:SetSize(width - Sc(36), y + height - Sc(40) - top)

	for index, recipe in ipairs(recipes) do
		self:AddCard(index, recipe)
	end

	self:ApplyFilter(true)
end

function PANEL:AddChip(card, entry, bTool)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local chip = card:Add("DPanel")
	local iconSize = Sc(26)
	local suffix = bTool and ("  " .. L("craftToolShort")) or ""

	surface.SetFont("nwInvName")

	local textWidth = surface.GetTextSize("99/" .. entry.amount .. suffix)

	chip:SetSize(Sc(3) + iconSize + Sc(6) + textWidth + Sc(10), Sc(30))

	local icon = chip:Add("nwItemIcon")

	icon:SetMouseInputEnabled(false)
	icon:SetPos(Sc(3), Sc(2))
	icon:SetSize(iconSize, iconSize)
	icon:SetItem({id = entry.id, amount = entry.amount})

	chip.OnCursorEntered = function(panel)
		NETWORK.gui.SetItemTooltip(panel, TooltipItem(entry.id, entry.amount))
	end
	chip.OnCursorExited = function(panel)
		NETWORK.gui.ClearTooltip(panel)
	end
	chip.Paint = function(_, width, height)
		local have = NETWORK.craft.Count(NETWORK.inventory.state, entry.id)
		local bOk = have >= entry.amount
		local color = bOk and theme.positive or theme.danger

		Rect(0, 0, width, height, color, bOk and 16 or 20)
		Outline(0, 0, width, height, bTool and WHITE or color, bTool and 60 or (bOk and 80 or 130))

		local text = math.min(have, 999) .. "/" .. entry.amount
		local textX = Sc(3) + iconSize + Sc(6)

		draw.SimpleText(text, "nwInvName", textX, math.Round(height * 0.5), color,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (bTool) then
			surface.SetFont("nwInvName")

			draw.SimpleText(L("craftToolShort"), "nwInvKey", textX +
				surface.GetTextSize(text) + Sc(6), math.Round(height * 0.5),
				theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	card.chips[#card.chips + 1] = chip
end

function PANEL:AddCard(index, recipe)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local card = self.scroll:Add("DPanel")
	local iconSize = Sc(64)
	local textX = Sc(12) + iconSize + Sc(14)
	local rightW = Sc(176)
	local base = NETWORK.item.Get(recipe.result.id)

	card:Dock(TOP)
	card:DockMargin(0, 0, Sc(8), Sc(6))
	card:SetTall(Sc(100))
	card.recipe = recipe
	card.index = index
	card.batch = 1
	card.chips = {}
	card.hover = 0
	card.category = NETWORK.craft.GetCategory(recipe.result.id)

	local words = {recipe.result.id, base and base.name or ""}

	for _, entry in ipairs(recipe.cost) do
		words[#words + 1] = entry.id .. " " .. ItemName(entry.id)
	end

	card.searchText = NETWORK.util.Lower(table.concat(words, " "))

	local holder = card:Add("DPanel")

	holder:SetPos(Sc(12), Sc(16))
	holder:SetSize(iconSize, iconSize)
	holder.Paint = function(_, width, height)
		Rect(0, 0, width, height, Color(9, 10, 11), 240)
		Outline(0, 0, width, height, WHITE, 22)
	end
	holder.OnCursorEntered = function(panel)
		NETWORK.gui.SetItemTooltip(panel, TooltipItem(recipe.result.id, recipe.result.amount))
	end
	holder.OnCursorExited = function(panel)
		NETWORK.gui.ClearTooltip(panel)
	end

	local icon = holder:Add("nwItemIcon")

	icon:SetMouseInputEnabled(false)
	icon:SetPos(Sc(4), Sc(4))
	icon:SetSize(iconSize - Sc(8), iconSize - Sc(8))
	icon:SetItem({id = recipe.result.id, amount = recipe.result.amount})

	for _, entry in ipairs(recipe.cost) do
		self:AddChip(card, entry, false)
	end

	for _, entry in ipairs(recipe.tools or {}) do
		self:AddChip(card, entry, true)
	end

	card.batchButtons = {}

	for _, option in ipairs({1, 5, "max"}) do
		local button = STYLE.Button(card, option == "max" and L("craftMax") or ("×" .. option),
			function()
				card.batch = option
			end)

		button.font = "nwInvKey"
		button.IsActiveFn = function()
			return card.batch == option
		end
		button.IsDisabledFn = function()
			if (self:GetTask()) then
				return true
			end

			local max = self:MaxFor(recipe)

			if (option == 1) then
				return max < 1
			end

			return max < (option == "max" and 2 or option)
		end

		card.batchButtons[#card.batchButtons + 1] = button
	end

	local make = STYLE.Button(card, function()
		local task = self:GetTask()

		if (task) then
			return task.index == index and L("craftStop") or L("craftBusyShort")
		end

		local count = self:CountFor(card)

		return count > 1 and L("craftMakeN", count) or L("craftMake")
	end, function()
		local task = self:GetTask()

		if (task) then
			if (task.index == index) then
				net.Start("nwCraftCancel")
				net.SendToServer()
			end

			return
		end

		self:Craft(card)
	end)

	make.primary = true
	make.DangerFn = function()
		local task = self:GetTask()

		return task != nil and task.index == index
	end
	make.IsDisabledFn = function()
		local task = self:GetTask()

		if (task) then
			return task.index != index
		end

		return self:CountFor(card) < 1
	end

	card.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover,
			(panel:IsHovered() or panel:IsChildHovered()) and 1 or 0, 12)

		if (card.batch != 1 and !self:GetTask()) then
			local max = self:MaxFor(recipe)

			if ((card.batch == "max" and max < 2) or (card.batch == 5 and max < 5)) then
				card.batch = 1
			end
		end
	end

	card.PerformLayout = function(panel, width, height)
		make:SetSize(rightW, Sc(34))
		make:SetPos(width - rightW - Sc(12), Sc(16))

		local buttonGap = Sc(4)
		local buttonW = math.floor((rightW - buttonGap * 2) / 3)

		for order, button in ipairs(card.batchButtons) do
			button:SetSize(order == 3 and (rightW - buttonW * 2 - buttonGap * 2) or buttonW, Sc(24))
			button:SetPos(width - rightW - Sc(12) + (order - 1) * (buttonW + buttonGap), Sc(56))
		end

		local maxX = width - rightW - Sc(28)
		local chipHeight = Sc(30)
		local cursorX, cursorY = textX, Sc(54)

		for _, chip in ipairs(card.chips) do
			if (cursorX + chip:GetWide() > maxX and cursorX > textX) then
				cursorX = textX
				cursorY = cursorY + chipHeight + Sc(4)
			end

			chip:SetPos(cursorX, cursorY)

			cursorX = cursorX + chip:GetWide() + Sc(6)
		end

		local wanted = math.max(Sc(100), cursorY + chipHeight + Sc(14))

		if (height != wanted) then
			panel:SetTall(wanted)

			if (IsValid(self.scroll)) then
				self.scroll:GetCanvas():InvalidateLayout()
				self.scroll:InvalidateLayout()
			end
		end
	end

	card.Paint = function(panel, width, height)
		local task = self:GetTask()
		local bActive = task != nil and task.index == index
		local max = self:MaxFor(recipe)
		local bReady = max >= 1

		Rect(0, 0, width, height, Color(13, 14, 16), 235)
		Rect(0, 0, width, height, WHITE, 5 * panel.hover)

		if (bActive) then
			Outline(0, 0, width, height, theme.combine, 170)
		else
			Outline(0, 0, width, height, WHITE, 18 + 24 * panel.hover)
		end

		Rect(0, 0, math.max(Sc(3), 2), height, bActive and theme.combine or
			(bReady and theme.positive or theme.line), bReady and 230 or 120)

		local name = base and base.name or recipe.result.id

		if (recipe.result.amount > 1) then
			name = name .. " ×" .. recipe.result.amount
		end

		local limit = width - textX - rightW - Sc(30)

		draw.SimpleText(NETWORK.util.TruncateWidth(name, "nwField", limit), "nwField",
			textX, Sc(22), theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (bActive) then
			local left = math.max(task.start + task.duration - CurTime(), 0)

			draw.SimpleText(L("craftWorking", task.done + 1, task.done + task.left,
				string.format("%.1f", left)), "nwInvKey", textX, Sc(41), theme.combineSoft,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local fraction = math.Clamp((CurTime() - task.start) / math.max(task.duration, 0.01),
				0, 1)

			Rect(1, height - Sc(4), width - 2, Sc(3), WHITE, 16)
			Rect(1, height - Sc(4), math.Round((width - 2) * fraction), Sc(3), theme.combine, 240)

			return
		end

		local time = NETWORK.craft.GetTime(recipe, self.entity)

		if (NETWORK.skills and NETWORK.skills.CraftTimeFactor) then
			time = math.max(0.5, time * NETWORK.skills.CraftTimeFactor(LocalPlayer()))
		end

		local meta = NETWORK.util.Upper(NETWORK.craft.CategoryName(card.category)) ..
			"  ·  " .. L("craftSeconds", string.format("%.1f", time))

		draw.SimpleText(meta, "nwInvKey", textX, Sc(41), theme.textFaint, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		if (recipe.skill) then
			surface.SetFont("nwInvKey")

			local bSkill = NETWORK.craft.HasSkill(LocalPlayer(), recipe)

			draw.SimpleText("·  " .. L("craftNeedSkillShort", recipe.skill), "nwInvKey",
				textX + surface.GetTextSize(meta) + Sc(8), Sc(41),
				bSkill and theme.textDim or theme.danger, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	self.cards[#self.cards + 1] = card
end

function PANEL:Craft(card)
	local count = self:CountFor(card)

	if (count < 1) then
		surface.PlaySound("buttons/button10.wav")

		return
	end

	net.Start("nwCraftMake")
		net.WriteUInt(card.index, 5)
		net.WriteUInt(math.min(count, NETWORK.craft.maxBatch), 7)
		net.WriteString(card.recipe.result.id)
	net.SendToServer()

	surface.PlaySound("buttons/lever5.wav")
end

function PANEL:ApplyFilter(bForce)
	local bChanged = bForce or false
	local visible = 0

	for _, card in ipairs(self.cards) do
		local bShow = (self.category == "all" or card.category == self.category) and
			(self.text == "" or string.find(card.searchText, self.text, 1, true) != nil) and
			(!self.bOnlyReady or self:MaxFor(card.recipe) >= 1 or
			(self:GetTask() and self:GetTask().index == card.index))

		if (card:IsVisible() != bShow) then
			card:SetVisible(bShow)

			bChanged = true
		end

		if (bShow) then
			visible = visible + 1
		end
	end

	self.visibleCount = visible

	if (bChanged and IsValid(self.scroll)) then
		self.scroll:GetCanvas():InvalidateLayout()
		self.scroll:InvalidateLayout()
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)

	local client = LocalPlayer()

	if (!IsValid(self.entity) or !IsValid(client) or
		client:GetPos():Distance(self.entity:GetPos()) > NETWORK.craft.range + 20) then
		self:Remove()

		return
	end

	if (self.bOnlyReady and RealTime() >= self.nextFilter) then
		self.nextFilter = RealTime() + 0.5

		self:ApplyFilter()
	end

	if (ConsumeEscape(self)) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local x, y, frameW, frameH = self.frameX, self.frameY, self.frameW, self.frameH

	Rect(0, 0, width, height, Color(0, 0, 0), 110 * self.alpha)

	local subtitle = L("craftSubtitle")

	if (NETWORK.skills and NETWORK.skills.Get) then
		subtitle = subtitle .. "  ·  " .. L("craftSkillLevel",
			NETWORK.skills.Get(LocalPlayer(), "crafting"))
	end

	STYLE.Frame(self, x, y, frameW, frameH, self.alpha, IsValid(self.entity) and
		NETWORK.craft.GetDisplayName(self.entity) or L("craftTitle"), subtitle)

	if (!self.recipes or !self.listY) then
		return
	end

	if ((self.visibleCount or 0) == 0) then
		draw.SimpleText(#self.recipes == 0 and L("craftEmpty") or L("craftNothingFound"),
			"nwInvName", x + math.Round(frameW * 0.5), self.listY + Sc(40), theme.textDim,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	Rect(x + 1, y + frameH - Sc(36), frameW - 2, 1, WHITE, 14 * self.alpha)

	local task = self:GetTask()
	local footer = L("craftFooterHint")
	local color = theme.textFaint

	if (task and self.recipes[task.index]) then
		footer = L("craftWorkingFooter", ItemName(self.recipes[task.index].result.id),
			task.done + 1, task.done + task.left)
		color = theme.combineSoft
	end

	draw.SimpleText(footer, "nwInvKey", x + Sc(18), y + frameH - Sc(18), color,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwCraftPanel", PANEL, "EditablePanel")

net.Receive("nwCraftOpen", function()
	local entity = net.ReadEntity()
	local recipes = NETWORK.util.ReadTable() or {}

	if (!IsValid(entity)) then
		return
	end

	local list = {}

	for _, raw in ipairs(recipes) do
		local recipe = NETWORK.craft.Normalize(raw)

		if (recipe) then
			list[#list + 1] = recipe
		end
	end

	if (NETWORK.craft.task and NETWORK.craft.task.entity != entity) then
		NETWORK.craft.task = nil
	end

	if (IsValid(NETWORK.gui.craft)) then
		NETWORK.gui.craft:Remove()
	end

	vgui.Create("nwCraftPanel"):Setup(entity, list)
end)

net.Receive("nwCraftState", function()
	if (!net.ReadBool()) then
		NETWORK.craft.task = nil

		return
	end

	local entity = net.ReadEntity()
	local index = net.ReadUInt(5)
	local duration = net.ReadFloat()
	local left = net.ReadUInt(7)
	local done = net.ReadUInt(7)

	NETWORK.craft.task = {
		entity = entity,
		index = index,
		duration = duration,
		start = CurTime(),
		left = left,
		done = done
	}
end)

function NETWORK.craft.RequestConfig(entity)
	net.Start("nwCraftConfigRequest")
		net.WriteEntity(entity)
	net.SendToServer()
end

net.Receive("nwCraftConfigOpen", function()
	local entity = net.ReadEntity()
	local data = NETWORK.util.ReadTable() or {}

	if (!IsValid(entity)) then
		return
	end

	if (IsValid(NETWORK.gui.craftEditor)) then
		NETWORK.gui.craftEditor:Remove()
	end

	if (IsValid(NETWORK.gui.craft)) then
		NETWORK.gui.craft:Remove()
	end

	local recipes = {}

	for _, raw in ipairs(data.recipes or {}) do
		local recipe = NETWORK.craft.Normalize(raw)

		if (recipe) then
			recipes[#recipes + 1] = recipe
		end
	end

	data.recipes = recipes

	vgui.Create("nwCraftEditor"):Setup(entity, data)
end)

properties.Add("nwcrafttable", {
	MenuLabel = "Настроить рецепты",
	Order = 1,
	MenuIcon = "icon16/wrench.png",

	Filter = function(self, entity, client)
		return NETWORK.craft.IsTable(entity) and client:IsAdmin()
	end,

	Action = function(self, entity)
		NETWORK.craft.RequestConfig(entity)
	end
})
