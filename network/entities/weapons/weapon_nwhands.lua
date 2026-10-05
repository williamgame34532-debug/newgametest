AddCSLuaFile()

SWEP.PrintName = "Руки"
SWEP.Author = "Network"
SWEP.Category = "Network"
SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.Slot = 0
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
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

SWEP.reach = 96
SWEP.carryDistance = 68
SWEP.maxMass = 220
SWEP.throwForce = 260
SWEP.knockDelay = 0.9
SWEP.pushForce = 190
SWEP.pushStamina = 8
SWEP.pushDelay = 0.7
SWEP.pushForce = 210
SWEP.pushStamina = 6
SWEP.pushDelay = 0.8

SWEP.punchDamage = 7
SWEP.punchReach = 72
SWEP.punchDelay = 0.55
SWEP.punchStamina = 2
SWEP.punchForce = 140

SWEP.lowerOffset = Vector(0, 0, -3.5)
SWEP.lowerAngle = Angle(2, 0, 0)

local DOORS = {
	prop_door_rotating = true,
	func_door = true,
	func_door_rotating = true,
	prop_dynamic = false
}

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:GetViewModelPosition(position, angles)
	local right = angles:Right()
	local up = angles:Up()
	local forward = angles:Forward()
	local offset = self.lowerOffset

	position = position + right * offset.x + up * offset.z + forward * offset.y

	angles:RotateAroundAxis(right, self.lowerAngle.p)

	return position, angles
end

function SWEP:CanUse()
	local owner = self:GetOwner()

	return IsValid(owner) and owner:Alive() and owner:HasCharacter()
end

function SWEP:PrimaryAttack()
	if (!SERVER or !self:CanUse()) then
		return
	end

	if (self.carried) then
		self:SetNextPrimaryFire(CurTime() + 0.4)
		self:Throw()

		return
	end

	self:Punch()
end

function SWEP:Punch()
	local owner = self:GetOwner()

	if ((self.nextPunch or 0) > CurTime()) then
		return
	end

	if (owner:IsExhausted() or owner:GetStamina() < self.punchStamina) then
		return
	end

	if (!owner:IsWeaponRaised()) then
		if ((self.nextRaiseHint or 0) < CurTime()) then
			self.nextRaiseHint = CurTime() + 2

			NETWORK.notice.Send(owner, "handsRaiseToPunch", "info")
		end

		self:SetNextPrimaryFire(CurTime() + 0.3)

		return
	end

	if (hook.Run("NetworkCanPunch", owner) == false) then
		return
	end

	self.nextPunch = CurTime() + self.punchDelay
	self:SetNextPrimaryFire(CurTime() + self.punchDelay)

	owner:SetAnimation(PLAYER_ATTACK1)
	owner:ViewPunch(Angle(-3, math.Rand(-2.5, 2.5), 0))
	owner:SetNWFloat("nwStamina", math.max(owner:GetStamina() - self.punchStamina, 0))
	owner.nwStaminaDelay = CurTime() + NETWORK.stamina.regenDelay

	local start = owner:EyePos()
	local trace = util.TraceHull({
		start = start,
		endpos = start + owner:GetAimVector() * self.punchReach,
		filter = owner,
		mins = Vector(-6, -6, -6),
		maxs = Vector(6, 6, 6),
		mask = MASK_SHOT_HULL
	})
	local entity = trace.Entity

	util.ScreenShake(owner:GetPos(), 4, 8, 0.3, 48)

	if (!IsValid(entity) or (!entity:IsPlayer() and !entity:IsNPC() and
		!entity:IsNextBot() and !entity:IsRagdoll())) then
		owner:EmitSound("npc/vort/claw_swing" .. math.random(1, 2) .. ".wav", 60,
			math.random(95, 110))

		if (IsValid(entity) and DOORS[entity:GetClass()]) then
			self:Knock(entity)
		end

		return
	end

	if (entity:IsPlayer() and (!entity:Alive() or !entity:HasCharacter())) then
		return
	end

	local strength = NETWORK.skills and NETWORK.skills.Get(owner, "strength") or 0
	local damage = self.punchDamage + strength * NETWORK.skills.Effect("strength", "punch")

	if (entity.SetLastHitGroup) then
		entity:SetLastHitGroup(HITGROUP_GENERIC)
	end

	local info = DamageInfo()

	info:SetAttacker(owner)
	info:SetInflictor(self)
	info:SetDamage(damage)
	info:SetDamageType(DMG_CLUB)
	info:SetDamagePosition(trace.HitPos)
	info:SetDamageForce(owner:GetAimVector() * damage * 120)

	entity:TakeDamageInfo(info)

	if (entity:IsPlayer()) then
		local direction = owner:GetAimVector()

		direction.z = 0
		direction:Normalize()

		entity:SetVelocity(direction * self.punchForce + Vector(0, 0, 30))
		entity:ViewPunch(Angle(math.Rand(4, 7), math.Rand(-5, 5), 0))

		util.ScreenShake(entity:GetPos(), 6, 10, 0.35, 48)
	end

	entity:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav",
		68, math.random(95, 105))

	NETWORK.chat.Send(owner, "it", L("handsPunch"))

	hook.Run("NetworkPunchLanded", owner, entity, damage)
end

function SWEP:SecondaryAttack()
end

function SWEP:IsCarryable(entity)
	if (entity.nwNoCarry) then
		return false
	end

	if (!IsValid(entity)) then
		return false
	end

	if (entity:IsRagdoll()) then
		return true
	end

	local physics = entity:GetPhysicsObject()

	if (!IsValid(physics) or !physics:IsMoveable()) then
		return false
	end

	local owner = self:GetOwner()
	local maxMass = self.maxMass + (NETWORK.skills and IsValid(owner) and
		NETWORK.skills.Get(owner, "strength") * NETWORK.skills.Effect("strength", "carryMass") or 0)

	if (physics:GetMass() > maxMass) then
		return false
	end

	return entity:GetClass() == "nw_item" or entity:GetClass():find("prop_physics") != nil
end

function SWEP:Knock(entity)
	local owner = self:GetOwner()

	if ((self.nextKnock or 0) > CurTime()) then
		return
	end

	self.nextKnock = CurTime() + self.knockDelay

	entity:EmitSound("physics/wood/wood_crate_impact_hard" .. math.random(2, 3) .. ".wav",
		70, math.random(95, 105))

	owner:SetAnimation(PLAYER_ATTACK1)

	NETWORK.chat.Send(owner, "it", L("handsKnock"))
end

function SWEP:Grab()
	local owner = self:GetOwner()
	local trace = owner:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or owner:GetPos():Distance(trace.HitPos) > self.reach) then
		return
	end

	if (DOORS[entity:GetClass()]) then
		self:Knock(entity)

		return
	end

	if (entity:GetClass() == "nw_furniture" and entity.GetOwnerChar) then
		if (entity:GetOwnerChar() == tostring(owner:GetCharacterID()) or owner:IsAdmin()) then
			entity:EmitSound("physics/wood/wood_box_impact_soft" .. math.random(1, 3) .. ".wav",
				60, 100)
			entity:Remove()

			owner:SetAnimation(PLAYER_ATTACK1)

			NETWORK.notice.Send(owner, "furnitureRemoved", "info")
		else
			NETWORK.notice.Send(owner, "furnitureNotYours", "warn")
		end

		return
	end

	if (entity:IsPlayer()) then
		self:Push(entity)

		return
	end

	if (!self:IsCarryable(entity)) then
		return
	end

	if (hook.Run("NetworkCanCarry", owner, entity) == false) then
		return
	end

	self.carried = entity
	self.carriedBone = entity:IsRagdoll() and (trace.PhysicsBone or 0) or 0

	owner:SetAnimation(PLAYER_ATTACK1)
	owner:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 4) .. ".wav",
		55, 105, 0.4)
end

function SWEP:Push(target)
	local owner = self:GetOwner()

	if ((self.nextPush or 0) > CurTime() or owner:IsExhausted()) then
		return
	end

	self.nextPush = CurTime() + self.pushDelay

	local direction = (target:GetPos() - owner:GetPos()):GetNormalized()

	direction.z = 0
	direction:Normalize()

	target:SetVelocity(direction * self.pushForce + Vector(0, 0, 40))

	owner:SetNWFloat("nwStamina", math.max(owner:GetStamina() - self.pushStamina, 0))
	owner.nwStaminaDelay = CurTime() + NETWORK.stamina.regenDelay
	owner:SetAnimation(PLAYER_ATTACK1)
	owner:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 4) .. ".wav",
		62, 100)

	NETWORK.chat.Send(owner, "it", L("handsPush"))
end

function SWEP:Push(target)
	local owner = self:GetOwner()

	if ((self.nextPush or 0) > CurTime()) then
		return
	end

	if (owner:GetStamina() < NETWORK.stamina.jumpCost * 0.5) then
		return
	end

	self.nextPush = CurTime() + self.pushDelay

	local direction = (target:GetPos() - owner:GetPos())

	direction.z = 0
	direction:Normalize()

	target:SetVelocity(direction * self.pushForce + Vector(0, 0, 40))

	owner:SetNWFloat("nwStamina", math.max(owner:GetStamina() - self.pushStamina, 0))
	owner.nwStaminaDelay = CurTime() + NETWORK.stamina.regenDelay

	owner:SetAnimation(PLAYER_ATTACK1)
	owner:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 4) .. ".wav",
		60, 105)

	target:EmitSound("physics/body/body_medium_impact_soft" .. math.random(5, 7) .. ".wav",
		60, 100)

	hook.Run("NetworkPlayerPushed", owner, target)
end

function SWEP:GetCarriedPhysics()
	if (!IsValid(self.carried)) then
		return
	end

	if (self.carried:IsRagdoll()) then
		return self.carried:GetPhysicsObjectNum(self.carriedBone or 0)
	end

	return self.carried:GetPhysicsObject()
end

function SWEP:UpdateCarry()
	local owner = self:GetOwner()
	local physics = self:GetCarriedPhysics()

	if (!IsValid(physics)) then
		self:Release()

		return
	end

	if (owner:GetPos():Distance(physics:GetPos()) > self.reach * 2.2) then
		self:Release()

		return
	end

	local target = owner:EyePos() + owner:GetAimVector() * self.carryDistance
	local mass = math.max(physics:GetMass(), 1)
	local strength = math.Clamp(45 / mass, 0.08, 1)
	local delta = target - physics:GetPos()

	physics:Wake()
	physics:SetVelocity(delta * 9 * strength)
	physics:AddAngleVelocity(-physics:GetAngleVelocity() * 0.4)

	if (mass > 60) then
		self.bSlowed = true

		owner:SetWalkSpeed(NETWORK.movement.walkSpeed * 0.55)
		owner:SetRunSpeed(NETWORK.movement.walkSpeed * 0.7)
	end
end

function SWEP:Throw()
	local physics = self:GetCarriedPhysics()
	local owner = self:GetOwner()

	if (IsValid(physics)) then
		local mass = math.max(physics:GetMass(), 1)

		physics:Wake()
		physics:SetVelocity(owner:GetAimVector() * self.throwForce *
			math.Clamp(40 / mass, 0.15, 1.4))

		owner:SetAnimation(PLAYER_ATTACK1)
	end

	self:Release()
end

function SWEP:Release()
	local owner = self:GetOwner()

	self.carried = nil
	self.carriedBone = nil

	if (IsValid(owner) and self.bSlowed) then
		self.bSlowed = nil

		NETWORK.movement.Apply(owner)
	end
end

function SWEP:Think()
	if (!SERVER) then
		return
	end

	local owner = self:GetOwner()

	if (!IsValid(owner) or !owner:Alive()) then
		return
	end

	if (!owner:KeyDown(IN_ATTACK2) or !self:CanUse()) then
		if (self.carried) then
			self:Release()
		end

		self.bGrabbed = false

		return
	end

	if (!self.bGrabbed) then
		self.bGrabbed = true

		self:Grab()

		return
	end

	if (IsValid(self.carried)) then
		self:UpdateCarry()
	end
end

function SWEP:OnDrop()
	self:Release()
end

function SWEP:Holster()
	if (SERVER and self.carried) then
		self:Release()
	end

	return true
end

function SWEP:OnRemove()
	if (SERVER and self.carried) then
		self:Release()
	end
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
	self:SendWeaponAnim(ACT_VM_DRAW)

	return true
end

function SWEP:DrawWorldModel()
end
