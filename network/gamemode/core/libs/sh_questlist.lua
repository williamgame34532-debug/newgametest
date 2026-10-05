NETWORK.quest.Register("garbage", {
	name = "Уборка путей",
	description = "Работница просит собрать металлолом на путях.",
	objectives = {
		{type = "item", id = "scrap", amount = 5}
	},
	rewards = {
		items = {
			{id = "ration", amount = 2},
			{id = "water", amount = 1}
		}
	}
})
