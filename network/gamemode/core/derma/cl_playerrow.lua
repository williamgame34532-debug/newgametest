local function CanObserve(viewer, target)
	if (target == viewer) then
		return true
	end

	local range = NETWORK.nameplate and NETWORK.nameplate.distance or 340
	local eyePos = viewer:EyePos()

	if (eyePos:DistToSqr(target:EyePos()) > range * range) then
		return false
	end

	for _, point in ipairs({target:EyePos(), target:WorldSpaceCenter()}) do

		local trace = _G.util.TraceLine({
			start = eyePos,
			endpos = point,
			filter = {viewer, target},
			mask = MASK_VISIBLE
		})

		if (!trace.Hit) then
			return true
		end
	end

	return false
end

function NETWORK.gui.BuildPlayerTooltip(target)
	local viewer = LocalPlayer()

	if (!IsValid(target) or !IsValid(viewer) or !target:HasCharacter()) then
		return nil
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local bKnown = target == viewer or viewer:IsRecognised(target) or viewer:IsAdmin()
	local faction = NETWORK.factions.Get(target:GetCharacterFaction())
	local color = faction and faction.color or theme.combine
	local classTable = NETWORK.classes and NETWORK.classes.Get(target:GetNWString("nwClass", ""))
	local role = faction and L(faction.name) or ""

	if (!bKnown) then
		role = ""
		color = NETWORK.recognition.strangerColor
	elseif (classTable and classTable.bCivilianHud) then
		local citizen = NETWORK.factions.Get("citizen")

		role = L(classTable.name)
		color = citizen and citizen.color or color
	elseif (classTable and classTable.name) then
		role = (role != "" and (role .. "  ·  ") or "") .. L(classTable.name)
	end

	local lines = {}

	if (bKnown) then
		local description = target:GetCharacterDescription() or ""

		if (description != "") then

			lines = util.WrapText(description, "nwTipBody", Sc(380) - Sc(38), 5)
		end
	else
		lines = {L("recogUnknownDesc")}
	end

	local footer = {}
	local group = bKnown and NETWORK.group and NETWORK.group.GetOf(target)

	if (group and group.name) then
		footer[#footer + 1] = {label = L("playersOrg"),
			value = util.TruncateWidth(group.name, "nwTipBody", Sc(140)),
			color = NETWORK.group.GetColor(group)}
	end

	local played = math.max(target:GetNWInt("nwPlaytime", 0), 0)

	if (played > 0) then
		footer[#footer + 1] = {label = L("invPlayed"), value = played >= 60 and
			L("invPlayedFull", math.floor(played / 60), played % 60) or
			L("invPlayedMinutes", played)}
	end

	local ping = target:Ping()

	footer[#footer + 1] = {label = L("playersPing"), value = ping .. " ms",
		color = ping < 100 and theme.positive or (ping < 200 and theme.warning or theme.danger)}

	local status, statusColor
	local bDown = target.IsDowned and (target:IsDowned() or
		(target.IsUnconscious and target:IsUnconscious())) or !target:Alive()

	if (bDown) then
		status, statusColor = L("scoreDowned"), theme.danger
	elseif (CanObserve(viewer, target)) then
		if (NETWORK.restraint and NETWORK.restraint.IsTied(target)) then
			status, statusColor = L("plateTied"), theme.warning
		elseif (NETWORK.nameplate and NETWORK.nameplate.GetWoundText) then
			local wound, woundColor = NETWORK.nameplate.GetWoundText(target)

			if (wound) then
				status, statusColor = wound, woundColor or theme.danger
			end
		end
	end

	if (status) then
		footer[#footer + 1] = {label = L("playersStatus"),
			value = util.TruncateWidth(status, "nwTipBody", Sc(170)), color = statusColor}
	end

	return {
		title = bKnown and target:GetCharacterName() or target:GetUnknownName(),
		subtitle = role != "" and role or nil,
		color = color,
		accent = color,
		icon = bKnown and NETWORK.factions.GetIcon(target) or NETWORK.recognition.strangerIcon,
		lines = lines,
		footer = footer
	}
end

local PANEL = {}

function PANEL:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.hover = 0
	self.select = 0
	self.reveal = 0
	self.revealDelay = 0
	self.startTime = CurTime()
	self.color = NETWORK.theme.inv.accent
	self.bSelected = false
end

function PANEL:Setup(client, color)
	self.client = client
	self.color = color or NETWORK.theme.inv.accent
	self.bLocal = client == LocalPlayer()
	self.bKnown = LocalPlayer():IsRecognised(client) or LocalPlayer():IsAdmin()
	self.cachedName = self.bKnown and client:GetCharacterName() or client:GetUnknownName()
	self.steamName = client:SteamName()

	self.model = self:Add("DModelPanel")
	self.model:SetModel(client:GetCharacterModel())
	self.model:SetFOV(34)
	self.model:SetMouseInputEnabled(false)
	self.model:SetAnimated(false)
	self.model.LayoutEntity = function() end

	local entity = self.model:GetEntity()

	if (IsValid(entity)) then
		NETWORK.util.ApplyAppearance(self.model, client)

		local sequence = entity:LookupSequence("idle_all_01")

		if (sequence and sequence > 0) then
			entity:ResetSequence(sequence)
		end

		local head = entity:LookupBone("ValveBiped.Bip01_Neck1") or
			entity:LookupBone("ValveBiped.Bip01_Head1")

		if (head) then
			local position = entity:GetBonePosition(head)

			self.model:SetLookAt(position - Vector(0, 0, 4))
			self.model:SetCamPos(position + Vector(62, 0, 6))
		end
	end
end

function PANEL:SetSelected(bSelected)
	self.bSelected = tobool(bSelected)
end

function PANEL:SetRevealDelay(delay)
	self.revealDelay = delay
end

function PANEL:OnCursorEntered()
	NETWORK.sound.Hover()

	if (IsValid(self.client) and NETWORK.gui.SetTooltip) then
		NETWORK.gui.SetTooltip(self, NETWORK.gui.BuildPlayerTooltip(self.client))
	end
end

function PANEL:OnCursorExited()
	if (NETWORK.gui.ClearTooltip) then
		NETWORK.gui.ClearTooltip(self)
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT and IsValid(self.client)) then
		SetClipboardText(self.client:SteamID())

		NETWORK.gui.Notify(L("playersCopied"), NETWORK.theme.inv.accentSoft)

		return
	end

	NETWORK.sound.Click()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	if (IsValid(self.model)) then
		self.model:SetSize(height + Sc(20), height - Sc(4))
		self.model:SetPos(Sc(8), Sc(2))
	end
end

function PANEL:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 10)
	self.select = util.Approach(self.select, self.bSelected and 1 or 0, 10)
	self.reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay, 0.4))
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local palette = NETWORK.theme.inv
	local util = NETWORK.util
	local reveal = self.reveal

	if (reveal < 0.01 or !IsValid(self.client)) then
		return
	end

	local hover = util.EaseInOut(self.hover)
	local selected = util.EaseInOut(self.select)
	local lit = math.max(hover * 0.7, selected)
	local x = math.Round((1 - reveal) * Sc(14)) + math.Round(hover * Sc(4))
	local color = self.color

	local S = NETWORK.style
	local radius = (S and S.Radius) and S.Radius("cell") or math.max(Sc(6), 4)
	local rowWidth = width - x

	draw.RoundedBox(radius, x, 0, rowWidth, height, Color(10, 13, 17, 190 * reveal))

	if (lit > 0.01) then
		draw.RoundedBox(radius, x, 0, rowWidth, height,
			Color(255, 255, 255, 12 * lit * reveal))
		util.DrawRoundedBorder(x, 0, rowWidth, height, radius, 1,
			Color(color.r, color.g, color.b, 150 * lit * reveal))
	end

	local bar = math.max(Sc(3), 2)
	local barHeight = math.Round(height * 0.6)

	draw.RoundedBox(math.floor(bar * 0.5), x + math.max(Sc(4), 3),
		math.Round((height - barHeight) * 0.5), bar, barHeight,
		Color(color.r, color.g, color.b, (200 + 55 * lit) * reveal))

	local frame = height + Sc(20)

	draw.RoundedBox(math.max(radius - Sc(2), 2), x + Sc(10), Sc(3), frame, height - Sc(6),
		Color(0, 0, 0, 120 * reveal))

	if (IsValid(self.model)) then
		self.model:SetAlpha(math.Round((self.bKnown and 255 or 60) * reveal))
	end

	local textX = x + Sc(10) + frame + Sc(16)

	draw.SimpleText(util.TruncateWidth(self.cachedName or "", "nwField",
		math.max(width - Sc(18) - Sc(120) - textX, Sc(40))), "nwField", textX,
		math.Round(height * 0.5) - Sc(10),
		ColorAlpha(self.bLocal and palette.text or palette.text,
			(215 + 40 * lit) * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local description = self.bKnown and self.client:GetCharacterDescription() or
		L("recogUnknownDesc")

	draw.SimpleText(util.Truncate(description, 58), "nwHudSmall", textX,
		math.Round(height * 0.5) + Sc(12),
		ColorAlpha(palette.textDim, 210 * reveal), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	local ping = self.client:Ping()
	local pingColor = ping < 100 and palette.positive or
		(ping < 200 and palette.warning or palette.danger)

	draw.SimpleText(ping .. " ms", "nwField", width - Sc(18),
		math.Round(height * 0.5) - Sc(10), ColorAlpha(pingColor, 240 * reveal),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Truncate(self.steamName, 24), "nwHudSmall",
		width - Sc(18), math.Round(height * 0.5) + Sc(12),
		ColorAlpha(palette.textFaint, 220 * reveal), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)
end

vgui.Register("nwPlayerRow", PANEL, "DButton")
