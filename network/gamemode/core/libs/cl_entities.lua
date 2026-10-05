properties.Add("nwentitysave", {
	MenuLabel = "Сохранить (Network)",
	Order = 1,
	MenuIcon = "icon16/disk.png",

	Filter = function(self, entity, client)
		if (!IsValid(entity) or !client:IsAdmin()) then
			return false
		end

		local class = entity:GetClass()

		if (entity:GetNWBool("nwPersist", false)) then
			return false
		end

		return string.StartWith(class, "nw_") or class == "prop_physics" or
			class == "prop_dynamic" or class == "prop_physics_multiplayer"
	end,

	Action = function(self, entity)
		net.Start("nwEntitySave")
			net.WriteEntity(entity)
		net.SendToServer()
	end
})
