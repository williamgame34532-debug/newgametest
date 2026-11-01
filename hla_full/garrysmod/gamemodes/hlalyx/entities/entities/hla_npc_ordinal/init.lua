AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

function ENT:SpawnFunction(p, tr, class)
	return HLA.Story.PlaceNPC(p, tr, 'ОРДИНАЛ')
end
