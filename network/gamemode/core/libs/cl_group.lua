NETWORK.group = NETWORK.group or {}

NETWORK.group.own = NETWORK.group.own or nil

function NETWORK.group.Send(action, payload)
	net.Start("nwGroupAction")
		net.WriteString(action)
		NETWORK.util.WriteTable(payload or {})
	net.SendToServer()
end

net.Receive("nwGroupSync", function()
	if (!net.ReadBool()) then
		NETWORK.group.own = nil
	else
		NETWORK.group.own = NETWORK.util.ReadTable()

		NETWORK.group.chat = NETWORK.group.own.chat or {}
	end

	local menu = NETWORK.gui.tabMenu

	if (IsValid(menu) and menu.RefreshTab) then
		menu:RefreshTab()
	end
end)

net.Receive("nwGroupInvite", function()
	local name = net.ReadString()
	local from = net.ReadString()
	local chat = NETWORK.gui.chat

	if (!IsValid(chat) or !chat.AddPrompt) then
		return
	end

	chat:AddPrompt("<font=nwChatBig><color=120,200,255>" ..
		L("groupInviteLine", from, name) .. "</color></font>", "notice",
		function()
			NETWORK.group.Send("accept")
		end)
end)

function NETWORK.group.IsOwnLeader()
	local group = NETWORK.group.own
	local client = LocalPlayer()

	if (!group or !IsValid(client)) then
		return false
	end

	return group.leader == tostring(client:GetCharacterID())
end

NETWORK.group.chat = NETWORK.group.chat or {}

net.Receive("nwGroupChat", function()
	local name = net.ReadString()
	local text = net.ReadString()
	local stamp = net.ReadString()
	local bOwn = net.ReadBool()

	NETWORK.group.chat[#NETWORK.group.chat + 1] = {
		name = name,
		text = text,
		time = stamp
	}

	while (#NETWORK.group.chat > (NETWORK.group.chatMax or 40)) do
		table.remove(NETWORK.group.chat, 1)
	end

	local menu = NETWORK.gui.tabMenu
	local bOpen = IsValid(menu) and menu.activeTab == "group"

	if (!bOpen) then
		NETWORK.group.unread = (NETWORK.group.unread or 0) + 1
	end

	if (!bOwn) then
		local panel = NETWORK.gui.chat

		if (IsValid(panel)) then

			local colour = NETWORK.group.GetColor(NETWORK.group.own)

			panel:AddMarkup(string.format("<color=%d,%d,%d>%s</color>",
				colour.r, colour.g, colour.b, L("groupChatNotice", name)),
				"notice")
		end

		surface.PlaySound("buttons/lightswitch2.wav")
	end

	if (IsValid(menu) and menu.RefreshTab and bOpen) then
		menu:RefreshTab()
	end
end)

function NETWORK.group.SendChat(text)
	net.Start("nwGroupChatSend")
		net.WriteString(text or "")
	net.SendToServer()
end
