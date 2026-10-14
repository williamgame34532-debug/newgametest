-- What you look at: on the body of a player (centred on the chest) - the faction icon, the name
-- and the description under it ("Неизвестный" / "Неизвестное описание" for someone you do not
-- know, NW.char.Knows); close by, "[E] Взаимодействие" under it opens the interaction wheel
-- (cl_social.lua);
-- over an item in the world - its icon, name and description (the E prompt: cl_interact.lua). Fades in when you
-- look at it, fades out when you look away. Hidden in the menus and the inventory.

local U = NW.ui
local I = NW.items

local alpha = {}
local RANGE_PLAYER = 300
local RANGE_ITEM = 160

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight, blur)
		surface.CreateFont(name, {font = font, size = math.max(12, math.Round(h * size)), weight = weight,
			extended = true, antialias = true, blursize = blur or 0})
	end

	F("nwLookName", "Montserrat SemiBold", 0.0235, 600)
	F("nwLookNameShadow", "Montserrat SemiBold", 0.0235, 600, 3)
	F("nwLookDesc", "Exo 2", 0.0162, 500)
	F("nwLookDescShadow", "Exo 2", 0.0162, 500, 2)
	F("nwLookHint", "Montserrat Medium", 0.0122, 500)
	F("nwLookHintShadow", "Montserrat Medium", 0.0122, 500, 2)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwLookFonts", Fonts)

local function Text(text, font, x, y, color, a, align)
	draw.SimpleText(text, font .. "Shadow", x + 1, y + 1, Color(0, 0, 0, 220 * a), align or TEXT_ALIGN_CENTER,
		TEXT_ALIGN_TOP)
	draw.SimpleText(text, font, x, y, ColorAlpha(color, 255 * a), align or TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

local function Lines(text, width, max)
	local lines = NW.inventory.WrapText(text, "nwLookDesc", width)

	if (#lines > max) then
		local cut = {}

		for i = 1, max do
			cut[i] = lines[i]
		end

		cut[max] = cut[max] .. "…"

		return cut
	end

	return lines
end

-- icon + name centred on x, then the description lines; returns the bottom
local function Block(x, y, icon, iconColor, name, nameColor, desc, descColor, a)
	local sh = ScrH()

	surface.SetFont("nwLookName")

	local nw, nh = surface.GetTextSize(name)
	local is = icon and math.Round(nh * 1.05) or 0
	local gap = icon and math.Round(nh * 0.35) or 0
	local left = x - (is + gap + nw) / 2

	if (icon) then
		surface.SetMaterial(icon)
		surface.SetDrawColor(0, 0, 0, 160 * a)
		surface.DrawTexturedRect(left + 1, y + (nh - is) / 2 + 1, is, is)
		surface.SetDrawColor(iconColor.r, iconColor.g, iconColor.b, 255 * a)
		surface.DrawTexturedRect(left, y + (nh - is) / 2, is, is)
	end

	Text(name, "nwLookName", left + is + gap, y, nameColor, a, TEXT_ALIGN_LEFT)
	y = y + nh + math.Round(sh * 0.003)

	if (desc and desc != "") then
		surface.SetFont("nwLookDesc")

		local lh = select(2, surface.GetTextSize("Ag"))

		for _, line in ipairs(Lines(desc, math.min(ScrW() * 0.26, sh * 0.45), 3)) do
			Text(line, "nwLookDesc", x, y, descColor, a)
			y = y + lh
		end
	end

	return y
end

local function Target(client)
	local eye = client:EyePos()
	local trace = util.TraceLine({
		start = eye,
		endpos = eye + client:GetAimVector() * RANGE_PLAYER,
		filter = client,
		mask = MASK_SHOT
	})
	local entity = trace.Entity

	if (!IsValid(entity)) then
		return
	end

	if (entity:IsPlayer() and entity:Alive() and entity:GetCharacterID() != 0) then
		return entity
	end

	if (entity:GetClass() == "nw_item" and trace.HitPos:DistToSqr(eye) < RANGE_ITEM * RANGE_ITEM) then
		return entity
	end
end

hook.Add("HUDPaint", "nwOverhead", function()
	local client = LocalPlayer()
	local hidden = !IsValid(client) or !client:Alive() or (NW.menu and NW.menu.active) or
		(NW.inventory and NW.inventory.IsOpen and NW.inventory.IsOpen()) or client:GetCharacterID() == 0
	local target = !hidden and Target(client) or nil
	local step = FrameTime() * 5

	if (IsValid(target)) then
		alpha[target] = alpha[target] or 0
	end

	for entity, a in pairs(alpha) do
		if (!IsValid(entity)) then
			alpha[entity] = nil
			continue
		end

		a = math.Approach(a, entity == target and 1 or 0, step)
		alpha[entity] = a

		if (a <= 0) then
			alpha[entity] = nil
			continue
		end

		if (entity:IsPlayer()) then
			-- right on the body: centred on the chest
			local chest = entity:LookupBone("ValveBiped.Bip01_Spine2")
			local pos = chest and entity:GetBonePosition(chest) or (entity:GetPos() + Vector(0, 0, 48))
			local screen = pos:ToScreen()

			if (screen.visible) then
				local known = NW.char.Knows(client, entity)
				local faction = NW.char.factions[entity:GetFaction() or ""]
				-- a stranger: a question mark instead of the faction icon
				local icon = known and faction and U.Material("network2/factions/" .. faction.logo .. ".png") or
					(!known and U.Material("network2/ui/unknown.png"))
				local color = known and faction and faction.color or U.color.text
				local sh = ScrH()

				local desc = known and entity:GetCharacterDescription() or "Неизвестное описание"
				local lines = desc != "" and #Lines(desc, math.min(ScrW() * 0.26, sh * 0.45), 3) or 0

				surface.SetFont("nwLookDesc")

				local lh = select(2, surface.GetTextSize("Ag"))

				surface.SetFont("nwLookName")

				local nameH = select(2, surface.GetTextSize("Ag"))
				local y = screen.y - (nameH + lines * lh) / 2 + (1 - a) * sh * 0.008

				local bottom = Block(screen.x, y, icon, color, known and entity:Nick() or "Неизвестный",
					known and Color(236, 240, 244) or Color(196, 200, 206), desc,
					known and Color(186, 192, 198) or Color(150, 156, 162), a)

				-- close enough: "[E] Взаимодействие" under it (cl_social.lua)
				NW.social.DrawHint(entity, screen.x, bottom, a)
			end
		else
			local item = entity:GetItem()

			if (item) then
				-- over the middle of the item's real bounds (the model origin is often off to a side)
				local mins, maxs = entity:WorldSpaceAABB()
				local top = Vector((mins.x + maxs.x) / 2, (mins.y + maxs.y) / 2, maxs.z + 6)
				local screen = top:ToScreen()

				if (screen.visible) then
					local cat = I.categories[item.category] or I.categories.misc
					local sh = ScrH()
					-- the whole block ends just above the item
					surface.SetFont("nwLookName")

					local nameH = select(2, surface.GetTextSize("Ag"))

					surface.SetFont("nwLookDesc")

					local lh = select(2, surface.GetTextSize("Ag"))
					local lines = #Lines(item.description or "", math.min(ScrW() * 0.26, sh * 0.45), 3)

					surface.SetFont("nwLookHint")

					local hintH = select(2, surface.GetTextSize("Ag"))
					local height = nameH + sh * 0.003 + lines * lh + sh * 0.006 + hintH
					Block(screen.x, screen.y - height - sh * 0.012 - (1 - a) * sh * 0.008,
						U.Material("network2/items/" .. item.icon .. ".png"), cat.color, item.name,
						Color(236, 240, 244), item.description, Color(186, 192, 198), a)
				end
			end
		end
	end
end)
