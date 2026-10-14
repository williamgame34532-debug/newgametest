-- Death, seen from the eyes. The camera stays in the head of the falling body (the ragdoll's
-- "eyes"), the head itself hidden; the colour drains, the picture darkens and blurs at the edges,
-- the heartbeat is gone. "ВЫ ПОГИБЛИ" fades in letter by letter, then the time until you can come
-- back (nw_respawn_time on the server, NW2 float nwRespawnAt) and "[ПРОБЕЛ] — очнуться".

local U = NW.ui
local state = {fade = 0}
local BLUR = Material("pp/blurscreen")

local function Fonts()
	local h = ScrH()

	surface.CreateFont("nwDeathTitle", {font = "Jura", size = math.max(28, math.Round(h * 0.06)), weight = 700,
		extended = true, antialias = true})
	surface.CreateFont("nwDeathText", {font = "Exo 2", size = math.max(14, math.Round(h * 0.021)), weight = 500,
		extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwDeathFonts", Fonts)

local function Dead(client)
	return IsValid(client) and !client:Alive() and client:GetCharacterID() != 0 and !NW.IsInMenu(client) and
		!(NW.menu and NW.menu.active)
end

hook.Add("Think", "nwDeath", function()
	local client = LocalPlayer()
	local dead = Dead(client)

	if (dead and !state.dead) then
		state.since = RealTime()
		state.angles = nil
	end

	state.dead = dead
	state.fade = math.Approach(state.fade, dead and 1 or 0, FrameTime() * (dead and 0.6 or 3))

	-- the head of the body is not in the way
	local ragdoll = dead and client:GetRagdollEntity()

	if (IsValid(ragdoll) and ragdoll != state.ragdoll) then
		state.ragdoll = ragdoll

		local head = ragdoll:LookupBone("ValveBiped.Bip01_Head1")

		if (head) then
			ragdoll:ManipulateBoneScale(head, Vector(0, 0, 0))
		end
	end
end)

hook.Add("CalcView", "nwDeath", function(client, origin, angles, fov)
	if (!Dead(client)) then
		return
	end

	local ragdoll = client:GetRagdollEntity()

	if (!IsValid(ragdoll)) then
		return
	end

	local attachment = ragdoll:LookupAttachment("eyes")
	local eyes = attachment and attachment > 0 and ragdoll:GetAttachment(attachment)

	if (!eyes) then
		return
	end

	-- smoothed, so the tumbling body does not shake the picture to pieces
	state.angles = state.angles and LerpAngle(math.min(FrameTime() * 8, 1), state.angles, eyes.Ang) or eyes.Ang

	return {origin = eyes.Pos + eyes.Ang:Forward() * 1.5, angles = state.angles, fov = fov, znear = 1,
		drawviewer = false}
end)

hook.Add("RenderScreenspaceEffects", "nwDeath", function()
	local f = state.fade

	if (f <= 0.01) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = 0.02 * f,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.12 * f,
		["$pp_colour_contrast"] = 1 - 0.2 * f,
		["$pp_colour_colour"] = 1 - 0.92 * f,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})
	DrawMotionBlur(0.2, 0.6 * f, 0.01)
end)

hook.Add("HUDPaint", "nwDeath", function()
	local f = state.fade

	if (f <= 0.01) then
		return
	end

	local sw, sh = ScrW(), ScrH()

	-- the edges blur and go dark
	surface.SetMaterial(BLUR)
	surface.SetDrawColor(255, 255, 255, 255)

	for i = 1, 2 do
		BLUR:SetFloat("$blur", i * 2 * f)
		BLUR:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(0, 0, sw, sh)
	end

	surface.SetDrawColor(0, 0, 0, 150 * f)
	surface.DrawRect(0, 0, sw, sh)

	if (!state.dead) then
		return
	end

	local age = RealTime() - (state.since or RealTime())
	local title = "ВЫ ПОГИБЛИ"
	local shown = math.Clamp(math.floor((age - 0.8) / 0.09), 0, utf8.len(title))

	if (shown > 0) then
		local text = string.sub(title, 1, (utf8.offset(title, shown + 1) or (#title + 1)) - 1)

		draw.SimpleText(text, "nwDeathTitle", sw / 2, sh * 0.42, Color(226, 222, 218, 235 * f), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	if (age < 2) then
		return
	end

	local a = math.Clamp((age - 2) / 0.8, 0, 1) * f
	local left = LocalPlayer():GetNW2Float("nwRespawnAt", 0) - CurTime()

	if (left > 0) then
		draw.SimpleText(string.format("Очнуться можно через %d с", math.ceil(left)), "nwDeathText", sw / 2,
			sh * 0.42 + sh * 0.06, Color(170, 172, 176, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	elseif (NW.interact and NW.interact.DrawKey) then
		NW.interact.DrawKey(input.LookupBinding("+jump", true) or "space", "Очнуться", sw / 2, sh * 0.42 + sh * 0.065,
			a)
	end
end)

-- no stock death camera from the base gamemode either
hook.Add("ShouldDrawLocalPlayer", "nwDeath", function(client)
	if (Dead(client)) then
		return false
	end
end)
