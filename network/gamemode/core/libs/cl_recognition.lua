NETWORK.recognition.known = NETWORK.recognition.known or {}

net.Receive("nwRecogniseSync", function()
	local list = NETWORK.util.ReadTable()

	NETWORK.recognition.known = {}

	for _, id in ipairs(list) do
		NETWORK.recognition.known[id] = true
	end

	hook.Run("NetworkRecognitionUpdated")
end)

net.Receive("nwRecogniseMenu", function()
	NETWORK.gui.OpenRecognise()
end)

function NETWORK.recognition.Send(mode)
	net.Start("nwRecognise")
		net.WriteString(mode)
	net.SendToServer()
end
