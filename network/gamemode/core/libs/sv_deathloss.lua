NETWORK.deathloss = NETWORK.deathloss or {}

local D = NETWORK.deathloss

D.categories = {
	weapon = true,
	weapons = true,
	ammo = true
}

NETWORK.config.Register("deathLoseWeapons", {
	name = "cfgDeathWeapons",
	description = "cfgDeathWeaponsDesc",
	category = "world",
	type = "bool",
	default = true
})

function D.Enabled()
	return NETWORK.config.Get("deathLoseWeapons") != false
end

function D.IsLost(item)
	local base = NETWORK.item.Get(item.id)

	if (!base) then
		return false
	end

	if (base.bKeepOnDeath) then
		return false
	end

	return D.categories[base.category or ""] == true or base.weaponClass != nil
end

function D.Strip(client)
	if (!D.Enabled() or !client:HasCharacter()) then
		return 0
	end

	local state = NETWORK.inventory.GetState(client)
	local lost = 0

	for _, list in ipairs({"items", "equipped", "storage"}) do
		for index, item in pairs((state or {})[list] or {}) do
			if (!istable(item) or !D.IsLost(item)) then
				continue
			end

			if (NETWORK.antidupe and istable(item.data) and item.data.uid) then
				NETWORK.antidupe.Release(item.data.uid)
			end

			state[list][index] = nil
			lost = lost + 1
		end
	end

	if (lost > 0) then
		NETWORK.inventory.Sync(client)
		NETWORK.notice.Send(client, "deathWeaponsLost", "warn", lost)
	end

	return lost
end

hook.Add("PlayerDeath", "nwDeathLoss", function(client)

	timer.Simple(0.1, function()
		if (IsValid(client)) then
			D.Strip(client)

			client:StripWeapons()
		end
	end)
end)

local function GiveHands(client)
	timer.Simple(0.2, function()
		if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
			return
		end

		local hands = NETWORK.weapon and NETWORK.weapon.hands or "weapon_nwhands"

		if (!client:HasWeapon(hands)) then
			client:Give(hands)
		end
	end)
end

hook.Add("PlayerSpawn", "nwDeathLossHands", GiveHands)
hook.Add("NetworkCharacterLoaded", "nwDeathLossHands", GiveHands)

timer.Create("nwHandsWatch", 30, 0, function()
	local hands = NETWORK.weapon and NETWORK.weapon.hands or "weapon_nwhands"

	for _, client in ipairs(player.GetAll()) do
		if (client:Alive() and client:HasCharacter() and !client:HasWeapon(hands)) then
			client:Give(hands)
		end
	end
end)
