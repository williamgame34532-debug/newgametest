ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'Combine Fabricator'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IsCombineFabricator = true
-- the model plays its own Half-Life: Alyx sequences
ENT.AutomaticFrameAdvance = true

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
	self:NetworkVar('Float', 2, 'DeployedAt')
	self:NetworkVar('Float', 3, 'FeedStarted')
	self:NetworkVar('Bool', 0, 'Deployed')  -- screen up, terminal usable
	self:NetworkVar('Bool', 1, 'TrayReady') -- resin tray presented, resin can be loaded
	self:NetworkVar('Bool', 2, 'BayOpen')   -- rib bay open, the item can be taken
	self:NetworkVar('Bool', 3, 'TrayOut')   -- resin tray outside the hull (resin is drawn in it)
end

function ENT:SpawnFunction(p, tr, class)
	if not tr.Hit then return end
	local e = ents.Create(class)
	e:SetPos(tr.HitPos + tr.HitNormal * 1)
	-- the working side of the compiled model (screen, resin tray, bay) is +X: turn it to the player
	e:SetAngles(Angle(0, p:EyeAngles().y + 180, 0))
	e:Spawn()
	e:Activate()
	return e
end
