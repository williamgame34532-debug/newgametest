NETWORK.config = NETWORK.config or {}
NETWORK.config.stored = NETWORK.config.stored or {}
NETWORK.config.order = NETWORK.config.order or {}
NETWORK.config.values = NETWORK.config.values or {}
NETWORK.config.categories = NETWORK.config.categories or {}
NETWORK.config.categoryOrder = NETWORK.config.categoryOrder or {}

function NETWORK.config.RegisterCategory(id, name, order)
	if (!NETWORK.config.categories[id]) then
		NETWORK.config.categoryOrder[#NETWORK.config.categoryOrder + 1] = id
	end

	NETWORK.config.categories[id] = {
		id = id,
		name = name,
		order = order or (#NETWORK.config.categoryOrder * 10)
	}
end

function NETWORK.config.Register(id, data)
	data.id = id
	data.type = data.type or "number"
	data.category = data.category or "general"
	data.order = data.order or (#NETWORK.config.order + 1) * 10

	if (!NETWORK.config.stored[id]) then
		NETWORK.config.order[#NETWORK.config.order + 1] = id
	end

	NETWORK.config.stored[id] = data

	return data
end

function NETWORK.config.Get(id)
	local value = NETWORK.config.values[id]

	if (value != nil) then
		return value
	end

	local data = NETWORK.config.stored[id]

	return data and data.default
end

function NETWORK.config.Apply(id)
	local data = NETWORK.config.stored[id]

	if (data and data.OnChanged) then
		data.OnChanged(NETWORK.config.Get(id))
	end
end

function NETWORK.config.ApplyAll()
	for _, id in ipairs(NETWORK.config.order) do
		NETWORK.config.Apply(id)
	end
end

function NETWORK.config.GetCategories()
	local list = {}

	for _, id in ipairs(NETWORK.config.categoryOrder) do
		list[#list + 1] = NETWORK.config.categories[id]
	end

	table.sort(list, function(a, b)
		return a.order < b.order
	end)

	return list
end

function NETWORK.config.GetEntries(category)
	local list = {}

	for _, id in ipairs(NETWORK.config.order) do
		local data = NETWORK.config.stored[id]

		if (data and (!category or data.category == category)) then
			list[#list + 1] = data
		end
	end

	table.sort(list, function(a, b)
		return a.order < b.order
	end)

	return list
end

NETWORK.config.RegisterCategory("characters", "cfgCatCharacters", 10)
NETWORK.config.RegisterCategory("movement", "cfgCatMovement", 20)
NETWORK.config.RegisterCategory("needs", "cfgCatNeeds", 30)
NETWORK.config.RegisterCategory("world", "cfgCatWorld", 35)
NETWORK.config.RegisterCategory("chat", "cfgCatChat", 40)
NETWORK.config.RegisterCategory("inventory", "cfgCatInventory", 50)

NETWORK.config.Register("characterSlots", {
	name = "cfgSlots",
	description = "cfgSlotsDesc",
	category = "characters",
	default = 2,
	min = 1,
	max = 8,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.character.maxSlots = value
	end
})

NETWORK.config.Register("walkSpeed", {
	name = "cfgWalk",
	description = "cfgWalkDesc",
	category = "movement",
	default = 95,
	min = 40,
	max = 250,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.movement.walkSpeed = value
	end
})

NETWORK.config.Register("runSpeed", {
	name = "cfgRun",
	description = "cfgRunDesc",
	category = "movement",
	default = 175,
	min = 80,
	max = 400,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.movement.runSpeed = value
	end
})

NETWORK.config.Register("jumpPower", {
	name = "cfgJump",
	description = "cfgJumpDesc",
	category = "movement",
	default = 150,
	min = 60,
	max = 300,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.movement.jumpPower = value
	end
})

NETWORK.config.Register("jumpCooldown", {
	name = "cfgJumpCooldown",
	description = "cfgJumpCooldownDesc",
	category = "movement",
	default = 0.45,
	min = 0,
	max = 3,
	decimals = 2,
	OnChanged = function(value)
		NETWORK.movement.jumpCooldown = value
	end
})

NETWORK.config.Register("airSpeedCap", {
	name = "cfgAirCap",
	description = "cfgAirCapDesc",
	category = "movement",
	default = 190,
	min = 100,
	max = 500,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.movement.airSpeedCap = value
	end
})

NETWORK.config.Register("staminaDrain", {
	name = "cfgStaminaDrain",
	description = "cfgStaminaDrainDesc",
	category = "needs",
	default = 13,
	min = 1,
	max = 50,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.stamina.sprintDrain = value
	end
})

NETWORK.config.Register("staminaRegen", {
	name = "cfgStaminaRegen",
	description = "cfgStaminaRegenDesc",
	category = "needs",
	default = 12,
	min = 1,
	max = 50,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.stamina.regen = value
	end
})

NETWORK.config.Register("hungerTime", {
	name = "cfgHunger",
	description = "cfgHungerDesc",
	category = "needs",
	default = 4500,
	min = 300,
	max = 20000,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.needs.hungerTime = value
	end
})

NETWORK.config.Register("thirstTime", {
	name = "cfgThirst",
	description = "cfgThirstDesc",
	category = "needs",
	default = 2700,
	min = 300,
	max = 20000,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.needs.thirstTime = value
	end
})

NETWORK.config.Register("radiusIC", {
	name = "cfgRadiusIC",
	description = "cfgRadiusICDesc",
	category = "chat",
	default = 280,
	min = 50,
	max = 1000,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.chat.Get("ic").radius = value
	end
})

NETWORK.config.Register("radiusWhisper", {
	name = "cfgRadiusWhisper",
	description = "cfgRadiusWhisperDesc",
	category = "chat",
	default = 110,
	min = 20,
	max = 500,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.chat.Get("whisper").radius = value
	end
})

NETWORK.config.Register("radiusYell", {
	name = "cfgRadiusYell",
	description = "cfgRadiusYellDesc",
	category = "chat",
	default = 640,
	min = 100,
	max = 2000,
	decimals = 0,
	OnChanged = function(value)
		NETWORK.chat.Get("yell").radius = value
	end
})

NETWORK.config.Register("maxWeight", {
	name = "cfgWeight",
	description = "cfgWeightDesc",
	category = "inventory",
	default = 20,
	min = 5,
	max = 120,
	decimals = 1,
	OnChanged = function(value)
		NETWORK.inventory.maxWeight = value
	end
})

NETWORK.config.Register("raiseTime", {
	name = "cfgRaise",
	description = "cfgRaiseDesc",
	category = "inventory",
	default = 1.4,
	min = 0.2,
	max = 5,
	decimals = 2,
	OnChanged = function(value)
		NETWORK.weapon.raiseTime = value
	end
})

NETWORK.config.Register("timeStart", {
	name = "cfgTimeStart",
	description = "cfgTimeStartDesc",
	category = "world",
	default = 8,
	min = 0,
	max = 23,
	decimals = 0
})

NETWORK.config.Register("timeScale", {
	name = "cfgTimeScale",
	description = "cfgTimeScaleDesc",
	category = "world",
	default = 1,
	min = 0,
	max = 60,
	decimals = 1
})

NETWORK.config.Register("businessLostOnDeath", {
	name = "cfgBusinessDeath",
	description = "cfgBusinessDeathDesc",
	category = "world",
	type = "bool",
	default = false
})

NETWORK.config.Register("soldierModel", {
	name = "cfgSoldierModel",
	description = "cfgSoldierModelDesc",
	category = "characters",
	type = "string",
	default = "models/player/combine_soldier.mdl"
})

NETWORK.config.Register("eliteModel", {
	name = "cfgEliteModel",
	description = "cfgEliteModelDesc",
	category = "characters",
	type = "string",
	default = "models/player/combine_super_soldier.mdl"
})

NETWORK.config.Register("soldierCallsign", {
	name = "cfgSoldierCallsign",
	description = "cfgSoldierCallsignDesc",
	category = "characters",
	type = "string",
	default = "C24:Soldier-%03d"
})

NETWORK.config.Register("eliteCallsign", {
	name = "cfgEliteCallsign",
	description = "cfgEliteCallsignDesc",
	category = "characters",
	type = "string",
	default = "C24:Elite-%03d"
})

NETWORK.config.Register("voiceVersion2", {
	name = "cfgVoiceV2",
	description = "cfgVoiceV2Desc",
	category = "chat",
	type = "bool",
	default = true
})

NETWORK.config.Register("boardModel", {
	name = "cfgBoardModel",
	description = "cfgBoardModelDesc",
	category = "world",
	type = "string",
	default = "models/props_junk/wood_crate001a.mdl"
})

NETWORK.config.Register("combineRifleDamage", {
	name = "cfgCombineRifle",
	description = "cfgCombineRifleDesc",
	category = "world",
	default = 1.35,
	min = 0.5,
	max = 5,
	decimals = 2
})

NETWORK.config.Register("heavyShotgunDamage", {
	name = "cfgHeavyShotgun",
	description = "cfgHeavyShotgunDesc",
	category = "world",
	default = 2.1,
	min = 0.5,
	max = 5,
	decimals = 2
})

NETWORK.config.Register("chatGestureChance", {
	name = "cfgChatGesture",
	description = "cfgChatGestureDesc",
	category = "world",
	default = 35,
	min = 0,
	max = 100,
	decimals = 0
})

NETWORK.config.Register("corpseTime", {
	name = "cfgCorpseTime",
	description = "cfgCorpseTimeDesc",
	category = "world",
	default = 0,
	min = 0,
	max = 3600,
	decimals = 0
})

NETWORK.config.Register("respawnTime", {
	name = "cfgRespawn",
	description = "cfgRespawnDesc",
	category = "world",
	default = 12,
	min = 1,
	max = 120,
	decimals = 0
})

NETWORK.config.Register("startTokens", {
	name = "cfgTokens",
	description = "cfgTokensDesc",
	category = "characters",
	default = 50,
	min = 0,
	max = 5000,
	decimals = 0
})
