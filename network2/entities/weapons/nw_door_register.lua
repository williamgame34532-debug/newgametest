AddCSLuaFile()

-- The registrar of the Alliance doors (admins): aimed at a door (prop or map door, a double door goes
-- whole) -
--   LMB   register it as a door of the Alliance (only the Alliance opens it, sv_doors.lua)
--   RMB   unregister it (the settings of the door are reset, it is unlocked)
--   R     what the door is now
-- A scanning sweep runs over the door (blue - registered, red - removed), the screen says what the door
-- looked at is. Kept with the map like the /door window.

SWEP.PrintName = "Регистратор дверей"
SWEP.Author = "Network"
SWEP.Instructions = "ЛКМ — зарегистрировать дверь Альянса · ПКМ — снять регистрацию · R — проверить"
SWEP.Purpose = "Дверь Альянса открывает только Альянс"
SWEP.Category = "Network"
SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.Slot = 5
SWEP.SlotPos = 3
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.ViewModelFOV = 54
SWEP.HoldType = "pistol"
SWEP.IsAlwaysRaised = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

local REACH = 256

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Door()
	local owner = self:GetOwner()

	return IsValid(owner) and NW.doors.Aimed(owner, REACH) or nil
end

function SWEP:Shoot(bRegister)
	local owner = self:GetOwner()

	self:SetNextPrimaryFire(CurTime() + 0.6)
	self:SetNextSecondaryFire(CurTime() + 0.6)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	owner:SetAnimation(PLAYER_ATTACK1)

	if (CLIENT) then
		return
	end

	local door = self:Door()

	if (!owner:IsAdmin()) then
		return NW.Notify(owner, "Регистратор — только для администрации")
	end

	if (!door) then
		owner:EmitSound("buttons/button10.wav", 55)

		return NW.Notify(owner, "Наведите на дверь")
	end

	local was = door:GetNW2String("nwDoorKind", "") == "alliance"

	if (bRegister == was) then
		return NW.Notify(owner, was and "Дверь уже зарегистрирована за Альянсом" or "Дверь не зарегистрирована")
	end

	NW.doors.SetAlliance(door, bRegister)

	if (NW.doors.Scan) then
		owner.nwDoorScan = 0
		NW.doors.Scan(door, owner, bRegister)
	end

	door:EmitSound(bRegister and "buttons/combine_button1.wav" or "buttons/combine_button2.wav", 65)
	NW.Notify(owner, bRegister and "Дверь зарегистрирована: только Альянс" or "Регистрация двери снята")
	MsgN(string.format("[DOORS] %s %s дверь %d", owner:Nick(), bRegister and "зарегистрировал" or "снял регистрацию",
		door:MapCreationID()))
end

function SWEP:PrimaryAttack()
	self:Shoot(true)
end

function SWEP:SecondaryAttack()
	self:Shoot(false)
end

function SWEP:Reload()
	if (CLIENT or (self.nextCheck or 0) > CurTime()) then
		return
	end

	self.nextCheck = CurTime() + 0.8

	local door = self:Door()
	local owner = self:GetOwner()

	if (!door) then
		return NW.Notify(owner, "Наведите на дверь")
	end

	local kind = NW.doors.Kind(door)

	NW.Notify(owner, kind and (kind.name .. ": " .. door:GetNW2String("nwDoorName", "")) or "Обычная дверь")
end

if (SERVER) then
	return
end

surface.CreateFont("nwRegisterHud", {font = "Montserrat SemiBold", size = math.max(14, math.Round(ScrH() * 0.022)),
	weight = 600, extended = true, antialias = true})

function SWEP:DrawHUD()
	local door = self:Door()
	local x, y = ScrW() / 2, ScrH() * 0.58
	local text, color

	if (!door) then
		text, color = "НАВЕДИТЕ НА ДВЕРЬ", Color(170, 176, 182)
	elseif (door:GetNW2String("nwDoorKind", "") == "alliance") then
		text, color = "ДВЕРЬ АЛЬЯНСА  ·  ПКМ — СНЯТЬ", Color(90, 190, 255)
	else
		local kind = NW.doors.Kind(door)

		text, color = (kind and string.upper(kind.name) or "НЕ ЗАРЕГИСТРИРОВАНА") .. "  ·  ЛКМ — ЗАРЕГИСТРИРОВАТЬ",
			Color(236, 206, 90)
	end

	draw.SimpleTextOutlined(text, "nwRegisterHud", x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1,
		Color(0, 0, 0, 200))
end
