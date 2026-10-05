AddCSLuaFile()

if (CLIENT) then
	SWEP.PrintName = "Электродубинка"
	SWEP.Slot = 0
	SWEP.SlotPos = 5
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
end

SWEP.Category = "Network"
SWEP.Author = "Chessnut"
SWEP.Purpose = "Служебное снаряжение Гражданской Обороны."
SWEP.Instructions = "ЛКМ — удар. ALT + ЛКМ — заряд. ПКМ — стук или толчок."
SWEP.Drop = false

SWEP.HoldType = "melee"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.ViewModelFOV = 47
SWEP.ViewModelFlip = false
SWEP.AnimPrefix = "melee"
SWEP.ViewTranslation = 4

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
SWEP.LowerAngles = Angle(15, -10, -20)
SWEP.FireWhenLowered = true

SWEP.StunsToDrop = 3
SWEP.StunMemory = 10
SWEP.RagdollTime = 60

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Activated")
end

function SWEP:Precache()
	util.PrecacheSound("physics/wood/wood_crate_impact_hard3.wav")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:OnRaised()
	self.lastRaiseTime = CurTime()
end

function SWEP:OnLowered()
	if (!self:GetActivated()) then
		return
	end

	self:SetActivated(false)

	local owner = self:GetOwner()

	if (SERVER and IsValid(owner)) then
		owner:EmitSound("Weapon_StunStick.Deactivate")

		if (NETWORK.anim.GetModelClass(owner:GetModel()) == "metrocop" and
			owner:LookupSequence("deactivatebaton") > 0) then
			owner:ForceSequence("deactivatebaton", nil, nil, true)
		end
	end
end

function SWEP:Holster()
	self:OnLowered()

	return true
end

local GLOW = Material("effects/stunstick")
local FLARE = Material("effects/blueflare1")
local GLOW_NOZ = Material("sprites/light_glow02_add_noz")
local GLOW_COLOR = Color(128, 128, 128)

function SWEP:DrawWorldModel()
	self:DrawModel()

	if (!self:GetActivated()) then
		return
	end

	local attachment = self:GetAttachment(1)

	if (!attachment) then
		return
	end

	local size = math.Rand(4, 6)
	local level = math.Rand(0.6, 0.8) * 255
	local color = Color(level, level, level)

	render.SetMaterial(FLARE)
	render.DrawSprite(attachment.Pos, size * 2, size * 2, color)

	render.SetMaterial(GLOW)
	render.DrawSprite(attachment.Pos, size, size + 3, GLOW_COLOR)
end

local BEAM_ATTACHMENTS = 9

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

		local core = viewModel:GetAttachment(viewModel:LookupAttachment("sparkrear"))

		if (core) then
			local size = math.Rand(3, 4)

			render.DrawSprite(core.Pos, size * 10, size * 15, color)
		end

		for index = 1, BEAM_ATTACHMENTS do
			for _, suffix in ipairs({"a", "b"}) do
				local attachment = viewModel:GetAttachment(
					viewModel:LookupAttachment("spark" .. index .. suffix))

				if (attachment and attachment.Pos) then
					local size = math.Rand(2.5, 5)

					render.DrawSprite(attachment.Pos, size, size, color)
				end
			end
		end
	cam.End3D()
end

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	if (!IsValid(owner) or !owner:IsWeaponRaised()) then
		return
	end

	if (owner:KeyDown(IN_WALK)) then
		if (SERVER) then
			local bState = !self:GetActivated()

			self:SetActivated(bState)

			owner:EmitSound(bState and "Weapon_StunStick.Activate" or
				"Weapon_StunStick.Deactivate")

			if (NETWORK.anim.GetModelClass(owner:GetModel()) == "metrocop") then
				owner:ForceSequence(bState and "activatebaton" or "deactivatebaton",
					nil, nil, true)
			end
		end

		return
	end

	self:EmitSound("Weapon_StunStick.Swing")
	self:SendWeaponAnim(ACT_VM_HITCENTER)

	owner:SetAnimation(PLAYER_ATTACK1)
	owner:ViewPunch(Angle(1, 0, 0.125))

	owner:LagCompensation(true)
		local data = {
			start = owner:GetShootPos(),
			endpos = owner:GetShootPos() + owner:GetAimVector() * 72,
			filter = owner
		}
		local trace = util.TraceLine(data)
	owner:LagCompensation(false)

	if (!SERVER or !trace.Hit) then
		return
	end

	local damage = self:GetActivated() and 5 or self.Primary.Damage

	if (self:GetActivated()) then
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

		if (self:GetActivated()) then
			entity.nwStuns = (entity.nwStuns or 0) + 1

			timer.Simple(self.StunMemory, function()
				if (IsValid(entity)) then
					entity.nwStuns = math.max((entity.nwStuns or 1) - 1, 0)
				end
			end)

			if (entity.nwStuns > self.StunsToDrop) then
				entity.nwStuns = 0

				NETWORK.ragdoll.Start(entity, self.RagdollTime)

				return
			end
		end
	elseif (entity:IsRagdoll()) then
		damage = self:GetActivated() and 2 or 10
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
		local trace = util.TraceHull({
			start = owner:GetShootPos(),
			endpos = owner:GetShootPos() + owner:GetAimVector() * 72,
			filter = owner,
			mins = Vector(-8, -8, -30),
			maxs = Vector(8, 8, 10)
		})
	owner:LagCompensation(false)

	local entity = trace.Entity

	if (!SERVER or !IsValid(entity)) then
		return
	end

	local bPushed = false

	if (NETWORK.door.IsDoor(entity)) then
		owner:ViewPunch(Angle(-1.3, 1.8, 0))
		owner:EmitSound("physics/wood/wood_crate_impact_hard3.wav")
		owner:SetAnimation(PLAYER_ATTACK1)

		self:SetNextSecondaryFire(CurTime() + 0.4)
		self:SetNextPrimaryFire(CurTime() + 1)

		return
	elseif (entity:IsPlayer()) then
		local direction = owner:GetAimVector() * 300

		direction.z = 0

		entity:SetVelocity(direction)

		bPushed = true
	else
		local physics = entity:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:SetVelocity(owner:GetAimVector() * 180)

			bPushed = true
		end
	end

	if (!bPushed) then
		return
	end

	self:SetNextSecondaryFire(CurTime() + 1.5)
	self:SetNextPrimaryFire(CurTime() + 1.5)

	owner:EmitSound("Weapon_Crossbow.BoltHitBody")

	if (NETWORK.anim.GetModelClass(owner:GetModel()) == "metrocop") then
		owner:ForceSequence("pushplayer")
	end
end
