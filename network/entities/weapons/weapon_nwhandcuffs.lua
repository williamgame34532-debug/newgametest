AddCSLuaFile()

if (CLIENT) then
	SWEP.PrintName = "Наручники"
	SWEP.Slot = 0
	SWEP.SlotPos = 6
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = true
end

SWEP.Category = "Network"
SWEP.Author = "Network"
SWEP.Instructions = "ЛКМ (удерживать) — надеть. ПКМ — снять."
SWEP.Drop = false
SWEP.HoldType = "normal"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.ViewModelFOV = 54

local function Usable(path)
	return (file.Size(path, "GAME") or 0) > 0
end

local V_MODEL = "models/chara/simplehandcuffs/v_handcuffs.mdl"
local W_MODEL = "models/chara/simplehandcuffs/w_handcuffs.mdl"

SWEP.bRealModels = Usable(V_MODEL) and Usable(W_MODEL)
SWEP.ViewModel = SWEP.bRealModels and V_MODEL or "models/weapons/c_arms.mdl"
SWEP.WorldModel = SWEP.bRealModels and W_MODEL or ""
SWEP.UseHands = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = ""
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""
SWEP.CuffTime = 4
SWEP.UncuffTime = 5

function SWEP:Initialize()
	self:SetHoldType(self.bRealModels and "slam" or self.HoldType)
end

function SWEP:Deploy()
	return true
end

function SWEP:Reload()
end

if (CLIENT) then
	function SWEP:DrawWorldModel()
		if (self.bRealModels) then
			self:DrawModel()
		end
	end
end

function SWEP:PrimaryAttack()
	if (CLIENT) then
		return
	end

	local owner = self:GetOwner()
	local target = NETWORK.restraint.GetTarget(owner)

	if (!target or target:GetNWBool("nwCuffed", false)) then
		self:SetNextPrimaryFire(CurTime() + 0.5)

		return
	end

	NETWORK.restraint.BeginCuff(owner, target, self.CuffTime)
	self:SetNextPrimaryFire(CurTime() + 0.2)
end

function SWEP:SecondaryAttack()
	if (CLIENT) then
		return
	end

	local owner = self:GetOwner()

	self:SetNextSecondaryFire(CurTime() + 0.5)

	if (owner.nwUncuffTask) then
		NETWORK.restraint.CancelUncuff(owner, "uncuffCancelled")

		return
	end

	local target = NETWORK.restraint.GetTarget(owner)

	if (!target or !target:GetNWBool("nwCuffed", false)) then
		return
	end

	NETWORK.restraint.BeginUncuff(owner, target, self.UncuffTime)
end

function SWEP:Holster()
	if (SERVER and IsValid(self:GetOwner())) then
		NETWORK.restraint.CancelCuff(self:GetOwner())
		NETWORK.restraint.CancelUncuff(self:GetOwner())
	end

	return true
end
