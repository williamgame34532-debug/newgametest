util.AddNetworkString("nwSearchOpen")
util.AddNetworkString("nwSearchClose")
util.AddNetworkString("nwSearchSync")
util.AddNetworkString("nwSearchTake")
util.AddNetworkString("nwSearchTakeAll")
util.AddNetworkString("nwSearchTokens")
util.AddNetworkString("nwSearchUntie")
util.AddNetworkString("nwSearchDrop")

NETWORK.search = NETWORK.search or {}

NETWORK.search.range = 110

NETWORK.search.requireHeld = false

NETWORK.search.actionDelay = 0.1

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone, ...)
end

local function Log(category, text, position)
	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add(category, text, position)
	end
end

function NETWORK.search.ResolveTarget(entity)
	if (IsValid(entity) and entity:GetClass() == "prop_ragdoll") then
		local owner = entity.nwPlayer

		if (IsValid(owner) and owner:IsPlayer() and
			owner.nwRagdollEntity == entity) then
			return owner
		end
	end

	return entity
end

function NETWORK.search.IsHelpless(target)
	return NETWORK.pmenu.IsHelpless(target)
end

local function CanReach(client, target)
	if (!IsValid(target)) then
		return false
	end

	if (!NETWORK.search.IsCorpse(target) and
		(!target:IsPlayer() or !target:HasCharacter())) then
		return false
	end

	local distance = client:GetPos():Distance(target:GetPos())

	if (target:IsPlayer() and IsValid(target.nwRagdollEntity)) then
		distance = math.min(distance,
			client:GetPos():Distance(target.nwRagdollEntity:GetPos()))
	end

	return distance <= NETWORK.search.range
end

function NETWORK.search.CanSearch(client, target)
	if (!CanReach(client, target)) then
		return false
	end

	if (NETWORK.search.IsCorpse(target)) then
		return true
	end

	if (NETWORK.pmenu.IsHelpless(target)) then
		return true
	end

	return NETWORK.factions.IsAlliance(client) and
		NETWORK.config.Get("allianceFrisk") == true
end

NETWORK.search.CanReach = CanReach

function NETWORK.search.IsCorpse(target)
	return IsValid(target) and !target:IsPlayer() and
		target:GetNWBool("nwCorpse", false)
end

local function BodyPos(target)
	if (target:IsPlayer() and IsValid(target.nwRagdollEntity)) then
		return target.nwRagdollEntity:GetPos()
	end

	return target:GetPos()
end

function NETWORK.search.Payload(target)
	if (NETWORK.search.IsCorpse(target)) then
		return {
			name = target:GetNWString("nwCorpseName", ""),
			items = target.nwLoot or {},
			equipped = {},
			storage = {},
			storageSlots = 0,
			tokens = 0,
			bTied = false,
			bCorpse = true
		}
	end

	local state = NETWORK.inventory.GetState(target)
	local container = NETWORK.inventory.ContainerOf(state)

	return {
		name = target:GetCharacterName(),
		items = state.items,
		equipped = state.equipped,
		storage = container and state.storage or {},
		storageSlots = container and NETWORK.item.GetStorageSlots(container) or 0,
		tokens = target:GetTokens(),
		bTied = NETWORK.restraint and NETWORK.restraint.IsTied(target) or false,
		bCorpse = false
	}
end

local function TheirState(target)
	if (NETWORK.search.IsCorpse(target)) then
		target.nwLoot = target.nwLoot or {}

		return {items = target.nwLoot, equipped = {}, storage = {}}, true
	end

	return NETWORK.inventory.GetState(target), false
end

local function SearcherName(client, target)
	if (target:IsPlayer() and client.GetRecognisedName) then
		return client:GetRecognisedName(target)
	end

	return client:GetCharacterName()
end

function NETWORK.search.Open(client, target)
	client.nwSearching = target

	if (IsValid(target) and target:IsPlayer()) then
		target:SetNWBool("nwSearched", true)

		Notice(target, "searchStarted", "warn", SearcherName(client, target))
	end

	if (NETWORK.rebels and NETWORK.rebels.OnSearch and IsValid(target) and target:IsPlayer()) then
		NETWORK.rebels.OnSearch(client, target)
	end

	net.Start("nwSearchOpen")
		net.WriteEntity(target)
		NETWORK.util.WriteTable(NETWORK.search.Payload(target))
	net.Send(client)

	client:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) ..
		".wav", 55, 110, 0.4)

	hook.Run("NetworkPlayerSearched", client, target)
end

function NETWORK.search.Close(client)
	if (IsValid(client.nwSearching) and client.nwSearching:IsPlayer()) then
		client.nwSearching:SetNWBool("nwSearched", false)
	end

	client.nwSearching = nil

	net.Start("nwSearchClose")
	net.Send(client)
end

function NETWORK.search.Sync(client)
	local target = client.nwSearching

	if (!IsValid(target)) then
		return
	end

	net.Start("nwSearchSync")
		NETWORK.util.WriteTable(NETWORK.search.Payload(target))
	net.Send(client)
end

local function Validate(client)
	local target = client.nwSearching

	if (!IsValid(target) or !CanReach(client, target) or
		!NETWORK.search.CanSearch(client, target)) then
		NETWORK.search.Close(client)

		return
	end

	return target
end

local function Throttled(client)
	if ((client.nwNextSearchAction or 0) > CurTime()) then
		return true
	end

	client.nwNextSearchAction = CurTime() + NETWORK.search.actionDelay

	return false
end

local function AfterChange(client, target, bCorpse)
	NETWORK.inventory.Sync(client)

	if (bCorpse) then
		target:SetNWBool("nwLooted", next(target.nwLoot or {}) == nil)
	else
		NETWORK.inventory.Sync(target)
	end

	NETWORK.search.Sync(client)
end

local function TakeOne(client, theirs, list, index, slot)
	local item = NETWORK.inventory.At(theirs, list, index, slot)

	if (!item) then
		return nil
	end

	if (NETWORK.issued and NETWORK.issued.Is(item) and
		!NETWORK.issued.CanHold(client)) then
		return nil, "issuedNoTake"
	end

	local mine = NETWORK.inventory.GetState(client)
	local copy = table.Copy(item)

	copy.x, copy.y = nil, nil

	if (NETWORK.inventory.Insert(mine, copy) > 0) then
		return nil, "deployNoRoom"
	end

	NETWORK.inventory.Put(theirs, list, index, slot, nil)

	return copy
end

net.Receive("nwSearchClose", function(_, client)
	if (IsValid(client.nwSearching)) then
		NETWORK.search.Close(client)
	end
end)

net.Receive("nwSearchTake", function(_, client)
	local list = net.ReadString()
	local index = net.ReadUInt(16)
	local slot = net.ReadString()
	local target = Validate(client)

	if (!target or Throttled(client)) then
		return
	end

	if (list != "items" and list != "equipped" and list != "storage") then
		return
	end

	local theirs, bCorpse = TheirState(target)
	local copy, reason = TakeOne(client, theirs, list, index, slot != "" and slot or nil)

	if (!copy) then
		if (reason) then
			NETWORK.chat.Notice(client, reason)
		end

		return
	end

	AfterChange(client, target, bCorpse)

	local name = NETWORK.item.GetName(copy)

	if (!bCorpse) then
		Notice(target, "searchTakenItem", "warn", name)
	end

	Log("search", string.format("%s забрал при обыске %s x%d у %s",
		NETWORK.log.Name(client), name, copy.amount or 1, NETWORK.log.Name(target)),
		client:GetPos())

	client:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav", 50, 115)

	hook.Run("NetworkSearchTook", client, target, copy)
end)

net.Receive("nwSearchTakeAll", function(_, client)
	local target = Validate(client)

	if (!target or Throttled(client)) then
		return
	end

	local theirs, bCorpse = TheirState(target)
	local indices = {}

	for index in pairs(theirs.items or {}) do
		indices[#indices + 1] = index
	end

	table.sort(indices)

	local taken = 0
	local names = {}

	for _, index in ipairs(indices) do
		local copy = TakeOne(client, theirs, "items", index, nil)

		if (copy) then
			taken = taken + 1
			names[#names + 1] = NETWORK.item.GetName(copy)

			hook.Run("NetworkSearchTook", client, target, copy)
		end
	end

	if (taken == 0) then
		return NETWORK.chat.Notice(client, "deployNoRoom")
	end

	AfterChange(client, target, bCorpse)

	Notice(client, "searchTakeAllDone", "good", taken)

	if (!bCorpse) then
		Notice(target, "searchTakenItem", "warn", table.concat(names, ", "))
	end

	Log("search", string.format("%s забрал при обыске всё (%d: %s) у %s",
		NETWORK.log.Name(client), taken, table.concat(names, ", "),
		NETWORK.log.Name(target)), client:GetPos())

	client:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav", 50, 105)
end)

net.Receive("nwSearchTokens", function(_, client)
	local amount = net.ReadUInt(32)
	local target = Validate(client)

	if (!target or Throttled(client) or !target:IsPlayer()) then
		return
	end

	amount = math.min(math.floor(amount), target:GetTokens())

	if (amount <= 0) then
		return
	end

	if (!NETWORK.currency.Take(target, amount)) then
		return
	end

	NETWORK.currency.Add(client, amount)

	Notice(client, "searchTokensTaken", "good", amount)
	Notice(target, "searchTokensLost", "bad", amount)

	Log("token", string.format("%s изъял при обыске %d токенов у %s",
		NETWORK.log.Name(client), amount, NETWORK.log.Name(target)), client:GetPos())

	client:EmitSound("physics/metal/chain_impact_soft" .. math.random(1, 3) .. ".wav",
		50, 140, 0.5)

	NETWORK.search.Sync(client)

	hook.Run("NetworkSearchTokens", client, target, amount)
end)

net.Receive("nwSearchUntie", function(_, client)
	local target = Validate(client)

	if (!target or !target:IsPlayer() or !NETWORK.restraint) then
		return
	end

	if (!NETWORK.factions.IsAlliance(client) and !client:IsAdmin()) then
		return
	end

	if (!NETWORK.restraint.IsTied(target)) then
		return
	end

	if (target:GetNWBool("nwCuffed", false)) then
		NETWORK.restraint.Uncuff(client, target)
	else
		NETWORK.restraint.Begin(client, target, true)
	end

	Log("search", string.format("%s развязал при обыске %s",
		NETWORK.log.Name(client), NETWORK.log.Name(target)), client:GetPos())

	timer.Simple((NETWORK.restraint.tieTime or 3) + 0.1, function()
		if (IsValid(client) and client.nwSearching == target) then
			NETWORK.search.Sync(client)
		end
	end)
end)

net.Receive("nwSearchDrop", function(_, client)
	local index = net.ReadUInt(16)
	local target = Validate(client)

	if (!target or Throttled(client)) then
		return
	end

	local theirs, bCorpse = TheirState(target)
	local item = NETWORK.inventory.At(theirs, "items", index, nil)

	if (!item) then
		return
	end

	if (NETWORK.issued and NETWORK.issued.Is(item) and
		!NETWORK.issued.CanHold(client)) then
		return NETWORK.chat.Notice(client, "issuedNoTake")
	end

	local position = BodyPos(target) + Vector(math.random(-14, 14), math.random(-14, 14), 10)
	local entity = NETWORK.item.Spawn(item.id, position, Angle(0, math.random(0, 360), 0),
		item.amount, item.data)

	if (!IsValid(entity)) then
		return
	end

	NETWORK.inventory.Put(theirs, "items", index, nil, nil)

	AfterChange(client, target, bCorpse)

	local name = NETWORK.item.GetName(item)

	Notice(client, "searchDropped", "info", name)

	if (!bCorpse) then
		Notice(target, "searchTakenItem", "warn", name)
	end

	Log("search", string.format("%s выбросил при обыске %s x%d у %s",
		NETWORK.log.Name(client), name, item.amount or 1, NETWORK.log.Name(target)),
		position)

	client:EmitSound("physics/cardboard/cardboard_box_impact_soft1.wav", 50, 110)

	hook.Run("NetworkSearchDropped", client, target, entity, item)
end)

timer.Create("nwSearchWatch", 0.5, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (!IsValid(client.nwSearching)) then
			continue
		end

		if (!client:Alive() or !CanReach(client, client.nwSearching)) then
			NETWORK.search.Close(client)
		end
	end
end)

hook.Add("PlayerDeath", "nwSearch", function(client)
	if (IsValid(client.nwSearching)) then
		NETWORK.search.Close(client)
	end
end)
