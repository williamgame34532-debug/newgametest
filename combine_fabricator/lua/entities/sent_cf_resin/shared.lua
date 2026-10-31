ENT.Type='anim' ENT.Base='base_anim' ENT.PrintName='Combine Resin' ENT.Category='Half-Life: Alyx' ENT.Spawnable=true
function ENT:SpawnFunction(p,tr,class)
 if not tr.Hit then return end
 local e=ents.Create(class) e:SetPos(tr.HitPos+tr.HitNormal*4) e:Spawn() e:Activate() return e
end
