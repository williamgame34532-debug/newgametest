-- Hands: RMB takes a prop or a body (ragdoll) and carries it in front of you, RMB again puts it
-- down, LMB throws it. Heavy things are dragged slower; too heavy or fixed ones cannot be taken.
AddCSLuaFile()

SWEP.PrintName = 'Руки'
SWEP.Author = 'hlalyx'
SWEP.Category = 'Half-Life: Alyx'
SWEP.Spawnable = true
SWEP.Slot = 0
SWEP.SlotPos = 0
SWEP.ViewModel = 'models/weapons/c_arms.mdl' -- just the hands of the character (fists animations)
SWEP.WorldModel = ''
SWEP.ViewModelFOV = 54
SWEP.UseHands = true
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.HoldType = 'normal'
SWEP.Primary = {ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = 'none'}
SWEP.Secondary = {ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = 'none'}

SWEP.Reach = 85          -- how far you can grab
SWEP.MaxMass = 220       -- heavier props cannot be lifted (bodies are always allowed)
SWEP.Throw = 1100        -- throw impulse for a light object; heavy ones fly slower

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:SetupDataTables()
	self:NetworkVar('Entity', 0, 'Held')
end

-- the view model: hands come up, then idle
function SWEP:PlayVM(name)
	local p = self:GetOwner()
	local vm = IsValid(p) and p:GetViewModel()
	if not IsValid(vm) then return 0 end
	local seq = vm:LookupSequence(name)
	if seq and seq >= 0 then
		vm:SendViewModelMatchingSequence(seq)
		return vm:SequenceDuration(seq)
	end
	return 0
end

function SWEP:Deploy()
	self:SetHoldType('normal')
	self.IdleAt = CurTime() + self:PlayVM('fists_draw')
	return true
end

function SWEP:Holster()
	if SERVER then self:Drop() end
	return true
end

function SWEP:OnRemove()
	if SERVER then self:Drop() end
end

function SWEP:OnDrop()
	if SERVER then self:Drop() end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.4)
	if SERVER and IsValid(self:GetHeld()) then self:Drop(true) end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.35)
	if CLIENT then return end
	if IsValid(self:GetHeld()) then self:Drop() else self:Grab() end
end

function SWEP:Reload() end

if CLIENT then
	-- a small dot at the centre of the screen, brighter over something that can be taken
	function SWEP:DrawHUD()
		local p = self:GetOwner()
		if not IsValid(p) or IsValid(self:GetHeld()) then return end
		local tr = p:GetEyeTrace()
		local e = tr.Entity
		local can = IsValid(e) and not e:IsPlayer() and not e:IsNPC() and tr.HitPos:DistToSqr(p:EyePos()) < self.Reach * self.Reach
			and (e:GetClass() == 'prop_ragdoll' or e:GetMoveType() == MOVETYPE_VPHYSICS)
		local c = HLA.Hud and HLA.Hud.AMBER_C or Color(120, 200, 255)
		surface.SetDrawColor(c.r, c.g, c.b, can and 230 or 70)
		local s = can and 4 or 2
		surface.DrawRect(ScrW() / 2 - s / 2, ScrH() / 2 - s / 2, s, s)
	end
	return
end

---------------------------------------------------------------------------------------------------
-- server: grabbing, carrying and throwing
local NOT_TAKEN = {hla_fabricator = true, hla_health_station = true, hla_forcefield = true}

function SWEP:Grab()
	local p = self:GetOwner()
	if not IsValid(p) then return end
	local tr = util.TraceLine({start = p:EyePos(), endpos = p:EyePos() + p:GetAimVector() * self.Reach, filter = p, mask = MASK_SHOT})
	local e = tr.Entity
	if not IsValid(e) or e:IsPlayer() or e:IsNPC() or NOT_TAKEN[e:GetClass()] or IsValid(e:GetParent()) then return end
	if hook.Run('HLAHandsCanGrab', p, e) == false then return end
	local ragdoll = e:GetClass() == 'prop_ragdoll'
	local ph = ragdoll and e:GetPhysicsObjectNum(tr.PhysicsBone or 0) or e:GetPhysicsObject()
	if not IsValid(ph) or not ph:IsMoveable() then return end
	if not ragdoll and e:GetMoveType() ~= MOVETYPE_VPHYSICS then return end
	if not ragdoll and ph:GetMass() > self.MaxMass then
		p:EmitSound('physics/body/body_medium_scrape_rough_loop1.wav', 55, 120, 0.4)
		timer.Simple(0.3, function() if IsValid(p) then p:StopSound('physics/body/body_medium_scrape_rough_loop1.wav') end end)
		return
	end
	self.Phys = ph
	self.Ragdoll = ragdoll
	-- keep the distance and the turn it had when taken, relative to where the player looks
	self.Dist = math.Clamp(tr.HitPos:Distance(p:EyePos()), 32, self.Reach)
	self.Offset = ph:WorldToLocal(tr.HitPos)
	self.OldGroup = e:GetCollisionGroup()
	e:SetCollisionGroup(COLLISION_GROUP_WEAPON) -- does not push the carrier
	self:SetHeld(e)
	self:SetHoldType(ragdoll and 'duel' or 'magic')
	e.HLAHeldBy = p
	p:EmitSound(ragdoll and 'physics/body/body_medium_impact_soft' .. math.random(1, 7) .. '.wav' or 'physics/cardboard/cardboard_box_impact_soft' .. math.random(1, 7) .. '.wav', 55, 100, 0.6)
end

function SWEP:Drop(throw)
	local e = self:GetHeld()
	self:SetHeld(NULL)
	self:SetHoldType('normal')
	local ph = self.Phys
	self.Phys = nil
	if not IsValid(e) then return end
	e.HLAHeldBy = nil
	local p = self:GetOwner()
	if throw and IsValid(p) and IsValid(ph) then
		local dir = p:GetAimVector()
		if self.Ragdoll then
			for i = 0, e:GetPhysicsObjectCount() - 1 do
				local b = e:GetPhysicsObjectNum(i)
				if IsValid(b) then b:SetVelocity(dir * 520 + p:GetVelocity()) end
			end
		else
			local speed = math.Clamp(self.Throw * 6 / math.max(ph:GetMass(), 1), 180, self.Throw)
			ph:SetVelocity(dir * speed + p:GetVelocity())
			ph:AddAngleVelocity(VectorRand() * 200)
		end
		p:EmitSound('weapons/slam/throw.wav', 60, math.random(95, 110), 0.7)
		self.IdleAt = CurTime() + self:PlayVM('fists_right')
		p:SetAnimation(PLAYER_ATTACK1)
	end
	-- give the old collisions back once it is clear of the player
	local old = self.OldGroup or COLLISION_GROUP_NONE
	local id = 'HLAHandsRestore' .. e:EntIndex()
	timer.Create(id, 0.25, 40, function()
		if not IsValid(e) then timer.Remove(id) return end
		if IsValid(e.HLAHeldBy) then timer.Remove(id) return end
		local clear = true
		for _, pl in ipairs(player.GetAll()) do
			local mn, mx = pl:WorldSpaceAABB()
			local emn, emx = e:WorldSpaceAABB()
			if mn.x <= emx.x and mx.x >= emn.x and mn.y <= emx.y and mx.y >= emn.y and mn.z <= emx.z and mx.z >= emn.z then clear = false break end
		end
		if clear or timer.RepsLeft(id) == 0 then
			e:SetCollisionGroup(old)
			timer.Remove(id)
		end
	end)
end

function SWEP:Think()
	if self.IdleAt and CurTime() >= self.IdleAt then
		self.IdleAt = nil
		self:PlayVM('fists_idle_0' .. math.random(1, 2))
	end
	local e = self:GetHeld()
	if not IsValid(e) then
		if self.Phys then self:Drop() end
		return
	end
	local p = self:GetOwner()
	local ph = self.Phys
	if not IsValid(p) or not p:Alive() or not IsValid(ph) or not ph:IsMoveable() then self:Drop() return end
	local eye = p:EyePos()
	local target = eye + p:GetAimVector() * self.Dist
	local grip = ph:LocalToWorld(self.Offset)
	-- let go when it got stuck far from the hands
	if grip:DistToSqr(target) > 70 * 70 or grip:DistToSqr(eye) > 140 * 140 then self:Drop() return end
	local mass = self.Ragdoll and 30 or ph:GetMass()
	local follow = math.Clamp(14 - mass / 25, 5, 14)  -- heavy things lag behind
	local vel = (target - grip) * follow + p:GetVelocity()
	if vel:Length() > 900 then vel = vel:GetNormalized() * 900 end
	ph:Wake()
	ph:SetVelocity(vel)
	if self.Ragdoll then
		-- the rest of the body hangs from the held bone; damp it so it does not flail
		for i = 0, e:GetPhysicsObjectCount() - 1 do
			local b = e:GetPhysicsObjectNum(i)
			if IsValid(b) and b ~= ph then b:SetVelocity(b:GetVelocity() * 0.92) end
		end
	else
		-- no spinning in the hands
		ph:AddAngleVelocity(-ph:GetAngleVelocity() * 0.4)
	end
end
