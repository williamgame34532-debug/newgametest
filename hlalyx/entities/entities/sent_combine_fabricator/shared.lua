ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'Combine Fabricator'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar('Int', 0, 'Stage')
	self:NetworkVar('Int', 1, 'Tab')
	self:NetworkVar('Int', 2, 'Selection')
	self:NetworkVar('Int', 3, 'Paid')
	self:NetworkVar('Int', 4, 'Cost')
	self:NetworkVar('Entity', 0, 'Operator')
	self:NetworkVar('String', 0, 'StatusText')
	self:NetworkVar('Float', 0, 'StageStarted')
	self:NetworkVar('Float', 1, 'StageUntil')
	CFRework.SetupChannelVars(self, 2)
end

function ENT:SpawnFunction(p, tr, class)
	if not tr.Hit then return end
	local e = ents.Create(class)
	e:SetPos(tr.HitPos + tr.HitNormal * 2)
	-- working side (+X) faces the player who spawned it
	e:SetAngles(Angle(0, p:EyeAngles().y + 180, 0))
	e:Spawn()
	e:Activate()
	return e
end
