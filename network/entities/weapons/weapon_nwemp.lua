AddCSLuaFile()

if (CLIENT) then
	SWEP.PrintName = "EMP-инструмент"
	SWEP.Slot = 0
	SWEP.SlotPos = 7
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = true
end

SWEP.Category = "Network"
SWEP.Author = "Network"
SWEP.Instructions = "ЛКМ — взлом."
SWEP.Drop = false
SWEP.HoldType = "slam"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.ViewModelFOV = 60
SWEP.ViewModel = Model("models/weapons/v_emptool.mdl")
SWEP.WorldModel = Model("models/weapons/w_emptool.mdl")
SWEP.UseHands = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 1)

	if (CLIENT) then
		return
	end

	NETWORK.emp.TryHack(self:GetOwner())
end

function SWEP:SecondaryAttack()
end
