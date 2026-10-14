-- Notifications: plain text at the top centre of the screen. Each one slides down and fades in
-- with the hint sound (sound/network2/ui/hls_hint.wav), stays 10 seconds and fades out; newer ones
-- push the older ones down (at most 5). Used for everything the server tells a player: an unknown
-- command, no room in the inventory, a refused request...
--   server  NW.Notify(client, text)       (client: a player or a list of players)
--   client  NW.notify.Add(text)
-- The old chat notices (nwChatNotice) show here too.

NW.notify = NW.notify or {}

local NT = NW.notify

if (SERVER) then
	util.AddNetworkString("nwNotify")

	function NW.Notify(client, text)
		net.Start("nwNotify")
			net.WriteString(tostring(text))
		net.Send(client)
	end

	return
end

local SOUND = "network2/ui/hls_hint.wav"
local LIFE = 10
local MAX = 5
local ACCENT = Color(232, 196, 72)

NT.list = NT.list or {}

local function Fonts()
	surface.CreateFont("nwNotify", {font = "Montserrat SemiBold", size = math.max(14, math.Round(ScrH() * 0.021)),
		weight = 600, extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwNotifyFonts", Fonts)

function NT.Add(text)
	text = string.Trim(tostring(text or ""))

	if (text == "") then
		return
	end

	-- the same text again: just renew it
	for _, entry in ipairs(NT.list) do
		if (entry.text == text) then
			entry.born = RealTime()

			surface.PlaySound(SOUND)

			return
		end
	end

	table.insert(NT.list, 1, {text = text, born = RealTime(), y = nil})

	while (#NT.list > MAX) do
		table.remove(NT.list)
	end

	surface.PlaySound(SOUND)
	MsgN("[!] " .. text)
end

net.Receive("nwNotify", function()
	NT.Add(net.ReadString())
end)

hook.Add("HUDPaint", "nwNotify", function()
	if (#NT.list == 0) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local now = RealTime()
	local pad = math.Round(sh * 0.012)
	local gap = math.Round(sh * 0.008)
	local y = math.Round(sh * 0.035)
	local dt = math.min(FrameTime(), 0.1)

	surface.SetFont("nwNotify")

	local _, th = surface.GetTextSize("Ag")
	local h = th + pad * 1.4

	for index = #NT.list, 1, -1 do
		if (now - NT.list[index].born > LIFE) then
			table.remove(NT.list, index)
		end
	end

	for _, entry in ipairs(NT.list) do
		local age = now - entry.born
		local appear = math.Clamp(age / 0.35, 0, 1)
		local leave = math.Clamp((LIFE - age) / 0.6, 0, 1)
		local ease = 1 - (1 - appear) ^ 3
		local a = ease * leave

		-- slides to its place in the stack
		entry.y = entry.y and Lerp(math.min(dt * 10, 1), entry.y, y) or y

		local tw = surface.GetTextSize(entry.text)
		local w = tw + pad * 2 + 10
		local x = math.Round((sw - w) / 2)
		local top = math.Round(entry.y - (1 - ease) * sh * 0.025)

		draw.RoundedBox(6, x, top, w, h, Color(10, 12, 15, 200 * a))
		draw.RoundedBox(2, x + pad * 0.6, top + h * 0.28, 3, h * 0.44, ColorAlpha(ACCENT, 255 * a))
		draw.SimpleText(entry.text, "nwNotify", x + pad + 10, top + h / 2, Color(236, 238, 242, 255 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		y = y + (h + gap) * leave
	end
end)
