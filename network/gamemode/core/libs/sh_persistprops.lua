local CLASSES = {
	prop_physics = true,
	prop_dynamic = true,
	prop_physics_multiplayer = true
}

local function CanPersist(client, entity)
	if (!IsValid(entity) or !IsValid(client) or !client:IsAdmin()) then
		return false
	end

	return CLASSES[entity:GetClass()] == true
end

properties.Add("nwUnpersistProp", {
	MenuLabel = "Не сохранять (Network)",
	Order = 2,
	MenuIcon = "icon16/disk_delete.png",
	Filter = function(self, entity, client)
		return CanPersist(client, entity) and entity:GetNWBool("nwPersist", false)
	end,
	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,
	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!self:Filter(entity, client)) then
			return
		end

		entity.nwPersist = nil

		entity:SetNWBool("nwPersist", false)

		NETWORK.entities.Save()
		NETWORK.chat.Notice(client, "propUnsaved")
	end
})

if (SERVER) then

	hook.Add("InitPostEntity", "nwPersistPropMark", function()
		timer.Simple(4, function()
			for class in pairs(CLASSES) do
				for _, entity in ipairs(ents.FindByClass(class)) do
					if (entity.nwPersist) then
						entity:SetNWBool("nwPersist", true)
					end
				end
			end
		end)
	end)

	concommand.Add("network_propsave", function(client)
		if (!IsValid(client) or !client:IsAdmin()) then
			return
		end

		NETWORK.command.Parse(client, "/propsave")
	end)

	NETWORK.command.Register("propsave", {
		description = "cmdPropsave",
		usage = "/propsave",
		adminOnly = true,
		OnRun = function(command, client)
			local entity = client:GetEyeTrace().Entity

			if (!CanPersist(client, entity)) then
				return NETWORK.chat.Notice(client, "propNotProp")
			end

			local bSave = !entity.nwPersist

			entity.nwPersist = bSave or nil

			entity:SetNWBool("nwPersist", bSave)

			if (bSave) then
				local physics = entity:GetPhysicsObject()

				if (IsValid(physics)) then
					physics:EnableMotion(false)
					physics:Sleep()
				end
			end

			NETWORK.entities.Save()
			NETWORK.chat.Notice(client, bSave and "propSaved" or "propUnsaved")
		end
	})
end
