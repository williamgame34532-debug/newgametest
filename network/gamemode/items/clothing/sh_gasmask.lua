ITEM.name = "Противогаз"
ITEM.description = "Резиновая маска с фильтром. Дышать в ней тяжело, но воздух чистый."
ITEM.model = "models/props_c17/gasmask.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 1
ITEM.width = 1
ITEM.height = 1
ITEM.category = "clothing"

ITEM.equipSlot = "mask"

ITEM.bodygroups = {[4] = 1}

ITEM.gasProtection = true

ITEM.radProtection = 0.3

if (SERVER) then

	hook.Add("EntityTakeDamage", "nwGasmask", function(victim, damage)
		if (!victim:IsPlayer() or !victim:HasCharacter()) then
			return
		end

		if (!damage:IsDamageType(DMG_NERVEGAS) and
			!damage:IsDamageType(DMG_POISON)) then
			return
		end

		local state = NETWORK.inventory.GetState(victim)
		local worn = state and state.equipped and state.equipped.mask

		if (!worn) then
			return
		end

		local base = NETWORK.item.Get(worn.id)

		if (!base or !base.gasProtection) then
			return
		end

		damage:SetDamage(0)

		return true
	end)
end
