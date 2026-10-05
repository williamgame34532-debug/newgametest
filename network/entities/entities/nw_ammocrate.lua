AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ящик патронов"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.Models = {
	"models/items/ammocrate_smg1.mdl",
	"models/items/ammocrate_ar2.mdl",
	"models/items/ammocrate_pistol.mdl"
}

ENT.max = 40
ENT.perUse = 1
ENT.range = 90

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Rounds")
	self:NetworkVar("String", 0, "Faction")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_ammocrate")

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0))
		entity:Spawn()
		entity:Activate()
		entity:SetFaction(client:HasCharacter() and client:GetCharacterFaction() or "")

		return entity
	end

	function ENT:Initialize()
		self:SetModel(self.Models[1])
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:EnableMotion(false)
		end

		if (self:GetRounds() <= 0) then
			self:SetRounds(self.max)
		end
	end

	function ENT:CanUse(client)
		local faction = self:GetFaction()

		if (faction == "" or client:IsAdmin()) then
			return true
		end

		if (client:GetCharacterFaction() == faction) then
			return true
		end

		local data = NETWORK.factions.Get(faction)

		return (data and data.bCombine) and NETWORK.factions.IsAlliance(client)
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.8

		if (!self:CanUse(client)) then
			return NETWORK.notice.Send(client, "ammoCrateForeign", "warn")
		end

		if (self:GetRounds() <= 0) then
			return NETWORK.notice.Send(client, "ammoCrateEmpty", "warn")
		end

		local weapon = client:GetActiveWeapon()

		if (!IsValid(weapon) or weapon:GetMaxClip1() <= 0) then
			return NETWORK.notice.Send(client, "ammoCrateNoWeapon", "warn")
		end

		local ammoType = game.GetAmmoName(weapon:GetPrimaryAmmoType() or 0)
		local id = (NETWORK.mech and NETWORK.mech.ammoItems or {})[ammoType or ""]

		if (!id) then
			return NETWORK.notice.Send(client, "ammoCrateNoWeapon", "warn")
		end

		self:SetRounds(self:GetRounds() - self.perUse)

		if (!NETWORK.inventory.Give(client, id, 1)) then
			NETWORK.item.Spawn(id, self:GetPos() + Vector(0, 0, 20))
		end

		self:EmitSound("items/ammo_pickup.wav", 60, 100)

		NETWORK.notice.Send(client, "ammoCrateTaken", "good", self:GetRounds())
	end
end

if (CLIENT) then
	function ENT:Draw()
		self:DrawModel()
	end
end
