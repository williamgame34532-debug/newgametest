-- One emitter post of a Combine force field (hla_forcefield): the HL:A combine_fence01a_128 from the
-- «Half-Life: Alyx - Combine Animated Prop's Pack» (models/props_combineal). The left post stands as the
-- model is, the right one is the same model turned 180°. Moved and turned with the physgun, the field
-- follows its inner edge.
ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'Стойка силового поля'
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.Model = 'models/props_combineal/combine_fence01a_128.mdl'
ENT.Inner = Vector(-0.66, 7.13, -73.8)          -- inner edge at the floor, in the model (scale 1)
ENT.BoxMin = Vector(-12.6, -16.0, -73.8)        -- solid part (the claws stick out further)
ENT.BoxMax = Vector(7.4, 7.1, 53.8)
ENT.Height = 127.55
-- the materials of the post with its lights (from hla_forcefield_content): blue when on, red when off
ENT.MatOn = 'models/hla/forcefield/combine_fence_hlvr'
ENT.MatOff = 'models/hla/forcefield/combine_fence_hlvr_off'

function ENT:SetupDataTables()
	self:NetworkVar('Float', 0, 'Scale')
	self:NetworkVar('Int', 0, 'Side')      -- -1 left, 1 right
	self:NetworkVar('Entity', 0, 'Field')
	self:NetworkVar('Bool', 0, 'Lit')
	self:NetworkVar('Int', 1, 'SkinMode') -- 0 auto (blue on / red off), 1 blue, 2 red, 3 the pack's own
end

ENT.SkinNames = {[0] = 'АВТО (вкл — голубой, выкл — красный)', 'ГОЛУБЫЕ ОГНИ', 'КРАСНЫЕ ОГНИ', 'ИСХОДНЫЙ МАТЕРИАЛ АДДОНА'}

function ENT:PostHeightNow() return self.Height * math.max(self:GetScale(), 0.1) end

-- where the field starts: the inner edge of the post at the floor, in the world
function ENT:InnerPoint()
	return self:LocalToWorld(self.Inner * math.max(self:GetScale(), 0.1))
end
