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

-- ----------------------------------------------------------- soft light (HDR) --
-- A softer, kinder light (nw_softlight, Настройки → Изображение), in the manner of HDR:
--   the eyes adapt   the light where you stand (render.GetLightColor) is measured all the time: in the
--                    dark the picture opens up a little, in bright light it holds back, slowly, like
--                    eyes getting used to it
--   the highlights   rolled off instead of burning: a lower contrast on top, a wide soft bloom that
--                    lets bright windows and lamps glow into the air around them
--   the sun          rays through gaps when the sun of the map is in view (util.GetSunInfo)
--   the warmth       a faint warm lift of the light colours, a cool touch in the shadows
local soft = CreateClientConVar("nw_softlight", "1", true, false, "Мягкий свет (HDR)")
local strength = CreateClientConVar("nw_softlight_strength", "1", true, false, "Сила мягкого света (0..2)")

local exposure = 0

hook.Add("RenderScreenspaceEffects", "nwSoftLight", function()
	local client = LocalPlayer()

	if (!soft:GetBool() or !IsValid(client) or client:GetCharacterID() == 0 or (NW.menu and NW.menu.active) or
		(NW.ThermalOn and NW.ThermalOn())) then
		return
	end

	local k = math.Clamp(strength:GetFloat(), 0, 2)

	-- the eyes: the light around (0 dark .. 1 bright), followed slowly
	local light = render.GetLightColor(EyePos())
	local luminance = math.Clamp(light.x * 0.3 + light.y * 0.59 + light.z * 0.11, 0, 1.5)
	local want = math.Clamp((0.35 - luminance) * 0.18, -0.06, 0.07)

	exposure = Lerp(math.Clamp(FrameTime() * 0.6, 0, 1), exposure, want)

	DrawColorModify({
		["$pp_colour_addr"] = 0.006 * k,
		["$pp_colour_addg"] = 0.003 * k,
		["$pp_colour_addb"] = 0.004 * k,
		["$pp_colour_brightness"] = exposure * k,
		["$pp_colour_contrast"] = 1 - 0.06 * k,
		["$pp_colour_colour"] = 1 - 0.04 * k,
		["$pp_colour_mulr"] = 0.015 * k,
		["$pp_colour_mulg"] = 0.008 * k,
		["$pp_colour_mulb"] = 0
	})

	-- the glow of the bright places into the air
	DrawBloom(0.62, 0.35 * k, 10, 10, 3, 1.1, 1, 0.92, 0.82)

	-- the sun through the gaps
	local sun = util.GetSunInfo()

	if (sun and sun.direction and sun.obstruction and sun.obstruction > 0) then
		local screen = (EyePos() + sun.direction * 4096):ToScreen()
		local facing = EyeAngles():Forward():Dot(sun.direction)

		if (facing > 0.3) then
			DrawSunbeams(0.85, 0.035 * k * sun.obstruction * facing, 0.22, screen.x / ScrW(), screen.y / ScrH())
		end
	end
end)
