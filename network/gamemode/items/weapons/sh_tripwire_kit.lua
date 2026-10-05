ITEM.name = "Растяжка"
ITEM.description = "Граната с проволокой и парой крючков. Ставится в проходе: якорь, затем конец проволоки. Своих не трогает — остальные узнают о ней слишком поздно."
ITEM.model = "models/weapons/w_grenade.mdl"
ITEM.rarity = "special"
ITEM.weight = 0.8
ITEM.maxStack = 2
ITEM.width = 1
ITEM.height = 1
ITEM.category = "weapon"

ITEM.useLabel = "itemDeploy"

function ITEM:OnUse(client)
	NETWORK.deploy.Start(client, "tripwire")

	return false
end
