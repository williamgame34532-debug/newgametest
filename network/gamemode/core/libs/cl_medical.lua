local M = NETWORK.medical

M.giveUpHold = 3

local function Minutes(seconds)
	seconds = math.max(math.floor(seconds), 0)

	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

NETWORK.bind.Register("examine", {
	name = "bindExamine",
	OnRun = function()
		net.Start("nwMedSelf")
		net.SendToServer()
	end
})

concommand.Add("network_examine", function()
	net.Start("nwMedSelf")
	net.SendToServer()
end)

local desaturate = 0

hook.Add("RenderScreenspaceEffects", "nwMedical", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		desaturate = 0

		return
	end

	local class = M.GetBloodClass(client:GetBlood())
	local target = class == 2 and 0.25 or (class == 3 and 0.6 or (class >= 4 and 0.8 or 0))

	desaturate = math.Approach(desaturate, target, FrameTime() * 0.4)

	if (desaturate < 0.01) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.05 * desaturate,
		["$pp_colour_contrast"] = 1 - 0.1 * desaturate,
		["$pp_colour_colour"] = 1 - desaturate,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})

	if (desaturate > 0.4) then
		DrawMotionBlur(0.2, (desaturate - 0.4) * 0.8, 0.01)
	end
end)

hook.Add("HUDPaintBackground", "nwMedicalOxygen", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:HasPneumothorax()) then
		return
	end

	local lack = 1 - math.Clamp(client:GetOxygen() / M.oxygenMax, 0, 1)

	if (lack < 0.05) then
		return
	end

	local pulse = 0.85 + math.abs(math.sin(CurTime() * 0.9)) * 0.15

	NETWORK.util.DrawVignette(0, 0, ScrW(), ScrH(),
		math.Round(math.min(ScrW(), ScrH()) * (0.35 + lack * 0.4)),
		(90 + 150 * lack) * pulse, Color(0, 0, 0))
end)

local heartbeat

hook.Add("Think", "nwMedicalHeartbeat", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local severity = 0

	if (client:Alive() and client:HasCharacter()) then
		local class = M.GetBloodClass(client:GetBlood())

		if (client:IsCritical()) then
			severity = 1
		elseif (class >= 3) then
			severity = class == 3 and 0.55 or 0.8
		end
	end

	if (severity <= 0) then
		if (heartbeat) then
			heartbeat:FadeOut(1.5)
			heartbeat = nil
		end

		return
	end

	if (!heartbeat) then
		heartbeat = CreateSound(client, "player/heartbeat1.wav")
		heartbeat:PlayEx(0, 100)
	end

	local pitch = client:IsCritical() and (client:IsStable() and 90 or 75) or
		(95 + severity * 30)

	heartbeat:ChangeVolume(0.35 + severity * 0.45, 0.5)
	heartbeat:ChangePitch(pitch, 0.5)
end)

local criticalSince
local giveUpStart
local overlay = 0

hook.Add("Think", "nwMedicalGiveUp", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:IsCritical()) then
		criticalSince = nil
		giveUpStart = nil

		return
	end

	criticalSince = criticalSince or CurTime()

	if (CurTime() - criticalSince < M.giveUpAfter or gui.IsGameUIVisible() or
		vgui.GetKeyboardFocus()) then
		giveUpStart = nil

		return
	end

	if (!input.IsKeyDown(KEY_SPACE)) then
		giveUpStart = nil

		return
	end

	giveUpStart = giveUpStart or CurTime()

	if (CurTime() - giveUpStart >= M.giveUpHold) then
		giveUpStart = nil
		criticalSince = CurTime() + 5

		net.Start("nwMedGiveUp")
		net.SendToServer()
	end
end)

local function DrawCentered(text, font, x, y, color)
	NETWORK.util.DrawSimpleTextShadow(text, font, x, y, color, TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER, math.max(NETWORK.util.Scale(2), 1))
end

hook.Add("HUDPaint", "nwMedicalState", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		overlay = 0

		return
	end

	local bCritical = client:Alive() and client:IsCritical()
	local bOut = client:Alive() and client:IsUnconscious()

	overlay = math.Approach(overlay, (bCritical or bOut) and 1 or 0, FrameTime() * 1.2)

	if (overlay <= 0.005) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local width, height = ScrW(), ScrH()
	local centerX = math.Round(width * 0.5)
	local centerY = math.Round(height * 0.44)
	local alpha = util.EaseInOut(overlay)

	local pulse = 0.85 + math.abs(math.sin(CurTime() * (bCritical and 1.1 or 0.6))) * 0.15

	surface.SetDrawColor(0, 0, 0, (bCritical and 170 or 235) * alpha * pulse)
	surface.DrawRect(0, 0, width, height)

	util.DrawVignette(0, 0, width, height, math.Round(math.min(width, height) * 0.6),
		220 * alpha, bCritical and Color(90, 6, 8) or Color(0, 0, 0))

	if (!client:Alive()) then
		return
	end

	local title = util.Upper(L(bCritical and "medHudCritical" or "medHudUnconscious"))
	local titleColor = bCritical and Color(232, 96, 88) or theme.textDim

	util.DrawTextSpacedShadow(title, "nwTitle",
		centerX - math.Round(util.TextSpacedSize(title, "nwTitle", Sc(10)) * 0.5),
		centerY - Sc(90), ColorAlpha(titleColor, 250 * alpha), Sc(10),
		TEXT_ALIGN_CENTER, math.max(Sc(2), 1))

	if (!bCritical) then
		local reason = client:HasPneumothorax() and client:GetOxygen() <= 0 and
			"medHudNoAir" or "medHudBloodLoss"

		DrawCentered(L(reason), "nwField", centerX, centerY - Sc(40),
			ColorAlpha(theme.textDim, 230 * alpha))
		DrawCentered(L("medHudWait"), "nwHudSmall", centerX, centerY - Sc(14),
			ColorAlpha(theme.textFaint, 220 * alpha))

		return
	end

	local left = client:GetCriticalLeft()
	local bStable = client:IsStable()
	local fraction = math.Clamp(left / math.max(M.criticalTime, 1), 0, 1)
	local ringColor = bStable and theme.warning or Color(232, 96, 88)
	local ringY = centerY + Sc(20)

	util.DrawArc(centerX, ringY, Sc(52), Sc(5), 1, Color(0, 0, 0, 180 * alpha), 96)
	util.DrawArc(centerX, ringY, Sc(52), Sc(5), fraction,
		ColorAlpha(ringColor, 250 * alpha), 96)

	DrawCentered(Minutes(left), "nwHeader", centerX, ringY,
		ColorAlpha(theme.text, 252 * alpha))

	DrawCentered(L(bStable and "medHudStable" or "medHudBleeding"), "nwField",
		centerX, centerY - Sc(42), ColorAlpha(bStable and theme.warning or theme.text,
		240 * alpha))

	local hintY = ringY + Sc(90)

	if (criticalSince and CurTime() - criticalSince >= M.giveUpAfter) then
		local hold = giveUpStart and math.Clamp((CurTime() - giveUpStart) /
			M.giveUpHold, 0, 1) or 0

		DrawCentered(L("medHudGiveUp"), "nwHudSmall", centerX, hintY,
			ColorAlpha(theme.textDim, 230 * alpha))

		if (hold > 0) then
			local barWidth = Sc(180)

			util.DrawProgressBar(centerX - math.Round(barWidth * 0.5), hintY + Sc(16),
				barWidth, math.max(Sc(3), 2), hold, Color(232, 96, 88), alpha)
		end
	else
		DrawCentered(L("medHudWaitHelp"), "nwHudSmall", centerX, hintY,
			ColorAlpha(theme.textFaint, 220 * alpha))
	end
end)

function M.GetStatusTags(client)
	local tags = {}
	local theme = NETWORK.theme

	for part, entry in pairs(client:GetBleedMap()) do
		local data = NETWORK.wound.GetPart(part)
		local name = data and L(data.name) or part

		if (entry.tq) then
			tags[#tags + 1] = {L("medTagTourniquet", name), theme.warning}
		elseif (entry.kind == "artery") then
			tags[#tags + 1] = {L("medTagArtery", name), theme.danger}
		end
	end

	for part in pairs(M.limbs) do
		local state = client:GetFracture(part)

		if (state > 0) then
			local data = NETWORK.wound.GetPart(part)

			tags[#tags + 1] = {L(state == 2 and "medTagSplinted" or "medTagFracture",
				data and L(data.name) or part), state == 2 and theme.textDim or theme.danger}
		end
	end

	if (client:HasPneumothorax()) then
		tags[#tags + 1] = {L("medTagBreath"), theme.danger}
	end

	if (client:GetNWBool("nwTransfusing", false)) then
		tags[#tags + 1] = {L("medTagTransfusion"), theme.positive}
	end

	return tags
end

hook.Add("HUDPaint", "nwMedicalTags", function()
	local client = LocalPlayer()

	if (NETWORK.hud.IsHidden() or !IsValid(client) or client:IsUnconscious() or
		client:IsDowned()) then
		return
	end

	local tags = M.GetStatusTags(client)

	if (#tags == 0) then
		return
	end

	local Sc = NETWORK.util.Scale
	local fade = NETWORK.hud.GetFade()
	local y = math.Round(ScrH() * 0.5) + Sc(96)
	local gap = Sc(8)

	surface.SetFont("nwHudSmall")

	local widths, total = {}, 0

	for index, tag in ipairs(tags) do
		widths[index] = surface.GetTextSize(NETWORK.util.Upper(tag[1])) + Sc(18)
		total = total + widths[index] + (index > 1 and gap or 0)
	end

	local x = math.Round((ScrW() - total) * 0.5)
	local tagHeight = Sc(20)

	for index, tag in ipairs(tags) do
		local color = tag[2]
		local tagWidth = widths[index]

		draw.RoundedBox(math.max(Sc(4), 2), x, y, tagWidth, tagHeight,
			Color(8, 9, 11, 200 * fade))
		draw.RoundedBox(math.max(Sc(4), 2), x, y, math.max(Sc(3), 2), tagHeight,
			ColorAlpha(color, 230 * fade))

		draw.SimpleText(NETWORK.util.Upper(tag[1]), "nwHudSmall",
			x + math.Round(tagWidth * 0.5) + Sc(1), y + math.Round(tagHeight * 0.5),
			ColorAlpha(color, 245 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		x = x + tagWidth + gap
	end
end)

net.Receive("nwMedOpen", function()
	local patient = net.ReadEntity()
	local data = NETWORK.util.ReadTable()

	if (IsValid(NETWORK.gui.medPanel)) then
		NETWORK.gui.medPanel:Remove()
	end

	if (!IsValid(patient)) then
		return
	end

	local panel = vgui.Create("nwMedPanel")

	panel:Setup(patient, data)
end)

net.Receive("nwMedData", function()
	local patient = net.ReadEntity()
	local data = NETWORK.util.ReadTable()
	local panel = NETWORK.gui.medPanel

	if (IsValid(panel) and panel.patient == patient) then
		panel:SetData(data)
	end
end)

net.Receive("nwMedClose", function()
	if (IsValid(NETWORK.gui.medPanel)) then
		NETWORK.gui.medPanel:Close(true)
	end
end)

M.body = M.body or {}

local BODY = M.body

BODY.aspect = 256 / 600

BODY.files = {
	head = "head",
	chest = "chest",
	stomach = "stomach",
	armLeft = "armleft",
	armRight = "armright",
	legLeft = "legleft",
	legRight = "legright"
}

BODY.anchors = {
	head = {0.498, 0.079},
	chest = {0.499, 0.278},
	stomach = {0.502, 0.469},
	armLeft = {0.16, 0.36},
	armRight = {0.84, 0.36},
	legLeft = {0.32, 0.74},
	legRight = {0.68, 0.74}
}

BODY.bounds = {
	head = {0.379, 0.007, 0.613, 0.152},
	chest = {0.289, 0.152, 0.707, 0.392},
	stomach = {0.258, 0.392, 0.746, 0.535},
	armLeft = {0.016, 0.168, 0.371, 0.572},
	armRight = {0.621, 0.168, 0.98, 0.572},
	legLeft = {0.133, 0.535, 0.496, 0.992},
	legRight = {0.496, 0.535, 0.867, 0.992}
}

BODY.materials = BODY.materials or {}

function BODY.GetMaterial(id)
	local cached = BODY.materials[id]

	if (cached != nil) then
		return cached or nil
	end

	local file = id == "body" and "body" or BODY.files[id]
	local material = file and Material("framework/body/" .. file .. ".png", "smooth mips")

	if (!material or material:IsError()) then
		BODY.materials[id] = false

		return
	end

	BODY.materials[id] = material

	return material
end

function BODY.IsAvailable()
	return BODY.GetMaterial("body") != nil
end

function BODY.GetRect(x, y, width, height)
	local bodyWidth = math.min(width, height * BODY.aspect)
	local bodyHeight = bodyWidth / BODY.aspect

	return math.Round(x + (width - bodyWidth) * 0.5),
		math.Round(y + (height - bodyHeight) * 0.5),
		math.Round(bodyWidth), math.Round(bodyHeight)
end

function BODY.GetAnchor(id, x, y, width, height)
	local anchor = BODY.anchors[id]

	return math.Round(x + anchor[1] * width), math.Round(y + anchor[2] * height)
end

function BODY.PartAt(localX, localY, x, y, width, height)
	local u = (localX - x) / math.max(width, 1)
	local v = (localY - y) / math.max(height, 1)
	local best, bestDistance

	for id, box in pairs(BODY.bounds) do
		if (u >= box[1] and u <= box[3] and v >= box[2] and v <= box[4]) then
			local anchor = BODY.anchors[id]
			local distance = (u - anchor[1]) ^ 2 + ((v - anchor[2]) * 2.3) ^ 2

			if (!bestDistance or distance < bestDistance) then
				best, bestDistance = id, distance
			end
		end
	end

	return best
end

function BODY.Draw(x, y, width, height, colors, alpha, base)
	alpha = alpha or 1
	base = base or Color(46, 49, 54)

	local silhouette = BODY.GetMaterial("body")

	if (!silhouette) then
		return false
	end

	surface.SetMaterial(silhouette)
	surface.SetDrawColor(0, 0, 0, 140 * alpha)
	surface.DrawTexturedRect(x + 2, y + 4, width, height)

	surface.SetDrawColor(base.r, base.g, base.b, 255 * alpha)
	surface.DrawTexturedRect(x, y, width, height)

	for id in pairs(BODY.files) do
		local color = colors and colors[id]
		local material = color and BODY.GetMaterial(id)

		if (material) then
			surface.SetMaterial(material)
			surface.SetDrawColor(color.r, color.g, color.b, (color.a or 255) * alpha)
			surface.DrawTexturedRect(x, y, width, height)
		end
	end

	draw.NoTexture()

	return true
end

M.game = M.game or {}

local GAME = M.game

net.Receive("nwMedGame", function()
	if (!net.ReadBool()) then
		GAME.active = nil

		return
	end

	if (IsValid(NETWORK.gui.medPanel)) then
		NETWORK.gui.medPanel:Close()
	end

	if (IsValid(NETWORK.gui.tabMenu)) then
		NETWORK.gui.tabMenu:Close()
	end

	GAME.active = {
		part = net.ReadString(),
		duration = net.ReadFloat(),
		id = net.ReadString(),
		start = RealTime(),
		hits = 0,
		misses = 0,
		window = 0.22,
		speed = 0.9,
		flash = 0
	}
end)

local function MarkerPosition(game)

	local t = (RealTime() - game.start) * game.speed

	return math.abs((t % 2) - 1)
end

function GAME.Try()
	local game = GAME.active

	if (!game or game.bDone) then
		return
	end

	game.bDone = true

	local position = MarkerPosition(game)
	local bHit = math.abs(position - 0.5) <= game.window * 0.5

	if (bHit) then
		game.hits = game.hits + 1
		game.window = math.max(game.window * 0.78, 0.08)
		game.speed = game.speed + 0.25
		game.flash = 1

		surface.PlaySound("buttons/button14.wav")
	else
		game.misses = game.misses + 1
		game.flash = -1

		surface.PlaySound("buttons/button10.wav")
	end

	net.Start("nwMedGameHit")
		net.WriteBool(bHit)
	net.SendToServer()
end

hook.Add("PlayerBindPress", "nwMedGame", function(_, bind, bPressed)
	if (!GAME.active or !bPressed) then
		return
	end

	if (bind == "+attack" or bind == "+jump") then
		GAME.Try()

		return true
	end
end)

local function EnsureOverlay()
	if (IsValid(GAME.overlay)) then
		return GAME.overlay
	end

	local panel = vgui.Create("DPanel")

	panel:SetSize(ScrW(), ScrH())
	panel:SetPos(0, 0)
	panel:SetMouseInputEnabled(false)
	panel:SetKeyboardInputEnabled(false)
	panel:SetDrawOnTop(true)
	panel.Paint = function()
		GAME.Paint()
	end

	GAME.overlay = panel

	return panel
end

hook.Add("Think", "nwMedGameOverlay", function()
	if (GAME.active) then
		EnsureOverlay()
	elseif (IsValid(GAME.overlay)) then
		GAME.overlay:Remove()
		GAME.overlay = nil
	end
end)

function GAME.Paint()
	local game = GAME.active

	if (!game) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local body = M.body
	local centerX = math.Round(ScrW() * 0.5)
	local baseY = math.Round(ScrH() * 0.64) - Sc(24)
	local bodyHeight = Sc(210)
	local bodyWidth = math.Round(bodyHeight * body.aspect)
	local bx = centerX - math.Round(bodyWidth * 0.5)
	local by = baseY - bodyHeight - Sc(60)

	game.flash = util.Approach(game.flash, 0, 4)

	util.DrawSoftLight(centerX, by + math.Round(bodyHeight * 0.5), bodyWidth * 2.4,
		bodyHeight * 1.3, Color(0, 0, 0), 150)

	if (body.IsAvailable()) then
		local pulse = 0.6 + math.abs(math.sin(RealTime() * 3)) * 0.4

		body.Draw(bx, by, bodyWidth, bodyHeight, {[game.part] = ColorAlpha(theme.danger, 230 * pulse)},
			1, Color(58, 60, 66))

		local ax, ay = body.GetAnchor(game.part, bx, by, bodyWidth, bodyHeight)
		local wave = (RealTime() % 1.2) / 1.2

		util.DrawRing(ax, ay, Sc(6) + wave * Sc(22), math.max(Sc(2), 1),
			ColorAlpha(theme.danger, 200 * (1 - wave)), 32, 1)
	end

	local trackWidth = Sc(320)
	local trackX = centerX - math.Round(trackWidth * 0.5)
	local trackY = baseY - Sc(44)
	local trackHeight = Sc(10)

	local plateX = trackX - Sc(16)
	local plateY = trackY - Sc(16)
	local plateWidth = trackWidth + Sc(32)
	local plateHeight = trackHeight + Sc(32)

	draw.RoundedBox(math.max(Sc(8), 4), plateX, plateY, plateWidth, plateHeight,
		Color(8, 9, 10, 220))
	util.DrawRoundedBorder(plateX, plateY, plateWidth, plateHeight, math.max(Sc(8), 4),
		math.max(Sc(1), 1), Color(255, 255, 255, 26))

	draw.RoundedBox(math.floor(trackHeight * 0.5), trackX, trackY, trackWidth, trackHeight,
		Color(255, 255, 255, 18))

	local windowWidth = math.Round(trackWidth * game.window)

	draw.RoundedBox(math.floor(trackHeight * 0.5), centerX - math.Round(windowWidth * 0.5), trackY,
		windowWidth, trackHeight, ColorAlpha(theme.combine, 70))
	util.DrawRoundedBorder(centerX - math.Round(windowWidth * 0.5), trackY, windowWidth, trackHeight,
		math.floor(trackHeight * 0.5), math.max(Sc(1), 1), ColorAlpha(theme.combine, 220))

	local markerX = trackX + math.Round(trackWidth * MarkerPosition(game))
	local markerColor = game.flash > 0 and theme.positive or (game.flash < 0 and theme.danger or
		theme.text)

	draw.RoundedBox(2, markerX - Sc(2), trackY - Sc(8), Sc(4), trackHeight + Sc(16), markerColor)

	local hint = game.bDone and (game.flash > 0 and "Попадание!" or "Мимо…") or
		"ЛКМ / ПРОБЕЛ — когда метка в синем окне"

	draw.SimpleText(hint, "nwHudSmall", centerX, trackY - Sc(20), ColorAlpha(theme.textDim, 235),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText("ПАУЗА — лечение продолжится после попытки", "nwHudSmall", centerX,
		trackY + trackHeight + Sc(14), ColorAlpha(theme.combine, 230), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	if (game.misses > 0) then
		draw.SimpleText("промахов: " .. game.misses, "nwHudSmall", centerX + Sc(60),
			trackY + trackHeight + Sc(14), ColorAlpha(theme.danger, 220), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
end
