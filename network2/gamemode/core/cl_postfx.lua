-- In game (not in the main menu or the character screens): a brighter, punchier picture - more
-- contrast and colour, a touch of warmth, soft bloom on bright spots and a little sharpening.
-- nw_postfx 0 turns it off (Настройки in the Q menu). Plus a soft vignette (nw_vignette).

local enabled = CreateClientConVar("nw_postfx", "1", true, false, "Яркая и насыщенная картинка в игре")

local GRADE = {
	["$pp_colour_addr"] = 0.004,
	["$pp_colour_addg"] = 0.002,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0.012,
	["$pp_colour_contrast"] = 1.12,
	["$pp_colour_colour"] = 1.24,
	["$pp_colour_mulr"] = 0.02,
	["$pp_colour_mulg"] = 0.01,
	["$pp_colour_mulb"] = 0
}

hook.Add("RenderScreenspaceEffects", "nwPostFX", function()
	local client = LocalPlayer()

	if (!enabled:GetBool() or !IsValid(client) or client:GetCharacterID() == 0 or (NW.menu and NW.menu.active)) then
		return
	end

	DrawColorModify(GRADE)
	DrawBloom(0.78, 0.55, 6, 6, 1, 1, 1, 1, 1)
	DrawSharpen(0.55, 0.65)
end)

-- a soft vignette over the game (under the HUD); nw_vignette 0 turns it off
local vignette = CreateClientConVar("nw_vignette", "1", true, false, "Виньетка по краям экрана в игре")
local VIGNETTE = Material("network2/menu/vignette.png", "smooth")

hook.Add("HUDPaintBackground", "nwVignette", function()
	local client = LocalPlayer()

	if (!vignette:GetBool() or !IsValid(client) or client:GetCharacterID() == 0 or (NW.menu and NW.menu.active)) then
		return
	end

	surface.SetMaterial(VIGNETTE)
	surface.SetDrawColor(255, 255, 255, 170)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end)
