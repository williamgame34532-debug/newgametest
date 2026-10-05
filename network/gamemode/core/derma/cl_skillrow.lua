local PANEL = {}

function PANEL:Init()
	self:SetCursor("hand")

	self.data = nil
	self.hover = 0
	self.reveal = 0
	self.fill = 0
	self.revealDelay = 0
	self.startTime = CurTime()

	if ((NETWORK.gui.instantUntil or 0) > CurTime()) then
		self.bInstant = true
		self.reveal = 1
		self.fill = 1
	end
end

function PANEL:Setup(data)
	self.data = data
end

function PANEL:SetRevealDelay(delay)
	self.revealDelay = delay or 0
end

function PANEL:GetSkillColor()
	return NETWORK.gui.SkillColor and NETWORK.gui.SkillColor(self.data and self.data.id) or
		NETWORK.theme.combine
end

function PANEL:OnCursorEntered()
	if (self.data and NETWORK.gui.SkillTooltip) then
		NETWORK.gui.SkillTooltip(self, self.data)
	end
end

function PANEL:OnCursorExited()
	NETWORK.gui.ClearTooltip(self)
end

function PANEL:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 12)

	if (self.bInstant) then
		return
	end

	self.reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay, 0.5))
	self.fill = util.EaseOut(util.Stagger(self.startTime, self.revealDelay + 0.2, 0.7))
end

function PANEL:Paint(width, height)
	local data = self.data
	local reveal = self.reveal

	if (!data or reveal < 0.01 or !NETWORK.gui.DrawSkillFrame) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local palette = theme.inv
	local client = LocalPlayer()
	local skills = NETWORK.skills
	local character = IsValid(client) and client:GetCharacter()

	if (!character) then
		return
	end

	local maxLevel = skills and skills.maxLevel or NETWORK.creation.skillMax
	local value = skills and skills.Get(client, data.id) or character:GetSkill(data.id)
	local earned = skills and skills.GetEarned(client, data.id) or 0
	local xp = skills and skills.GetXP(client, data.id) or 0
	local need = (skills and value < maxLevel) and skills.Need(value) or 0
	local hover = util.EaseOut(self.hover)
	local color = self:GetSkillColor()
	local x = math.Round((1 - reveal) * Sc(16))
	local pad = Sc(16)
	local thread = math.max(Sc(3), 2)
	local frameWidth = width - x

	util.DrawBlurRect(self, x, 0, frameWidth, height, 3 * reveal)
	NETWORK.gui.DrawSkillFrame(x, 0, frameWidth, height, color, reveal, hover)

	local iconSize = Sc(24)
	local topY = pad + math.Round(iconSize * 0.5)
	local textX = x + pad + Sc(4)

	if (NETWORK.gui.DrawSkillIcon(data.id, textX, topY - math.Round(iconSize * 0.5), iconSize,
		ColorAlpha(color, (215 + 40 * hover) * reveal))) then
		textX = textX + iconSize + Sc(10)
	end

	local nameWidth = util.DrawTextSpaced(util.Upper(L(data.name)), "nwLabelBold", textX, topY,
		ColorAlpha(theme.text, (235 + 20 * hover) * reveal), Sc(2), TEXT_ALIGN_CENTER) or 0

	if (earned > 0) then
		draw.SimpleText("+" .. earned, "nwInvKey", textX + nameWidth + Sc(8), topY,
			ColorAlpha(color, 235 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local levelX = x + frameWidth - pad

	draw.SimpleText(tostring(value), "nwSkillLevel", levelX, topY + Sc(6),
		ColorAlpha(color, 250 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetFont("nwSkillLevel")

	local levelWidth = surface.GetTextSize(tostring(value))

	draw.SimpleText(util.Upper(L("skillLvlShort")), "nwInvKey", levelX - levelWidth - Sc(6),
		topY + Sc(2), ColorAlpha(palette.textFaint, 235 * reveal), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	local textWidth = frameWidth - pad * 2 - thread
	local lineY = topY + Sc(24)

	for _, line in ipairs(util.WrapText(L(data.description), "nwLabel", textWidth, 2)) do
		draw.SimpleText(line, "nwLabel", x + pad + Sc(4), lineY,
			ColorAlpha(palette.textDim, (200 + 40 * hover) * reveal), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		lineY = lineY + Sc(16)
	end

	local bottomY = height - Sc(20)
	local tickWidth = math.min(Sc(150), math.Round(frameWidth * 0.4))

	NETWORK.gui.DrawSkillTicks(x + pad + Sc(4), bottomY - Sc(2), tickWidth, value, earned, maxLevel,
		color, reveal)

	if (need > 0) then
		draw.SimpleText(xp .. " / " .. need, "nwHudSmall", levelX, bottomY,
			ColorAlpha(palette.textDim, 225 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText(util.Upper(L("skillMaxLabel")), "nwHudSmall", levelX, bottomY,
			ColorAlpha(color, 235 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	NETWORK.gui.DrawSkillXP(x + thread, height - math.max(Sc(3), 2), frameWidth - thread,
		xp * self.fill, need, color, reveal)
end

vgui.Register("nwSkillTile", PANEL, "DPanel")

vgui.Register("nwSkillRow", PANEL, "DPanel")
