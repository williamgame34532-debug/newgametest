local FACTION = {}

FACTION.name = "factionVortigaunt"
FACTION.description = "factionVortigauntDescription"
FACTION.icon = "framework/icons/citizen.png"
FACTION.unknownName = "unknownVortigaunt"
FACTION.color = Color(136, 196, 96)
FACTION.bDefault = false
FACTION.bWhitelist = true

FACTION.models = {
	"models/vortigaunt_slave.mdl"
}

FACTION.defaultClass = "vortslave"

FACTION.toughness = {
	damage = 0.5,
	bleedSoften = 0.6,
	fracture = 0.25,
	pneumo = false,
	pain = 0.3,
	wound = 0.5,
	knockdown = false,
	armour = 0.3,
	weaponPower = {
		swep_vortigaunt_beam = 3
	}
}

NETWORK.factions.Register("vortigaunt", FACTION)

function NETWORK.factions.IsVortigaunt(client)
	return IsValid(client) and client:IsPlayer() and client:HasCharacter() and
		client:GetCharacterFaction() == "vortigaunt"
end

if (SERVER) then

	local function EnsureClass(client, character)
		if (!character or character:GetFaction() != "vortigaunt") then
			return
		end

		if (!NETWORK.classes or !NETWORK.classes.Get(FACTION.defaultClass)) then
			return
		end

		local key = tostring(character:GetID())

		NETWORK.classes.assigned = NETWORK.classes.assigned or {}

		local entry = NETWORK.classes.GetEntry(character)
		local current = entry and NETWORK.classes.Get(entry.id)

		if (current and current.faction == "vortigaunt") then
			return
		end

		NETWORK.classes.assigned[key] = {id = FACTION.defaultClass}
		NETWORK.classes.SaveAll()
	end

	hook.Add("NetworkCharacterCreated", "nwVortigaunt", EnsureClass)
	hook.Add("NetworkCharacterLoaded", "nwVortigaunt", EnsureClass)
end
