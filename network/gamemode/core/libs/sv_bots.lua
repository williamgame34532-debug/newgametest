NETWORK.bots = NETWORK.bots or {}

NETWORK.bots.faction = "citizen"
NETWORK.bots.kit = "worker"
NETWORK.bots.prefix = "Bot"
NETWORK.bots.description = "BotBotBotBotBot"
NETWORK.bots.idOffset = 900000

local function GetFreeIndex()
	local used = {}

	for _, other in ipairs(player.GetBots()) do
		if (other.nwBotIndex) then
			used[other.nwBotIndex] = true
		end
	end

	local index = 1

	while (used[index]) do
		index = index + 1
	end

	return index
end

function NETWORK.bots.Setup(client)
	if (!IsValid(client) or !client:IsBot() or client:HasCharacter()) then
		return
	end

	local faction = NETWORK.factions.Get(NETWORK.bots.faction) or NETWORK.factions.GetDefault()

	if (!faction) then
		return
	end

	local config = NETWORK.creation
	local models = faction.models
	local index = GetFreeIndex()

	client.nwBotIndex = index

	local skills = {}

	for i = 1, #config.skills do
		skills[config.skills[i].id] = 0
	end

	local character = NETWORK.character.New({
		id = NETWORK.bots.idOffset + index,
		steamID = client:SteamID(),
		name = NETWORK.bots.prefix .. string.format("%02d", index),
		surname = "",
		description = NETWORK.bots.description,
		model = models[math.random(#models)] or NETWORK.player.fallbackModel,
		faction = faction.id,
		kit = NETWORK.bots.kit,
		height = math.random(config.heightMin, config.heightMax),
		skills = skills,
		created = os.time(),
		bTemporary = true
	})

	NETWORK.character.Set(client, character)
end

hook.Add("PlayerInitialSpawn", "nwBots", function(client)
	if (!client:IsBot()) then
		return
	end

	timer.Simple(0.4, function()
		NETWORK.bots.Setup(client)
	end)
end)

concommand.Add("network_bots_refresh", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	for _, bot in ipairs(player.GetBots()) do
		bot.nwBotIndex = nil

		NETWORK.character.Clear(bot)
		NETWORK.bots.Setup(bot)
	end
end)
