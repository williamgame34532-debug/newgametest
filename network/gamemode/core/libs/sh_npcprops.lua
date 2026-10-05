if (SERVER) then
	util.AddNetworkString("nwNPCConfig")

	net.Receive("nwNPCConfig", function(_, client)
		if (!client:IsAdmin()) then
			return
		end

		local entity = net.ReadEntity()
		local payload = NETWORK.util.ReadTable()

		if (!IsValid(entity) or entity:GetClass() != "nw_npc") then
			return
		end

		entity:SetNPCName(NETWORK.util.Sanitise(payload.name, 48))
		entity:SetDialogue(isstring(payload.dialogue) and payload.dialogue or "")

		if (isstring(payload.model) and payload.model != "") then
			entity:SetNPCModel(payload.model)
		end

		entity:SetNPCSequence(isstring(payload.sequence) and payload.sequence or "")
		entity:SetFactions(table.concat(
			NETWORK.dialogue.ParseFactions(payload.factions), ","))

		entity:Apply()
	end)
else
	function NETWORK.gui.SendNPCConfig(entity, payload)
		net.Start("nwNPCConfig")
			net.WriteEntity(entity)
			NETWORK.util.WriteTable(payload)
		net.SendToServer()
	end
end

properties.Add("nwNPCConfig", {
	MenuLabel = "Настроить NPC",
	Order = 1,
	MenuIcon = "icon16/user_edit.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_npc" and client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenNPCConfig(entity)
	end
})
