-- Actions that take time ("Одеваю", "Экипирую", ...): a ring that fills up, the action over it
-- and the seconds left inside. The server starts one (NW.progress.Start) and runs its callback
-- when the time is up; death cancels it. The ring shows in the middle of the screen a little
-- below the centre, or, with the inventory open, under its grid (NW.progress.Draw).

NW.progress = NW.progress or {}

local P = NW.progress
local meta = FindMetaTable("Player")

-- text, start, finish of the running action (or nil)
function meta:GetAction()
	local finish = self:GetNW2Float("nwActEnd", 0)

	if (finish > CurTime()) then
		return self:GetNW2String("nwActText", ""), self:GetNW2Float("nwActStart", 0), finish
	end
end

if (SERVER) then
	function P.Busy(client)
		return client:GetAction() != nil
	end

	function P.Cancel(client)
		timer.Remove("nwAction" .. client:EntIndex())
		client:SetNW2Float("nwActEnd", 0)
	end

	-- done() runs when the time is up, if check() (when given) still says yes
	function P.Start(client, text, seconds, done, check)
		if (P.Busy(client)) then
			return false
		end

		client:SetNW2String("nwActText", text)
		client:SetNW2Float("nwActStart", CurTime())
		client:SetNW2Float("nwActEnd", CurTime() + seconds)

		timer.Create("nwAction" .. client:EntIndex(), seconds, 1, function()
			if (!IsValid(client)) then
				return
			end

			client:SetNW2Float("nwActEnd", 0)

			if (client:Alive() and (!check or check())) then
				done()
			end
		end)

		return true
	end

	hook.Add("PlayerDeath", "nwProgress", P.Cancel)
	hook.Add("PlayerSpawn", "nwProgress", P.Cancel)

	return
end

-- ------------------------------------------------------------------ drawing --
local ACCENT = Color(232, 196, 72)
local TEXT = Color(234, 238, 242)

local function Fonts()
	local h = ScrH()

	surface.CreateFont("nwProgressText", {font = "Montserrat SemiBold", size = math.max(16, math.Round(h * 0.026)),
		weight = 600, extended = true, antialias = true})
	surface.CreateFont("nwProgressTime", {font = "Exo 2", size = math.max(14, math.Round(h * 0.021)), weight = 600,
		extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwProgressFonts", Fonts)

local function Arc(cx, cy, r1, r2, a1, a2, color)
	local steps = math.max(2, math.ceil((a2 - a1) / 6))

	draw.NoTexture()
	surface.SetDrawColor(color)

	for i = 0, steps - 1 do
		local s = math.rad(a1 + (a2 - a1) * i / steps)
		local e = math.rad(a1 + (a2 - a1) * (i + 1) / steps)

		surface.DrawPoly({
			{x = cx + math.cos(s) * r1, y = cy + math.sin(s) * r1},
			{x = cx + math.cos(s) * r2, y = cy + math.sin(s) * r2},
			{x = cx + math.cos(e) * r2, y = cy + math.sin(e) * r2},
			{x = cx + math.cos(e) * r1, y = cy + math.sin(e) * r1}
		})
	end
end

P.fade = 0

-- the ring at x, y (its centre); returns false when there is nothing to show
function P.Draw(x, y, alpha)
	local client = LocalPlayer()
	local text, start, finish = client:GetAction()

	if (text) then
		P.last = {text = text, start = start, finish = finish}
	end

	P.fade = math.Approach(P.fade, text and 1 or 0, FrameTime() * 6)

	local last = P.last

	if (P.fade <= 0 or !last) then
		return false
	end

	local sh = ScrH()
	local a = P.fade * (alpha or 1)
	local r = math.Round(sh * 0.047)
	local width = math.max(4, math.Round(sh * 0.0068))
	local fraction = math.Clamp((CurTime() - last.start) / math.max(last.finish - last.start, 0.01), 0, 1)
	local left = math.max(0, last.finish - CurTime())

	-- a dark disc, the track, the fill
	Arc(x, y, 0, r, 0, 360, Color(10, 12, 14, 170 * a))
	Arc(x, y, r - width, r, 0, 360, Color(255, 255, 255, 22 * a))
	Arc(x, y, r - width, r, -90, -90 + 360 * fraction, ColorAlpha(ACCENT, 240 * a))

	draw.SimpleText(string.format("%.1f с", left), "nwProgressTime", x, y, ColorAlpha(TEXT, 255 * a),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleTextOutlined(last.text, "nwProgressText", x, y - r - sh * 0.01, ColorAlpha(TEXT, 255 * a),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 160 * a))

	return true
end

-- without the inventory: in the middle, a little below the centre
hook.Add("HUDPaint", "nwProgress", function()
	if (NW.inventory and NW.inventory.IsOpen and NW.inventory.IsOpen()) then
		return
	end

	P.Draw(ScrW() / 2, ScrH() * 0.64)
end)
