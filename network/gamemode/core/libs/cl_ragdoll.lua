NETWORK.ragdoll = NETWORK.ragdoll or {}

function NETWORK.ragdoll.Get()
	local client = LocalPlayer()

	return IsValid(client) and client:GetNWEntity("nwRagdollEntity", NULL) or NULL
end

NETWORK.view.Register("ragdoll", 8, function(client, view)
	local ragdoll = NETWORK.ragdoll.Get()

	if (!IsValid(ragdoll)) then
		return
	end

	ragdoll:SetupBones()

	local position, angles

	local attachment = ragdoll:LookupAttachment("eyes")

	if (attachment and attachment > 0) then
		local data = ragdoll:GetAttachment(attachment)

		if (data) then
			position, angles = data.Pos, data.Ang
		end
	end

	if (!position) then
		local bone = ragdoll:LookupBone("ValveBiped.Bip01_Head1") or
			ragdoll:LookupBone("ValveBiped.Bip01_Neck1")

		if (bone) then
			position, angles = ragdoll:GetBonePosition(bone)
		end
	end

	if (!position) then
		position = ragdoll:GetPos() + Vector(0, 0, 12)
		angles = ragdoll:GetAngles()
	end

	local forward = angles:Forward()

	view.origin = position + forward * 3
	view.angles = angles
	view.fov = 78
	view.drawviewer = true

	return "stop"
end)

hook.Add("RenderScreenspaceEffects", "nwRagdoll", function()
	local ragdoll = NETWORK.ragdoll.Get()

	if (!IsValid(ragdoll)) then
		return
	end

	local client = LocalPlayer()
	local until_ = client:GetNWFloat("nwRagdollUntil", 0)
	local left = math.max(until_ - CurTime(), 0)
	local strength = math.Clamp(left / 10 + 0.35, 0.35, 1)

	DrawMotionBlur(0.32, 0.75 * strength, 0.01)

	DrawColorModify({
		["$pp_colour_addr"] = 0.02 * strength,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.08 * strength,
		["$pp_colour_contrast"] = 1 - 0.22 * strength,
		["$pp_colour_colour"] = 1 - 0.65 * strength,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})

	DrawSharpen(-0.4 * strength, 1.4)
end)

local downShow = 0

hook.Add("HUDPaint", "nwRagdoll", function()
	local client = LocalPlayer()
	local ragdoll = NETWORK.ragdoll.Get()

	local bDown = IsValid(ragdoll) and !client:GetNWBool("nwUnconscious", false)

	downShow = NETWORK.util.Approach(downShow, bDown and 1 or 0,
		bDown and 2.5 or 4)

	if (downShow < 0.01) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local show = util.EaseInOut(downShow)
	local shadow = math.max(Sc(2), 1)

	local breath = 0.6 + math.abs(math.sin(CurTime() * 1.2)) * 0.4

	surface.SetDrawColor(4, 4, 6, 90 * show)
	surface.DrawRect(0, 0, ScrW(), ScrH())

	util.DrawVignette(0, 0, ScrW(), ScrH(),
		math.Round(math.min(ScrW(), ScrH()) * 0.6), 190 * show * breath,
		Color(70, 8, 10))

	local until_ = client:GetNWFloat("nwRagdollUntil", 0)
	local left = math.max(until_ - CurTime(), 0)
	local width = math.min(Sc(320), math.Round(ScrW() * 0.22))
	local x = math.Round((ScrW() - width) * 0.5)
	local y = math.Round(ScrH() * 0.78)

	local title = util.Upper(L("ragdollUnconscious"))
	local titleWidth = util.TextSpacedSize(title, "nwHudLabel", Sc(4))

	local plateX = x - Sc(28)
	local plateY = y - Sc(42)
	local plateWidth = width + Sc(56)
	local plateHeight = Sc(86)

	draw.RoundedBox(math.max(Sc(8), 4), plateX, plateY, plateWidth, plateHeight,
		Color(8, 9, 10, 200 * show))
	util.DrawRoundedBorder(plateX, plateY, plateWidth, plateHeight, math.max(Sc(8), 4),
		math.max(Sc(1), 1), Color(255, 255, 255, 26 * show))
	surface.SetDrawColor(198, 72, 66, 220 * show)
	surface.DrawRect(plateX + Sc(12), plateY + Sc(12), math.max(Sc(3), 2), plateHeight - Sc(24))

	util.DrawTextSpacedShadow(title, "nwHudLabel",
		math.Round((ScrW() - titleWidth) * 0.5), y - Sc(20),
		ColorAlpha(theme.text, (150 + 90 * breath) * show), Sc(4),
		TEXT_ALIGN_CENTER, shadow)

	if (left > 0) then

		local total = math.max(NETWORK.ragdoll.minTime or 10, 1)
		local fraction = math.Clamp(left / total, 0, 1)

		util.DrawProgressBar(x, y, width, math.max(Sc(5), 3), fraction,
			Color(198, 72, 66), show)

		util.DrawSimpleTextShadow(string.format("%.0f", math.ceil(left)),
			"nwHudLabelSmall", x + width, y + Sc(18),
			ColorAlpha(theme.textDim, 235 * show), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER, shadow)
	end

	local bHelp = false

	for _, other in ipairs(player.GetAll()) do
		if (other != client and other:Alive() and
			other:GetPos():Distance(client:GetPos()) < 200) then
			bHelp = true

			break
		end
	end

	if (bHelp) then
		util.DrawSimpleTextShadow(L("plateDownedHint"), "nwHudLabelSmall",
			math.Round(ScrW() * 0.5), y + Sc(18),
			ColorAlpha(theme.textFaint, 220 * show), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, shadow)
	end
end)
