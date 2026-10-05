NETWORK.jail = NETWORK.jail or {}

NETWORK.jail.model = "models/hla_prop/combine_terminal.mdl"
NETWORK.jail.fallback = "models/props_combine/combine_interface001.mdl"

NETWORK.jail.range = 120
NETWORK.jail.scanRange = 320
NETWORK.jail.holdRange = 900
NETWORK.jail.refresh = 2

NETWORK.jail.termDefault = 15
NETWORK.jail.termMax = 240

NETWORK.jail.timeScale = 1
NETWORK.jail.terms = {5, 10, 15, 30, 60}
NETWORK.jail.reasonMax = 90

NETWORK.jail.reasons = {
	"jailReasonCurfew",
	"jailReasonDisobedience",
	"jailReasonWeapon",
	"jailReasonCheck",
	"jailReasonProperty",
	"jailReasonAiding"
}

function NETWORK.jail.GetModel()
	if (file.Exists(NETWORK.jail.model, "GAME")) then
		return NETWORK.jail.model
	end

	return NETWORK.jail.fallback
end

function NETWORK.jail.CanUse(client, entity)
	if (!IsValid(entity) or !IsValid(client) or !client:Alive() or
		!client:HasCharacter()) then
		return false
	end

	if (!NETWORK.factions.IsAlliance(client) and !client:IsAdmin()) then
		return false
	end

	return client:GetPos():Distance(entity:GetPos()) <= NETWORK.jail.range
end

function NETWORK.jail.CanJail(target)
	if (!IsValid(target) or !target:IsPlayer() or !target:Alive() or
		!target:HasCharacter()) then
		return false
	end

	return !NETWORK.factions.IsAlliance(target)
end
