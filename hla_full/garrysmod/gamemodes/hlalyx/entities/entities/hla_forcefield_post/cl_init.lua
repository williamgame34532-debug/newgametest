include('shared.lua')

-- the pack's own material has no lights: the HL:A material with the blue (on) / red (off) lights is
-- put over it when hla_forcefield_content is installed
local hasLit
function ENT:Draw()
	if hasLit == nil then hasLit = file.Exists('materials/' .. self.MatOn .. '.vmt', 'GAME') end
	local mode = self:GetSkinMode()
	local want = ''
	if hasLit and mode ~= 3 then
		if mode == 1 then want = self.MatOn
		elseif mode == 2 then want = self.MatOff
		else want = self:GetLit() and self.MatOn or self.MatOff end
	end
	if self.mat ~= want then self.mat = want self:SetSubMaterial(0, want ~= '' and want or nil) end
	self:DrawModel()
end
