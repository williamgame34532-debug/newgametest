util.AddNetworkString("nwJunkConfig")

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

function NETWORK.junk.Begin(client, entity)
	if (client.nwJunkPending or !IsValid(entity)) then
		return
	end

	if (entity:GetSearched()) then
		return Notice(client, "junkEmpty")
	end

	client.nwJunkPending = entity

	Progress(client, "junkProgress", NETWORK.junk.searchTime)

	entity:EmitSound("physics/cardboard/cardboard_box_scrape_smooth_loop1.wav", 55,
		math.random(95, 105), 0.5)

	timer.Simple(NETWORK.junk.searchTime, function()
		if (!IsValid(client)) then
			return
		end

		local pending = client.nwJunkPending

		client.nwJunkPending = nil

		if (IsValid(entity)) then
			entity:StopSound(
				"physics/cardboard/cardboard_box_scrape_smooth_loop1.wav")
		end

		if (pending != entity or !IsValid(entity) or !client:Alive()) then
			return
		end

		if (client:GetPos():Distance(entity:GetPos()) > NETWORK.junk.range) then
			return Progress(client, "", 0)
		end

		NETWORK.junk.Search(client, entity)
	end)
end

function NETWORK.junk.Search(client, entity)
	if (entity:GetSearched()) then
		return Notice(client, "junkEmpty")
	end

	local state = NETWORK.inventory.GetState(client)
	local count = math.random(math.max(entity:GetMinItems(), 1),
		math.max(entity:GetMaxItems(), entity:GetMinItems(), 1))

	local rolled = NETWORK.junk.Roll(entity.loot, count)

	entity:SetSearched(true)

	local refill = NETWORK.junk.GetRefill(entity)

	if (refill > 0) then
		timer.Simple(refill, function()
			if (IsValid(entity)) then
				entity:SetSearched(false)
			end
		end)
	end

	if (#rolled == 0) then
		return Notice(client, "junkNothing")
	end

	local found = 0

	for _, id in ipairs(rolled) do
		local item = NETWORK.item.New(id, 1)

		if (!item) then
			continue
		end

		NETWORK.item.OnCreated(item, client, client:GetCharacter())

		if (NETWORK.inventory.Insert(state, item) > 0) then
			local drop = ents.Create("nw_item")

			if (IsValid(drop)) then
				drop:SetPos(entity:GetPos() + Vector(math.random(-16, 16),
					math.random(-16, 16), 12))
				drop:SetItem(item)
				drop:Spawn()
				drop:Activate()
			end
		end

		found = found + 1
	end

	NETWORK.inventory.Sync(client)

	client:EmitSound("items/ammo_pickup.wav", 55, math.random(95, 105), 0.6)

	Notice(client, found > 0 and "junkFound" or "junkNothing")

	hook.Run("NetworkJunkSearched", client, entity, rolled)
end

net.Receive("nwJunkConfig", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable()

	if (!IsValid(entity) or entity:GetClass() != "nw_junk") then
		return
	end

	local loot = {}

	for id, weight in pairs(payload.loot or {}) do
		weight = math.Clamp(math.Round(tonumber(weight) or 0), 0, 100)

		if (weight > 0 and NETWORK.item.Get(id)) then
			loot[id] = weight
		end
	end

	entity.loot = loot

	entity:SetMinItems(math.Clamp(math.Round(tonumber(payload.minItems) or 1), 1, 10))
	entity:SetMaxItems(math.Clamp(math.Round(tonumber(payload.maxItems) or 2),
		entity:GetMinItems(), 10))

	entity:SetRefill(math.Clamp(math.Round(tonumber(payload.refill) or 0),
		-1, 86400))

	if (isstring(payload.model) and string.Trim(payload.model) != "") then
		local model = string.lower(string.Trim(payload.model))

		if (!util.IsValidModel(model)) then
			return Notice(client, "junkBadModel")
		end

		util.PrecacheModel(model)

		entity:SetJunkModel(model)
		entity:Apply()
	end

	entity:SetSearched(false)

	Notice(client, "junkSaved")
end)
