NETWORK.factory = NETWORK.factory or {}

local F = NETWORK.factory

local PLATE_FILL = Color(10, 13, 17, 226)
local PLATE_LINE = Color(150, 196, 220, 46)
local PLATE_SUB = Color(186, 196, 206, 235)
local PLATE_TRACK = Color(255, 255, 255, 22)
local BIN_EMPTY = Color(180, 186, 194)

local function Theme()
	return NETWORK.theme
end

function F.DrawPlate(title, subtitle, color, progress, width, hint)
	local S = NETWORK.style

	width = width or 260
	color = color or Theme().combine

	local pad = 16
	local height = 42

	if (subtitle) then
		height = height + 22
	end

	if (hint) then
		height = height + 30
	end

	if (progress) then
		height = height + 14
	end

	height = height + 6

	local x, y = math.Round(-width * 0.5), math.Round(-height * 0.5)

	S.Card(x, y, width, height, 1, {
		radius = 12, accent = color, blur = false, shadow = false,
		fill = PLATE_FILL, border = PLATE_LINE
	})

	NETWORK.util.DrawCircle(x + pad + 4, y + 23, 4, color)

	draw.SimpleText(title or "", "nwTermScreenBody", x + pad + 16, y + 23, color,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local cursor = y + 42

	if (subtitle) then
		draw.SimpleText(subtitle, "nwTermScreenSmall", x + pad, cursor + 8, PLATE_SUB,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + 22
	end

	if (hint) then
		S.Chip(hint, "nwTermScreenSmall", x + pad, cursor + 2, color, 1,
			{padX = 8, padY = 3, fill = 30, border = 140})

		cursor = cursor + 30
	end

	if (progress) then
		local barWidth = width - pad * 2

		draw.RoundedBox(2, x + pad, cursor + 2, barWidth, 4, PLATE_TRACK)
		draw.RoundedBox(2, x + pad, cursor + 2,
			math.Round(barWidth * math.Clamp(progress, 0, 1)), 4, ColorAlpha(color, 240))
	end
end

local faceFrame, faceAngles = -1, Angle(0, 0, 0)

function F.FaceAngles()
	local frame = FrameNumber()

	if (frame != faceFrame) then
		faceFrame = frame
		faceAngles = LocalPlayer():EyeAngles()
		faceAngles:RotateAroundAxis(faceAngles:Up(), -90)
		faceAngles:RotateAroundAxis(faceAngles:Forward(), 90)
	end

	return faceAngles
end

function F.InRange(entity, range)
	range = range or 600

	return LocalPlayer():GetPos():DistToSqr(entity:GetPos()) <= range * range
end

hook.Add("PostDrawTranslucentRenderables", "nwRationBinLabel", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	for _, entity in ipairs(ents.FindByClass("nw_container")) do

		if (!entity.GetContainerID or entity:GetContainerID() != "ration_bin" or
			!F.InRange(entity, 500)) then
			continue
		end

		local stock = entity:GetNWInt("nwBinStock", 0)

		cam.Start3D2D(entity:GetPos() + Vector(0, 0, entity:OBBMaxs().z + 12), F.FaceAngles(), 0.08)
			F.DrawPlate(L("rationBinTitle"), stock > 0 and L("rationBinStock", stock) or
				L("rationBinEmpty"), stock > 0 and Theme().positive or BIN_EMPTY, nil, 300,
				NETWORK.factorywork.IsWorker(LocalPlayer()) and L("factoryHintBin") or nil)
		cam.End3D2D()
	end
end)

local progress

net.Receive("nwFactoryProgress", function()
	local label = net.ReadString()
	local duration = net.ReadFloat()

	if (duration <= 0) then
		progress = nil

		return
	end

	progress = {
		label = L(label),
		start = CurTime(),
		endTime = CurTime() + duration,
		duration = duration
	}
end)

hook.Add("HUDPaint", "nwFactoryProgress", function()
	if (!progress) then
		return
	end

	local remain = progress.endTime - CurTime()

	if (remain <= 0) then
		progress = nil

		return
	end

	local S = NETWORK.style
	local Sc = NETWORK.util.Scale
	local theme = Theme()
	local accent = theme.combine
	local width, height = Sc(320), Sc(50)
	local x = math.Round((ScrW() - width) * 0.5)
	local y = ScrH() - Sc(176)
	local fraction = math.Clamp(1 - remain / progress.duration, 0, 1)
	local appear = math.Clamp((CurTime() - progress.start) / 0.15, 0, 1)
	local pad = Sc(14)

	S.Card(x, y, width, height, appear, {radius = S.Radius("card"), accent = accent})

	draw.SimpleText(progress.label, "nwInvName", x + pad, y + Sc(18),
		ColorAlpha(theme.text, 245 * appear), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(string.format("%.1f", remain), "nwInvKey", x + width - pad, y + Sc(18),
		ColorAlpha(theme.textDim, 235 * appear), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local barWidth = width - pad * 2
	local barHeight = math.max(Sc(4), 3)
	local barY = y + height - pad - barHeight + Sc(2)

	draw.RoundedBox(math.floor(barHeight * 0.5), x + pad, barY, barWidth, barHeight,
		ColorAlpha(accent, 34 * appear))
	draw.RoundedBox(math.floor(barHeight * 0.5), x + pad, barY,
		math.max(math.Round(barWidth * fraction), barHeight), barHeight,
		ColorAlpha(accent, 240 * appear))
end)

local NEAR = 1400
local LOOK = 600

local factoryClasses = {"nw_factory_terminal", "nw_factory_table", "nw_factory_crate",
	"nw_ration_bin"}

local scan = {at = 0, step = 1, bNear = false}

local function HasRationToDeliver()
	local state = NETWORK.inventory and NETWORK.inventory.state

	if (!state) then
		return false
	end

	for _, list in ipairs({"items", "storage"}) do
		for _, item in pairs(state[list] or {}) do

			if (istable(item) and NETWORK.ration.IsRation(item.id) and istable(item.data) and
				item.data.crew and !item.data.credited) then
				return true
			end
		end
	end

	return false
end

local function Scan(client)
	if (RealTime() < scan.at) then
		return scan
	end

	scan.at = RealTime() + 0.5

	local position = client:GetPos()
	local bNear = false

	for _, class in ipairs(factoryClasses) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (position:DistToSqr(entity:GetPos()) <= NEAR * NEAR) then
				bNear = true

				break
			end
		end

		if (bNear) then
			break
		end
	end

	scan.bNear = bNear

	if (!bNear) then
		return scan
	end

	local step = 1
	local bBox, bParts, bRation = false, false, false

	for _, entity in ipairs(ents.FindByClass("nw_item")) do
		if (position:DistToSqr(entity:GetPos()) > LOOK * LOOK or !entity.GetItemID) then
			continue
		end

		local id = entity:GetItemID()

		if (id == "factory_box") then
			bBox = true
		elseif (string.sub(id, 1, 8) == "factory_") then
			bParts = true
		elseif (NETWORK.ration.IsRation(id)) then
			bRation = true
		end
	end

	local bTerminal = false

	for _, entity in ipairs(ents.FindByClass("nw_factory_terminal")) do
		if (position:DistToSqr(entity:GetPos()) <= LOOK * LOOK and entity.GetLoaded and
			(entity:GetLoaded() > 0 or entity:GetAssembleEnd() > CurTime())) then
			bTerminal = true

			break
		end
	end

	if (bRation or HasRationToDeliver()) then
		step = 4
	elseif (bParts or bTerminal) then
		step = 3
	elseif (bBox) then
		step = 2
	end

	scan.step = step

	return scan
end

local card = {alpha = 0, wrapKey = nil, wrapLines = {}}

local function Segments(x, y, width, height, count, filled, color, empty, gap)
	local segment = math.floor((width - gap * (count - 1)) / count)
	local radius = math.floor(height * 0.5)

	for index = 1, count do
		draw.RoundedBox(radius, x + (index - 1) * (segment + gap), y, segment, height,
			index <= filled and color or empty)
	end
end

hook.Add("HUDPaint", "nwFactoryShiftCard", function()
	local client = LocalPlayer()
	local WORK = NETWORK.factorywork

	if (!IsValid(client) or !WORK or !WORK.IsWorker(client)) then
		card.alpha = 0

		return
	end

	local bShow = !NETWORK.hud.IsHidden() and !IsValid(NETWORK.gui.terminal) and
		!IsValid(NETWORK.factoryUnpack) and Scan(client).bNear

	card.alpha = math.Approach(card.alpha, bShow and 1 or 0, FrameTime() * 4)

	if (card.alpha <= 0.01) then
		return
	end

	local S = NETWORK.style
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = Theme()
	local accent = theme.combine
	local alpha = card.alpha * NETWORK.hud.GetFade()
	local own = WORK.GetOwn(client)
	local bOpen = !NETWORK.schedule or !NETWORK.schedule.IsFactoryShift or
		NETWORK.schedule.IsFactoryShift()

	local width = Sc(304)
	local pad = Sc(14)
	local inner = width - pad * 2
	local x = Sc(26)
	local y = math.Round(ScrH() * 0.26)

	local step = scan.step
	local instruction

	if (own.bDone) then
		instruction = L("workHudDone")
	elseif (!bOpen) then
		instruction = L("workHudClosed")
	else
		instruction = L(WORK.steps[step].text)
	end

	if (card.wrapKey != instruction) then
		card.wrapKey = instruction
		card.wrapLines = util.WrapText(instruction, "nwInvBody", inner, 3)
	end

	local lineHeight = Sc(17)
	local height = Sc(70) + #card.wrapLines * lineHeight + Sc(12) + Sc(82)

	S.Card(x, y, width, height, alpha, {radius = S.Radius("panel"), accent = accent})

	draw.SimpleText(util.Upper(L("workHudTitle")), "nwInvHeader", x + pad, y + Sc(22),
		ColorAlpha(theme.text, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local stateText, stateColor

	if (own.bDone) then
		stateText, stateColor = L("workStateDone"), theme.positive
	elseif (!bOpen) then
		stateText, stateColor = L("factoryPlantClosed"), theme.warning
	else
		stateText, stateColor = L("workStateActive"), accent
	end

	S.Chip(util.Upper(stateText), "nwInvKey", x + width - pad, y + Sc(13), stateColor, alpha,
		{alignRight = true})

	local chipsY = y + Sc(40)
	local chipX = x + pad

	for index, entry in ipairs(WORK.steps) do
		local bCurrent = bOpen and !own.bDone and index == step
		local bPast = bOpen and !own.bDone and index < step
		local color = bCurrent and accent or (bPast and theme.positive or theme.textDim)
		local chipWidth = S.Chip(util.Upper(L(entry.short)), "nwInvKey", chipX, chipsY, color,
			alpha * (bCurrent and 1 or 0.75), {fill = bCurrent and 60 or 14,
			border = bCurrent and 200 or 60})

		chipX = chipX + chipWidth

		if (index < #WORK.steps) then
			draw.SimpleText("›", "nwInvKey", chipX + Sc(6), chipsY + Sc(8),
				ColorAlpha(theme.textDim, 200 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			chipX = chipX + Sc(12)
		end
	end

	local textY = chipsY + Sc(30)

	for index, line in ipairs(card.wrapLines) do
		draw.SimpleText(line, "nwInvBody", x + pad, textY + (index - 1) * lineHeight,
			ColorAlpha(own.bDone and theme.positive or theme.text, 240 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local rowY = textY + #card.wrapLines * lineHeight + Sc(12)
	local labelWidth = Sc(86)
	local dim = ColorAlpha(theme.textDim, 235 * alpha)
	local empty = ColorAlpha(accent, 30 * alpha)
	local good = ColorAlpha(theme.positive, 220 * alpha)
	local filled = ColorAlpha(accent, 220 * alpha)
	local boxCount = own.bDone and WORK.boxSize or own.box

	draw.SimpleText(L("factoryQuotaState", own.quotas, WORK.quotas), "nwInvKey", x + pad,
		rowY + Sc(6), dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Segments(x + pad + labelWidth, rowY + Sc(2), inner - labelWidth, Sc(8), WORK.quotas,
		own.quotas, good, empty, Sc(5))

	draw.SimpleText(L("factoryBoxState", boxCount, WORK.boxSize), "nwInvKey", x + pad,
		rowY + Sc(26), dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Segments(x + pad + labelWidth, rowY + Sc(22), inner - labelWidth, Sc(8), WORK.boxSize,
		boxCount, filled, empty, Sc(5))

	local barY = rowY + Sc(44)
	local barHeight = math.max(Sc(3), 2)

	draw.RoundedBox(1, x + pad, barY, inner, barHeight, empty)
	draw.RoundedBox(1, x + pad, barY, math.Round(inner * WORK.GetProgress(own)), barHeight,
		own.bDone and good or filled)

	local moneyY = rowY + Sc(66)

	draw.SimpleText(util.Upper(L("workHudEarned")), "nwInvKey", x + pad, moneyY, dim,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(L("workHudEarnedValue", own.earned, own.points), "nwInvKey",
		x + width - pad, moneyY, ColorAlpha(theme.text, 245 * alpha), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)
end)

if (NETWORK.interact and NETWORK.interact.Register and NETWORK.interact.targets) then
	for class, label in pairs({
		nw_factory_terminal = "interactFactoryTerminal",
		nw_factory_table = "interactFactoryTable",
		nw_factory_crate = "interactFactoryCrate"
	}) do
		if (!NETWORK.interact.targets[class]) then
			NETWORK.interact.Register(class, {label = label, icon = "factory"})
		end
	end
end
