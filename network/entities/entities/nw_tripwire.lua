AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "nw_trap"
ENT.PrintName = "Растяжка"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.models = {
	"models/weapons/w_grenade.mdl",
	"models/items/grenadeammo.mdl",
	"models/props_junk/garbage_metalcan001a.mdl"
}
ENT.armTime = 2
ENT.fuse = 1
ENT.radius = 200
ENT.damage = 90
ENT.defaultLength = 120

if (SERVER) then
	function ENT:OnTrapInit()
		local finish = self.nwDeployExtra

		if (!isvector(finish) and self:GetWireEnd() == vector_origin) then
			local start = self:GetPos() + Vector(0, 0, 4)
			local trace = util.TraceLine({
				start = start,
				endpos = start + self:GetForward() * self.defaultLength,
				filter = self,
				mask = MASK_SOLID_BRUSHONLY
			})

			finish = trace.HitPos
		end

		if (isvector(finish)) then
			self:SetWireEnd(finish)
		end
	end

	function ENT:GetWireStart()
		return self:WorldSpaceCenter()
	end

	function ENT:FindCrossing()
		local start, finish = self:GetWireStart(), self:GetWireEnd()
		local mins, maxs = Vector(-3, -3, -3), Vector(3, 3, 3)

		if (ents.FindAlongRay) then
			for _, entity in ipairs(ents.FindAlongRay(start, finish, mins, maxs)) do
				if (entity != self and self:IsTarget(entity)) then
					return entity
				end
			end

			return
		end

		local trace = util.TraceHull({
			start = start,
			endpos = finish,
			mins = mins,
			maxs = maxs,
			filter = self,
			mask = MASK_SHOT_HULL
		})

		if (IsValid(trace.Entity) and self:IsTarget(trace.Entity)) then
			return trace.Entity
		end
	end

	function ENT:TrapThink()
		if (self.bTriggered) then
			return
		end

		local target = self:FindCrossing()

		if (IsValid(target)) then
			self:Trigger(target)
		end
	end

	function ENT:Trigger(target)
		if (self.bTriggered) then
			return
		end

		self.bTriggered = true
		self:SetSprung(true)

		self:EmitSound("physics/metal/metal_grenade_impact_hard" .. math.random(1, 3) .. ".wav", 70)
		self:EmitSound("weapons/grenade/tick1.wav", 70, 100)

		NETWORK.trap.Log(self:GetClass() .. ": задел " .. NETWORK.trap.Name(target) ..
			" (владелец: " .. NETWORK.trap.Name(self.nwOwner) .. ")", self:GetPos())

		timer.Simple(self.fuse, function()
			if (IsValid(self)) then
				self:Blast(self:WorldSpaceCenter(), self.radius, self.damage)
			end
		end)
	end

	function ENT:OnDestroyed()
		self:Blast(self:WorldSpaceCenter(), self.radius, self.damage)
	end
else
	local WIRE = Material("cable/cable2")

	function ENT:Think()
		local finish = self:GetWireEnd()

		if (finish != vector_origin) then
			local start = self:WorldSpaceCenter()
			local mins = Vector(math.min(start.x, finish.x), math.min(start.y, finish.y),
				math.min(start.z, finish.z)) - Vector(8, 8, 8)
			local maxs = Vector(math.max(start.x, finish.x), math.max(start.y, finish.y),
				math.max(start.z, finish.z)) + Vector(8, 8, 8)

			self:SetRenderBoundsWS(mins, maxs)
		end
	end

	function ENT:DrawTranslucent()
		local finish = self:GetWireEnd()

		if (self:GetSprung() or finish == vector_origin) then
			return
		end

		local client = LocalPlayer()
		local bRebel = NETWORK.trap.IsRebel(client)
		local start = self:WorldSpaceCenter()
		local alpha = bRebel and 150 or 55

		render.SetMaterial(WIRE)
		render.DrawBeam(start, finish, bRebel and 0.45 or 0.3, 0,
			start:Distance(finish) / 32, Color(150, 150, 146, alpha))
	end
end
