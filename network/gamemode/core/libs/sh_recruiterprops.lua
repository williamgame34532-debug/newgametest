if (SERVER) then
	util.AddNetworkString("nwRecruiterConfig")

	net.Receive("nwRecruiterConfig", function(_, client)
		if (!client:IsAdmin()) then
			return
		end

		local entity = net.ReadEntity()
		local payload = NETWORK.util.ReadTable()

		if (!IsValid(entity) or entity:GetClass() != "nw_recruiter") then
			return
		end

		entity:SetNPCName(NETWORK.util.Sanitise(payload.name, 48))
		entity:SetConfigID(string.gsub(string.lower(
			NETWORK.util.Sanitise(payload.config, 32)), "[^%w_]", ""))

		if (isstring(payload.model) and payload.model != "") then
			entity:SetNPCModel(payload.model)
		end

		entity:SetNPCSequence(isstring(payload.sequence) and payload.sequence or "")

		entity:Apply()
	end)
else
	function NETWORK.gui.SendRecruiterConfig(entity, payload)
		net.Start("nwRecruiterConfig")
			net.WriteEntity(entity)
			NETWORK.util.WriteTable(payload)
		net.SendToServer()
	end
end

properties.Add("nwRecruiterConfig", {
	MenuLabel = "Настроить вербовщика",
	Order = 1,
	MenuIcon = "icon16/group_add.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_recruiter" and
			client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenRecruiterConfig(entity)
	end
})
