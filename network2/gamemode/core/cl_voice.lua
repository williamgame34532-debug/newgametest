-- Voice chat, seen: no stock voice panels. While you talk, a microphone stands next to the
-- NETWORK logo (bottom right) with "Говорю...", "Шепчу..." or "Кричу..." (the range from the G
-- wheel) over it; over the head of everyone who talks, an animated microphone. The microphone
-- (materials/network2/ui/mic_*.png, branding/make_mic.py): the capsule fills up with the voice,
-- waves run out on both sides, it sways a little.

NW.voice = NW.voice or {}

local V = NW.voice
local U = NW.ui
local FRAME = Material("network2/ui/mic_frame.png", "smooth mips")
local FILL = Material("network2/ui/mic_fill.png", "smooth mips")
local WAVE = Material("network2/ui/mic_wave.png", "smooth mips")
local ACCENT = Color(232, 196, 72)

-- the inside of the capsule on the texture (top / bottom, 0..1)
local FILL_TOP, FILL_BOTTOM = 44 / 256, 130 / 256

local WORDS = {"Шепчу", "Говорю", "Кричу"}

surface.CreateFont("nwVoiceText", {font = "Montserrat SemiBold", size = math.max(12, math.Round(ScrH() * 0.016)),
	weight = 600, extended = true, antialias = true})

-- no stock panels
function GM:PlayerStartVoice(client)
end

function GM:PlayerEndVoice(client)
end

hook.Add("InitPostEntity", "nwVoicePanels", function()
	if (IsValid(g_VoicePanelList)) then
		g_VoicePanelList:Remove()
	end
end)

-- how loud a player is now, smoothed
function V.Level(client)
	local now = client:IsSpeaking() and math.Clamp(client:VoiceVolume() * 2.2, 0, 1) or 0

	client.nwVoiceLevel = Lerp(math.Clamp(FrameTime() * 14, 0, 1), client.nwVoiceLevel or 0, now)
	client.nwVoiceShow = math.Approach(client.nwVoiceShow or 0, client:IsSpeaking() and 1 or 0, FrameTime() * 5)

	return client.nwVoiceLevel, client.nwVoiceShow
end

-- the microphone at x, y (its top left), size, how loud (0..1), alpha (0..1); works in 3D2D too
function V.DrawMic(x, y, size, level, alpha, color)
	color = color or ACCENT

	local t = RealTime()

	-- waves on both sides, growing with the voice
	for i = 1, 2 do
		local phase = (t * 1.6 + i * 0.5) % 1
		local grow = 1 + phase * 0.35 * (0.4 + level)
		local a = alpha * (1 - phase) * math.Clamp(level * 1.6, 0.15, 1)
		local ws = size * grow
		local off = (ws - size) / 2

		surface.SetMaterial(WAVE)
		surface.SetDrawColor(255, 255, 255, 200 * a)
		surface.DrawTexturedRect(x - off, y - off * 0.6, ws, ws)
		surface.DrawTexturedRectUV(x - off, y - off * 0.6, ws, ws, 1, 0, 0, 1)
	end

	-- the fill from the bottom of the capsule
	local fill = math.Clamp(0.12 + level * 0.88, 0, 1)
	local v0 = FILL_BOTTOM - (FILL_BOTTOM - FILL_TOP) * fill

	surface.SetMaterial(FILL)
	surface.SetDrawColor(color.r, color.g, color.b, 235 * alpha)
	surface.DrawTexturedRectUV(x, y + size * v0, size, size * (FILL_BOTTOM - v0), 0, v0, 1, FILL_BOTTOM)

	surface.SetMaterial(FRAME)
	surface.SetDrawColor(255, 255, 255, 255 * alpha)
	surface.DrawTexturedRect(x, y, size, size)
end

-- next to the logo while you talk
hook.Add("HUDPaint", "nwVoiceSelf", function()
	local client = LocalPlayer()

	if (!IsValid(client) or (NW.menu and NW.menu.active)) then
		return
	end

	local level, show = V.Level(client)

	if (show <= 0.01) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local scale = GetConVar("nw_watermark_scale")
	local w = math.Round(sw * (scale and scale:GetFloat() or 0.16))
	local h = math.Round(w / 4)
	local margin = math.Round(sh * 0.012)
	local size = math.Round(h * 0.95)
	local x = sw - margin - w - size - math.Round(sh * 0.01)
	local y = sh - margin - h + (h - size) / 2 + (1 - show) * sh * 0.01

	V.DrawMic(x, y, size, level, show)

	local mode = client.GetVoiceMode and client:GetVoiceMode() or 2
	local dots = string.rep(".", math.floor(RealTime() * 3) % 3 + 1)

	draw.SimpleTextOutlined((WORDS[mode] or WORDS[2]) .. dots, "nwVoiceText", x + size / 2, y - sh * 0.004,
		ColorAlpha(U.color.text, 255 * show), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 140 * show))
end)
