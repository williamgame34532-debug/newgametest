-- Weapon selection (after the Helix "Weapon Select" plugin, made minimal for this project): a
-- plain list of weapon names on the right side of the screen, the chosen one exactly in the
-- vertical middle with a thin accent mark. Only the names. Font: Montserrat (OFL,
-- resource/fonts). Wheel / number keys pick, attack takes the weapon; the list fades after a few
-- seconds. Sounds: textline_* when moving; the weapon itself makes the equip sound (sh_raise.lua).

NW.weaponSelect = NW.weaponSelect or {}

local WS = NW.weaponSelect
local U = NW.ui

WS.index = WS.index or 1
WS.delta = WS.delta or WS.index
WS.alpha = WS.alpha or 0
WS.alphaDelta = WS.alphaDelta or 0
WS.fadeTime = WS.fadeTime or 0

local function Fonts()
	local h = ScrH()

	surface.CreateFont("nwWeaponSelected", {font = "Montserrat SemiBold", size = math.max(14, math.Round(h * 0.024)),
		weight = 600, extended = true, antialias = true})
	surface.CreateFont("nwWeaponOther", {font = "Montserrat Medium", size = math.max(12, math.Round(h * 0.0185)),
		weight = 500, extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwWeaponSelectFonts", Fonts)

-- the weapons in slot order
local function Weapons(client)
	local list = {}

	for _, weapon in ipairs(client:GetWeapons()) do
		if (IsValid(weapon)) then
			list[#list + 1] = weapon
		end
	end

	table.sort(list, function(a, b)
		local sa, sb = a:GetSlot(), b:GetSlot()

		if (sa != sb) then
			return sa < sb
		end

		return a:GetSlotPos() < b:GetSlotPos()
	end)

	return list
end

-- upper case for Latin and Cyrillic (string.upper only knows ASCII)
local function Upper(text)
	local out = {}

	for _, code in utf8.codes(text) do
		if (code >= 0x430 and code <= 0x44F) then
			code = code - 0x20
		elseif (code == 0x451) then
			code = 0x401
		elseif (code >= 97 and code <= 122) then
			code = code - 32
		end

		out[#out + 1] = utf8.char(code)
	end

	return table.concat(out)
end

local function Name(weapon)
	local name = weapon.GetPrintName and weapon:GetPrintName() or weapon:GetClass()

	if (string.sub(name, 1, 1) == "#") then
		name = language.GetPhrase(string.sub(name, 2))
	end

	return Upper(name)
end

-- a plain vertical list on the right, the chosen weapon exactly in the middle of the screen
hook.Add("HUDPaint", "nwWeaponSelect", function()
	local frame = FrameTime()

	WS.alphaDelta = Lerp(math.Clamp(frame * 10, 0, 1), WS.alphaDelta, WS.alpha)

	local fraction = WS.alphaDelta

	if (fraction < 0.01) then
		return
	end

	local client = LocalPlayer()
	local weapons = Weapons(client)

	if (#weapons == 0) then
		WS.alpha = 0

		return
	end

	if (!weapons[WS.index]) then
		WS.index = #weapons
	end

	WS.delta = Lerp(math.Clamp(frame * 14, 0, 1), WS.delta, WS.index)

	local h = ScrH()
	local right = ScrW() - ScrW() * 0.03
	local middle = h * 0.5
	local step = h * 0.04

	for i, weapon in ipairs(weapons) do
		local offset = i - WS.delta
		local distance = math.abs(offset)
		local alpha = math.Clamp(1 - distance / 3.5, 0, 1) * fraction

		if (alpha > 0.01) then
			local selected = i == WS.index
			local font = selected and "nwWeaponSelected" or "nwWeaponOther"
			local y = middle + offset * step
			local x = right - (selected and 0 or h * 0.006)
			local color = selected and U.color.text or U.color.dim

			draw.SimpleText(Name(weapon), font, x - h * 0.018, y, ColorAlpha(color, 255 * alpha * (selected and 1 or 0.8)),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			-- a thin mark: long and bright for the chosen one, a dot for the rest
			if (selected) then
				surface.SetDrawColor(U.color.accent.r, U.color.accent.g, U.color.accent.b, 240 * alpha)
				surface.DrawRect(x - 3, y - h * 0.011, 3, h * 0.022)
			else
				surface.SetDrawColor(255, 255, 255, 60 * alpha)
				surface.DrawRect(x - 3, y - 1, 3, 2)
			end
		end
	end

	if (WS.fadeTime < CurTime() and WS.alpha > 0) then
		WS.alpha = 0
	end
end)

local function Changed(weapon)
	WS.alpha = 1
	WS.fadeTime = CurTime() + 5

	if (IsValid(weapon)) then
		U.Tick()
	end
end

hook.Add("PlayerBindPress", "nwWeaponSelect", function(client, bind, bPressed)
	bind = string.lower(bind)

	if (!bPressed or (!string.find(bind, "invprev", 1, true) and !string.find(bind, "invnext", 1, true) and
		!string.find(bind, "slot", 1, true) and !string.find(bind, "attack", 1, true))) then
		return
	end

	if (client:InVehicle() or vgui.CursorVisible() or (NW.menu and NW.menu.active)) then
		return
	end

	-- placing a pose (the G wheel) takes the mouse wheel and the buttons
	if (NW.wheel and NW.wheel.placing) then
		return
	end

	-- Alt + wheel is the camera distance (cl_thirdperson.lua)
	if (input.IsKeyDown(KEY_LALT) and (string.find(bind, "invprev", 1, true) or string.find(bind, "invnext", 1, true))) then
		return
	end

	local current = client:GetActiveWeapon()
	local bValid = IsValid(current)

	-- the physics gun pushes / pulls with the wheel while attack is held
	if (bValid and current:GetClass() == "weapon_physgun" and client:KeyDown(IN_ATTACK)) then
		return
	end

	local bTool = false

	if (bValid and current:GetClass() == "gmod_tool") then
		local tool = client:GetTool()

		bTool = tool and tool.Scroll != nil
	end

	local weapons = Weapons(client)

	if (#weapons == 0) then
		return
	end

	-- the list starts at the weapon in the hands
	if (WS.alpha == 0) then
		for i, weapon in ipairs(weapons) do
			if (weapon == current) then
				WS.index = i
				WS.delta = i
			end
		end
	end

	if (string.find(bind, "invprev", 1, true) and !bTool) then
		local old = WS.index

		WS.index = math.min(WS.index + 1, #weapons)

		if (WS.alpha == 0 or old != WS.index) then
			Changed(weapons[WS.index])
		end

		return true
	elseif (string.find(bind, "invnext", 1, true) and !bTool) then
		local old = WS.index

		WS.index = math.max(WS.index - 1, 1)

		if (WS.alpha == 0 or old != WS.index) then
			Changed(weapons[WS.index])
		end

		return true
	elseif (string.find(bind, "slot", 1, true)) then
		WS.index = math.Clamp(tonumber(string.match(bind, "slot(%d)")) or 1, 1, #weapons)
		Changed(weapons[WS.index])

		return true
	elseif (string.find(bind, "attack", 1, true) and WS.alpha > 0) then
		local weapon = weapons[WS.index]

		if (IsValid(weapon)) then
			input.SelectWeapon(weapon)
			WS.alpha = 0
		end

		return true
	end
end)

hook.Add("Think", "nwWeaponSelect", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		WS.alpha = 0
	end
end)

hook.Add("ScoreboardShow", "nwWeaponSelect", function()
	WS.alpha = 0
end)
