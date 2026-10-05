NETWORK.interact = NETWORK.interact or {}

NETWORK.interact.range = 120
NETWORK.interact.targets = NETWORK.interact.targets or {}

function NETWORK.interact.Register(class, data)
	NETWORK.interact.targets[class] = data
end

local function Alliance(client)
	return NETWORK.factions.IsAlliance(client)
end

local function HasBodybag()
	local state = NETWORK.inventory.state

	if (!state) then
		return false
	end

	for _, list in ipairs({"items", "storage"}) do
		for _, item in pairs(state[list] or {}) do
			if (istable(item) and item.id == "bodybag") then
				return true
			end
		end
	end

	return false
end

NETWORK.interact.Register("nw_container", {icon = "crate"})
NETWORK.interact.Register("nw_ration_bin", {icon = "box"})
NETWORK.interact.Register("nw_locker", {icon = "locker"})
NETWORK.interact.Register("nw_junk", {
	icon = "trash",
	CanUse = function(client, entity)
		return !entity:GetSearched()
	end
})
NETWORK.interact.Register("nw_trader", {icon = "trade"})
NETWORK.interact.Register("nw_recruiter", {icon = "recruit"})
NETWORK.interact.Register("nw_npc", {icon = "talk"})
NETWORK.interact.Register("nw_vending", {icon = "vending"})
NETWORK.interact.Register("nw_dispenser", {icon = "ration"})

NETWORK.interact.Register("nw_terminal", {
	icon = "terminal",
	CanUse = function(client, entity)
		if (NETWORK.terminal.CanOpen(client)) then
			return true
		end

		return entity.GetAlarm != nil and entity:GetAlarm()
	end
})
NETWORK.interact.Register("nw_workterminal", {
	icon = "factory",
	CanUse = function(client)
		return NETWORK.factorywork.IsWorker(client) or client:IsAdmin()
	end
})
NETWORK.interact.Register("nw_business_terminal", {icon = "card"})

NETWORK.interact.Register("nw_infoterminal", {label = "interactInfo", icon = "info"})
NETWORK.interact.Register("nw_fabricator", {icon = "gears"})
NETWORK.interact.Register("nw_supply_crate", {icon = "crate"})
NETWORK.interact.Register("nw_supply_depot", {
	label = "interactDepot",
	icon = "depot",
	CanUse = function(client)
		return NETWORK.factions.IsCWU(client)
	end
})
NETWORK.interact.Register("nw_admin_computer", {
	label = "interactComputer",
	icon = "computer",
	CanUse = function(client)
		return NETWORK.admincomp and NETWORK.admincomp.CanUse(client)
	end
})
NETWORK.interact.Register("nw_council_computer", {
	label = "interactCouncilComputer",
	icon = "council",
	CanUse = function(client)
		return NETWORK.admincomp and NETWORK.admincomp.CanUse(client)
	end
})
NETWORK.interact.Register("nw_workbench", {icon = "craft"})

NETWORK.interact.Register("nw_xenlife", {
	label = "interactXen",
	icon = "biohazard",
	CanUse = function(client)
		return NETWORK.factions.IsCWU(client)
	end
})
NETWORK.interact.Register("nw_cmbterminal", {icon = "terminal", CanUse = Alliance})
NETWORK.interact.Register("nw_jailterminal", {icon = "prisoner", CanUse = Alliance})
NETWORK.interact.Register("nw_mine", {icon = "mine", CanUse = Alliance})
NETWORK.interact.Register("npc_turret_floor", {icon = "turret", CanUse = Alliance})
NETWORK.interact.Register("npc_cscanner", {icon = "scanner", CanUse = Alliance})

function NETWORK.interact.GetTarget(client)

	client = client or LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity)) then
		return
	end

	if (client:GetShootPos():Distance(trace.HitPos) > NETWORK.interact.range) then
		return
	end

	if (NETWORK.door.IsDoor(entity)) then
		local data = NETWORK.door.GetData(entity)

		if (!data) then
			return entity, "interactDoor"
		end

		local bFaction = false
		local allowed = NETWORK.door.GetFactions(data)

		if (allowed) then
			local mine = client:GetCharacterFaction()

			for _, id in ipairs(allowed) do
				if (id == mine or (id == "alliance" and Alliance(client)) or
					(id == "cwu" and NETWORK.factions.IsCWU and NETWORK.factions.IsCWU(client))) then
					bFaction = true

					break
				end
			end
		elseif (data.type == "faction") then
			bFaction = Alliance(client)
		end

		if (data.type == "faction") then
			return entity, bFaction and "interactDoor" or "interactLocked"
		end

		if (NETWORK.door.IsLocked(data) and
			!NETWORK.door.IsOwner(data, client:SteamID64()) and !bFaction) then
			return entity, "interactLocked"
		end

		return entity, "interactDoor"
	end

	if (NETWORK.pmenu.Resolve(entity)) then
		return
	end

	local data = NETWORK.interact.targets[entity:GetClass()]

	if (!data) then
		return
	end

	if (data.CanUse and !data.CanUse(client, entity)) then
		return
	end

	return entity, data.label or "interactUse"
end

local ICON_ALIASES = {
	backpack = "crate",
	lock = "padlock",
	delete = "trash",
	shopping_cart = "trade",
	work = "recruit",
	person = "talk",
	store = "vending",
	restaurant = "ration",
	developer_board = "terminal",
	build = "craft",
	construction = "defuse",
	pest_control = "biohazard"
}

local ICON_LEGACY = {
	crate = "backpack",
	box = "backpack",
	locker = "lock",
	padlock = "lock",
	trash = "delete",
	trade = "shopping_cart",
	recruit = "work",
	talk = "person",
	vending = "store",
	ration = "restaurant",
	terminal = "developer_board",
	computer = "developer_board",
	council = "developer_board",
	factory = "developer_board",
	card = "developer_board",
	depot = "backpack",
	craft = "build",
	dismantle = "build",
	defuse = "construction",
	biohazard = "pest_control",
	door = "key",
	scanner = "visibility",
	prisoner = "lock",
	turret = "shield",
	mine = "warning",
	gears = "settings_input_component"
}

local resolvedIcons = {}

function NETWORK.interact.ResolveIcon(name)
	if (!isstring(name) or name == "") then
		return
	end

	local cached = resolvedIcons[name]

	if (cached != nil) then
		return cached or nil
	end

	local candidates

	if (string.find(name, "/", 1, true)) then
		candidates = {name}
	else
		local modern = ICON_ALIASES[name] or name

		candidates = {
			"framework/interact/" .. modern .. ".png",
			"framework/icons/" .. (ICON_LEGACY[modern] or name) .. ".png",
			"framework/icons/" .. name .. ".png"
		}
	end

	local result = false

	for _, path in ipairs(candidates) do
		local material = NETWORK.util.GetMaterial(path, "smooth")

		if (material and !material:IsError()) then
			result = path

			break
		end
	end

	resolvedIcons[name] = result

	return result or nil
end

function NETWORK.interact.GetIcon(entity, label)
	if (label == "interactLocked") then
		return NETWORK.interact.ResolveIcon("padlock")
	end

	if (label == "interactDoor") then
		return NETWORK.interact.ResolveIcon("door")
	end

	if (!IsValid(entity)) then
		return
	end

	local data = NETWORK.interact.targets[entity:GetClass()]

	if (data and data.icon) then
		return NETWORK.interact.ResolveIcon(data.icon)
	end
end

hook.Add("HUDPaint", "nwInteract", function()
	if (NETWORK.hud.IsHidden()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
		return
	end

	if (IsValid(NETWORK.gui.menu) or IsValid(client:GetNWEntity("nwRagdollEntity", NULL))) then
		return
	end

	local entity, label = NETWORK.interact.GetTarget(client)

	if (!entity) then
		NETWORK.interact.alpha = NETWORK.util.Approach(NETWORK.interact.alpha or 0, 0, 6)
	else
		NETWORK.interact.alpha = NETWORK.util.Approach(NETWORK.interact.alpha or 0, 1, 12)
		NETWORK.interact.label = label
		NETWORK.interact.icon = NETWORK.interact.GetIcon(entity, label)
	end

	local alpha = NETWORK.util.EaseInOut(NETWORK.interact.alpha) *
		NETWORK.hud.GetFade()

	if (alpha < 0.02 or !NETWORK.interact.label) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local text = L(NETWORK.interact.label)
	local key = string.upper(input.LookupBinding("+use", true) or "E")
	local bLocked = NETWORK.interact.label == "interactLocked"

	local target = entity or NETWORK.interact.lastEntity
	local title, description, titleColor

	if (IsValid(target)) then
		NETWORK.interact.lastEntity = target
	end

	if (IsValid(target) and target:GetClass() == "nw_item" and target.GetItem) then
		local item = target:GetItem()

		if (item) then
			title = NETWORK.item.GetName(item)
			description = NETWORK.item.GetDescription and
				NETWORK.item.GetDescription(item) or ""

			local base = NETWORK.item.Get(item.uniqueID or "")
			local category = (base and base.category) or item.category or "misc"
			local palette = {medical = theme.positive, weapon = theme.danger,
				contraband = theme.danger, service = theme.combine, key = theme.combine}

			titleColor = palette[category] or theme.text

			if (base and base.bContraband) then
				titleColor = theme.danger
			end
		end
	end

	local iconPath = NETWORK.interact.icon
	local icon = iconPath and util.GetMaterial(iconPath, "smooth") or nil

	if (icon and icon:IsError()) then
		icon = nil
	end

	surface.SetFont("nwInvName")

	local textWidth = surface.GetTextSize(text)
	local keySize = Sc(34)
	local iconSize = Sc(18)
	local iconGap = Sc(8)
	local iconSpace = icon and (iconSize + iconGap) or 0
	local gap = Sc(12)
	local padding = Sc(10)
	local thin = math.max(Sc(1), 1)
	local boxWidth = keySize + gap + iconSpace + textWidth + padding * 2 + Sc(4)
	local boxHeight = Sc(46)

	local lines = {}
	local headHeight = 0

	if (title) then
		surface.SetFont("nwInvName")
		boxWidth = math.max(boxWidth, surface.GetTextSize(title) + padding * 2 + Sc(8))

		local limit = math.max(boxWidth, Sc(280))

		lines = util.WrapText(description or "", "nwLabel", math.min(limit,
			ScrW() * 0.33) - padding * 2, 3)

		surface.SetFont("nwLabel")

		for _, line in ipairs(lines) do
			boxWidth = math.max(boxWidth, surface.GetTextSize(line) + padding * 2 + Sc(8))
		end

		boxWidth = math.min(boxWidth, math.floor(ScrW() * 0.33))
		headHeight = Sc(34) + #lines * Sc(15) + (#lines > 0 and Sc(6) or 0)
	end

	local totalHeight = boxHeight + headHeight
	local x = math.Round((ScrW() - boxWidth) * 0.5)
	local y = math.Round(ScrH() * 0.78) + math.Round((1 - alpha) * Sc(10)) - headHeight
	local accent = bLocked and theme.danger or theme.combine

	util.DrawBlurScreen(x, y, boxWidth, totalHeight, 4 * alpha)

	surface.SetDrawColor(0, 0, 0, 200 * alpha)
	surface.DrawRect(x, y, boxWidth, totalHeight)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 120 * alpha)
	surface.DrawOutlinedRect(x, y, boxWidth, totalHeight, thin)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 235 * alpha)
	surface.DrawRect(x, y + totalHeight - math.max(Sc(2), 2), boxWidth, math.max(Sc(2), 2))

	if (title) then
		draw.SimpleText(title, "nwInvName", x + padding + Sc(4), y + Sc(17),
			ColorAlpha(titleColor or theme.text, 252 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		for index, line in ipairs(lines) do
			draw.SimpleText(line, "nwLabel", x + padding + Sc(4),
				y + Sc(34) + (index - 1) * Sc(15) + Sc(6),
				ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end

		surface.SetDrawColor(255, 255, 255, 18 * alpha)
		surface.DrawRect(x + padding, y + headHeight - 1, boxWidth - padding * 2, thin)
	end

	local rowY = y + headHeight
	local keyX = x + padding + Sc(4)
	local keyY = rowY + math.Round((boxHeight - keySize) * 0.5)

	local ring = util.GetMaterial("framework/hud/action_ring.png", "smooth")
	local keyCX = keyX + math.Round(keySize * 0.5)
	local keyCY = keyY + math.Round(keySize * 0.5)

	surface.SetDrawColor(0, 0, 0, 120 * alpha)
	surface.DrawRect(keyX, keyY, keySize, keySize)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 200 * alpha)
	surface.DrawOutlinedRect(keyX, keyY, keySize, keySize, thin)

	if (ring and !ring:IsError()) then
		surface.SetDrawColor(accent.r, accent.g, accent.b, 120 * alpha)
		surface.SetMaterial(ring)
		surface.DrawTexturedRectRotated(keyCX, keyCY, keySize - Sc(4), keySize - Sc(4),
			RealTime() * 40)
	else
		util.DrawArc(keyCX, keyCY, math.floor(keySize * 0.5) - Sc(4), thin, 1,
			ColorAlpha(accent, 90 * alpha), 48)
	end

	draw.SimpleText(key, "nwInvName", keyCX, keyCY,
		ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	local textX = keyX + keySize + gap
	local textY = rowY + math.Round(boxHeight * 0.5)

	if (icon) then
		local iconY = textY - math.Round(iconSize * 0.5)

		surface.SetMaterial(icon)
		surface.SetDrawColor(0, 0, 0, 160 * alpha)
		surface.DrawTexturedRect(textX + 1, iconY + 1, iconSize, iconSize)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 245 * alpha)
		surface.DrawTexturedRect(textX, iconY, iconSize, iconSize)

		textX = textX + iconSpace
	end

	draw.SimpleText(text, "nwInvName", textX, textY,
		ColorAlpha(bLocked and theme.danger or theme.text, 252 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)

local holdStart

hook.Add("HUDPaint", "nwSearchHoldRing", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:HasCharacter() or
		NETWORK.hud.IsHidden()) then
		holdStart = nil

		return
	end

	local bValid = NETWORK.pmenu.GetTarget(client) != nil and
		!input.IsKeyDown(KEY_LSHIFT) and !IsValid(NETWORK.gui.playerMenu)

	if (!bValid or !input.IsKeyDown(input.GetKeyCode(
		input.LookupBinding("+use") or "e"))) then
		holdStart = nil

		return
	end

	holdStart = holdStart or CurTime()

	local hold = NETWORK.pmenu.holdTime
	local fraction = math.Clamp((CurTime() - holdStart) / hold, 0, 1)

	if (fraction >= 1) then
		return
	end

	local Sc = NETWORK.util.Scale
	local width = Sc(70)
	local height = math.max(Sc(3), 2)
	local x = math.Round((ScrW() - width) * 0.5)
	local y = math.Round(ScrH() * 0.5) + Sc(52)
	local color = NETWORK.theme.hover

	local show = math.Clamp(fraction * 6, 0, 1)

	y = y + math.Round((1 - show) * Sc(5))

	surface.SetDrawColor(0, 0, 0, 180 * show)
	surface.DrawRect(x, y, width, height)

	local fill = math.max(math.Round(width * fraction), 2)

	surface.SetDrawColor(color.r, color.g, color.b, 250 * show)
	surface.DrawRect(x + math.Round((width - fill) * 0.5), y, fill, height)
end)
