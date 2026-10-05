AddCSLuaFile()
ENT.Type="anim"
ENT.Base="nw_ied"
ENT.PrintName="Радиозаряд сопротивления"
ENT.Category="Network"
ENT.Spawnable=false
ENT.models={"models/props_lab/reciever01b.mdl"}
ENT.armTime=3
ENT.damage=160
ENT.radius=240
if (SERVER) then
 function ENT:TrapThink() end -- No proximity trigger: detonator only.
 function ENT:OnArmed() end
end
