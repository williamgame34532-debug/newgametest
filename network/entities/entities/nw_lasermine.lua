AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "nw_trap"
ENT.PrintName = "Лазерная мина"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.models = {
	"models/props_combine/combinebutton.mdl",
	"models/props_combine/combine_mine01.mdl"
}
ENT.armTime = 3
ENT.length = 400
ENT.fuse = 0.35
ENT.radius = 140
ENT.damage = 100

if (SERVER) then
	function ENT:UpdateBeam()
		local start = self:WorldSpaceCenter()
		local trace = util.TraceLine({
			start = start,
			endpos = start + self:GetForward() * self.length,
			filter = self,
			mask = MASK_SOLID_BRUSHONLY
		})

		self:SetWireEnd(trace.HitPos)
	end

	function ENT:OnTrapInit()
		self:UpdateBeam()
		self:EmitSound("buttons/combine_button1.wav", 55, 110)
	end

	function ENT:OnArmed()
		self:UpdateBeam()
		self:EmitSound("buttons/combine_button7.wav", 55, 120)
	end

	function ENT:IsTarget(entity)
		if (!NETWORK.trap.IsLiving(entity)) then
			return false
		end

		if (entity:IsPlayer()) then
			if (entity == self.nwOwner) then
				return false
			end

			return NETWORK.deploy.GetHostile(self)[entity:GetCharacterFaction() or ""] == true
		end

		return !NETWORK.trap.IsAllianceSide(entity)
	end

	function ENT:TrapThink()
		if (self.bTriggered) then
			return
		end

		if ((self.nextBeam or 0) < CurTime()) then
			self.nextBeam = CurTime() + 1

			self:UpdateBeam()
		end

		local start, finish = self:WorldSpaceCenter(), self:GetWireEnd()

		for _, entity in ipairs(ents.FindAlongRay and
			ents.FindAlongRay(start, finish, Vector(-2, -2, -2), Vector(2, 2, 2)) or {}) do
			if (entity != self and self:IsTarget(entity)) then
				self:Trigger(entity)

				return
			end
		end
	end

	function ENT:Trigger(target)
		self.bTriggered = true
		self:SetSprung(true)

		self:EmitSound("npc/roller/mine/rmine_predetonate.wav", 75, 130)

		NETWORK.trap.Log(self:GetClass() .. ": луч пересёк " .. NETWORK.trap.Name(target) ..
			" (владелец: " .. NETWORK.trap.Name(self.nwOwner) .. ")", self:GetPos())

		timer.Simple(self.fuse, function()
			if (!IsValid(self)) then
				return
			end

			local start, finish = self:WorldSpaceCenter(), self:GetWireEnd()
			local point = IsValid(target) and target:WorldSpaceCenter() or finish
			local direction = (finish - start):GetNormalized()

			local along = math.Clamp((point - start):Dot(direction), 0, start:Distance(finish))
			local hit = start + direction * along

			local effect = EffectData()

			effect:SetOrigin(hit)

			util.Effect("Explosion", effect, true, true)

			local owner = self.nwOwner

			util.BlastDamage(self, (IsValid(owner) and owner:IsPlayer()) and owner or self,
				hit, self.radius, self.damage)

			self:Blast(start, self.radius, self.damage * 0.4)
		end)
	end
else
	local BEAM = Material("sprites/bluelaser1")
	local GLOW = Material("sprites/light_glow02_add")
	local COLOR = Color(90, 170, 255)

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
		local start = self:WorldSpaceCenter()

		render.SetMaterial(GLOW)
		render.DrawSprite(start, 10, 10, ColorAlpha(COLOR, self:GetArmed() and 200 or 60))

		local finish = self:GetWireEnd()

		if (!self:GetArmed() or finish == vector_origin) then
			return
		end

		local flicker = self:GetSprung() and math.abs(math.sin(CurTime() * 30)) or 1

		render.SetMaterial(BEAM)
		render.DrawBeam(start, finish, 1.6, 0, 1, ColorAlpha(COLOR, 170 * flicker))
		render.SetMaterial(GLOW)
		render.DrawSprite(finish, 6, 6, ColorAlpha(COLOR, 140 * flicker))
	end
end
