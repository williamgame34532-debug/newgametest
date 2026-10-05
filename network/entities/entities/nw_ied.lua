AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "nw_trap"
ENT.PrintName = "Самодельная мина"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.models = {

	"models/props_combine/combine_mine01.mdl",
	"models/props_junk/metal_paintcan001a.mdl",
	"models/props_junk/garbage_metalcan001a.mdl",
	"models/props_junk/popcan01a.mdl"
}
ENT.armTime = 3
ENT.proximity = 90
ENT.fuse = 0.6
ENT.radius = 220
ENT.damage = 100

if (SERVER) then
	function ENT:OnArmed()
		self:EmitSound("buttons/blip2.wav", 45, 140)
	end

	function ENT:TrapThink()
		if (self.bTriggered) then
			return
		end

		local position = self:GetPos()

		for _, entity in ipairs(ents.FindInSphere(position, self.proximity)) do
			if (entity != self and self:IsTarget(entity)) then
				self:Trigger(entity)

				return
			end
		end
	end

	function ENT:Trigger(target)
		self.bTriggered = true
		self:SetSprung(true)

		self:EmitSound("buttons/blip1.wav", 75, 120)

		NETWORK.trap.Log(self:GetClass() .. ": сработала на " .. NETWORK.trap.Name(target) ..
			" (владелец: " .. NETWORK.trap.Name(self.nwOwner) .. ")", self:GetPos())

		timer.Simple(self.fuse, function()
			if (IsValid(self)) then
				self:Blast(self:GetPos() + Vector(0, 0, 8), self.radius, self.damage)
			end
		end)
	end

	function ENT:OnDestroyed()
		self:Blast(self:GetPos() + Vector(0, 0, 8), self.radius, self.damage)
	end
else
	local GLOW = Material("sprites/light_glow02_add")

	function ENT:DrawTranslucent()
		if (!self:GetSprung()) then
			return
		end

		render.SetMaterial(GLOW)
		render.DrawSprite(self:WorldSpaceCenter() + Vector(0, 0, 6), 18, 18,
			Color(235, 60, 50, 200 * math.abs(math.sin(CurTime() * 16))))
	end
end
