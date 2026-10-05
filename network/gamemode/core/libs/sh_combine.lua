NETWORK.combine = NETWORK.combine or {}
NETWORK.combine.list = NETWORK.combine.list or {}

function NETWORK.combine.Register(first, second, result, amount)
	NETWORK.combine.list[#NETWORK.combine.list + 1] = {
		first = first,
		second = second,
		result = result,
		amount = math.max(math.Round(tonumber(amount) or 1), 1)
	}
end

function NETWORK.combine.Find(id, has)
	for _, recipe in ipairs(NETWORK.combine.list) do
		if (recipe.first == id and has(recipe.second)) then
			return recipe, recipe.second
		end

		if (recipe.second == id and has(recipe.first)) then
			return recipe, recipe.first
		end
	end
end

NETWORK.combine.Register("rag", "wire", "bandage")
NETWORK.combine.Register("scrap", "wire", "battery")
NETWORK.combine.Register("can", "resin", "scrap")

if (SERVER) then

	local function TakeOne(client, id)
		return NETWORK.inventory.Take(client, id, 1)
	end

	local function Has(client, id)
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({"items", "storage"}) do
			for _, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == id) then
					return true
				end
			end
		end

		return false
	end

	function NETWORK.combine.TryUse(client, id)
		local recipe, other = NETWORK.combine.Find(id, function(needed)
			return Has(client, needed)
		end)

		if (!recipe) then
			return false
		end

		if (!TakeOne(client, other)) then
			return false
		end

		if (!TakeOne(client, id)) then

			NETWORK.inventory.Give(client, other, 1)

			return false
		end

		local base = NETWORK.item.Get(recipe.result)

		if (!NETWORK.inventory.Give(client, recipe.result, recipe.amount)) then

			NETWORK.item.Spawn(recipe.result, client:GetPos() +
				client:GetForward() * 20 + Vector(0, 0, 12))
		end

		client:EmitSound("physics/cardboard/cardboard_box_impact_soft3.wav",
			55, math.random(95, 105))

		NETWORK.chat.Notice(client, L("combineDone",
			base and base.name or recipe.result))

		NETWORK.log.Add("item", string.format("%s собрал %s из %s + %s",
			NETWORK.log.Name(client), recipe.result, id, other))

		return true
	end

	function NETWORK.combine.Hint(client, id)
		for _, recipe in ipairs(NETWORK.combine.list) do
			local needed

			if (recipe.first == id) then
				needed = recipe.second
			elseif (recipe.second == id) then
				needed = recipe.first
			end

			if (needed and !Has(client, needed)) then
				local base = NETWORK.item.Get(needed)

				NETWORK.chat.Notice(client, L("combineNeed",
					base and base.name or needed))

				return
			end
		end
	end
end
