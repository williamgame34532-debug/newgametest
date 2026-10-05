AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Баррикада"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "BarricadeType")
	self:NetworkVar("Int", 0, "Durability")
	self:NetworkVar("Int", 1, "MaxDurability")
	self:NetworkVar("Int", 2, "OwnerChar")
end

function ENT:GetDoor()
	return self:GetNWEntity("nwBarricadeDoor", NULL)
end

function ENT:SetDoor(door)
	self:SetNWEntity("nwBarricadeDoor", door)
end

function ENT:GetTypeData()
	return NETWORK.barricade and NETWORK.barricade.Get(self:GetBarricadeType())
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

local SOUNDS = {
	wood = {
		hit = "physics/wood/wood_plank_impact_hard%d.wav", hitCount = 5,
		crack = "physics/wood/wood_crate_break%d.wav", crackCount = 5,
		broken = "physics/wood/wood_plank_break%d.wav", brokenCount = 4
	},
	metal = {
		hit = "physics/metal/metal_solid_impact_hard%d.wav", hitCount = 5,
		crack = "physics/metal/metal_box_strain%d.wav", crackCount = 4,
		broken = "physics/metal/metal_box_break%d.wav", brokenCount = 2
	},
	concrete = {
		hit = "physics/concrete/concrete_impact_hard%d.wav", hitCount = 3,
		crack = "physics/concrete/concrete_break%d.wav", crackCount = 2,
		broken = "physics/concrete/concrete_break%d.wav", brokenCount = 3
	}
}

local function PickSound(set, key)
	local entry = SOUNDS[set] or SOUNDS.wood
	local count = entry[key .. "Count"] or 1

	return string.format(entry[key], math.random(1, count))
end

function ENT:SpawnFunction(client, trace)
	if (!trace.Hit) then
		return
	end

	local entity = ents.Create("nw_barricade")

	entity:SetPos(trace.HitPos + trace.HitNormal * 8)
	entity:SetAngles(Angle(0, client:EyeAngles().y + 90, 0))
	entity:Spawn()
	entity:Activate()
	entity:ApplyType("metal", true)

	return entity
end

function ENT:Initialize()
	self:SetModel(NETWORK.barricade and NETWORK.barricade.lastResort or
		"models/props_junk/wood_crate001a.mdl")
	self:SetUseType(SIMPLE_USE)

	self.nextHitSound = 0
	self.stage = 3

	self:SetupPhysics()
end

function ENT:SetupPhysics()
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)

	local physics = self:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:EnableMotion(false)
		physics:Sleep()
	end
end

function ENT:ApplyType(id, bFresh)
	local data = NETWORK.barricade.Get(id)

	if (!data) then
		return
	end

	self:SetBarricadeType(id)

	local model = NETWORK.barricade.PickModel(data)

	if (self:GetModel() != model) then
		self:SetModel(model)
		self:SetupPhysics()
	end

	if (bFresh or self:GetMaxDurability() <= 0) then
		self:SetMaxDurability(data.health)
		self:SetDurability(data.health)
	end

	self.appliedType = id
	self.stage = self:GetStage()
end

function ENT:GetStage()
	local fraction = self:GetFraction()

	return fraction > 0.66 and 3 or (fraction > 0.33 and 2 or 1)
end

function ENT:Think()

	local id = self:GetBarricadeType()

	if (id != "" and self.appliedType != id) then
		self:ApplyType(id)
	end

	self:NextThink(CurTime() + 1)

	return true
end

function ENT:ScaleDamage(damage)
	local data = self:GetTypeData()
	local scale = data and data.damageScale or {}
	local amount = damage:GetDamage()

	if (damage:IsExplosionDamage()) then
		return amount * (scale.blast or 1)
	end

	if (damage:IsBulletDamage()) then
		return amount * (scale.bullet or 1)
	end

	if (damage:IsDamageType(DMG_CLUB) or damage:IsDamageType(DMG_SLASH)) then
		return amount * (scale.club or 1)
	end

	if (damage:IsDamageType(DMG_CRUSH)) then
		return amount * 0.25
	end

	return amount
end

function ENT:OnTakeDamage(damage)
	if (self.bBroken or self:GetDurability() <= 0) then
		return 0
	end

	local amount = math.max(math.Round(self:ScaleDamage(damage)), 0)

	if (amount <= 0) then
		return 0
	end

	local data = self:GetTypeData()
	local material = data and data.material or "wood"

	self:SetDurability(math.max(self:GetDurability() - amount, 0))

	if (self.nextHitSound < CurTime()) then
		self.nextHitSound = CurTime() + 0.15

		self:EmitSound(PickSound(material, "hit"), 70, math.random(92, 108), 0.8)
	end

	if (self:GetDurability() <= 0) then
		self:Break(damage:GetAttacker())

		return amount
	end

	local stage = self:GetStage()

	if (stage < (self.stage or 3)) then
		self.stage = stage

		self:EmitSound(PickSound(material, "crack"), 75, math.random(95, 105))

		local tone = stage == 2 and 205 or 150

		self:SetColor(Color(tone, tone, tone, 255))
	end

	return amount
end

function ENT:Break(attacker)
	if (self.bBroken) then
		return
	end

	self.bBroken = true

	local data = self:GetTypeData()
	local material = data and data.material or "wood"
	local center = self:WorldSpaceCenter()

	self:EmitSound(PickSound(material, "broken"), 80, math.random(95, 105))

	local effect = EffectData()

	effect:SetOrigin(center)
	effect:SetScale(1)
	effect:SetMagnitude(1)

	util.Effect(material == "metal" and "ManhackSparks" or "ThumperDust", effect, true, true)

	self:GibBreakClient(Vector(0, 0, 60))

	hook.Run("NetworkBarricadeBroken", self, attacker)

	self:Remove()
end

function ENT:Use(client)
	if (NETWORK.barricade.Use) then
		NETWORK.barricade.Use(client, self)
	elseif (NETWORK.barricade.BeginDismantle) then
		NETWORK.barricade.BeginDismantle(client, self)
	end
end

function ENT:RefreshStage()
	local stage = self:GetStage()

	self.stage = stage

	local tone = stage >= 3 and 255 or (stage == 2 and 205 or 150)

	self:SetColor(Color(tone, tone, tone, 255))
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
