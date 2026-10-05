NETWORK.container.state = NETWORK.container.state or {items = {}, slots = 0}

function NETWORK.container.GetEntity()
	return NETWORK.container.entity
end

function NETWORK.container.GetItem(index)
	return NETWORK.container.state.items[index]
end

function NETWORK.container.GetSlots()
	return NETWORK.container.state.slots
end

function NETWORK.container.Request(action, payload)
	net.Start("nwContainerAction")
		net.WriteString(action)
		NETWORK.util.WriteTable(payload or {})
	net.SendToServer()
end

function NETWORK.container.Move(from, to, bRotate)
	NETWORK.container.Request("move", {
		fromList = from.list,
		fromIndex = from.index,
		fromSlot = from.slot,
		toList = to.list,
		toIndex = to.index,
		toSlot = to.slot
	})
end

function NETWORK.container.Split(source, amount, target)
	NETWORK.container.Request("split", {
		fromList = source.list,
		fromIndex = source.index,
		fromSlot = source.slot,
		toList = target and target.list or source.list,
		toIndex = target and target.index or nil,
		amount = amount or 1
	})
end

function NETWORK.container.Swap()
	NETWORK.container.Request("swap")
end

function NETWORK.container.SendConfig(entity, name, description, refill)
	net.Start("nwContainerConfig")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable({
			name = name,
			description = description,
			refill = tonumber(refill) or 0
		})
	net.SendToServer()
end

net.Receive("nwContainerOpen", function()
	local entity = net.ReadEntity()

	if (!IsValid(entity)) then
		return
	end

	NETWORK.container.entity = entity
	NETWORK.container.state = {items = {}, slots = entity:GetContainerSlots()}

	NETWORK.gui.OpenContainer(entity)
end)

net.Receive("nwContainerSync", function()
	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable()
	local items = {}

	for index, item in pairs(payload) do
		items[tonumber(index)] = item
	end

	NETWORK.container.entity = entity
	NETWORK.container.state.items = items
	NETWORK.container.state.slots = IsValid(entity) and entity:GetContainerSlots() or 0

	hook.Run("NetworkContainerUpdated")
end)

net.Receive("nwContainerClose", function()
	NETWORK.container.entity = nil
	NETWORK.container.state = {items = {}, slots = 0}

	NETWORK.gui.CloseContainer()
end)

function NETWORK.container.SendLoot(entity, items)
	net.Start("nwContainerLoot")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(items or {})
	net.SendToServer()
end
