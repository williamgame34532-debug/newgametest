NETWORK.diag = NETWORK.diag or {}

NETWORK.diag.version = "2026.09.12"

if (SERVER) then
	util.AddNetworkString("nwDiag")

	NETWORK.command.Register("nwdiag", {
		description = "cmdNwDiag",
		usage = "/nwdiag",
		OnRun = function(command, client)
			local character = client:GetCharacter()

			net.Start("nwDiag")
				net.WriteString(NETWORK.diag.version)
				net.WriteUInt(NETWORK.inventory.columns or 0, 8)
				net.WriteUInt(NETWORK.inventory.rows or 0, 8)
				net.WriteString(client:GetNWString("nwClass", ""))
				net.WriteString(character and character:GetName() or "")
				net.WriteString(character and character:GetModel() or "")
				net.WriteUInt(math.Clamp(client:Health(), 0, 1023), 10)
				net.WriteUInt(math.Clamp(client:Armor(), 0, 1023), 10)
			net.Send(client)
		end
	})
else
	net.Receive("nwDiag", function()
		local serverVersion = net.ReadString()
		local columns = net.ReadUInt(8)
		local rows = net.ReadUInt(8)
		local class = net.ReadString()
		local name = net.ReadString()
		local model = net.ReadString()
		local health = net.ReadUInt(10)
		local armor = net.ReadUInt(10)

		local client = LocalPlayer()

		local function Line(label, server, mine)
			local bSame = tostring(server) == tostring(mine)

			MsgC(Color(150, 160, 175), string.format("%-14s", label),
				bSame and Color(150, 220, 170) or Color(240, 120, 110),
				string.format("сервер: %-28s клиент: %s\n", tostring(server),
				tostring(mine)))
		end

		MsgC(Color(120, 200, 255), "\n=== ДИАГНОСТИКА NETWORK ===\n")

		Line("Версия", serverVersion, NETWORK.diag.version)
		Line("Колонки", columns, NETWORK.inventory.columns or 0)
		Line("Ряды", rows, NETWORK.inventory.rows or 0)
		Line("Класс", class, client:GetNWString("nwClass", ""))
		Line("Имя", name, client:GetCharacterName())
		Line("Модель", model, client:GetModel())
		Line("Здоровье", health, client:Health())
		Line("Броня", armor, client:Armor())

		local state = NETWORK.inventory.state
		local count = 0

		for _, list in ipairs({"items", "storage", "equipped"}) do
			for _ in pairs(state and state[list] or {}) do
				count = count + 1
			end
		end

		MsgC(Color(150, 160, 175), string.format("%-14s", "Предметов"),
			Color(226, 236, 248), tostring(count) .. " (по данным клиента)\n")

		if (serverVersion != NETWORK.diag.version) then
			MsgC(Color(240, 120, 110),
				"\nВЕРСИИ НЕ СОВПАДАЮТ. Клиент работает на старых файлах: " ..
				"выйдите из игры полностью, удалите папку\n" ..
				"garrysmod/download/lua (если есть) и зайдите заново.\n")
		end

		MsgC(Color(120, 200, 255), "===========================\n\n")
	end)
end
