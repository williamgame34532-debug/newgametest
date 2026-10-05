NETWORK.climate = NETWORK.climate or {}

local C = NETWORK.climate

C.demand = {clear = 0, overcast = 1, fog = 2, rain = 2, storm = 3}

C.warmth = {jacket = 2, vest = 1, pants = 1, boots = 1, hat = 1, gloves = 0.5, mask = 0.5, helmet = 0.5}

C.exemptFactions = {disinfector = true}
C.exemptClasses = {cwuhead = true}

C.coldWarn = 40
C.coldFreeze = 80
C.wetWarn = 40

function C.IsExempt(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return true
	end

	if (client.IsCombine and client:IsCombine()) then
		return true
	end

	local factionID = client:GetCharacterFaction()

	if (factionID and C.exemptFactions[factionID]) then
		return true
	end

	return C.exemptClasses[client:GetNWString("nwClass", "")] == true
end

function C.ItemWarmth(item)
	if (!istable(item)) then
		return 0
	end

	local base = NETWORK.item.Get(item.id)

	if (!base) then
		return 0
	end

	if (isnumber(base.warmth)) then
		return base.warmth
	end

	return C.warmth[base.equipSlot or ""] or 0
end

function C.GetWarmth(equipped)
	local total = 0

	for _, item in pairs(equipped or {}) do
		total = total + C.ItemWarmth(item)
	end

	return total
end

function C.HasCoat(equipped)
	for _, item in pairs(equipped or {}) do
		local base = NETWORK.item.Get(item.id)

		if (base and (base.equipSlot == "jacket" or base.waterproof)) then
			return true
		end
	end

	return false
end

function C.GetDemand()
	local weather = NETWORK.weather and NETWORK.weather.GetCurrent and NETWORK.weather.GetCurrent()

	return weather and (C.demand[weather.id] or 0) or 0
end

local PLAYER = FindMetaTable("Player")

function PLAYER:GetCold()
	return self:GetNWFloat("nwCold", 0)
end

function PLAYER:GetWet()
	return self:GetNWFloat("nwWet", 0)
end

NETWORK.config.Register("climate", {
	name = "cfgClimate",
	description = "cfgClimateDesc",
	category = "world",
	type = "bool",
	default = true
})

NETWORK.config.Register("climateColdRate", {
	name = "cfgClimateColdRate",
	description = "cfgClimateColdRateDesc",
	category = "world",
	type = "number",
	default = 1.5,
	min = 0.2,
	max = 10,
	decimals = 1
})

NETWORK.config.Register("climateDamage", {
	name = "cfgClimateDamage",
	description = "cfgClimateDamageDesc",
	category = "world",
	type = "bool",
	default = true
})
