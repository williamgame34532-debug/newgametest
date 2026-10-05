AddCSLuaFile()

SWEP.PrintName = "Регистратор дверей Альянса"
SWEP.Author = "Network"
SWEP.Category = "Network"
SWEP.Instructions = "ЛКМ — зарегистрировать дверь за Альянсом, ПКМ — снять регистрацию"
SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.Slot = 0
SWEP.SlotPos = 5
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

SWEP.reach = 220

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)

	return true
end

function SWEP:DrawWorldModel()
end

function SWEP:GetDoor()
	local owner = self:GetOwner()
	local trace = owner:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or owner:GetPos():Distance(trace.HitPos) > self.reach) then
		return
	end

	if (!NETWORK.door.IsDoor(entity)) then
		return
	end

	return entity
end

function SWEP:CanUse()
	local owner = self:GetOwner()

	return SERVER and IsValid(owner) and owner:IsAdmin() and owner:HasCharacter()
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.6)

	if (!self:CanUse()) then
		return
	end

	local owner = self:GetOwner()
	local door = self:GetDoor()

	if (!door) then
		return NETWORK.notice.Send(owner, "doorNotDoor", "warn")
	end

	local data = NETWORK.door.GetData(door)

	if (data and data.type == "faction") then
		return NETWORK.notice.Send(owner, "doorRegAlready", "info")
	end

	data = data or {}
	data.type = "faction"
	data.factions = NETWORK.door.ParseFactions("alliance")
	data.bLocked = false

	NETWORK.door.Set(door, data)
	NETWORK.door.Close(door, data)

	door:EmitSound("buttons/combine_button1.wav", 60, 100)

	NETWORK.notice.Send(owner, "doorRegistered", "good")
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.6)

	if (!self:CanUse()) then
		return
	end

	local owner = self:GetOwner()
	local door = self:GetDoor()

	if (!door) then
		return NETWORK.notice.Send(owner, "doorNotDoor", "warn")
	end

	local data = NETWORK.door.GetData(door)

	if (!data or data.type != "faction") then
		return NETWORK.notice.Send(owner, "doorRegNone", "info")
	end

	NETWORK.door.Set(door, nil)

	door:EmitSound("buttons/combine_button2.wav", 60, 100)

	NETWORK.notice.Send(owner, "doorUnregistered", "info")
end
