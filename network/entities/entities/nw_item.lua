AddCSLuaFile()

ENT.Type = "anim"

ENT.RenderGroup = RENDERGROUP_BOTH
ENT.PrintName = "Network Item"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.PickupTime = 0.7

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "ItemID")
	self:NetworkVar("Int", 0, "ItemAmount")
	self:NetworkVar("String", 1, "ItemData")

	self:NetworkVar("Float", 0, "Integrity")

	if (SERVER) then
		self:SetIntegrity(1)
	end
end

function ENT:GetItem()
	local id = self:GetItemID()

	if (id == "" or !NETWORK.item.Get(id)) then
		return
	end

	return {
		id = id,
		amount = math.max(self:GetItemAmount(), 1),
		data = util.JSONToTable(self:GetItemData() or "{}") or {}
	}
end

if (SERVER) then
	local FALLBACK_MODEL = "models/props_junk/cardboard_box001a.mdl"

	function ENT:SetupPhysics()
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		self:SetCollisionGroup(COLLISION_GROUP_NONE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()

			return
		end

		self:SetModel(FALLBACK_MODEL)
		self:PhysicsInit(SOLID_VPHYSICS)

		physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
		end
	end

	function ENT:Initialize()
		local model = self.model or FALLBACK_MODEL

		if (!util.IsValidModel(model)) then
			model = FALLBACK_MODEL
		end

		self:SetModel(model)
		self:SetUseType(CONTINUOUS_USE)
		self:SetupPhysics()

		self:SetHealth(self.BaseHealth)
		self:SetMaxHealth(self.BaseHealth)

		self.holders = {}
		self.damageTaken = 0
	end

	function ENT:SetItem(item)
		local model = NETWORK.item.GetModel(item)

		if (!model or !util.IsValidModel(model)) then
			model = FALLBACK_MODEL
		end

		self.model = model

		self:SetItemID(item.id)
		self:SetItemAmount(item.amount or 1)
		self:SetItemData(util.TableToJSON(item.data or {}))
		self:SetModel(model)
		self:SetupPhysics()
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		local start = self.holders[activator] or CurTime()

		self.holders[activator] = start

		if (CurTime() - start < self.PickupTime) then
			return
		end

		self.holders[activator] = nil

		local bTaken, reason = NETWORK.inventory.Pickup(activator, self)

		if (bTaken) then
			activator:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav", 55, 110)
		elseif (reason) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(reason)
			net.Send(activator)
		end
	end

	util.AddNetworkString("nwItemTake")

	net.Receive("nwItemTake", function(_, client)
		local entity = net.ReadEntity()

		if (!IsValid(entity) or entity:GetClass() != "nw_item") then
			return
		end

		if (!client:Alive() or !client:HasCharacter()) then
			return
		end

		if (client:GetPos():Distance(entity:GetPos()) > NETWORK.worldItem.range + 24) then
			return
		end

		if ((client.nwNextTake or 0) > CurTime()) then
			return
		end

		client.nwNextTake = CurTime() + 0.25

		local bTaken, reason = NETWORK.inventory.Pickup(client, entity)

		if (bTaken) then
			client:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav", 55, 110)
		elseif (reason) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(reason)
			net.Send(client)
		end
	end)

	ENT.BaseHealth = 40

	ENT.CategoryHealth = {
		food = 6,
		junk = 10,
		rations = 6,
		misc = 16,
		clothing = 18,
		ammo = 20,
		modules = 26,
		armour = 34,
		weapon = 40,
		factory = 30
	}

	function ENT:GetBreakHealth()
		local item = self:GetItem()

		if (!item) then
			return self.BaseHealth
		end

		local base = NETWORK.item.Get(item.id)

		if (base and tonumber(base.durability)) then
			return math.max(tonumber(base.durability), 4)
		end

		local category = base and base.category or "misc"
		local health = self.CategoryHealth[category] or self.BaseHealth

		return math.max(health + (item.amount or 1) * 2, 4)
	end

	function ENT:Break(attacker)
		if (self.bBroken) then
			return
		end

		self.bBroken = true

		local effect = EffectData()

		effect:SetOrigin(self:WorldSpaceCenter())
		effect:SetMagnitude(1)
		effect:SetScale(1)

		util.Effect("GlassImpact", effect)

		self:EmitSound("physics/cardboard/cardboard_box_break" ..
			math.random(1, 3) .. ".wav", 70, math.random(95, 110))

		hook.Run("NetworkItemBroken", self, attacker, self:GetItem())

		self:Remove()
	end

	function ENT:OnTakeDamage(damage)

		local amount = damage:GetDamage()

		if (amount < 3) then
			return
		end

		self.damageTaken = (self.damageTaken or 0) + amount

		local limit = self:GetBreakHealth()

		self:SetIntegrity(math.Clamp(1 - self.damageTaken / limit, 0, 1))

		if (self.damageTaken < limit) then

			local physics = self:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:ApplyForceCenter(damage:GetDamageForce() * 0.35)
			end

			return
		end

		self:Break(damage:GetAttacker())
	end

	function ENT:Think()
		for client, start in pairs(self.holders) do
			if (!IsValid(client) or CurTime() - start > self.PickupTime + 0.4) then
				self.holders[client] = nil
			end
		end

		self:NextThink(CurTime() + 0.2)

		return true
	end
else
	function ENT:Initialize()
		self.holdStart = 0
		self.shownIntegrity = 1
	end

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
		local integrity = self:GetIntegrity()

		if (integrity >= 0.999) then
			self.damageTime = nil

			return
		end

		if (self.shownIntegrity != integrity) then
			self.damageTime = CurTime()
			self.shownIntegrity = integrity
		end

		local age = CurTime() - (self.damageTime or 0)
		local fade = math.Clamp(1 - (age - 2) / 1, 0, 1)

		if (fade <= 0.01) then
			return
		end

		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 3)
		local direction = position - EyePos()

		if (direction:Length() > 400) then
			return
		end

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			return
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local width = 60
		local height = 4

		cam.Start3D2D(position, angles, 0.09)
			surface.SetDrawColor(0, 0, 0, 190 * fade)
			surface.DrawRect(-width * 0.5, -height * 0.5, width, height)

			local color = Color(
				Lerp(integrity, 206, 150),
				Lerp(integrity, 64, 122),
				Lerp(integrity, 52, 38)
			)

			surface.SetDrawColor(color.r, color.g, color.b, 250 * fade)
			surface.DrawRect(-width * 0.5, -height * 0.5,
				math.Round(width * integrity), height)
		cam.End3D2D()
	end
end
