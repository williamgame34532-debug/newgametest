local function AddCreateTile(container)
	local tile = container:Add("DButton")

	tile:SetSize(64, 64)
	tile:SetText("")
	tile:SetTooltip(L("itemCreateNode"))
	tile.Paint = function(panel, width, height)
		local accent = NETWORK.theme.accent
		local radius = NETWORK.style and NETWORK.style.Radius and NETWORK.style.Radius("cell") or 6

		draw.RoundedBox(radius, 0, 0, width, height,
			Color(accent.r, accent.g, accent.b, panel:IsHovered() and 70 or 30))
		draw.SimpleText("+", "DermaLarge", width / 2, height / 2, color_white,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	tile.DoClick = function()
		if (NETWORK.itemedit and NETWORK.itemedit.OpenCreator) then
			NETWORK.itemedit.OpenCreator()
		end
	end
end

local function BuildItemPanel(container)
	AddCreateTile(container)

	for _, base in ipairs(NETWORK.item.GetAll()) do
		local icon = container:Add("SpawnIcon")

		icon:SetModel(base.model)
		icon:SetSize(64, 64)
		icon:SetTooltip(L(base.name) .. (base.bCustom and ("\n" .. L("itemCreateCustomTag")) or ""))
		icon.DoClick = function()
			RunConsoleCommand("network_item_give", base.id)

			NETWORK.sound.Click()
		end
		icon.OpenMenu = function()
			local menu = DermaMenu()

			menu:AddOption("Выдать 5", function()
				RunConsoleCommand("network_item_give", base.id, "5")
			end)

			menu:AddOption("Заспавнить в мире", function()
				RunConsoleCommand("network_item_spawn", base.id)
			end)

			menu:AddOption("Скопировать id", function()
				SetClipboardText(base.id)
			end)

			if (NETWORK.itemedit and NETWORK.itemedit.AddMenuOptions) then
				NETWORK.itemedit.AddMenuOptions(menu, base.id)
			end

			menu:Open()
		end
	end
end

hook.Add("Initialize", "nwItemSpawnMenu", function()
	timer.Simple(1, function()
		if (!spawnmenu or !spawnmenu.AddCreationTab) then
			return
		end

		spawnmenu.AddCreationTab("Предметы", function()
			local panel = vgui.Create("ContentContainer")

			panel:SetVisible(false)
			panel:SetTriggerSpawnlistChange(false)

			local header = vgui.GetControlTable("ContentHeader") and
				panel:Add("ContentHeader")

			if (IsValid(header)) then
				header:SetText("Network: предметы")
			end

			BuildItemPanel(panel)

			return panel
		end, "icon16/box.png", 60)
	end)
end)
