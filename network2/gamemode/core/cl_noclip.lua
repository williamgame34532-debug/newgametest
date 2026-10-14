-- The noclip view (admins, sh_noclip.lua): while flying, everything that matters is seen through
-- the walls -
--   players      an outline in the colour of their faction; over the head the character's name,
--                the Steam name, the faction, health and the distance
--   items        an outline in the colour of their category and the name (within 3000 units)
--   containers,  the name (within 3000 units)
--   NPCs
--   zones        the boxes and their names (as in the editor)
-- A strip at the top says the observer mode is on.

local Z = NW.zones
local U = NW.ui
local I = NW.items

local RANGE = 3000

surface.CreateFont("nwNoclip", {font = "Exo 2", size = math.max(13, math.Round(ScrH() * 0.016)), weight = 600,
	extended = true, antialias = true})
surface.CreateFont("nwNoclipSmall", {font = "Exo 2", size = math.max(11, math.Round(ScrH() * 0.0135)), weight = 500,
	extended = true, antialias = true})

local function Active()
	local client = LocalPlayer()

	return IsValid(client) and client:IsAdmin() and client:GetMoveType() == MOVETYPE_NOCLIP and !client:InVehicle()
end

local function FactionColor(target)
	local faction = NW.char.factions[target:GetFaction() or ""]

	return faction and faction.color or Color(200, 206, 212), faction and faction.name or "—"
end

local function ItemColor(entity)
	local item = entity.GetItem and entity:GetItem()
	local cat = item and (I.categories[item.category] or I.categories.misc)

	return cat and cat.color or U.color.text, item and item.name or "Предмет"
end

-- outlines through the walls
hook.Add("PreDrawHalos", "nwNoclip", function()
	if (!Active()) then
		return
	end

	local me = LocalPlayer()
	local byColor = {}

	local function Add(entity, color)
		local key = color.r .. "," .. color.g .. "," .. color.b
		local entry = byColor[key] or {color = color, list = {}}

		entry.list[#entry.list + 1] = entity
		byColor[key] = entry
	end

	for _, target in ipairs(player.GetAll()) do
		if (target != me and target:Alive() and !target:GetNW2Bool("nwKnocked", false)) then
			Add(target, (FactionColor(target)))
		end
	end

	for _, entity in ipairs(ents.FindInSphere(me:EyePos(), RANGE)) do
		if (entity:GetClass() == "nw_item") then
			Add(entity, (ItemColor(entity)))
		end
	end

	for _, entry in pairs(byColor) do
		halo.Add(entry.list, entry.color, 2, 2, 1, true, true)
	end
end)

-- the zones
hook.Add("PostDrawTranslucentRenderables", "nwNoclip", function(bDepth, bSkybox)
	if (bSkybox or !Active() or (Z.editor and Z.editor.active)) then
		return
	end

	Z.DrawBoxes()
end)

local function Label(lines, pos, alpha)
	local screen = pos:ToScreen()

	if (!screen.visible) then
		return
	end

	local y = screen.y

	for i = #lines, 1, -1 do
		local line = lines[i]

		draw.SimpleTextOutlined(line[1], line[3] or "nwNoclip", screen.x, y, ColorAlpha(line[2], 255 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 200 * alpha))

		surface.SetFont(line[3] or "nwNoclip")

		local _, h = surface.GetTextSize(line[1])

		y = y - h
	end
end

hook.Add("HUDPaint", "nwNoclip", function()
	if (!Active()) then
		return
	end

	local me = LocalPlayer()
	local eye = me:EyePos()

	-- players
	for _, target in ipairs(player.GetAll()) do
		if (target != me) then
			local color, faction = FactionColor(target)
			local body = target:GetNW2Bool("nwKnocked", false) and target:GetNW2Entity("nwBody") or target
			local pos = IsValid(body) and (body == target and target:EyePos() + Vector(0, 0, 14) or
				body:WorldSpaceCenter() + Vector(0, 0, 20)) or target:EyePos()
			local distance = math.Round(eye:Distance(pos) / 52.5, 1)
			local state = !target:Alive() and "мёртв" or (target:GetNW2Bool("nwKnocked", false) and "без сознания" or
				(target:Health() .. " HP"))

			Label({
				{target:Nick(), color},
				{target:SteamName() .. " · " .. faction, U.color.dim, "nwNoclipSmall"},
				{state .. " · " .. distance .. " м", U.color.dim, "nwNoclipSmall"}
			}, pos, 1)
		end
	end

	-- items, containers, NPCs
	for _, entity in ipairs(ents.FindInSphere(eye, RANGE)) do
		local class = entity:GetClass()
		local alpha = math.Clamp(1.4 - eye:Distance(entity:GetPos()) / RANGE, 0.35, 1)

		if (class == "nw_item") then
			local color, name = ItemColor(entity)

			Label({{name, color, "nwNoclipSmall"}}, entity:WorldSpaceCenter() + Vector(0, 0, 8), alpha)
		elseif (class == "nw_container") then
			Label({{"▣ " .. entity:GetTitle(), U.color.hint, "nwNoclipSmall"}}, entity:WorldSpaceCenter() + Vector(0, 0, 20),
				alpha)
		elseif (class == "nw_npc") then
			Label({{entity:GetNPCName(), U.color.accent, "nwNoclipSmall"}}, entity:EyePos() + Vector(0, 0, 14), alpha)
		elseif (entity:IsNPC() and entity:Health() > 0) then
			Label({{language.GetPhrase(class), Color(230, 110, 90), "nwNoclipSmall"}},
				entity:WorldSpaceCenter() + Vector(0, 0, entity:OBBMaxs().z * 0.6), alpha)
		end
	end

	-- the zones
	if (!(Z.editor and Z.editor.active)) then
		Z.DrawLabels()
	end

	-- the strip
	local sw, sh = ScrW(), ScrH()
	local text = "НОУКЛИП · НАБЛЮДАТЕЛЬ" .. (me:GetNoDraw() and " · вас не видно" or "")

	surface.SetFont("nwNoclip")

	local tw, th = surface.GetTextSize(text)
	local w, h = tw + sh * 0.03, th + sh * 0.012
	local x, y = (sw - w) / 2, sh * 0.012

	draw.RoundedBox(4, x, y, w, h, Color(14, 16, 19, 200))
	surface.SetDrawColor(U.color.accent)
	surface.DrawRect(x, y + h - 2, w, 2)
	draw.SimpleText(text, "nwNoclip", sw / 2, y + h / 2, U.color.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
