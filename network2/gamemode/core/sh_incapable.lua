-- Dead or unconscious: nothing can be done. No chat, no voice, no inventory, no wheel, no E, no
-- weapons; only Space (to come to / to come back, cl_body.lua), TAB and the console. In the menu
-- (nwInMenu, the player is dead there) everything of the menu works.
-- The server drops the action messages of such a player (the list below); the client does not let
-- the binds and the keys through. Loaded last: every net receiver is there already.

function NW.Incapable(client)
	if (!IsValid(client) or client:GetNW2Bool("nwInMenu", false) or client:GetCharacterID() == 0) then
		return false
	end

	return !client:Alive() or client:GetNW2Bool("nwKnocked", false)
end

if (SERVER) then
	local BLOCKED = {"nwAct", "nwInvAction", "nwInvMove", "nwInvTake", "nwRequestAnswer", "nwSocial", "nwStorageAll",
		"nwStorageMove", "nwStorageTokens", "nwTerminal", "nwNpcAction", "nwTyping"}

	for _, name in ipairs(BLOCKED) do
		local key = string.lower(name)
		local receive = net.Receivers[key]

		if (receive) then
			net.Receivers[key] = function(length, client)
				if (!NW.Incapable(client)) then
					receive(length, client)
				end
			end
		end
	end

	hook.Add("PlayerUse", "nwIncapable", function(client)
		if (NW.Incapable(client)) then
			return false
		end
	end)

	return
end

-- what still goes through
local ALLOWED = {"+jump", "+showscores", "-showscores", "toggleconsole", "cancelselect", "gameui", "screenshot",
	"jpeg", "+attack"}

hook.Add("PlayerBindPress", "nwIncapable", function(client, bind)
	if (!NW.Incapable(client)) then
		return
	end

	bind = string.lower(bind)

	for _, allowed in ipairs(ALLOWED) do
		if (string.find(bind, allowed, 1, true)) then
			-- a click only brings you back when dead (the base gamemode); unconscious it does nothing
			if (allowed == "+attack" and client:Alive()) then
				return true
			end

			return
		end
	end

	return true
end)

-- falling down or dying with the chat or the microphone open: they close
local was = false

hook.Add("Think", "nwIncapable", function()
	local now = NW.Incapable(LocalPlayer())

	if (now and !was) then
		if (NW.chat and NW.chat.open and NW.chat.Close) then
			NW.chat.Close()
		end

		RunConsoleCommand("-voicerecord")

		if (NW.inventory and NW.inventory.IsOpen and NW.inventory.IsOpen() and NW.inventory.Close) then
			NW.inventory.Close()
		end
	end

	was = now
end)
