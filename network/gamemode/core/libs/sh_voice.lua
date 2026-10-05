NETWORK.voice = NETWORK.voice or {}
NETWORK.voice.stored = NETWORK.voice.stored or {}
NETWORK.voice.order = NETWORK.voice.order or {}
NETWORK.voice.categories = NETWORK.voice.categories or {}
NETWORK.voice.categoryOrder = NETWORK.voice.categoryOrder or {}

NETWORK.voice.prefix = ";"

NETWORK.voice.classes = {
	ic = true,
	yell = true,
	whisper = true,
	radiocp = true,
	radiota = true,
	radiotac = true,
	squadc = true,
	radio = true
}

function NETWORK.voice.RegisterCategory(id, name)
	if (!NETWORK.voice.categories[id]) then
		NETWORK.voice.categoryOrder[#NETWORK.voice.categoryOrder + 1] = id
	end

	NETWORK.voice.categories[id] = {id = id, name = name}
end

function NETWORK.voice.Register(id, data)
	data.id = id
	data.category = data.category or "misc"
	data.faction = data.faction

	local key = NETWORK.util.Lower(id)
	local existing = NETWORK.voice.stored[key]

	if (existing and existing.class and data.class and
		existing.class != data.class) then
		existing.variants = existing.variants or {}
		existing.variants[#existing.variants + 1] = data

		return data
	end

	if (!NETWORK.voice.stored[key]) then
		NETWORK.voice.order[#NETWORK.voice.order + 1] = key
	end

	NETWORK.voice.stored[key] = data

	return data
end

function NETWORK.voice.Resolve(client, data)
	if (!data) then
		return
	end

	if (NETWORK.voice.CanUse(client, data)) then
		return data
	end

	for _, variant in ipairs(data.variants or {}) do
		if (NETWORK.voice.CanUse(client, variant)) then
			return variant
		end
	end
end

function NETWORK.voice.CanUse(client, data)
	if (!data) then
		return true
	end

	if (data.class and client:GetNWString("nwClass", "") != data.class) then
		return false
	end

	if (!data.faction) then
		return true
	end

	local faction = client:GetCharacterFaction()

	if (istable(data.faction)) then
		for _, id in ipairs(data.faction) do
			if (id == faction) then
				return true
			end
		end

		return false
	end

	return faction == data.faction
end

function NETWORK.voice.GetByCategory(category, client)
	local list = {}

	for _, id in ipairs(NETWORK.voice.order) do
		local data = NETWORK.voice.stored[id]

		if (data.category != category) then
			continue
		end

		if (client) then
			data = NETWORK.voice.Resolve(client, data)

			if (!data) then
				continue
			end
		end

		list[#list + 1] = data
	end

	return list
end

function NETWORK.voice.Get(id)
	return NETWORK.voice.stored[NETWORK.util.Lower(string.Trim(id or ""))]
end

function NETWORK.voice.Parse(text)
	text = string.Trim(text or "")

	if (text == "") then
		return
	end

	local parts = string.Explode(NETWORK.voice.prefix, text)
	local list, count = {}, 0

	for _, part in ipairs(parts) do

		local trimmed = string.Trim(part)

		if (trimmed == "") then
			continue
		end

		local data = NETWORK.voice.Get(trimmed)

		if (data) then
			count = count + 1

			list[#list + 1] = {data = data}
		else

			list[#list + 1] = {text = trimmed}
		end
	end

	if (count == 0) then
		return
	end

	return list, count
end

function NETWORK.voice.IsFemale(client)
	if (!IsValid(client)) then
		return false
	end

	return string.find(string.lower(client:GetModel() or ""), "female") != nil
end

function NETWORK.voice.GetSound(client, data)
	if (!data) then
		return
	end

	if (data.soundFemale and NETWORK.voice.IsFemale(client)) then
		return data.soundFemale
	end

	return data.sound
end
