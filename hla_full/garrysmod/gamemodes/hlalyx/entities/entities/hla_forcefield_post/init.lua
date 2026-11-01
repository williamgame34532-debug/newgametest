AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

function ENT:Initialize()
	self:SetModel(self.Model)
	if self:GetScale() <= 0 then self:SetScale(1) end
	self:SetLit(true)
	self:Setup()
end

-- solid metal: a frozen physics box around the post, scaled with it
function ENT:Setup()
	local s = self:GetScale()
	self:SetModelScale(s, 0)
	local mn, mx = self.BoxMin * s, self.BoxMax * s
	self:PhysicsInitBox(mn, mx)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetCollisionBounds(mn, mx)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:SetMass(300) ph:EnableMotion(false) end
end

-- place the post so that its inner edge is at «edge»; the right post is turned 180° from «ang»
function ENT:PlaceAt(edge, ang)
	local a = Angle(ang.p, ang.y + (self:GetSide() > 0 and 180 or 0), ang.r)
	self:SetAngles(a)
	self:SetPos(edge - LocalToWorld(self.Inner * self:GetScale(), angle_zero, vector_origin, a))
end

-- turn the post around its inner edge (the field stays where it is)
function ENT:TurnAroundInner(deg)
	local ip = self:InnerPoint()
	local ang = self:GetAngles()
	ang:RotateAroundAxis(Vector(0, 0, 1), deg)
	self:SetAngles(ang)
	self:SetPos(ip - LocalToWorld(self.Inner * self:GetScale(), angle_zero, vector_origin, ang))
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:EnableMotion(false) ph:Sleep() end
	local f = self:GetField()
	if IsValid(f) then f:Follow(true) end
end

function ENT:OnRemove()
	local f = self:GetField()
	if IsValid(f) and not f.Removing then f.Removing = true f:Remove() end
end
