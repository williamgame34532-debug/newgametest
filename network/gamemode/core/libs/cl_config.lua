net.Receive("nwConfigSync", function()
	NETWORK.config.values = NETWORK.util.ReadTable()

	NETWORK.config.ApplyAll()

	hook.Run("NetworkConfigUpdated")
end)

function NETWORK.config.Request(id, value)
	net.Start("nwConfigSet")
		net.WriteString(id)
		NETWORK.util.WriteTable({value = value})
	net.SendToServer()
end
