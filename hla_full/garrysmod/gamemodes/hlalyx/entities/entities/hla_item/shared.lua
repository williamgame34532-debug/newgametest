ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'Предмет'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = false
ENT.IsHLAItem = true
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar('String', 0, 'ItemID')
end
