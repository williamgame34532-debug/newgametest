-- The intro when joining: a black screen, then "Network: H-L Roleplay" comes in letter by letter
-- (each rises and sharpens out of a wide spacing, a thin line opens under it), holds, goes away
-- (the letters drift apart and fade), and the black fades into the main menu. Space / Enter
-- skips it. nw_intro 0 turns it off.

local enabled = CreateClientConVar("nw_intro", "1", true, false, "Интро при заходе")
local TEXT = "Network: H-L Roleplay"

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

	-- the black
	local black = t < OUT and 1 or 1 - Ease((t - OUT) / (BLACK_OUT - OUT))

	surface.SetDrawColor(0, 0, 0, 255 * black)
	surface.DrawRect(0, 0, sw, sh)

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
	local y = sh * 0.46

	for i, char in ipairs(I.chars) do
		local appear = Ease((t - LETTERS_IN - (i - 1) * 0.045) / 0.6)
		local wide = (1 - appear) * sh * 0.012
		local alpha = 255 * appear * (1 - out)

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
