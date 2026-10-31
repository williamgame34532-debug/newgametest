-- Combine health station from Half-Life: Alyx: a larva vial goes in from the inventory,
-- holding E heals until the vial is empty; E on an empty vial ejects it.
ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'Станция первой помощи'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IsHealthStation = true

HLA = HLA or {}
HLA.Station = HLA.Station or {
	Dir = 'models/hla/health_station/',
	VialHP = 50,        -- health in one larva vial
	HealRate = 15,      -- per second while E is held
	UseRange = 90,
}

function ENT:SetupDataTables()
	self:NetworkVar('Bool', 0, 'HasVial')
	self:NetworkVar('Float', 0, 'Charge')
	self:NetworkVar('Entity', 0, 'Healer')
	self:NetworkVar('Entity', 1, 'Gauge')
end

function ENT:CanTakeVial() return not self:GetHasVial() end

-- where a vial sits (the gauge's own attachment, as in HL:A)
function ENT:VialSlot()
	local g = self:GetGauge()
	if not IsValid(g) then return end
	local id = g:LookupAttachment('health_vial_attach')
	if not id or id <= 0 then return end
	local a = g:GetAttachment(id)
	if a then return a.Pos, a.Ang end
end
