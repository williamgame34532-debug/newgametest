properties.Add("nwJunkConfig", {
	MenuLabel = "Настроить мусор",
	Order = 1,
	MenuIcon = "icon16/basket.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_junk" and client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenJunkConfig(entity)
	end
})
