NETWORK.inventory.state = NETWORK.inventory.state or NETWORK.inventory.NewState()

function NETWORK.inventory.GetItem(index)
	return NETWORK.inventory.state.items[index]
end

function NETWORK.inventory.GetEquipped(slot)
	return NETWORK.inventory.state.equipped[slot]
end

function NETWORK.inventory.GetStorage(index)
	return NETWORK.inventory.state.storage[index]
end

function NETWORK.inventory.GetContainer()
	return NETWORK.inventory.ContainerOf(NETWORK.inventory.state)
end

function NETWORK.inventory.Count()
	return NETWORK.inventory.CountState(NETWORK.inventory.state)
end

function NETWORK.inventory.GetWeight()
	return NETWORK.inventory.WeightOf(NETWORK.inventory.state)
end

function NETWORK.inventory.Request(action, payload)
	net.Start("nwInventoryAction")
		net.WriteString(action)
		NETWORK.util.WriteTable(payload or {})
	net.SendToServer()
end

function NETWORK.inventory.Move(from, to, bRotate)
	NETWORK.inventory.Request("move", {
		fromList = from.list,
		fromIndex = from.index,
		fromSlot = from.slot,
		toList = to.list,
		toIndex = to.index,
		toSlot = to.slot,
		rotate = bRotate
	})
end

function NETWORK.inventory.Split(source, amount, target)
	NETWORK.inventory.Request("split", {
		fromList = source.list,
		fromIndex = source.index,
		fromSlot = source.slot,
		toList = target and target.list or source.list,
		toIndex = target and target.index or nil,
		amount = amount or 1
	})
end

function NETWORK.inventory.Rotate(source)
	NETWORK.inventory.Move(source, source, true)
end

function NETWORK.inventory.Equip(index)
	local item = NETWORK.inventory.GetItem(index)
	local slot = item and NETWORK.item.GetEquipSlot(item)

	if (!slot) then
		return
	end

	NETWORK.inventory.Move({list = "items", index = index},
		{list = "equipped", slot = slot})
end

function NETWORK.inventory.Unequip(slot)
	local item = NETWORK.inventory.GetEquipped(slot)
	local free = item and NETWORK.inventory.FindSpot(NETWORK.inventory.state.items,
		NETWORK.inventory.columns, NETWORK.inventory.rows, item)

	if (!free) then
		return
	end

	NETWORK.inventory.Move({list = "equipped", slot = slot}, {list = "items", index = free})
end

function NETWORK.inventory.ToStorage(index)
	local container = NETWORK.inventory.GetContainer()

	if (!container) then
		return
	end

	local item = NETWORK.inventory.GetItem(index)
	local columns = NETWORK.inventory.columns
	local free = item and NETWORK.inventory.FindSpot(NETWORK.inventory.state.storage,
		columns, math.ceil(NETWORK.item.GetStorageSlots(container) / columns), item)

	if (!free) then
		return
	end

	NETWORK.inventory.Move({list = "items", index = index}, {list = "storage", index = free})
end

function NETWORK.inventory.FromStorage(index)
	local item = NETWORK.inventory.GetStorage(index)
	local free = item and NETWORK.inventory.FindSpot(NETWORK.inventory.state.items,
		NETWORK.inventory.columns, NETWORK.inventory.rows, item)

	if (!free) then
		return
	end

	NETWORK.inventory.Move({list = "storage", index = index}, {list = "items", index = free})
end

function NETWORK.inventory.Drop(source)
	NETWORK.inventory.Request("drop", {
		fromList = source.list,
		fromIndex = source.index,
		fromSlot = source.slot
	})
end

function NETWORK.inventory.Use(source)
	NETWORK.inventory.Request("use", {
		fromList = source.list,
		fromIndex = source.index,
		fromSlot = source.slot
	})
end

function NETWORK.inventory.CanDrop(item, list, index, slot, fromList)
	return NETWORK.inventory.CanPlace(NETWORK.inventory.state, item, list, index, slot, fromList)
end

local function SameState(a, b)
	if (type(a) != type(b)) then return false end
	if (!istable(a)) then return a == b end
	for k, v in pairs(a) do if (!SameState(v, b[k])) then return false end end
	for k in pairs(b) do if (a[k] == nil) then return false end end
	return true
end

net.Receive("nwInventorySync", function()
	local state = NETWORK.util.ReadTable()

	state.items = state.items or {}
	state.equipped = state.equipped or {}
	state.storage = state.storage or {}

	local unchanged = SameState(state, NETWORK.inventory.state or {})
	NETWORK.inventory.lastSync = CurTime()
	if (unchanged) then return end
	local previous = NETWORK.inventory.state and NETWORK.inventory.state.equipped

	if (previous and NETWORK.gui.InventoryNotice) then
		for slot, item in pairs(state.equipped) do
			local before = previous[slot]

			if (!before or before.id != item.id) then
				NETWORK.gui.InventoryNotice(L("invEquipped",
					NETWORK.item.GetName(item)), NETWORK.theme.positive)

				break
			end
		end
	end

	NETWORK.inventory.state = state
	NETWORK.inventory.lastSync = CurTime()

	hook.Run("NetworkInventoryUpdated")
end)

concommand.Add("network_inv_diag", function()
	local function Say(text)
		MsgN("[Network/клиент] " .. text)
	end

	local state = NETWORK.inventory.state
	local last = NETWORK.inventory.lastSync

	Say("сборка " .. tostring(NETWORK.buildTag) .. ", персонаж: " ..
		tostring(LocalPlayer():HasCharacter()))
	Say("последний Sync: " .. (last and (math.Round(CurTime() - last) .. " с назад") or
		"НЕ ПРИХОДИЛ"))
	Say("сумка на клиенте: " .. (state and (table.Count(state.items or {}) .. " вещей, " ..
		table.Count(state.equipped or {}) .. " надето") or "состояния нет"))
	Say("меню: " .. tostring(IsValid(NETWORK.gui.tabMenu)) .. ", перенос в руке: " ..
		tostring(NETWORK.gui.drag != nil) .. ", обыск: " .. tostring(IsValid(NETWORK.gui.search)))

	local before = NETWORK.inventory.lastSync

	NETWORK.inventory.Request("ping", {})

	timer.Simple(1, function()
		Say((NETWORK.inventory.lastSync or 0) > (before or 0) and
			"ответ сервера на действие пришёл — сеть работает" or
			"ОТВЕТ НА ДЕЙСТВИЕ НЕ ПРИШЁЛ за секунду — смотрите консоль сервера")
	end)

	RunConsoleCommand("network_inv_diag_sv")
end)

net.Receive("nwAppearance", function()
	hook.Run("NetworkAppearanceChanged")

	timer.Create("nwAppearanceRefresh", 0.1, 1, function()
		local menu = NETWORK.gui.tabMenu

		if (IsValid(menu) and menu.activeTab == "character") then
			NETWORK.gui.instantUntil = CurTime() + 0.2

			menu:RefreshTab(true)

			NETWORK.gui.instantUntil = 0
		end
	end)
end)
