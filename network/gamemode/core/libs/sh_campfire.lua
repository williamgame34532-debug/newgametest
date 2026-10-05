NETWORK.campfire = NETWORK.campfire or {}

NETWORK.campfire.fuel = {
	scrap = 180,
	rag = 200,
	wire = 90,
	trash_bag = 260,
	trash_full = 300,
	bottle_empty = 60,
	ration_empty = 120,
	blank_form = 90,
	document = 90,
	resin = 240
}

function NETWORK.campfire.FuelValue(id)
	return NETWORK.campfire.fuel[id or ""] or 0
end

if (SERVER) then

	function NETWORK.campfire.TryFuel(client, entity)
		if (!IsValid(entity) or entity:GetFuel() >= entity.fuelMax) then
			return false
		end

		local state = NETWORK.inventory.GetState(client)

		for _, item in pairs((state or {}).items or {}) do
			if (!istable(item)) then
				continue
			end

			local value = NETWORK.campfire.FuelValue(item.id)

			if (value <= 0 or !NETWORK.inventory.Take(client, item.id, 1)) then
				continue
			end

			entity:SetFuel(math.min(entity:GetFuel() + value, entity.fuelMax))

			if (!entity:GetLit()) then
				entity:SetLitState(true)
			end

			entity:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav", 60,
				math.random(95, 105))

			NETWORK.notice.Send(client, "campfireFuelled", "good")

			return true
		end

		return false
	end
end
