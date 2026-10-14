-- A container (a crate, a locker, a stash): E opens the storage window (sv_storage.lua). Admins
-- spawn it from the spawn menu (Entities → network2) and set it up in that window → Настроить:
-- name, model, grid (up to 10 x 10), the loot table and how often the loot comes back.
-- Containers are saved per map with what is inside (sv_containers.lua).

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Контейнер"
ENT.Category = "network2"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Title")
end

if (SERVER) then
	ENT.DefaultModel = "models/props_junk/wood_crate001a.mdl"

	function ENT:SpawnFunction(client, trace, class)
		if (!trace.Hit) then
			return
		end

		local entity = ents.Create(class)

		entity:SetPos(trace.HitPos + trace.HitNormal * 24)
		entity:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self.nwData = self.nwData or NW.containers.Default()

		self:Apply()
		self:SetUseType(SIMPLE_USE)
		NW.containers.Changed()
	end

	-- the model and physics from the settings; the container stays where it was put
	function ENT:Apply()
		local data = self.nwData
		local model = util.IsValidModel(data.model or "") and data.model or self.DefaultModel

		self:SetModel(model)
		self:SetTitle(data.title or "Контейнер")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(activator)
		if (IsValid(activator) and activator:IsPlayer() and activator:Alive() and activator:GetCharacterID() != 0) then
			NW.storage.Open(activator, NW.containers.Source(self))
		end
	end

	function ENT:Think()
		local data = self.nwData

		if (data and (data.refresh or 0) > 0) then
			self.nwNextRefresh = self.nwNextRefresh or CurTime() + data.refresh

			if (CurTime() >= self.nwNextRefresh) then
				self.nwNextRefresh = CurTime() + data.refresh
				NW.containers.Fill(self)
			end
		end

		self:NextThink(CurTime() + 1)

		return true
	end

	function ENT:OnRemove()
		NW.containers.Changed()
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
