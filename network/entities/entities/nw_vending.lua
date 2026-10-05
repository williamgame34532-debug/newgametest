AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Автомат с напитками"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.Price = 1
ENT.Drink = "water"

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_vending")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = "models/props_interiors/VendingMachineSoda01a.mdl"

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		if (self:GetNWBool("nwBroken")) then
			return NETWORK.mechanic.TryRepair(client, self)
		end

		if (client:KeyDown(IN_SPEED) and NETWORK.mechanic.TryMaintain and
			NETWORK.mechanic.TryMaintain(client, self)) then
			return
		end

		if (client:GetTokens() < self.Price) then
			return NETWORK.chat.Notice(client, "shopNoTokens")
		end

		NETWORK.currency.Add(client, -self.Price)

		self:EmitSound("ambient/machines/vend_drop.wav", 60)
		NETWORK.item.Spawn(self.Drink, self:GetPos() + self:GetForward() * 24 +
			Vector(0, 0, 14))

		if ((self.nwMaintainedUntil or 0) > CurTime()) then
			return
		end

		if (math.random() <= 0.5) then
			NETWORK.mechanic.Break(self)
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
		if (!self:GetNWBool("nwBroken")) then
			return
		end

		local client = LocalPlayer()

		if (client:GetNWString("nwClass", "") != "mechanic" and
			!client:IsAdmin()) then
			return
		end

		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 14)
		local angles = client:EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(position, angles, 0.12)
			local blink = 0.6 + math.abs(math.sin(RealTime() * 3)) * 0.4

			draw.SimpleText("⚠ НЕИСПРАВНОСТЬ", "nwTagDesc", 0, 0,
				Color(240, 96, 86, 240 * blink), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
