net.Receive("nwDialogueOpen", function()
	local entity = net.ReadEntity()

	if (!IsValid(entity)) then
		return
	end

	NETWORK.gui.OpenDialogue(entity)
end)

net.Receive("nwDialogueNode", function()
	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable()

	if (!IsValid(NETWORK.gui.dialogue)) then
		NETWORK.gui.OpenDialogue(entity)
	end

	if (IsValid(NETWORK.gui.dialogue)) then
		NETWORK.gui.dialogue:SetNode(payload)
	end
end)

net.Receive("nwDialogueClose", function()
	if (IsValid(NETWORK.gui.dialogue)) then
		NETWORK.gui.dialogue:Close()
	end
end)

function NETWORK.dialogue.Reply(index)
	net.Start("nwDialogueReply")
		net.WriteUInt(index, 8)
	net.SendToServer()
end
