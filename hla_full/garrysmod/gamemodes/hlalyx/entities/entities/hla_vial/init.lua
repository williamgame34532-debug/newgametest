AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

function ENT:Initialize()
	self:SetItemID('health_vial')
	self.BaseClass.Initialize(self)
end
