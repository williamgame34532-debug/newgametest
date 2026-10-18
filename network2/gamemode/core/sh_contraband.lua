-- A citizen with a weapon in the hands near the Alliance: the units who can see it get a yellow notice at
-- the top right, as if from the dispatcher (the radio opens, "attention", closes):
--   «Внимание: замечен гражданский с контрабандой. Будьте осторожны.» and the zone.
-- It slides in, stays a few seconds, slides away. One suspect - not more often than every 30 s.
-- Not a weapon: the hands, the physics gun, the tool gun, the camera, the stunstick and the like.

NW.contraband = NW.contraband or {}

local CB = NW.contraband

CB.harmless = {nw_hands = true, weapon_physgun = true, gmod_tool = true, gmod_camera = true, weapon_physcannon = true,
	nw_stunstick = true, weapon_stunstick = true, weapon_fists = true}

if (SERVER) then
	util.AddNetworkString("nwContraband")

	local RANGE = 900

	local function Sees(unit, suspect)
		if (unit:GetPos():DistToSqr(suspect:GetPos()) > RANGE * RANGE) then
			return false
		end

		local trace = util.TraceLine({start = unit:EyePos(), endpos = suspect:WorldSpaceCenter(),
			filter = {unit, suspect}, mask = MASK_SOLID_BRUSHONLY})

		return !trace.Hit
	end

	function CB.Check(suspect)
		if ((suspect.nwContrabandNext or 0) > CurTime() or NW.zones.IsAlliance(suspect) or
			suspect:GetCharacterID() == 0) then
			return
		end

		local weapon = suspect:GetActiveWeapon()

		if (!IsValid(weapon) or CB.harmless[weapon:GetClass()]) then
			return
		end

		local units = {}

		for _, unit in ipairs(player.GetAll()) do
			if (unit != suspect and unit:Alive() and unit:GetCharacterID() != 0 and NW.zones.IsAlliance(unit) and
				Sees(unit, suspect)) then
				units[#units + 1] = unit
			end
		end

		if (#units == 0) then
			return
		end

		suspect.nwContrabandNext = CurTime() + 30

		local zone = NW.zones.At(NW.zones.Point(suspect))

		net.Start("nwContraband")
			net.WriteString(zone and zone.name or "")
		net.Send(units)
	end

	-- taken out: checked a moment later (the weapon is in the hands then)
	hook.Add("PlayerSwitchWeapon", "nwContraband", function(client)
		timer.Simple(0.2, function()
			if (IsValid(client)) then
				CB.Check(client)
			end
		end)
	end)

	-- or walking with it into sight
	timer.Create("nwContraband", 2, 0, function()
		for _, client in ipairs(player.GetAll()) do
			if (client:Alive()) then
				CB.Check(client)
			end
		end
	end)

	return
end

-- ------------------------------------------------------------------ client --
surface.CreateFont("nwAlertHead", {font = "Oswald Medium", size = math.max(14, math.Round(ScrH() * 0.022)), weight = 500,
	extended = true, antialias = true})
surface.CreateFont("nwAlertText", {font = "Exo 2", size = math.max(11, math.Round(ScrH() * 0.0165)), weight = 600,
	extended = true, antialias = true})

local YELLOW = Color(244, 204, 64)
local alerts = {}
local LIFE = 7

net.Receive("nwContraband", function()
	local zone = net.ReadString()

	table.insert(alerts, 1, {zone = zone, born = RealTime()})

	while (#alerts > 3) do
		table.remove(alerts)
	end

	-- as if from the dispatcher: the radio opens, the attention tone, the radio closes
	surface.PlaySound("network2/radio2/on1.wav")

	timer.Simple(0.15, function()
		surface.PlaySound("npc/overwatch/radiovoice/attention.wav")
	end)

	timer.Simple(1.3, function()
		surface.PlaySound("network2/radio2/off" .. math.random(1, 3) .. ".wav")
	end)
end)

hook.Add("HUDPaint", "nwContraband", function()
	if (#alerts == 0) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local w = math.Round(sh * 0.46)
	local h = math.Round(sh * 0.085)
	local y = math.Round(sh * 0.2)
	local now = RealTime()

	for index = #alerts, 1, -1 do
		if (now - alerts[index].born > LIFE) then
			table.remove(alerts, index)
		end
	end

	for _, alert in ipairs(alerts) do
		local age = now - alert.born
		-- in from the right with a little overshoot, out to the right at the end
		local enter = math.Clamp(age / 0.35, 0, 1)
		local leave = math.Clamp((age - (LIFE - 0.5)) / 0.5, 0, 1)
		local ease = 1 - (1 - enter) ^ 3
		local slide = (1 - ease) * (w + 40) + leave * leave * (w + 40) - math.sin(enter * math.pi) * 8
		local x = sw - w - sh * 0.02 + slide
		local a = (1 - leave)
		local blink = age < 1.2 and math.floor(age * 8) % 2 == 0

		draw.RoundedBox(4, x, y, w, h, Color(20, 16, 4, 225 * a))
		surface.SetDrawColor(YELLOW.r, YELLOW.g, YELLOW.b, 255 * a)
		surface.DrawRect(x, y, 4, h)
		surface.SetDrawColor(YELLOW.r, YELLOW.g, YELLOW.b, (blink and 120 or 50) * a)
		surface.DrawOutlinedRect(x, y, w, h, 1)

		NW.ui.DrawIcon("alert", x + h * 0.22, y + h * 0.22, h * 0.56, ColorAlpha(YELLOW, 255 * a))

		local tx = x + h * 0.95

		draw.SimpleText("ВНИМАНИЕ", "nwAlertHead", tx, y + h * 0.27, ColorAlpha(YELLOW, 255 * a), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText("Замечен гражданский с контрабандой. Будьте осторожны.", "nwAlertText", tx, y + h * 0.58,
			Color(250, 240, 210, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(alert.zone != "" and ("Зона: " .. alert.zone) or "Зона не определена", "nwAlertText", tx,
			y + h * 0.82, Color(200, 180, 120, 230 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		y = y + (h + sh * 0.01) * ease * (1 - leave)
	end
end)
