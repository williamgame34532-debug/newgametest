ITEM.name = "Лазерная мина"
ITEM.description = "Настенный излучатель Альянса. Луч длиной до 400 единиц; кто пересёк его без допуска — получает направленный заряд."
ITEM.model = "models/props_combine/combine_mine01.mdl"
ITEM.rarity = "special"
ITEM.weight = 1.5
ITEM.maxStack = 2
ITEM.width = 1
ITEM.height = 1
ITEM.category = "weapon"

ITEM.useLabel = "itemDeploy"
ITEM.factions = {"cp", "cmb", "combine"}

function ITEM:OnUse(client)
	NETWORK.deploy.Start(client, "lasermine")

	return false
end
