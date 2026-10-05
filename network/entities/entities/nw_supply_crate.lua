AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Ящик поставки"
ENT.Category = "Network"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "OrderID")
	self:NetworkVar("String", 0, "OrderName")
	self:NetworkVar("Bool", 0, "Delivered")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/items/item_item_crate.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		self.health = NETWORK.supply.crateHealth
		self.nwCarryable = true

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:SetMass(25)
			physics:Wake()
		end
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.5

		if (!NETWORK.factions.IsAlliance(activator) or activator:KeyDown(IN_SPEED)) then
			if (!activator:IsPlayerHolding()) then
				activator:PickupObject(self)
			end

			return
		end

		NETWORK.supply.Open(activator, self)
	end

	function ENT:OnTakeDamage(info)
		if (self.bBroken) then
			return
		end

		self.health = (self.health or 100) - info:GetDamage()

		if (self.health <= 0) then
			self.bBroken = true

			NETWORK.supply.Break(self, info:GetAttacker())
		end
	end
else
	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (!IsValid(client) or client:GetPos():DistToSqr(self:GetPos()) > 220 * 220) then
			return
		end

		local angles = (self:GetPos() - EyePos()):Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)
		angles.p = 0
		angles.r = 90

		local color = self:GetDelivered() and NETWORK.theme.positive or
			Color(240, 178, 70)

		cam.Start3D2D(self:GetPos() + Vector(0, 0, 34), angles, 0.08)
			local title = NETWORK.util.Upper(self:GetOrderName())
			local sub = NETWORK.util.Upper(L(self:GetDelivered() and "supplyCrateReady" or
				"supplyCrateSealed"))

			surface.SetFont("nwChat")

			local width = math.max(surface.GetTextSize(title), 200) + 60

			draw.RoundedBox(12, -width * 0.5, -32, width, 64, Color(8, 9, 11, 220))
			draw.RoundedBox(4, -width * 0.5, -32, 6, 64, color)
			draw.SimpleText(title, "nwChat", 0, -10, NETWORK.theme.text, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(sub, "nwHudSmall", 0, 14, color, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			if (NETWORK.factions.IsAlliance(client)) then
				draw.SimpleText(L("supplyCrateHint"), "nwHudSmall", 0, 48,
					NETWORK.theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		cam.End3D2D()
	end
end
