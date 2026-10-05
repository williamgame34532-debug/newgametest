NETWORK.workbench = NETWORK.workbench or {}

local C = NETWORK.workbench

C.range = NETWORK.craft.range

function C.ParseRecipes(text)
	local list, skipped = NETWORK.craft.ParseWorkbench(text)

	if (skipped > 0) then
		list.skipped = skipped
	end

	return list
end

function C.Count(client, id)
	local state = SERVER and NETWORK.inventory.GetState(client) or NETWORK.inventory.state

	return NETWORK.craft.Count(state, id)
end

if (SERVER) then
	util.AddNetworkString("nwWorkbenchMake")
	util.AddNetworkString("nwWorkbenchConfig")

	function C.Open(client, entity)
		NETWORK.craft.Open(client, entity)
	end

	net.Receive("nwWorkbenchMake", function(_, client)
		local entity = net.ReadEntity()
		local index = net.ReadUInt(8)

		if (!IsValid(entity) or entity:GetClass() != "nw_craft_table" or index > 31) then
			return
		end

		client.nwCraftTable = entity

		NETWORK.craft.Start(client, entity, index, 1)
	end)

	net.Receive("nwWorkbenchConfig", function(_, client)
		local entity = net.ReadEntity()
		local payload = NETWORK.util.ReadTable() or {}

		if (!IsValid(entity) or entity:GetClass() != "nw_craft_table") then
			return
		end

		NETWORK.craft.ApplyConfig(client, entity, payload)
	end)
end

if (CLIENT and NETWORK.interact and NETWORK.interact.Register) then
	NETWORK.interact.Register("nw_crafttable", {icon = "build"})
	NETWORK.interact.Register("nw_craft_table", {icon = "build"})
end
