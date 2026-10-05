AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Навесной замок"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Locked")
	self:NetworkVar("Int", 0, "Durability")
	self:NetworkVar("Int", 1, "MaxDurability")
	self:NetworkVar("Int", 2, "OwnerChar")
	self:NetworkVar("Entity", 0, "Door")
end

function ENT:GetFraction()
	return math.Clamp(self:GetDurability() / math.max(self:GetMaxDurability(), 1), 0, 1)
end

if (CLIENT) then
	function ENT:Draw()
		self:DrawModel()
	end

	return
end

function ENT:Initialize()
	self:SetModel(NETWORK.padlock.GetModel())
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetUseType(SIMPLE_USE)

	local physics = self:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:EnableMotion(false)
		physics:Sleep()
	end

	self:SetMaxDurability(NETWORK.padlock.health)
	self:SetDurability(NETWORK.padlock.health)

	self.bNoPersist = true
	self.spawnTime = CurTime()
	self.nextHitSound = 0
end

function ENT:Attach(door, position, angles)
	if (!IsValid(door)) then
		self:Remove()

		return false
	end

	self:SetDoor(door)
	self:SetPos(position)
	self:SetAngles(angles)
	self:SetParent(door)

	door:DeleteOnRemove(self)

	return true
end

function ENT:SetState(bLocked)
	self:SetLocked(bLocked and true or false)

	self:EmitSound(bLocked and "doors/door_latch3.wav" or "doors/door_latch1.wav", 65,
		bLocked and 125 or 118)

	if (NETWORK.barricade.RefreshDoor) then
		NETWORK.barricade.RefreshDoor(self:GetDoor())
	end
end

function ENT:Think()

	if (!IsValid(self:GetDoor()) and CurTime() - (self.spawnTime or 0) > 2) then
		self:Remove()

		return
	end

	self:NextThink(CurTime() + 1)

	return true
end

function ENT:OnTakeDamage(damage)
	if (self.bBroken) then
		return 0
	end

	local amount = damage:GetDamage()

	if (damage:IsExplosionDamage()) then
		amount = amount * 1.5
	elseif (damage:IsDamageType(DMG_CLUB) or damage:IsDamageType(DMG_SLASH)) then
		amount = amount * 1.25
	end

	amount = math.max(math.Round(amount), 0)

	if (amount <= 0) then
		return 0
	end

	self:SetDurability(math.max(self:GetDurability() - amount, 0))

	if (self.nextHitSound < CurTime()) then
		self.nextHitSound = CurTime() + 0.15

		self:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) ..
			".wav", 70, math.random(110, 125))
	end

	if (self:GetDurability() <= 0) then
		self:Break(damage:GetAttacker())
	end

	return amount
end

function ENT:Break(attacker)
	if (self.bBroken) then
		return
	end

	self.bBroken = true

	self:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 75, 120)

	local effect = EffectData()

	effect:SetOrigin(self:WorldSpaceCenter())
	effect:SetMagnitude(1)
	effect:SetScale(1)

	util.Effect("ManhackSparks", effect, true, true)

	if (NETWORK.padlock.OnBroken) then
		NETWORK.padlock.OnBroken(self, attacker)
	end

	self:Remove()
end

function ENT:Use(client)
	if (NETWORK.padlock.Use) then
		NETWORK.padlock.Use(client, self)
	end
end

function ENT:OnRemove()
	local door = self:GetDoor()

	if (IsValid(door) and NETWORK.barricade and NETWORK.barricade.RefreshDoor) then
		timer.Simple(0, function()
			NETWORK.barricade.RefreshDoor(door)
		end)
	end
end

function ENT:CanProperty(client)
	return IsValid(client) and client:IsAdmin()
end

function ENT:CanTool(client)
	return IsValid(client) and client:IsAdmin()
end
