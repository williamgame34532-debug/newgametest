concommand.Add("network_debug", function(client)
	local function Line(text)
		if (CLIENT) then
			MsgC(Color(126, 224, 250), "[NETWORK] ", Color(226, 236, 248), text, "\n")
		else
			MsgC(Color(126, 224, 250), "[NETWORK] ", Color(226, 236, 248), text, "\n")
		end
	end

	Line("=== " .. (CLIENT and "КЛИЕНТ" or "СЕРВЕР") .. " ===")
	Line("Версия: " .. tostring(NETWORK.version) .. "  сборка: " .. tostring(NETWORK.build))
	Line("Предметов: " .. #NETWORK.item.GetAll())
	Line("Фракций: " .. table.Count(NETWORK.factions.stored or {}))
	Line("Зон: " .. table.Count(NETWORK.zone.list or {}))
	Line("Диалогов: " .. #NETWORK.dialogue.GetAll())
	Line("Дверей оформлено: " .. table.Count(NETWORK.door.list or {}))
	Line("Команд: " .. #NETWORK.command.GetAll())

	if (SERVER) then
		Line("Сохранений состояния: " .. table.Count(NETWORK.persistence.cache or {}))
		Line("Слотов экипировки: " .. NETWORK.inventory.GetSize())

		for _, target in ipairs(player.GetAll()) do
			local state = NETWORK.inventory.GetState(target)

			Line(string.format("  %s: предметов %d, ранений %d, токенов %d",
				target:SteamID(), table.Count(state.items or {}),
				table.Count(target.nwWounds or {}), target:GetTokens()))
		end

		return
	end

	Line("Слот с подсветкой: " .. tostring(vgui.GetControlTable("nwItemSlot") != nil and
		vgui.GetControlTable("nwItemSlot").PaintOver != nil))
	Line("Иконка предмета: " .. tostring(vgui.GetControlTable("nwItemIcon") != nil))
	Line("Редактор иконок: " .. tostring(vgui.GetControlTable("nwIconEditor") != nil))
	Line("Настроенных иконок: " .. table.Count(NETWORK.icon.stored or {}))
	Line("Логотип найден: " .. tostring(!NETWORK.util.GetMaterial(
		NETWORK.hud.logoPath, "smooth"):IsError()))
	Line("Панель ранений: " .. tostring(vgui.GetControlTable("nwWoundPanel") != nil))
	Line("Меню помощи: " .. tostring(vgui.GetControlTable("nwHelpMenu") != nil))
	Line("Превью перетаскивания: " .. tostring(vgui.GetControlTable("nwDragPreview") != nil))
	Line("Ранений известно: " .. table.Count(NETWORK.wound.state or {}))
	Line("Знакомых: " .. table.Count(NETWORK.recognition.known or {}))
end)
