AddCSLuaFile()

-- The Lambda sprayed on a wall (sh_rebels.lua, materials/network2/fx/graffiti_lambda.png). The Alliance
-- and the CWU wash it off: E.

ENT.Type = "anim"
ENT.PrintName = "Граффити Сопротивления"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local SIZE = 46

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_junk/PopCan01a.mdl")
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-1, -SIZE / 2, -SIZE / 2), Vector(1, SIZE / 2, SIZE / 2))
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)
	end

	function ENT:Use(client)
		if (IsValid(client) and client:IsPlayer()) then
			NW.rebels.Clean(client, self)
		end
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_graffiti")
	end)

	return
end

local MATERIAL = Material("network2/fx/graffiti_lambda.png", "smooth mips")

function ENT:Draw()
end

function ENT:DrawTranslucent()
	if (EyePos():DistToSqr(self:GetPos()) > 2500 * 2500) then
		return
	end

	-- flat on the wall: x along the wall, y down
	local angle = self:GetAngles()

	angle:RotateAroundAxis(angle:Up(), 90)
	angle:RotateAroundAxis(angle:Forward(), 90)

	cam.Start3D2D(self:GetPos(), angle, SIZE / 256)
		surface.SetMaterial(MATERIAL)
		surface.SetDrawColor(255, 255, 255, 235)
		surface.DrawTexturedRect(-128, -128, 256, 256)
	cam.End3D2D()
end
