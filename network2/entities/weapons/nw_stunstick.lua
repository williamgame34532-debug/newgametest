AddCSLuaFile()

-- The stunstick of Civil Protection (after the Helix ix_stunstick, Chessnut), made for Network:
--   on safety it is carried (HL:A idles with the baton, the sprint with it - sh_anims.lua, set
--   "stunstick"); hold R to raise it
--   LMB              a blow (7.5); switched on - a stun blow (5): four stuns within 10 seconds knock the
--                    target out (NW.body.Knock)
--   Alt + LMB        switch the stun on / off (only raised)
--   RMB              knock on a door, push a player (stronger with Strength) or shove a prop
-- Every member of Civil Protection gets one as an item when joining the faction (FACTION.items).

if (CLIENT) then
	SWEP.PrintName = "Электродубинка"
	SWEP.Slot = 0
	SWEP.SlotPos = 5
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
end

SWEP.Category = "Network"
SWEP.Author = "Chessnut, Network"
SWEP.Instructions = "ЛКМ: удар. Alt + ЛКМ: электрошок. ПКМ: толкнуть / постучать."
SWEP.Purpose = "Порядок на улицах Сити-17."
SWEP.Drop = false

SWEP.HoldType = "melee"
SWEP.HasSafety = true

SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.ViewModelFOV = 47
SWEP.ViewModelFlip = false
SWEP.AnimPrefix = "melee"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""
SWEP.Primary.Damage = 7.5
SWEP.Primary.Delay = 0.7

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.ViewModel = Model("models/weapons/c_stunstick.mdl")
SWEP.WorldModel = Model("models/weapons/w_stunbaton.mdl")
SWEP.UseHands = true

local STUNS_TO_KNOCK = 4

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Activated")
end

function SWEP:Precache()
	util.PrecacheSound("physics/wood/wood_crate_impact_hard3.wav")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Holster()
	self:SetActivated(false)

	return true
end

function SWEP:Think()
	-- put on safety: the stun goes off
	if (SERVER and self:GetActivated() and IsValid(self:GetOwner()) and !self:GetOwner():IsWeaponRaised()) then
		self:SetActivated(false)
		self:GetOwner():EmitSound("Weapon_StunStick.Deactivate")
	end
end

-- ------------------------------------------------------------------- the glow --
if (CLIENT) then
	local GLOW = Material("effects/stunstick")
	local GLOW2 = Material("effects/blueflare1")
	local GLOW_NOZ = Material("sprites/light_glow02_add_noz")
	local color_glow = Color(128, 128, 128)

	function SWEP:DrawWorldModel()
		self:DrawModel()

		if (!self:GetActivated()) then
			return
		end

		local attachment = self:GetAttachment(1)

		if (attachment) then
			local size = math.Rand(4, 6)
			local glow = math.Rand(0.6, 0.8) * 255

			render.SetMaterial(GLOW2)
			render.DrawSprite(attachment.Pos, size * 2, size * 2, Color(glow, glow, glow))
			render.SetMaterial(GLOW)
			render.DrawSprite(attachment.Pos, size, size + 3, color_glow)
		end
	end

	function SWEP:PostDrawViewModel()
		if (!self:GetActivated()) then
			return
		end

		local viewModel = LocalPlayer():GetViewModel()

		if (!IsValid(viewModel)) then
			return
		end

		cam.Start3D(EyePos(), EyeAngles())
			local color = Color(255, 255, 255, 50 + math.sin(RealTime() * 2) * 20)

			GLOW_NOZ:SetFloat("$alpha", color.a / 255)
			render.SetMaterial(GLOW_NOZ)

			local attachment = viewModel:GetAttachment(viewModel:LookupAttachment("sparkrear"))

			if (attachment) then
				local size = math.Rand(3, 4)

				render.DrawSprite(attachment.Pos, size * 10, size * 15, color)
			end

			for i = 1, 9 do
				for _, side in ipairs({"a", "b"}) do
					attachment = viewModel:GetAttachment(viewModel:LookupAttachment("spark" .. i .. side))

					if (attachment and attachment.Pos) then
						local size = math.Rand(2.5, 5)

						render.DrawSprite(attachment.Pos, size, size, color)
					end
				end
			end
		cam.End3D()
	end
end

-- ------------------------------------------------------------------ attacks --
function SWEP:PrimaryAttack()
	local owner = self:GetOwner()

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	if (!IsValid(owner) or !owner:IsWeaponRaised()) then
		return
	end

	-- Alt + LMB: the stun on / off
	if (owner:KeyDown(IN_WALK)) then
		if (SERVER) then
			self:SetActivated(!self:GetActivated())
			owner:EmitSound(self:GetActivated() and "Weapon_StunStick.Activate" or "Weapon_StunStick.Deactivate")
		end

		return
	end

	self:EmitSound("Weapon_StunStick.Swing")
	self:SendWeaponAnim(ACT_VM_HITCENTER)
	owner:SetAnimation(PLAYER_ATTACK1)
	owner:ViewPunch(Angle(1, 0, 0.125))

	owner:LagCompensation(true)

	local data = {start = owner:GetShootPos(), filter = owner}

	data.endpos = data.start + owner:GetAimVector() * 72

	local trace = util.TraceLine(data)

	owner:LagCompensation(false)

	if (!SERVER or !trace.Hit) then
		return
	end

	local stun = self:GetActivated()
	local damage = stun and 5 or self.Primary.Damage

	if (stun) then
		local effect = EffectData()

		effect:SetStart(trace.HitPos)
		effect:SetNormal(trace.HitNormal)
		effect:SetOrigin(trace.HitPos)
		util.Effect("StunstickImpact", effect, true, true)
	end

	owner:EmitSound("Weapon_StunStick.Melee_HitWorld")

	local entity = trace.Entity

	if (!IsValid(entity)) then
		return
	end

	if (entity:IsPlayer()) then
		entity:ViewPunch(Angle(-20, math.random(-15, 15), math.random(-10, 10)))

		if (stun) then
			if (CurTime() - (entity.nwStunLast or 0) > 10) then
				entity.nwStuns = 0
			end

			entity.nwStunLast = CurTime()
			entity.nwStuns = (entity.nwStuns or 0) + 1

			if (entity.nwStuns >= STUNS_TO_KNOCK and NW.body and NW.body.Knock) then
				entity.nwStuns = 0
				NW.body.Knock(entity)

				return
			end
		end
	elseif (entity:IsRagdoll()) then
		damage = stun and 2 or 10
	end

	local info = DamageInfo()

	info:SetAttacker(owner)
	info:SetInflictor(self)
	info:SetDamage(damage)
	info:SetDamageType(DMG_CLUB)
	info:SetDamagePosition(trace.HitPos)
	info:SetDamageForce(owner:GetAimVector() * 10000)
	entity:DispatchTraceAttack(info, data.start, data.endpos)
end

function SWEP:SecondaryAttack()
	local owner = self:GetOwner()

	if (!IsValid(owner)) then
		return
	end

	owner:LagCompensation(true)

	local data = {start = owner:GetShootPos(), filter = owner, mins = Vector(-8, -8, -30), maxs = Vector(8, 8, 10)}

	data.endpos = data.start + owner:GetAimVector() * 72

	local trace = util.TraceHull(data)

	owner:LagCompensation(false)

	local entity = trace.Entity

	if (!SERVER or !IsValid(entity)) then
		return
	end

	if (NW.doors and NW.doors.IsDoor(entity)) then
		if (hook.Run("CanPlayerKnock", owner, entity) == false) then
			return
		end

		owner:ViewPunch(Angle(-1.3, 1.8, 0))
		owner:EmitSound("physics/wood/wood_crate_impact_hard3.wav")
		owner:SetAnimation(PLAYER_ATTACK1)
		self:SetNextSecondaryFire(CurTime() + 0.4)
		self:SetNextPrimaryFire(CurTime() + 1)

		return
	end

	if (entity:IsPlayer()) then
		local character = owner.nwCharacter
		local strength = character and character.skills and character.skills.strength or 0
		local direction = owner:GetAimVector() * (300 + strength * 15)

		direction.z = 0
		entity:SetVelocity(direction)
	else
		local physics = entity:GetPhysicsObject()

		if (!IsValid(physics)) then
			return
		end

		physics:SetVelocity(owner:GetAimVector() * 180)
	end

	self:SetNextSecondaryFire(CurTime() + 1.5)
	self:SetNextPrimaryFire(CurTime() + 1.5)
	owner:EmitSound("Weapon_Crossbow.BoltHitBody")
end
