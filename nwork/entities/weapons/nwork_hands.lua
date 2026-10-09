--[[-------------------------------------------------------------------------
	N-work — руки.

	Оружие по умолчанию: ничего не держит в руках и не рисует прицел.
	ЛКМ — постучать (в дверь или по предмету перед собой).
---------------------------------------------------------------------------]]

SWEP.PrintName    = "Руки"
SWEP.Author       = "N-work"
SWEP.Slot         = 0
SWEP.SlotPos      = 1
SWEP.Spawnable    = false
SWEP.DrawAmmo     = false
SWEP.DrawCrosshair = false
SWEP.ViewModel    = Model( "models/weapons/c_arms.mdl" )
SWEP.WorldModel   = ""
SWEP.UseHands     = false

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

function SWEP:Initialize()
	self:SetHoldType( "normal" )
end

function SWEP:Deploy()
	if SERVER and IsValid( self:GetOwner() ) then
		self:GetOwner():DrawViewModel( false )
	end
	return true
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire( CurTime() + 0.6 )

	local owner = self:GetOwner()
	if not IsValid( owner ) then return end

	local tr = owner:GetEyeTrace()
	if not tr.Hit or tr.HitPos:DistToSqr( owner:GetShootPos() ) > 64 * 64 then return end

	local ent = tr.Entity
	local isDoor = IsValid( ent ) and string.find( ent:GetClass(), "door", 1, true )

	if SERVER then
		owner:EmitSound( isDoor and "physics/wood/wood_crate_impact_hard2.wav"
			or "physics/body/body_medium_impact_soft" .. math.random( 1, 7 ) .. ".wav", 65 )
	end
	owner:SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:SecondaryAttack() end

function SWEP:DrawWorldModel() end
