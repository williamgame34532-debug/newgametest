AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Склад снабжения"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

local MODELS = {
	"models/props_c17/shelfunit01a.mdl",
	"models/props_wasteland/controlroom_storagecloset001a.mdl",
	"models/props_c17/FurnitureDrawer001a.mdl",
	"models/props_junk/wood_crate002a.mdl"
}

ENT.Models = MODELS

local defaultModel

function ENT:GetDefaultModel()
	if (defaultModel) then
		return defaultModel
	end

	for _, path in ipairs(MODELS) do
		if (util.IsValidModel(path) or file.Exists(path, "GAME")) then
			defaultModel = path

			return path
		end
	end

	defaultModel = MODELS[#MODELS]

	if (SERVER) then
		NETWORK.util.PrintWarning(
			"Ни одна модель не найдена, используется запасная: " .. defaultModel)
	end

	return defaultModel
end

local CATALOGUE = {
	{
		id = "chair_office",
		model = "models/props_c17/chair_office01a.mdl",
		price = 120,
		name = "furnChairOffice"
	},
	{
		id = "chair_wood",
		model = "models/props_c17/FurnitureChair001a.mdl",
		price = 80,
		name = "furnChairWood"
	},
	{
		id = "stool",
		model = "models/props_c17/FurnitureStool001a.mdl",
		price = 55,
		name = "furnStool"
	},
	{
		id = "table",
		model = "models/props_c17/FurnitureTable001a.mdl",
		price = 200,
		name = "furnTable"
	},
	{
		id = "shelf",
		model = "models/props_c17/shelfunit01a.mdl",
		price = 260,
		name = "furnShelf"
	},
	{
		id = "crate",
		model = "models/props_junk/wood_crate001a.mdl",
		price = 40,
		name = "furnCrate"
	}
}

ENT.Catalogue = CATALOGUE

local FOOD = {
	{id = "water", price = 2, name = "furnWater"},
	{id = "dry_ration", price = 3, name = "furnDryRation"},
	{id = "bread", price = 4, name = "furnBread"},
	{id = "nutrient_bar", price = 4, name = "furnNutrientBar"},
	{id = "canned_fruit", price = 9, name = "furnCannedFruit"},
	{id = "ration_basic", price = 12, name = "furnRationBasic"}
}

ENT.Food = FOOD

function ENT.GetFood(id)
	for _, entry in ipairs(FOOD) do
		if (entry.id == id) then
			return entry
		end
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "ShopModel")
end

function ENT.GetEntry(id)
	for _, entry in ipairs(CATALOGUE) do
		if (entry.id == id) then
			return entry
		end
	end
end

if (SERVER) then
	util.AddNetworkString("nwFurnitureMenu")
	util.AddNetworkString("nwFurnitureBuy")

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_furnitureshop")

		if (!IsValid(entity)) then
			return
		end

		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p = 0
		angles.r = 0

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(angles:SnapTo("y", 45))
		entity:Spawn()
		entity:Activate()

		if (NETWORK.entities and NETWORK.entities.Save) then
			NETWORK.entities.Save()
		end

		return entity
	end

	function ENT:Initialize()
		local model = self:GetShopModel()

		if (model == "" or !(util.IsValidModel(model) or
			file.Exists(model, "GAME"))) then
			model = self:GetDefaultModel()

			self:SetShopModel(model)
		end

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		for _, entry in ipairs(self.Catalogue) do
			util.PrecacheModel(entry.model)
		end

		for _, entry in ipairs(self.Food) do
			local base = NETWORK.item.Get(entry.id)

			if (base and base.model) then
				util.PrecacheModel(base.model)
			end
		end

		self.nextUse = 0
	end

	function ENT:Apply()
		local model = self:GetShopModel()

		if (model != "" and (util.IsValidModel(model) or
			file.Exists(model, "GAME"))) then
			util.PrecacheModel(model)
			self:SetModel(model)
			self:PhysicsInit(SOLID_VPHYSICS)

			local physics = self:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:EnableMotion(false)
				physics:Sleep()
			end
		end
	end

	function ENT:CanBuy(client)
		if (!IsValid(client) or !client:HasCharacter()) then
			return false
		end

		if (client:IsAdmin()) then
			return true
		end

		local entry = NETWORK.business and NETWORK.business.Get and
			NETWORK.business.Get(client:GetCharacter())

		return entry != nil and entry.status == "approved"
	end

	function ENT:Use(client)
		if (self.nextUse > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.5

		if (!self:CanBuy(client)) then
			self:EmitSound("buttons/combine_button_locked.wav", 60)

			return NETWORK.chat.Notice(client, "furnNoBusiness")
		end

		client.nwFurnitureShop = self

		net.Start("nwFurnitureMenu")
			net.WriteEntity(self)
		net.Send(client)
	end

	net.Receive("nwFurnitureBuy", function(_, client)
		local shop = net.ReadEntity()
		local id = net.ReadString()

		if (!IsValid(shop) or shop:GetClass() != "nw_furnitureshop") then
			return
		end

		if (client:GetPos():Distance(shop:GetPos()) > 160) then
			return NETWORK.chat.Notice(client, "furnTooFar")
		end

		if (!shop:CanBuy(client)) then
			return NETWORK.chat.Notice(client, "furnNoBusiness")
		end

		local food = shop.GetFood(id)

		if (food) then
			if (client:GetTokens() < food.price) then
				return NETWORK.chat.Notice(client, "furnNoTokens")
			end

			if (!NETWORK.inventory.Give(client, food.id, 1)) then
				return NETWORK.chat.Notice(client, "invNoRoom")
			end

			NETWORK.currency.Add(client, -food.price)

			shop:EmitSound("items/ammocrate_open.wav", 65, 110)
			NETWORK.chat.Notice(client, "furnBought")

			if (NETWORK.log and NETWORK.log.Add) then
				NETWORK.log.Add("item", string.format("%s купил продовольствие: %s (%d)",
					NETWORK.log.Name(client), food.id, food.price),
					shop:GetPos())
			end

			return
		end

		local entry = shop.GetEntry(id)

		if (!entry) then
			return
		end

		if (client:GetTokens() < entry.price) then
			return NETWORK.chat.Notice(client, "furnNoTokens")
		end

		local position = shop:GetPos() + shop:GetForward() * 46 +
			Vector(0, 0, 16)
		local furniture = ents.Create("nw_furniture")

		if (!IsValid(furniture)) then
			return
		end

		furniture:SetFurnitureID(entry.id)
		furniture:SetPos(position)
		furniture:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
		furniture:Spawn()
		furniture:Activate()

		furniture.nwOwner = tostring(client:GetCharacter():GetID())
		furniture:SetOwnerChar(furniture.nwOwner)

		NETWORK.currency.Add(client, -entry.price)

		shop:EmitSound("items/ammocrate_open.wav", 65, 100)

		NETWORK.chat.Notice(client, "furnBought")

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("item", string.format("%s купил мебель: %s (%d)",
				NETWORK.log.Name(client), entry.id, entry.price),
				shop:GetPos())
		end
	end)
else
	function ENT:Draw()
		self:DrawModel()

		NETWORK.label.Draw(self, L("furnShopLabel"), L("furnShopSub"))
	end
end
