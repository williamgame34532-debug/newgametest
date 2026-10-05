NETWORK.wound = NETWORK.wound or {}

NETWORK.wound.parts = {
	{id = "head", name = "woundHead", x = 0.5, y = 0.08, radius = 0.075},
	{id = "chest", name = "woundChest", x = 0.5, y = 0.28, radius = 0.1},
	{id = "stomach", name = "woundStomach", x = 0.5, y = 0.45, radius = 0.08},
	{id = "armLeft", name = "woundArmLeft", x = 0.27, y = 0.33, radius = 0.065},
	{id = "armRight", name = "woundArmRight", x = 0.73, y = 0.33, radius = 0.065},
	{id = "legLeft", name = "woundLegLeft", x = 0.4, y = 0.72, radius = 0.075},
	{id = "legRight", name = "woundLegRight", x = 0.6, y = 0.72, radius = 0.075}
}

NETWORK.wound.hitgroups = {
	[HITGROUP_HEAD] = "head",
	[HITGROUP_CHEST] = "chest",
	[HITGROUP_STOMACH] = "stomach",
	[HITGROUP_LEFTARM] = "armLeft",
	[HITGROUP_RIGHTARM] = "armRight",
	[HITGROUP_LEFTLEG] = "legLeft",
	[HITGROUP_RIGHTLEG] = "legRight"
}

NETWORK.wound.max = 100
NETWORK.wound.limpAt = 40
NETWORK.wound.fallAt = 65
NETWORK.wound.fallTime = 4
NETWORK.wound.healAmount = 45

function NETWORK.wound.GetPart(id)
	for _, data in ipairs(NETWORK.wound.parts) do
		if (data.id == id) then
			return data
		end
	end
end

function NETWORK.wound.GetState(client)
	if (SERVER) then
		client.nwWounds = client.nwWounds or {}

		return client.nwWounds
	end

	if (!IsValid(client) or client == LocalPlayer()) then
		return NETWORK.wound.state or {}
	end

	local state = {}

	for _, part in ipairs(NETWORK.wound.parts) do
		local value = client:GetNWInt("nwWound_" .. part.id, 0)

		if (value > 0) then
			state[part.id] = value
		end
	end

	return state
end

function NETWORK.wound.Get(client, id)
	return math.Clamp(NETWORK.wound.GetState(client)[id] or 0, 0, NETWORK.wound.max)
end

function NETWORK.wound.GetSeverity(value)
	if (value >= NETWORK.wound.fallAt) then
		return "woundSevere", Color(232, 92, 92)
	end

	if (value >= NETWORK.wound.limpAt) then
		return "woundModerate", Color(240, 200, 90)
	end

	if (value > 0) then
		return "woundLight", Color(200, 200, 210)
	end

	return "woundHealthy", Color(120, 220, 140)
end

function NETWORK.wound.IsLimping(client)
	if (NETWORK.toughness and !NETWORK.toughness.CanLimp(client)) then
		return false
	end

	return math.max(NETWORK.wound.Get(client, "legLeft"),
		NETWORK.wound.Get(client, "legRight")) >= NETWORK.wound.limpAt
end
