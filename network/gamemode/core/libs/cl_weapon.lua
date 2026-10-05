local LOWER_PITCH = 44
local LOWER_YAW = -22
local LOWER_ROLL = -10
local lowerFraction = 0

hook.Add("PreDrawViewModel", "nwWeaponRaise", function(viewModel, client, weapon)
	local player = LocalPlayer()

	if (!IsValid(player) or !player:HasCharacter()) then
		return
	end

	local active = player:GetActiveWeapon()

	if (IsValid(active) and active.IsSafety and active:IsSafety()) then
		return
	end

	if (!player:IsWeaponRaised() and lowerFraction >= 0.99) then
		return true
	end
end)

hook.Add("CalcViewModelView", "nwWeaponRaise", function(weapon, viewModel, oldPos, oldAng, position, angles)
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local bLowered = !client:IsWeaponRaised()

	local active = client:GetActiveWeapon()

	if (IsValid(active) and active.IsSafety and active:IsSafety()) then
		bLowered = false
	end

	lowerFraction = NETWORK.util.Approach(lowerFraction, bLowered and 1 or 0, 5)
	NETWORK.weapon.lowerFraction = lowerFraction

	if (lowerFraction < 0.005) then
		return
	end

	local fraction = NETWORK.util.EaseInOut(lowerFraction)

	angles = Angle(angles.p, angles.y, angles.r)

	angles:RotateAroundAxis(angles:Right(), LOWER_PITCH * fraction)
	angles:RotateAroundAxis(angles:Up(), LOWER_YAW * fraction)
	angles:RotateAroundAxis(angles:Forward(), LOWER_ROLL * fraction)

	position = position + angles:Up() * (fraction * -3.4) +
		angles:Forward() * (fraction * -5) + angles:Right() * (fraction * 1.2)

	return position, angles
end)

hook.Add("PostDrawViewModel", "nwWeaponHands", function(viewModel, client, weapon)
	local player = LocalPlayer()

	if (!IsValid(player) or !player:IsWeaponRaised()) then
		return
	end

	if (IsValid(weapon) and weapon:GetClass() == NETWORK.weapon.hands) then
		local hands = player:GetHands()

		if (IsValid(hands)) then
			if (NETWORK.chgen and NETWORK.chgen.Draw and GetConVar("network_chgen"):GetBool()) then
				NETWORK.chgen.Draw(hands)
			else
				hands:DrawModel()
			end
		end
	end
end)

hook.Add("NetworkDrawHUD", "nwWeaponRaise", function()
	local client = LocalPlayer()
	local progress = client:GetRaiseProgress()

	NETWORK.weapon.raiseShow = math.Approach(NETWORK.weapon.raiseShow or 0,
		progress > 0.01 and 1 or 0, FrameTime() * 5)

	local show = NETWORK.util.EaseInOut(NETWORK.weapon.raiseShow)

	if (show < 0.01) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util

	local bRaised = client:IsWeaponRaised()
	local radius = Sc(26)
	local thickness = math.max(Sc(3), 2)
	local centerX = math.Round(ScrW() * 0.5)
	local centerY = math.Round(ScrH() * 0.5) + math.Round((1 - show) * Sc(6))

	local plate = NETWORK.nameplate
	local bPlate = plate and plate.lookBottom and (plate.lookAlpha or 0) > 0.02 and
		(RealTime() - (plate.lookTime or 0)) < 0.2

	NETWORK.weapon.tipShift = math.Approach(NETWORK.weapon.tipShift or 0,
		bPlate and 1 or 0, FrameTime() * 6)

	if ((NETWORK.weapon.tipShift or 0) > 0.01 and plate and plate.lookBottom) then
		local target = plate.lookBottom + Sc(26) + Sc(18)

		centerY = centerY + math.Round((target - centerY) *
			NETWORK.util.EaseInOut(NETWORK.weapon.tipShift))
	end
	local color = bRaised and theme.hover or theme.accent
	local span = 0.34

	util.DrawArc(centerX, centerY, radius, thickness, span,
		Color(0, 0, 0, 170 * show), 160, 90 - span * 180)

	util.DrawArc(centerX, centerY, radius, thickness, span * progress,
		ColorAlpha(color, 250 * show), 160, 90 - span * 180 * progress)

	for side = -1, 1, 2 do
		local angle = math.rad(90 + side * span * 180)
		local inner = radius - thickness
		local outer = radius + thickness

		util.DrawThickLine(
			centerX + math.cos(angle) * inner, centerY + math.sin(angle) * inner,
			centerX + math.cos(angle) * outer, centerY + math.sin(angle) * outer,
			math.max(Sc(2), 1), ColorAlpha(color, 140 * show))
	end

	if (progress >= 1) then
		util.DrawCircle(centerX, centerY + radius + Sc(5), math.max(Sc(2), 2),
			ColorAlpha(color, 235 * show))
	end
end)

hook.Add("StartCommand", "nwWeaponSafety", function(client, cmd)
	if (client != LocalPlayer() or !client:HasCharacter()) then
		return
	end

	if (IsValid(client:GetNWEntity("nwRagdollEntity"))) then
		if (client:GetNWFloat("nwRagdollUntil", 0) < CurTime()) then
			cmd:RemoveKey(IN_ATTACK2)

			return
		end

		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)

		return
	end

	if (client:IsWeaponRaised()) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and weapon:GetClass() == NETWORK.weapon.hands) then
		return
	end

	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
end)

local hintUntil = 0
local nextHint = 0
local bUrgent = false
local lastWeapon = ""

local function GetRaiseKey()
	local bind = input.LookupBinding("+reload", true)

	return string.upper(bind or "R")
end

local function ShowHint(bStrong)
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or client:IsWeaponRaised()) then
		return
	end

	if (!bStrong and nextHint > CurTime()) then
		return
	end

	nextHint = CurTime() + 5
	hintUntil = CurTime() + (bStrong and 3.5 or 2.5)
	bUrgent = bStrong or false
end

local function IsRealWeapon(weapon)
	if (!IsValid(weapon)) then
		return false
	end

	local class = weapon:GetClass()

	return class != NETWORK.weapon.hands and !NETWORK.weapon.alwaysRaised[class]
end

hook.Add("PlayerBindPress", "nwWeaponRaiseHint", function(client, bind, bPressed)
	if (!bPressed or client:IsWeaponRaised()) then
		return
	end

	if (!string.find(bind, "+attack")) then
		return
	end

	if (IsRealWeapon(client:GetActiveWeapon()) and
		!IsValid(client:GetNWEntity("nwRagdollEntity"))) then
		ShowHint(true)
	end
end)

hook.Add("Think", "nwWeaponRaiseHint", function()
	if (!NETWORK.util.Throttle("weapon.hint", 0.25)) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local weapon = client:GetActiveWeapon()
	local class = IsValid(weapon) and weapon:GetClass() or ""

	if (class == lastWeapon) then
		return
	end

	lastWeapon = class

	if (IsRealWeapon(weapon) and !client:IsWeaponRaised()) then
		ShowHint(false)
	end
end)

local function DrawKeyHint(key, text, colour, alpha, pulse, y)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local x = math.Round(ScrW() * 0.5)

	surface.SetFont("nwChatSmall")

	local textWidth = surface.GetTextSize(text)
	local keyWidth = key and math.max(surface.GetTextSize(key) + Sc(16), Sc(30)) or 0
	local keyGap = key and Sc(10) or 0
	local total = keyWidth + keyGap + textWidth
	local keyX = x - math.Round(total * 0.5)

	local boxX = keyX - Sc(10)
	local boxWidth = total + Sc(20)
	local boxY = y - Sc(17)
	local boxHeight = Sc(34)
	local radius = math.max(Sc(6), 4)

	draw.RoundedBox(radius, boxX, boxY, boxWidth, boxHeight,
		Color(6, 7, 9, 214 * alpha))

	surface.SetDrawColor(colour.r, colour.g, colour.b, 235 * alpha * pulse)
	surface.DrawRect(boxX, boxY + radius, math.max(Sc(2), 2),
		boxHeight - radius * 2)

	if (key) then
		draw.RoundedBox(math.max(Sc(4), 3), keyX, y - Sc(11), keyWidth, Sc(22),
			Color(255, 255, 255, 22 * alpha))

		draw.SimpleText(key, "nwChatSmall", keyX + math.Round(keyWidth * 0.5), y,
			ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	draw.SimpleText(text, "nwChatSmall", keyX + keyWidth + keyGap, y,
		ColorAlpha(colour, 252 * alpha * pulse), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
end

hook.Add("NetworkDrawHUD", "nwWeaponRaiseHint", function()
	local client = LocalPlayer()

	if (IsValid(client) and client:KeyDown(IN_SPEED) and
		client:KeyDown(IN_USE)) then
		return
	end

	if (hintUntil < CurTime() or !IsValid(client) or client:IsWeaponRaised()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local left = hintUntil - CurTime()
	local alpha = math.Clamp(left, 0, 1) * NETWORK.hud.GetFade()
	local colour = bUrgent and theme.warning or theme.textDim
	local rise = math.Round((1 - math.Clamp(left * 2, 0, 1)) * Sc(4))
	local pulse = bUrgent and (0.82 + math.abs(math.sin(RealTime() * 5)) * 0.18) or 1

	DrawKeyHint(GetRaiseKey(), L("weaponRaiseHint"), colour, alpha, pulse,
		math.Round(ScrH() * 0.5) + Sc(110) + rise)
end)

local wearHint = {weapon = nil, state = 0, untilTime = 0}

NETWORK.weaponwear.OnDryFire = function(client, weapon, state)

	if ((wearHint.clickAt or 0) > RealTime()) then
		return
	end

	wearHint.clickAt = RealTime() + 0.2

	client:EmitSound("weapons/pistol/pistol_empty.wav", 62, math.random(96, 104), 0.8)

	wearHint.weapon = weapon
	wearHint.state = state
	wearHint.untilTime = CurTime() + 3.5

	net.Start("nwWearDry")
	net.SendToServer()
end

hook.Add("NetworkDrawHUD", "nwWeaponWearHint", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:IsWeaponRaised()) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (!IsValid(weapon) or weapon != wearHint.weapon) then
		return
	end

	local W = NETWORK.weaponwear
	local state = W.GetState(weapon)

	if (state == W.STATE_OK) then
		wearHint.weapon = nil

		return
	end

	local left = state == W.STATE_JAM and 1 or (wearHint.untilTime - CurTime())

	if (left <= 0) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local alpha = math.Clamp(left, 0, 1) * NETWORK.hud.GetFade()
	local pulse = 0.82 + math.abs(math.sin(RealTime() * 5)) * 0.18

	if (state == W.STATE_JAM) then
		DrawKeyHint(GetRaiseKey(), L("weaponJamHint"), theme.warning, alpha, pulse,
			math.Round(ScrH() * 0.5) + Sc(110))
	else
		DrawKeyHint(nil, L("weaponBrokenHint"), theme.danger or theme.warning, alpha,
			pulse, math.Round(ScrH() * 0.5) + Sc(110))
	end
end)

local gunFeelConVar = CreateClientConVar("network_gunfeel", "1", true, false,
	"Сила отдачи камеры при стрельбе (0 — выключить)")

local GUN_STIFFNESS = 190
local GUN_DAMPING = 17

local kick = {
	p = 0, y = 0, r = 0, fov = 0,
	vp = 0, vy = 0, vr = 0, vfov = 0,
	shake = 0
}

local kickByClass = {
	weapon_pistol = 0.55,
	weapon_357 = 1.6,
	weapon_smg1 = 0.45,
	weapon_ar2 = 0.7,
	weapon_shotgun = 1.5,
	weapon_crossbow = 1.1,
	weapon_rpg = 1.8
}

local kickCache = {}

local function GetKickScale(weapon)
	local class = weapon:GetClass()

	if (kickByClass[class]) then
		return kickByClass[class]
	end

	if (kickCache[class]) then
		return kickCache[class]
	end

	local scale = 0.7
	local primary = weapon.Primary

	if (istable(primary)) then
		local kickUp = tonumber(primary.KickUp)
		local damage = tonumber(primary.Damage)

		if (kickUp) then
			scale = math.Clamp(0.35 + kickUp * 1.1, 0.35, 2.2)
		elseif (damage) then
			scale = math.Clamp(damage / 40, 0.35, 2.2)
		end

		if ((tonumber(primary.NumShots) or 1) > 1) then
			scale = math.max(scale, 1.4)
		end

		if ((tonumber(primary.RPM) or 0) > 650) then
			scale = scale * 0.8
		end
	end

	kickCache[class] = scale

	return scale
end

local function IsAiming(weapon)
	if (isfunction(weapon.GetIronSights)) then
		local bOk, result = pcall(weapon.GetIronSights, weapon)

		return bOk and result == true
	end

	return false
end

local function GunKick(client, weapon)
	local intensity = gunFeelConVar:GetFloat()

	if (intensity <= 0) then
		return
	end

	local scale = GetKickScale(weapon) * intensity

	if (IsAiming(weapon)) then
		scale = scale * 0.6
	end

	if (client:Crouching()) then
		scale = scale * 0.8
	end

	kick.vp = kick.vp - 30 * scale * math.Rand(0.85, 1.15)
	kick.vy = kick.vy + math.Rand(-9, 9) * scale
	kick.vr = kick.vr + math.Rand(-12, 12) * scale
	kick.vfov = kick.vfov + 16 * scale
	kick.shake = math.min(kick.shake + 0.35 * scale, 1.4)
end

local track = {weapon = nil, clip = -1, reserve = -1, attackAt = 0}

local function IsThrowable(weapon)
	local W = NETWORK.weaponwear

	if (W and W.skip and W.skip[weapon:GetClass()]) then
		return true
	end

	local ammoType = weapon:GetPrimaryAmmoType()
	local name = ammoType and ammoType >= 0 and game.GetAmmoName(ammoType) or ""

	name = string.lower(name or "")

	return string.find(name, "grenade", 1, true) != nil or
		string.find(name, "slam", 1, true) != nil
end

local function StepSpring(dt)
	for _, axis in ipairs({"p", "y", "r", "fov"}) do
		local velocity = "v" .. axis
		local force = -GUN_STIFFNESS * kick[axis] - GUN_DAMPING * kick[velocity]

		kick[velocity] = kick[velocity] + force * dt
		kick[axis] = kick[axis] + kick[velocity] * dt
	end

	kick.shake = math.max(kick.shake - dt * 3.2, 0)
end

hook.Add("Think", "nwGunFeel", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local dt = math.min(FrameTime(), 0.1)

	while (dt > 0) do
		local step = math.min(dt, 1 / 120)

		StepSpring(step)
		dt = dt - step
	end

	local weapon = client:GetActiveWeapon()

	if (!client:Alive() or !IsValid(weapon)) then
		track.weapon = nil

		return
	end

	if (client:KeyDown(IN_ATTACK)) then
		track.attackAt = CurTime()
	end

	local clip = weapon:Clip1()
	local ammoType = weapon:GetPrimaryAmmoType()
	local reserve = (ammoType and ammoType >= 0) and client:GetAmmoCount(ammoType) or -1

	if (track.weapon != weapon) then
		track.weapon = weapon
		track.clip = clip
		track.reserve = reserve

		return
	end

	local fired = 0

	if (clip >= 0) then
		fired = track.clip - clip
	elseif (reserve >= 0) then
		fired = track.reserve - reserve
	end

	track.clip = clip
	track.reserve = reserve

	if (fired >= 1 and fired <= 3 and CurTime() - track.attackAt < 0.3 and
		!IsThrowable(weapon)) then
		GunKick(client, weapon)
	end
end)

NETWORK.view.Register("gunfeel", 45, function(client, view)
	if (math.abs(kick.p) + math.abs(kick.y) + math.abs(kick.r) + math.abs(kick.fov) +
		kick.shake < 0.005) then
		return
	end

	local time = RealTime()
	local shake = kick.shake * kick.shake * 0.35

	view.angles = Angle(
		view.angles.p + kick.p + math.sin(time * 61) * shake,
		view.angles.y + kick.y + math.cos(time * 53) * shake,
		view.angles.r + kick.r + math.sin(time * 47) * shake * 0.6
	)

	view.fov = (view.fov or 75) + kick.fov

	return true
end)
