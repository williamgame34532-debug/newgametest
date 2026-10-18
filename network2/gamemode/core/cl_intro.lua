-- The intro when joining: the splash (materials/network2/menu/splash.jpg, branding/make_splash.py - the
-- emblem pressed into a dark wall) comes out of the black and slowly closes in, then
-- "Network: H-L Roleplay" comes in letter by letter at the bottom
-- (each rises and sharpens out of a wide spacing, a thin line opens under it), holds, goes away
-- (the letters drift apart and fade), and the black fades into the main menu. Space / Enter
-- skips it. nw_intro 0 turns it off.

local enabled = CreateClientConVar("nw_intro", "1", true, false, "Интро при заходе")
local TEXT = "Network: H-L Roleplay"
local SPLASH = Material("network2/menu/splash.jpg", "smooth")
local VIGNETTE = Material("network2/menu/vignette.png", "smooth")

local I = {}

surface.CreateFont("nwIntro", {font = "Jura", size = math.max(24, math.Round(ScrH() * 0.058)), weight = 700,
	extended = true, antialias = true})

-- the timeline (seconds)
local LETTERS_IN, HOLD, OUT, BLACK_OUT = 1.0, 4.6, 5.6, 6.9

local function Ease(t)
	t = math.Clamp(t, 0, 1)

	return 1 - (1 - t) ^ 3
end

hook.Add("InitPostEntity", "nwIntro", function()
	if (!enabled:GetBool()) then
		return
	end

	I.start = RealTime()
	I.sound = false

	local chars = {}

	for _, code in utf8.codes(TEXT) do
		chars[#chars + 1] = utf8.char(code)
	end

	I.chars = chars
end)

hook.Add("Think", "nwIntro", function()
	if (!I.start) then
		return
	end

	local t = RealTime() - I.start

	if (!I.sound and t >= LETTERS_IN) then
		I.sound = true
		surface.PlaySound("network2/ui/char/hls_ui_appear.wav")
	end

	-- skip: straight to the end of the text
	if (t > 0.5 and t < OUT and (input.IsKeyDown(KEY_SPACE) or input.IsKeyDown(KEY_ENTER))) then
		I.start = RealTime() - OUT
	end

	if (t > BLACK_OUT) then
		I.start = nil
	end
end)

hook.Add("DrawOverlay", "nwIntro", function()
	if (!I.start) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local t = RealTime() - I.start

	-- the splash out of the black, closing in slowly; all of it fades into the menu at the end
	local gone = t < OUT and 1 or 1 - Ease((t - OUT) / (BLACK_OUT - OUT))
	local shown = Ease(t / 1.2)
	local zoom = 1 + 0.04 * Ease(t / BLACK_OUT)
	local iw, ih = sw * zoom, sw * zoom * 9 / 16

	if (ih < sh * zoom) then
		iw, ih = sh * zoom * 16 / 9, sh * zoom
	end

	surface.SetDrawColor(0, 0, 0, 255 * gone)
	surface.DrawRect(0, 0, sw, sh)
	surface.SetMaterial(SPLASH)
	surface.SetDrawColor(255, 255, 255, 255 * gone * shown)
	surface.DrawTexturedRect((sw - iw) / 2, (sh - ih) / 2, iw, ih)

	-- a band of light passes slowly over the wall and the emblem
	local sweep = ((t - 0.6) / 3.2)

	if (sweep > 0 and sweep < 1.3) then
		local bx = -sw * 0.3 + sweep * sw * 1.3
		local band = sw * 0.12

		for i = 0, 15 do
			local k = 1 - math.abs(i - 7.5) / 7.5

			surface.SetDrawColor(180, 210, 240, 10 * k * gone * shown)
			surface.DrawRect(bx + i * band / 16, 0, band / 16 + 1, sh)
		end
	end

	-- dust in the light: slow points drifting up
	I.dust = I.dust or {}

	if (#I.dust == 0) then
		for i = 1, 70 do
			I.dust[i] = {x = math.Rand(0, 1), y = math.Rand(0, 1), s = math.Rand(1, 2.6), v = math.Rand(0.006, 0.02),
				p = math.Rand(0, 6)}
		end
	end

	for _, mote in ipairs(I.dust) do
		local my = (mote.y - t * mote.v) % 1
		local mx = mote.x + math.sin(t * 0.4 + mote.p) * 0.01

		surface.SetDrawColor(200, 220, 240, (30 + 30 * math.sin(t + mote.p)) * gone * shown)
		surface.DrawRect(mx * sw, my * sh, mote.s, mote.s)
	end

	-- the corners breathe darker
	surface.SetMaterial(VIGNETTE)
	surface.SetDrawColor(0, 0, 0, (120 + 40 * math.sin(t * 0.8)) * gone)
	surface.DrawTexturedRect(0, 0, sw, sh)

	if (t < LETTERS_IN or t > OUT + 0.6) then
		return
	end

	-- the text going away: drifting apart and fading
	local out = t > HOLD and Ease((t - HOLD) / (OUT - HOLD)) or 0

	surface.SetFont("nwIntro")

	local spacing = sh * 0.006 + out * sh * 0.02
	local widths, total = {}, 0

	for i, char in ipairs(I.chars) do
		widths[i] = surface.GetTextSize(char)
		total = total + widths[i] + (i < #I.chars and spacing or 0)
	end

	local x = (sw - total) / 2
	local y = sh * 0.84

	for i, char in ipairs(I.chars) do
		local appear = Ease((t - LETTERS_IN - (i - 1) * 0.045) / 0.6)
		local wide = (1 - appear) * sh * 0.012
		local alpha = 255 * appear * (1 - out)

		-- a soft cold glow under each letter, then the letter
		draw.SimpleText(char, "nwIntro", x + wide * (i - #I.chars / 2) * 0.3 + 1, y + (1 - appear) * sh * 0.015 + 2,
			Color(0, 0, 0, alpha * 0.6), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(char, "nwIntro", x + wide * (i - #I.chars / 2) * 0.3, y + (1 - appear) * sh * 0.015,
			Color(236, 240, 244, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		x = x + widths[i] + spacing
	end

	-- the line under it opens from the middle
	local line = Ease((t - LETTERS_IN - 0.5) / 1.0) * (1 - out)
	local lw = sh * 0.42 * line

	surface.SetDrawColor(64, 190, 240, 200 * line)
	surface.DrawRect(sw / 2 - lw / 2, y + sh * 0.045, lw, 1)
end)
