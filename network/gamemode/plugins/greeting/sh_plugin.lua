PLUGIN.name = "Приветствие в чате"
PLUGIN.author = "Network"
PLUGIN.description = "Приветствие зоны и встреча персонажа пишутся в чат, а не уведомлением."
PLUGIN.version = "1.0"

PLUGIN.config = {
	enabled = true,

	delay = 1.5,

	zoneInChat = true
}

if (CLIENT) then

	local greetingMode = CreateClientConVar("network_zone_greeting", "chat", true, false,
		"Приветствие зоны: chat или notify")

	function PLUGIN:NetworkZoneGreeting(zone, data)
		if (!self.config.zoneInChat or greetingMode:GetString() != "chat") then
			return
		end

		NETWORK.chat.Notify(zone.greeting, data and data.color)

		return true
	end
else
	function PLUGIN:NetworkCharacterLoaded(client, character)
		timer.Simple(self.config.delay, function()
			if (!IsValid(client) or !client:HasCharacter() or
				client:GetCharacter() != character) then
				return
			end

			local zone = NETWORK.zone and NETWORK.zone.AtEntity and NETWORK.zone.AtEntity(client)
			local where = zone and zone.name and zone.name != "" and
				L("greetChatZone", zone.name) or ""

			NETWORK.chat.Notice(client, L("greetChat", character:GetName()) .. where)
		end)
	end
end

function PLUGIN:OnLoaded()
	NETWORK.util.Print("Приветствие в чате: готово.")
end
