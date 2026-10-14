-- Bottom right corner, in the manner of a game's title card: a thin line with "CLOSED BETA",
-- the wide thin "NETWORK" wordmark and "WORK IN PROGRESS" under it, translucent
-- (materials/network2/watermark.png, 1024x256; branding/make_watermark.py draws it).
-- About 16% of the screen width. nw_watermark 0 hides it, nw_watermark_scale scales it.

local enabled = CreateClientConVar("nw_watermark", "1", true, false, "Логотип в углу экрана")
local size = CreateClientConVar("nw_watermark_scale", "0.16", true, false, "Ширина логотипа (доля экрана)", 0.08, 0.6)
local mark = Material("network2/watermark.png", "smooth mips")

hook.Add("HUDPaint", "nwWatermark", function()
	if (!enabled:GetBool() or (NW.menu and NW.menu.active)) then
		return
	end

	local w = math.Round(ScrW() * size:GetFloat())
	local h = math.Round(w / 4)
	local margin = math.Round(ScrH() * 0.012)

	surface.SetDrawColor(255, 255, 255, 230)
	surface.SetMaterial(mark)
	surface.DrawTexturedRect(ScrW() - margin - w, ScrH() - margin - h, w, h)
end)
