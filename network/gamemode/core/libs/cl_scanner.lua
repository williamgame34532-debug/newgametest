NETWORK.scanner = NETWORK.scanner or {}

net.Receive("nwRepairOpen", function()
	NETWORK.gui.OpenRepairGame()
end)

function NETWORK.scanner.SendResult(bSuccess)
	net.Start("nwRepairResult")
		net.WriteBool(bSuccess)
	net.SendToServer()
end
