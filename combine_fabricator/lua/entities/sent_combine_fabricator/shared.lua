ENT.Type='anim' ENT.Base='base_anim'
ENT.PrintName='Combine Fabricator — 3D2D' ENT.Category='Half-Life: Alyx'
ENT.Spawnable=true ENT.AdminOnly=false
function ENT:SetupDataTables()
 self:NetworkVar('Int',0,'Stage') self:NetworkVar('Int',1,'Tab') self:NetworkVar('Int',2,'Selection')
 self:NetworkVar('Int',3,'Paid') self:NetworkVar('Int',4,'SlotMask') self:NetworkVar('Int',5,'OrderCost')
 self:NetworkVar('Entity',0,'Operator') self:NetworkVar('Float',0,'StageStarted') self:NetworkVar('Float',1,'StageUntil')
 self:NetworkVar('String',0,'StatusText')
 self:NetworkVar('Float',2,'MotionStarted') self:NetworkVar('Float',3,'MotionFrom') self:NetworkVar('Float',4,'MotionTo')
 self:NetworkVar('Float',5,'TrayStarted') self:NetworkVar('Float',6,'TrayFrom') self:NetworkVar('Float',7,'TrayTo')
 self:NetworkVar('Float',8,'BatchDrainAt')
end
function ENT:SpawnFunction(p,tr,class)
 if not tr.Hit then return end
 local e=ents.Create(class) e:SetPos(tr.HitPos+tr.HitNormal*2) e:SetAngles(Angle(0,p:EyeAngles().y+180,0)) e:Spawn() e:Activate() return e
end
