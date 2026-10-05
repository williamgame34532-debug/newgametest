PLUGIN.name = "Пример плагина"
PLUGIN.author = "Network"
PLUGIN.description = "Показывает структуру плагина фреймворка"
PLUGIN.version = "1.0"

function PLUGIN:OnLoaded()
	NETWORK.util.Print("Пример плагина готов к работе.")
end

function PLUGIN:NetworkPlayerLoadout(client, character)
	if (!SERVER or !self.config.enabled) then
		return
	end

	local kit = character:GetKitTable()

	NETWORK.util.Print(string.format("%s появился как %s (набор: %s)",
		client:SteamID(), character:GetName(), kit and L(kit.name) or "нет"))
end
