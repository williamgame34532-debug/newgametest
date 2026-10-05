properties.Add("nwTraderConfig", {
	MenuLabel = "Настроить торговца",
	Order = 1,
	MenuIcon = "icon16/user_suit.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_trader" and client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenTraderConfig(entity)
	end
})

properties.Add("nwTraderOffers", {
	MenuLabel = "Товары торговца",
	Order = 2,
	MenuIcon = "icon16/coins.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_trader" and client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenTraderOffers(entity)
	end
})
