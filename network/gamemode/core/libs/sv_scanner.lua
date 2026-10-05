util.AddNetworkString("nwRepairOpen")
util.AddNetworkString("nwRepairResult")

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local function Find(state, id)
	for _, key in ipairs({"items", "storage"}) do
		for index, item in pairs(state[key] or {}) do
			if (item.id == id) then
				return key, index, item
			end
		end
	end
end

local function Take(state, id)
	local list, index, item = Find(state, id)

	if (!list) then
		return false
	end

	if ((item.amount or 1) > 1) then
		item.amount = item.amount - 1
	else
		state[list][index] = nil
	end

	return true
end

hook.Add("OnNPCKilled", "nwScannerSalvage", function(npc)
	if (!IsValid(npc) or !NETWORK.scanner.classes[npc:GetClass()]) then
		return
	end

	if (npc.nwNoSalvage) then
		return
	end

	local item = NETWORK.item.New(NETWORK.scanner.wreck, 1)

	if (!item) then
		return
	end

	local entity = ents.Create("nw_item")

	if (!IsValid(entity)) then
		return
	end

	entity:SetPos(npc:GetPos() + Vector(0, 0, 8))
	entity:SetAngles(Angle(0, math.random(0, 360), 0))
	entity:SetItem(item)
	entity:Spawn()
	entity:Activate()

	local physics = entity:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:SetVelocity(VectorRand() * 40 + Vector(0, 0, 60))
	end

	hook.Run("NetworkScannerSalvaged", npc, entity)
end)

function NETWORK.scanner.BeginRepair(client)
	local state = NETWORK.inventory.GetState(client)

	if (!Find(state, NETWORK.scanner.kit)) then
		Notice(client, "repairNoKit")

		return false
	end

	if (client.nwRepair and client.nwRepair.until_ > CurTime()) then
		return false
	end

	client.nwRepair = {started = CurTime(), until_ = CurTime() + 120}

	net.Start("nwRepairOpen")
	net.Send(client)

	return true
end

net.Receive("nwRepairResult", function(_, client)
	local bSuccess = net.ReadBool()
	local session = client.nwRepair

	client.nwRepair = nil

	if (!session or session.until_ < CurTime()) then
		return
	end

	if (CurTime() - session.started < 2) then
		return
	end

	local state = NETWORK.inventory.GetState(client)

	if (!Find(state, NETWORK.scanner.wreck)) then
		return Notice(client, "repairNoWreck")
	end

	Take(state, NETWORK.scanner.kit)

	if (!bSuccess) then
		NETWORK.inventory.Sync(client)

		client:EmitSound("buttons/button10.wav", 60, 90)

		return Notice(client, "repairFailed")
	end

	Take(state, NETWORK.scanner.wreck)

	local item = NETWORK.item.New(NETWORK.scanner.repaired, 1)

	NETWORK.item.OnCreated(item, client, client:GetCharacter())

	if (NETWORK.inventory.Insert(state, item) > 0) then
		local entity = ents.Create("nw_item")

		if (IsValid(entity)) then
			entity:SetPos(client:GetPos() + client:GetAimVector() * 40 + Vector(0, 0, 20))
			entity:SetItem(item)
			entity:Spawn()
			entity:Activate()
		end
	end

	NETWORK.inventory.Sync(client)

	client:EmitSound("npc/scanner/scanner_photo1.wav", 65, 105)

	Notice(client, "repairDone")

	hook.Run("NetworkScannerRepaired", client)
end)
