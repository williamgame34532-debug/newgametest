AddCSLuaFile()

ENT.Type = "anim"

ENT.RenderGroup = RENDERGROUP_BOTH
ENT.PrintName = "Токены"
ENT.Category = "Network"
ENT.Spawnable = false

ENT.Model = "models/props_lab/box01a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Amount")
end

if (SERVER) then
	function ENT:Initialize()

		self:SetModel(self.Model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
		end
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or
			!activator:HasCharacter()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.5

		local amount = self:GetAmount()

		if (amount <= 0) then
			self:Remove()

			return
		end

		NETWORK.currency.Add(activator, amount)

		activator:EmitSound("physics/metal/metal_solid_impact_bullet" ..
			math.random(1, 4) .. ".wav", 60, 130, 0.5)

		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(L("tokensPicked", amount))
		net.Send(activator)

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("token", string.format("%s поднял %d токенов",
				NETWORK.log.Name(activator), amount), self:GetPos())
		end

		self:Remove()
	end

	function NETWORK.currency.Drop(position, amount, angles)
		local entity = ents.Create("nw_tokens")

		if (!IsValid(entity)) then
			return
		end

		entity:SetPos(position)
		entity:SetAngles(angles or Angle(0, math.random(0, 360), 0))
		entity:Spawn()
		entity:Activate()
		entity:SetAmount(math.max(math.floor(amount), 1))

		return entity
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
		local client = LocalPlayer()
		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 4)
		local distance = client:GetPos():Distance(position)

		if (distance > 300) then
			return
		end

		local fade = math.Clamp((300 - distance) / 60, 0, 1)
		local direction = position - EyePos()

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			return
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local text = NETWORK.currency.Format(self:GetAmount())

		cam.Start3D2D(position, angles, 0.1)
			surface.SetFont("nwTagDesc")

			local width = surface.GetTextSize(text) + 30
			local height = 26

			surface.SetDrawColor(6, 8, 11, 175 * fade)
			surface.DrawRect(-width * 0.5, -height * 0.5, width, height)

			surface.SetDrawColor(NETWORK.theme.warning.r,
				NETWORK.theme.warning.g, NETWORK.theme.warning.b, 240 * fade)
			surface.DrawRect(-width * 0.5, -height * 0.5, 3, height)

			draw.SimpleText(text, "nwTagDesc", 4, 0,
				ColorAlpha(NETWORK.theme.warning, 252 * fade), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
