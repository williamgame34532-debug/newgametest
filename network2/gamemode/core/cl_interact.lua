-- What can be used nearby. Within reach small round marks appear and grow as you come closer:
-- items show their own icon in their middle, doors a door icon on the handle, other usable
-- entities (scripted ones, buttons) a hand in their middle. The one you look at is bigger and
-- gold, and at the bottom of the screen: [E] Взять <item> / Открыть дверь / Взаимодействовать с
-- <name> (the key is the real +use key, on materials/network2/ui/key.png).

local U = NW.ui
local I = NW.items

local KEY = Material("network2/ui/key.png", "smooth")
local ACCENT = Color(232, 196, 72)
local RANGE = 160
local USE_RANGE = 110

local DOORS = {prop_door_rotating = true, func_door = true, func_door_rotating = true}
-- entities of the engine and the base gamemode that are never something to use
local SERVICE = {gmod_hands = true, physgun_beam = true, predicted_viewmodel = true, nw_item = true}
local BUTTONS = {func_button = true, gmod_button = true, func_rot_button = true}

surface.CreateFont("nwInteract", {font = "Montserrat SemiBold", size = math.max(13, math.Round(ScrH() * 0.019)),
	weight = 600, extended = true, antialias = true})
surface.CreateFont("nwInteractKey", {font = "Montserrat SemiBold", size = math.max(12, math.Round(ScrH() * 0.017)),
	weight = 700, extended = true, antialias = true})

NW.interact = NW.interact or {}

-- [key] text, centred on x (y is the middle); used here and over players (cl_overhead.lua)
function NW.interact.DrawKey(key, text, cx, y, alpha)
	local sh = ScrH()
	local ks = math.Round(sh * 0.036)
	local gap = math.Round(sh * 0.01)

	alpha = alpha or 1
	surface.SetFont("nwInteract")

	local tw = surface.GetTextSize(text)

	-- a long key name (SPACE, ENTER) gets a wider cap
	key = U.Upper(key)
	surface.SetFont("nwInteractKey")

	local kw = math.max(ks, surface.GetTextSize(key) + ks * 0.55)
	local x = math.Round(cx - (kw + gap + tw) / 2)

	y = math.Round(y)

	surface.SetMaterial(KEY)
	surface.SetDrawColor(255, 255, 255, 255 * alpha)
	surface.DrawTexturedRect(x, y - ks / 2, kw, ks)
	draw.SimpleText(key, "nwInteractKey", x + kw / 2, y - 1, ColorAlpha(U.color.text, 255 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleTextOutlined(text, "nwInteract", x + kw + gap, y, ColorAlpha(U.color.text, 255 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 170 * alpha))
end

-- what kind of thing, or nil
local function Kind(entity)
	if (!IsValid(entity) or entity:IsPlayer() or entity:IsNPC() or entity:IsWeapon()) then
		return
	end

	local class = entity:GetClass()

	-- a body: unconscious or dead (the E wheel: cl_social.lua)
	if (class == "prop_ragdoll") then
		return (entity:GetNW2Bool("nwCorpse", false) or IsValid(entity:GetNW2Entity("nwPlayer"))) and "body" or nil
	end

	if (class == "nw_item") then
		return "item"
	elseif (DOORS[class]) then
		return "door"
	elseif (BUTTONS[class]) then
		return "entity"
	end

	-- a scripted entity of the world; not what goes with a player (the first person hands gmod_hands,
	-- the physics gun beam: in third person a mark would follow the character), nothing hidden or
	-- without a body
	if (entity:IsScripted() and !entity:IsWeapon() and !SERVICE[class] and !entity:GetNoDraw() and
		entity:GetSolid() != SOLID_NONE) then
		local owner = entity:GetOwner()
		local parent = entity:GetParent()

		if (!(IsValid(owner) and owner:IsPlayer()) and !(IsValid(parent) and parent:IsPlayer())) then
			return "entity"
		end
	end
end

-- the door handle: on the far side from the hinge, at hand height
local function Handle(entity)
	if (entity:GetClass() != "prop_door_rotating") then
		return entity:WorldSpaceCenter()
	end

	local mins, maxs = entity:OBBMins(), entity:OBBMaxs()
	local size = maxs - mins
	local axis = size.x > size.y and "x" or "y"
	local far = math.abs(maxs[axis]) > math.abs(mins[axis]) and maxs[axis] or mins[axis]
	local spot = (mins + maxs) / 2

	spot[axis] = far * 0.84
	spot.z = mins.z + size.z * 0.45

	return entity:LocalToWorld(spot)
end

local function Where(entity, kind)
	if (kind == "door") then
		return Handle(entity)
	end

	return entity:WorldSpaceCenter()
end

local function Name(entity)
	local name = entity.PrintName

	if (!name or name == "") then
		name = language.GetPhrase(entity:GetClass())
	end

	return name
end

local function Prompt(entity, kind)
	if (kind == "item") then
		local item = entity:GetItem()

		return "Взять " .. (item and item.name or "предмет")
	elseif (kind == "door") then
		return "Открыть дверь"
	elseif (kind == "body") then
		-- the same for the dead and the unconscious: only the pulse tells them apart
		return "Осмотреть человека"
	elseif (entity:GetClass() == "nw_container") then
		return "Открыть: " .. entity:GetTitle()
	elseif (entity:GetClass() == "nw_npc") then
		return "Поговорить: " .. entity:GetNPCName()
	end

	return "Взаимодействовать с " .. Name(entity)
end

-- entity -> {kind, focus, shown, near}: kept between scans, so the marks fade and grow smoothly
-- instead of starting over every scan
local marks = {}
local nextScan = 0
local prompt = {alpha = 0}

local function Hidden(client)
	return !IsValid(client) or !client:Alive() or client:GetCharacterID() == 0 or (NW.menu and NW.menu.active) or
		vgui.CursorVisible() or client:InVehicle()
end

hook.Add("HUDPaint", "nwInteract", function()
	local client = LocalPlayer()

	if (Hidden(client)) then
		return
	end

	local eye = client:EyePos()

	-- what is around (a few times a second)
	if (RealTime() > nextScan) then
		nextScan = RealTime() + 0.2

		for _, mark in pairs(marks) do
			mark.inRange = false
		end

		for _, entity in ipairs(ents.FindInSphere(eye, RANGE)) do
			local kind = Kind(entity)

			if (kind) then
				local mark = marks[entity] or {kind = kind, focus = 0, shown = 0, near = 0}

				mark.inRange = true
				marks[entity] = mark
			end
		end
	end

	local trace = client:GetEyeTrace()
	local aimed = trace.Entity
	local aimedKind = IsValid(aimed) and trace.HitPos:DistToSqr(eye) < USE_RANGE * USE_RANGE and Kind(aimed)
	local sh = ScrH()
	local dt = math.Clamp(FrameTime(), 0, 0.1)

	for entity, mark in pairs(marks) do
		if (!IsValid(entity)) then
			marks[entity] = nil

			continue
		end

		local pos = Where(entity, mark.kind)
		local distance = pos:Distance(eye)
		local screen = pos:ToScreen()
		local seen = mark.inRange and distance <= RANGE and screen.visible and
			!util.TraceLine({start = eye, endpos = pos, filter = {client, entity}, mask = MASK_VISIBLE}).Hit

		mark.shown = math.Approach(mark.shown, seen and 1 or 0, dt * 5)
		mark.focus = math.Approach(mark.focus, (seen and entity == aimed and aimedKind) and 1 or 0, dt * 7)
		mark.near = Lerp(math.min(dt * 8, 1), mark.near, math.Clamp((RANGE - distance) / (RANGE * 0.6), 0, 1))

		if (mark.shown <= 0) then
			if (!mark.inRange) then
				marks[entity] = nil
			end

			continue
		end

		local ease = mark.shown * mark.shown * (3 - 2 * mark.shown)
		local focus = mark.focus * mark.focus * (3 - 2 * mark.focus)
		local size = sh * (0.016 + mark.near * 0.008 + focus * 0.01) * (0.7 + ease * 0.3)
		local alpha = math.Clamp(mark.near * 1.4, 0, 1) * (0.6 + focus * 0.4) * ease
		local x, y = math.Round(screen.x), math.Round(screen.y)
		local r = math.Round(size * 0.85)

		-- a gold ring around the one you look at
		if (focus > 0.01) then
			local o = r + 2

			draw.RoundedBox(o, x - o, y - o, o * 2, o * 2, Color(ACCENT.r, ACCENT.g, ACCENT.b, 220 * focus * alpha))
		end

		draw.RoundedBox(r, x - r, y - r, r * 2, r * 2, Color(12, 14, 17, 225 * alpha))

		local material, color

		if (mark.kind == "item") then
			local item = entity:GetItem()
			local cat = item and (I.categories[item.category] or I.categories.misc)

			material = U.Material("network2/items/" .. (item and item.icon or "bag") .. ".png")
			color = cat and cat.color or U.color.text
		elseif (mark.kind == "door") then
			material = U.Icon("door")
			color = U.color.text
		elseif (mark.kind == "body") then
			material = U.Icon("examine")
			color = Color(214, 120, 110)
		elseif (entity:GetClass() == "nw_container") then
			material = U.Icon("storage")
			color = U.color.text
		elseif (entity:GetClass() == "nw_npc") then
			material = U.Icon("talk")
			color = U.color.text
		else
			material = U.Icon("interact")
			color = U.color.text
		end

		local is = math.Round(size * 0.95)
		local c = Color(Lerp(focus, color.r, ACCENT.r), Lerp(focus, color.g, ACCENT.g), Lerp(focus, color.b, ACCENT.b))

		surface.SetMaterial(material)
		surface.SetDrawColor(c.r, c.g, c.b, 255 * alpha)
		surface.DrawTexturedRect(x - is / 2, y - is / 2, is, is)
	end

	-- the prompt at the bottom: fades in and out, keeps the last text while fading
	if (aimedKind) then
		prompt.text = Prompt(aimed, aimedKind)
	end

	prompt.alpha = math.Approach(prompt.alpha, aimedKind and 1 or 0, dt * 6)

	if (prompt.alpha > 0 and prompt.text) then
		NW.interact.DrawKey(input.LookupBinding("+use", true) or "E", prompt.text, ScrW() / 2,
			sh * 0.79 + (1 - prompt.alpha) * sh * 0.01, prompt.alpha)
	end
end)
