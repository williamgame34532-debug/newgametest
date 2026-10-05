AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Товар"
ENT.Spawnable = false
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "ItemID")
	self:NetworkVar("Int", 0, "Price")
end

if (SERVER) then
	function ENT:Setup(itemID, price, ownerChar, ownerSid)
		local base = NETWORK.item.Get(itemID)

		self:SetItemID(itemID)
		self:SetPrice(price)
		self:SetNWString("nwOwnerChar", ownerChar)
		self.ownerSid = ownerSid

		local model = base and base.model or "models/props_junk/cardboard_box004a.mdl"

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)

		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:SetMass(2)
		end
	end

	ENT.CarryTime = 0.35

	function ENT:Buy(client)
		local character = client:GetCharacter()

		if (!character) then
			return
		end

		if (tostring(character:GetID()) == self:GetNWString("nwOwnerChar")) then
			NETWORK.item.Spawn(self:GetItemID(), self:GetPos() + Vector(0, 0, 6))
			self:Remove()

			return
		end

		local price = self:GetPrice()

		if (client:GetTokens() < price) then
			return NETWORK.chat.Notice(client, "shopNoTokens")
		end

		NETWORK.currency.Add(client, -price)

		for _, seller in ipairs(player.GetAll()) do
			if (seller:SteamID64() == self.ownerSid) then
				NETWORK.currency.Add(seller, price)
				NETWORK.chat.Notice(seller, "shopSold")

				break
			end
		end

		NETWORK.inventory.Give(client, self:GetItemID(), 1)
		NETWORK.chat.Notice(client, "shopBought")

		self:EmitSound("buttons/blip1.wav", 55, 120)
		self:Remove()
	end

	ENT.CarryTime = 0.3

	function ENT:Use()
	end

	local function Aimed(client)
		local entity = client:GetEyeTrace().Entity

		if (!IsValid(entity) or entity:GetClass() != "nw_shopitem") then
			return
		end

		if (client:GetPos():Distance(entity:GetPos()) > 110) then
			return
		end

		return entity
	end

	hook.Add("KeyPress", "nwShopItemUse", function(client, key)
		if (key != IN_USE or !client:HasCharacter() or !client:Alive()) then
			return
		end

		local entity = Aimed(client)

		if (!IsValid(entity)) then
			return
		end

		client.nwShopItem = entity
		client.nwShopStart = CurTime()
		client.nwShopCarried = false

		timer.Simple(entity.CarryTime, function()
			if (!IsValid(client) or !IsValid(entity)) then
				return
			end

			if (client.nwShopItem != entity or !client:KeyDown(IN_USE)) then
				return
			end

			client.nwShopCarried = true

			client:PickupObject(entity)
			entity:EmitSound("physics/cardboard/cardboard_box_impact_soft1.wav",
				55, 105)
		end)
	end)

	hook.Add("KeyRelease", "nwShopItemUse", function(client, key)
		if (key != IN_USE) then
			return
		end

		local entity = client.nwShopItem

		client.nwShopItem = nil

		if (!IsValid(entity) or client.nwShopCarried) then
			client.nwShopCarried = false

			return
		end

		if (CurTime() - (client.nwShopStart or 0) < entity.CarryTime and
			IsValid(Aimed(client))) then
			entity:Buy(client)
		end
	end)

else
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 6)
		local angles = LocalPlayer():EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local base = NETWORK.item.Get(self:GetItemID())

		cam.Start3D2D(position, angles, 0.09)
			draw.SimpleText(base and base.name or "?", "nwTagDesc", 0, -10,
				Color(226, 236, 246, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(self:GetPrice() .. " ткн", "nwTagDesc", 0, 10,
				Color(240, 196, 84, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
