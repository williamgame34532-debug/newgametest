AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "nw_trap"
ENT.PrintName = "Капкан"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.models = {
	"models/props_junk/sawblade001a.mdl",
	"models/props_c17/trappropeller_blade.mdl"
}
ENT.armTime = 2
ENT.damage = 25
ENT.stepSize = 14

if (SERVER) then
	function ENT:FindStepper()
		local position = self:GetPos()
		local size = self.stepSize

		for _, entity in ipairs(ents.FindInBox(position + Vector(-size, -size, -4),
			position + Vector(size, size, 24))) do
			if (entity != self and NETWORK.trap.IsLiving(entity)) then
				return entity
			end
		end
	end

	function ENT:TrapThink()
		if (!self:GetSprung()) then
			local victim = self:FindStepper()

			if (IsValid(victim)) then
				self:Snap(victim)
			end

			return
		end

		local victim = self:GetVictim()

		if (!IsValid(victim)) then
			return
		end

		local bAlive = victim:IsPlayer() and victim:Alive() or (victim:IsNPC() and victim:Health() > 0)

		if (!bAlive or CurTime() >= (self.releaseAt or 0) or
			victim:GetPos():Distance(self:GetPos()) > 96) then
			self:Release()
		end
	end

	function ENT:Snap(victim)
		self:SetSprung(true)
		self:SetVictim(victim)

		self.releaseAt = CurTime() + NETWORK.trap.rootTime

		self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 75, 120)
		self:EmitSound("npc/roller/blade_cut.wav", 70, 80)

		local owner = self.nwOwner
		local info = DamageInfo()

		info:SetDamage(self.damage)
		info:SetDamageType(DMG_SLASH)
		info:SetAttacker((IsValid(owner) and owner:IsPlayer()) and owner or self)
		info:SetInflictor(self)
		info:SetDamagePosition(self:GetPos())

		victim:TakeDamageInfo(info)

		if (!IsValid(victim) or (victim:IsPlayer() and !victim:Alive())) then
			return self:SetVictim(NULL)
		end

		NETWORK.trap.Root(victim, self, NETWORK.trap.rootTime)

		if (victim:IsPlayer()) then
			victim:ViewPunch(Angle(8, 0, 0))
			NETWORK.trap.Notice(victim, "trapCaught", "bad")
		end

		NETWORK.trap.Log("капкан поймал " .. NETWORK.trap.Name(victim) .. " (владелец: " ..
			NETWORK.trap.Name(owner) .. ")", self:GetPos())
	end

	function ENT:Release(helper)
		local victim = self:GetVictim()

		self:SetVictim(NULL)

		if (!IsValid(victim)) then
			return
		end

		NETWORK.trap.Unroot(victim)

		self:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 65, 90)
	end

	function ENT:OnRemove()
		self:Release()
	end
else

	function ENT:Draw()
		if (self:GetSprung()) then
			render.SetColorModulation(0.6, 0.6, 0.6)
				self:DrawModel()
			render.SetColorModulation(1, 1, 1)

			return
		end

		self:DrawModel()
	end
end
