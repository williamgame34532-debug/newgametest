AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Мешок с трупом"
ENT.Spawnable = false
ENT.PhysgunDisabled = true

if (SERVER) then
	function ENT:Initialize()
		local model = "models/bodybags/bodybag_01.mdl"

		if (file.Exists(model, "GAME")) then
			util.PrecacheModel(model)
		else
			model = "models/props_junk/garbage_bag001a.mdl"
		end

		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:SetMass(28)
		end
	end

	function ENT:PhysgunPickup()
		return false
	end

	function ENT:OnTakeDamage(damage)
		if (damage:IsDamageType(DMG_BURN) or damage:IsDamageType(DMG_BLAST) or
			damage:IsDamageType(DMG_ENERGYBEAM) or self:IsOnFire()) then
			self:EmitSound("ambient/fire/gascan_ignite1.wav", 60)

			local effect = EffectData()

			effect:SetOrigin(self:WorldSpaceCenter())
			util.Effect("cball_explode", effect)

			self:Remove()
		end
	end

	function ENT:Think()
		if (self:IsOnFire()) then
			self:Remove()
		end

		self:NextThink(CurTime() + 0.5)

		return true
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 8)
		local angles = LocalPlayer():EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(position, angles, 0.09)
			draw.SimpleText("Мешок с трупом", "nwTagDesc", 0, 0,
				Color(200, 208, 216, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
