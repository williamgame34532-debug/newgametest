ITEM.name = "Стяжки"
ITEM.description = "Пластиковые хомуты. Одного хватает, чтобы связать руки; снять их можно только разрезав."
ITEM.model = "models/props_c17/tools_wrench01a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.3
ITEM.maxStack = 4
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

ITEM.useLabel = "itemTie"
ITEM.bConsumeOnUse = true

function ITEM:OnUse(client)
	local target = NETWORK.restraint.GetTarget(client)

	if (!target) then
		NETWORK.chat.Notice(client, "tieNoTarget")

		return false
	end

	if (NETWORK.restraint.IsTied(target)) then
		if (hook.Run("NetworkCanUntie", client, target) == false) then
			return false
		end

		NETWORK.restraint.Begin(client, target, true)

		return false
	end

	NETWORK.restraint.Begin(client, target, false)

	return true
end
