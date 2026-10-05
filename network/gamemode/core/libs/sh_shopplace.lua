NETWORK.shop = NETWORK.shop or {}
NETWORK.business = NETWORK.business or {}

NETWORK.shop.range = 150
NETWORK.shop.maxPrice = 9999

function NETWORK.shop.CanSell(item)
	local base = item and NETWORK.item.Get(item.id)

	if (!base) then
		return false
	end

	return base.category == "food" or base.category == "container" or
		base.bSellable == true
end

local cachedDoors = {}
local cachedAt = 0

function NETWORK.shop.GetBusinessDoors()
	if (CurTime() - cachedAt < 5) then
		return cachedDoors
	end

	cachedAt = CurTime()
	cachedDoors = {}

	for _, door in ipairs(ents.GetAll()) do
		if (!NETWORK.door.IsDoor(door)) then
			continue
		end

		local data = NETWORK.door.GetData(door)

		if (data and data.type == "business") then
			cachedDoors[#cachedDoors + 1] = door
		end
	end

	return cachedDoors
end

function NETWORK.shop.CanPlaceAt(client, position)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	local id = tostring(client:GetCharacterID())

	for _, door in ipairs(NETWORK.shop.GetBusinessDoors()) do
		if (!IsValid(door)) then
			continue
		end

		if (door:GetPos():Distance(position) > 500) then
			continue
		end

		local data = NETWORK.door.GetData(door)

		if (data and tostring(data.owner or "") == id) then
			return true
		end
	end

	return false
end

function NETWORK.business.IsOwner(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	local id = tostring(client:GetCharacterID())

	for _, door in ipairs(NETWORK.shop.GetBusinessDoors()) do
		if (!IsValid(door)) then
			continue
		end

		local data = NETWORK.door.GetData(door)

		if (data and tostring(data.owner or "") == id) then
			return true
		end
	end

	return false
end
