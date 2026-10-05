if (SERVER) then
	util.AddNetworkString("nwLedConfig")

	net.Receive("nwLedConfig", function(_, client)
		if (!client:IsAdmin()) then
			return
		end

		local entity = net.ReadEntity()
		local payload = NETWORK.util.ReadTable()

		if (!IsValid(entity) or entity:GetClass() != "nw_led") then
			return
		end

		entity:SetText(NETWORK.util.Sanitise(payload.text, 64))
		entity:SetSubtext(NETWORK.util.Sanitise(payload.subtext, 64))
		entity:SetStyle(math.Clamp(math.Round(tonumber(payload.style) or 0), 0, 3))
		entity:SetTextScale(math.Clamp(tonumber(payload.scale) or 1, 0.2, 4))
	end)

	NETWORK.command.Register("led", {
	description = "cmdLed",
	usage = "/led <текст>",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local entity = client:GetEyeTrace().Entity

			if (!IsValid(entity) or entity:GetClass() != "nw_led") then
				return
			end

			entity:SetText(NETWORK.util.Sanitise(table.concat(arguments, " "), 64))
		end
	})
else
	function NETWORK.gui.SendLedConfig(entity, payload)
		net.Start("nwLedConfig")
			net.WriteEntity(entity)
			NETWORK.util.WriteTable(payload)
		net.SendToServer()
	end
end

properties.Add("nwLedConfig", {
	MenuLabel = "Настроить панель",
	Order = 1,
	MenuIcon = "icon16/monitor.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_led" and client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenLedConfig(entity)
	end
})
