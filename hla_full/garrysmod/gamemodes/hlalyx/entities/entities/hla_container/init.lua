AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

function ENT:SpawnFunction(p, tr)
	if not tr.Hit then return end
	local e = ents.Create('hla_container')
	e:SetPos(tr.HitPos + tr.HitNormal * 4)
	e:SetAngles(Angle(0, p:EyeAngles().y + 180, 0))
	e:Spawn()
	e:Activate()
	e:DropToFloor()
	if HLA.Loot then HLA.Loot.Refill(e) HLA.Loot.SaveMap() end
	return e
end

function ENT:Initialize()
	local L = HLA.Loot
	self.cfg = self.cfg or {model = L.Models[1].model, title = 'ЯЩИК СНАБЖЕНИЯ', table = 'default', slots = 8, respawn = 10}
	self:SetModel(self.cfg.model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
	self:SetTitle(self.cfg.title)
	self:SetSlots(self.cfg.slots)
	self.items = self.items or {}
	self.nextRefill = CurTime() + self.cfg.respawn * 60
end

function ENT:Use(p)
	if not IsValid(p) or not p:IsPlayer() or not p:Alive() or p.HLAInMenu then return end
	HLA.Loot.Open(p, self)
end

function ENT:OnRemove()
	if HLA.Loot and not HLA.Loot.loading and not HLA.Loot.cleaning then timer.Simple(0, HLA.Loot.SaveMap) end
end
