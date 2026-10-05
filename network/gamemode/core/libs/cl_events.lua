local announce

net.Receive("nwEventAnnounce", function()
	announce = {
		text = net.ReadString(),
		color = net.ReadColor(),
		duration = net.ReadFloat(),
		start = RealTime()
	}

	surface.PlaySound("ambient/alarms/klaxon1.wav")
end)

hook.Add("HUDPaint", "nwEventAnnounce", function()
	if (!announce) then
		return
	end

	local age = RealTime() - announce.start

	if (age > announce.duration) then
		announce = nil

		return
	end

	local Sc = NETWORK.util.Scale

	local fade = math.Clamp(age / 0.25, 0, 1) *
		math.Clamp((announce.duration - age) / 1, 0, 1)

	local y = ScrH() * 0.22

	surface.SetFont("nwTermTitle")

	local width = surface.GetTextSize(announce.text)

	surface.SetDrawColor(8, 9, 11, 200 * fade)
	surface.DrawRect(ScrW() * 0.5 - width * 0.5 - Sc(24), y - Sc(24),
		width + Sc(48), Sc(48))

	surface.SetDrawColor(announce.color.r, announce.color.g, announce.color.b,
		220 * fade)
	surface.DrawRect(ScrW() * 0.5 - width * 0.5 - Sc(24), y - Sc(24),
		math.max(Sc(3), 2), Sc(48))

	draw.SimpleTextOutlined(announce.text, "nwTermTitle", ScrW() * 0.5, y,
		ColorAlpha(announce.color, 255 * fade), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220 * fade))
end)

local beacons = {}

net.Receive("nwEventDrop", function()
	local origin = net.ReadVector()
	local ground = net.ReadVector()
	local color = net.ReadColor()

	beacons[#beacons + 1] = {
		origin = origin,
		ground = ground,
		color = color,
		start = RealTime()
	}
end)

local beam = Material("sprites/physbeam")

hook.Add("PostDrawTranslucentRenderables", "nwEventDrop", function(bDepth, bSky)
	if (bSky or #beacons == 0) then
		return
	end

	local now = RealTime()

	for index = #beacons, 1, -1 do
		local beacon = beacons[index]
		local age = now - beacon.start

		if (age > 60) then
			table.remove(beacons, index)

			continue
		end

		local fade = math.Clamp((60 - age) / 10, 0, 1)

		render.SetMaterial(beam)
		render.DrawBeam(beacon.ground, beacon.ground + Vector(0, 0, 800),
			48, 0, 1, ColorAlpha(beacon.color, 180 * fade))
	end
end)
