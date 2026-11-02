ENT.Type = 'anim'
ENT.PrintName = 'Контейнер с лутом'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.IsHLAContainer = true

function ENT:SetupDataTables()
	self:NetworkVar('String', 0, 'Title')
	self:NetworkVar('Int', 0, 'Slots')
	self:NetworkVar('Int', 1, 'Filled')
end
