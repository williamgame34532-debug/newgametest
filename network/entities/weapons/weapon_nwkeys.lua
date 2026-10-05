AddCSLuaFile()

SWEP.PrintName = "Связка ключей"
SWEP.Author = "Network"
SWEP.Category = "Network"
SWEP.Instructions = "ЛКМ — постучать. ПКМ (удерживать взгляд) — запереть или отпереть."
SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.Slot = 1
SWEP.SlotPos = 0
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.UseHands = true

SWEP.ViewModel = "models/weapons/c_arms_animations.mdl"
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 54
SWEP.HoldType = "normal"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.reach = 200
SWEP.lowerOffset = Vector(0, 0, -3)

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:GetViewModelPosition(position, angles)
	local up = angles:Up()

	return position + up * self.lowerOffset.z, angles
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
	self:SendWeaponAnim(ACT_VM_DRAW)

	return true
end

function SWEP:DrawWorldModel()
end

function SWEP:GetDoor()
	local owner = self:GetOwner()
	local trace = owner:GetEyeTrace()

	if (!NETWORK.door.IsDoor(trace.Entity)) then
		return
	end

	if (owner:GetPos():Distance(trace.HitPos) > self.reach) then
		return
	end

	return trace.Entity
end

SWEP.knockDelay = 1.2

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.knockDelay)

	if (!SERVER) then
		return
	end

	local owner = self:GetOwner()
	local entity = self:GetDoor()

	if (!entity) then
		return
	end

	entity:EmitSound("physics/wood/wood_crate_impact_hard" .. math.random(2, 3) .. ".wav",
		70, math.random(95, 105))

	owner:SetAnimation(PLAYER_ATTACK1)

	NETWORK.chat.Send(owner, "it", L("handsKnock"))

	local data = NETWORK.door.GetData(entity)

	if (!data) then
		return
	end

	local title = NETWORK.door.GetTitle(data)
	local ownerID = owner:SteamID64()

	for steamID in pairs(NETWORK.door.GetOwners(data)) do
		if (steamID == ownerID) then
			continue
		end

		for _, resident in ipairs(player.GetAll()) do
			if (resident:SteamID64() == steamID and resident:HasCharacter()) then
				NETWORK.notice.Send(resident, "doorKnockHome", "info", title)

				break
			end
		end
	end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.4)

	if (!SERVER) then
		return
	end

	local owner = self:GetOwner()
	local entity = self:GetDoor()

	if (!entity) then
		return
	end

	if (NETWORK.door.BeginKeyTurn(owner, entity)) then
		self:SetNextSecondaryFire(CurTime() + NETWORK.door.lockTime + 0.2)
	end
end

function SWEP:Holster()
	if (SERVER and NETWORK.door.CancelKeyTurn) then
		NETWORK.door.CancelKeyTurn(self:GetOwner())
	end

	return true
end

if (!CLIENT) then
	return
end

local TYPE_ICONS = {
	residential = "framework/icons/home.png",
	business = "framework/icons/storefront.png",
	faction = "framework/icons/shield.png",
	public = "framework/icons/location_city.png"
}

local function DrawIcon(path, x, y, size, color)
	local material = NETWORK.util.GetMaterial(path, "smooth")

	if (!material or material:IsError()) then
		return false
	end

	surface.SetMaterial(material)
	surface.SetDrawColor(0, 0, 0, (color.a or 255) * 0.5)
	surface.DrawTexturedRect(x + 1, y + 1, size, size)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawTexturedRect(x, y, size, size)

	return true
end

local function Fit(text, font, limit)
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= limit) then
		return text
	end

	local chars = {}

	for glyph in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
		chars[#chars + 1] = glyph
	end

	for count = #chars - 1, 1, -1 do
		local short = table.concat(chars, "", 1, count) .. "…"

		if (surface.GetTextSize(short) <= limit) then
			return short
		end
	end

	return "…"
end

SWEP.ringRows = 8

function SWEP:DrawHUD()
	local client = LocalPlayer()

	if (!IsValid(client) or (NETWORK.hud and NETWORK.hud.IsHidden and NETWORK.hud.IsHidden())) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local line = math.max(Sc(1), 1)
	local doors = NETWORK.door.GetOwned(client:SteamID64())

	local width = Sc(250)
	local padding = Sc(10)
	local headerHeight = Sc(32)
	local footerHeight = Sc(22)
	local rowHeight = Sc(24)
	local iconSize = Sc(14)

	local rows = math.min(#doors, self.ringRows)
	local extra = #doors - rows
	local bodyHeight = (rows > 0 and rows * rowHeight or rowHeight) +
		(extra > 0 and Sc(18) or 0) + Sc(6)
	local height = headerHeight + bodyHeight + footerHeight

	local x = Sc(24)
	local y = math.Round(ScrH() * 0.5 - height * 0.5)

	surface.SetDrawColor(8, 9, 10, 205)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(255, 255, 255, 30)
	surface.DrawOutlinedRect(x, y, width, height, line)

	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 230)
	surface.DrawRect(x, y, width, math.max(Sc(2), 2))

	local headerIcon = Sc(16)

	if (!DrawIcon("framework/icons/key.png", x + padding,
		y + math.Round((headerHeight - headerIcon) * 0.5) + 1, headerIcon, theme.combine)) then
		surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 230)
		surface.DrawRect(x + padding, y + math.Round(headerHeight * 0.5) - Sc(2), Sc(10), Sc(4))
	end

	draw.SimpleText(string.upper(L("keysRing")), "nwHudLabel", x + padding + headerIcon + Sc(8),
		y + math.Round(headerHeight * 0.5) + 1, theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 24)
	surface.DrawRect(x + padding, y + headerHeight, width - padding * 2, line)

	local cursor = y + headerHeight + Sc(3)

	if (#doors == 0) then
		draw.SimpleText(L("keysNoDoors"), "nwInvBody", x + width * 0.5,
			cursor + math.Round(rowHeight * 0.5), theme.textDim, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		cursor = cursor + rowHeight
	end

	for index = 1, rows do
		local entry = doors[index]
		local data = entry.data
		local typeData = NETWORK.door.GetType(data.type)
		local bLocked = NETWORK.door.IsLocked(data)
		local rowY = cursor + (index - 1) * rowHeight
		local middle = rowY + math.Round(rowHeight * 0.5)
		local iconY = middle - math.Round(iconSize * 0.5)

		if (!DrawIcon(TYPE_ICONS[data.type] or TYPE_ICONS.public, x + padding, iconY, iconSize,
			typeData.color)) then
			surface.SetDrawColor(typeData.color.r, typeData.color.g, typeData.color.b, 230)
			surface.DrawRect(x + padding + Sc(4), middle - Sc(2), Sc(4), Sc(4))
		end

		local stateColor = bLocked and theme.danger or ColorAlpha(theme.positive, 150)

		if (!DrawIcon(bLocked and "framework/icons/lock.png" or "framework/icons/key.png",
			x + width - padding - iconSize, iconY, iconSize, stateColor)) then
			surface.SetDrawColor(stateColor.r, stateColor.g, stateColor.b, stateColor.a or 255)
			surface.DrawRect(x + width - padding - Sc(10), middle - Sc(2), Sc(10), Sc(3))
		end

		local textX = x + padding + iconSize + Sc(8)
		local limit = width - padding * 2 - iconSize * 2 - Sc(16)

		draw.SimpleText(Fit(NETWORK.door.GetTitle(data), "nwInvBody", limit), "nwInvBody",
			textX, middle, theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	cursor = cursor + rows * rowHeight

	if (extra > 0) then
		draw.SimpleText("+" .. extra, "nwInvKey", x + padding + iconSize + Sc(8),
			cursor + Sc(9), theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(18)
	end

	local footerY = y + height - footerHeight

	surface.SetDrawColor(255, 255, 255, 24)
	surface.DrawRect(x + padding, footerY, width - padding * 2, line)

	draw.SimpleText(Fit(L("keysHint"), "nwInvKey", width - padding * 2), "nwInvKey",
		x + padding, footerY + math.Round(footerHeight * 0.5) + 1, theme.textDim,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end
