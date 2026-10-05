local scene
local startTime = 0

net.Receive("nwCutscenePlay", function()
	scene = NETWORK.util.ReadTable()
	startTime = CurTime()
end)

net.Receive("nwCutsceneStop", function()
	scene = nil
end)

function NETWORK.cutscene.IsPlaying()
	return scene != nil
end

local function Shot(data)
	return Vector(data.pos[1], data.pos[2], data.pos[3]),
		Angle(data.ang[1], data.ang[2], data.ang[3]), data.fov or 75
end

NETWORK.view.Register("cutscene", 950, function(client, view)
	if (!scene) then
		return
	end

	local time = CurTime() - startTime
	local length = NETWORK.cutscene.GetLength(scene)

	if (time >= length) then
		scene = nil

		return
	end

	local from, to, fraction = NETWORK.cutscene.Resolve(scene, time)

	if (!from or !to) then
		return
	end

	local fromPos, fromAng, fromFov = Shot(from)
	local toPos, toAng, toFov = Shot(to)
	local ease = NETWORK.util.EaseInOut(fraction)

	view.origin = LerpVector(ease, fromPos, toPos)
	view.angles = LerpAngle(ease, fromAng, toAng)
	view.fov = Lerp(ease, fromFov, toFov)
	view.drawviewer = true

	return true
end)

hook.Add("HUDShouldDraw", "nwCutscene", function(element)
	if (scene and element != "CHudChat") then
		return false
	end
end)

hook.Add("NetworkShouldDrawHUD", "nwCutscene", function()
	if (scene) then
		return false
	end
end)

hook.Add("HUDPaint", "nwCutscene", function()
	if (!scene) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local time = CurTime() - startTime
	local length = NETWORK.cutscene.GetLength(scene)
	local _, shot, _, index = NETWORK.cutscene.Resolve(scene, time)

	local open = math.min(math.Clamp(time / 0.5, 0, 1),
		math.Clamp((length - time) / 0.5, 0, 1))
	local bar = math.Round(ScrH() * 0.11 * util.EaseOut(open))

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, ScrW(), bar)
	surface.DrawRect(0, ScrH() - bar, ScrW(), bar)

	if (open < 0.5) then
		return
	end

	if (shot and shot.text and shot.text != "") then
		draw.SimpleText(shot.text, "nwTipTitle", math.Round(ScrW() * 0.5),
			ScrH() - math.Round(bar * 0.5),
			ColorAlpha(NETWORK.theme.text, 250 * open), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	local barWidth = math.Round(ScrW() * 0.2)
	local barX = math.Round((ScrW() - barWidth) * 0.5)

	util.DrawProgressBar(barX, math.Round(bar * 0.5), barWidth,
		math.max(Sc(3), 2), math.Clamp(time / length, 0, 1),
		NETWORK.theme.accent, open * 0.8)

	draw.SimpleText(index .. " / " .. #scene.shots, "nwHudSmall",
		barX + barWidth + Sc(12), math.Round(bar * 0.5) + 1,
		ColorAlpha(NETWORK.theme.textFaint, 220 * open), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
end)
