-- NPCs, server side (the config: sh_npc.lua, the windows: cl_npc.lua).
--   talking    E → the whole config goes to the player with their quest states for this NPC; the
--              lines are walked through on the client; buying, selling and quests come back here
--   buying     the price is taken (tokens and/or items from the grid), the thing goes into a free
--              cell; a limited stock goes down (and is saved)
--   selling    one such thing from the grid → the NPC's price in tokens
--   quests     the state per character (data.quests["<npc uid>:<quest id>"] = "active" / "done");
--              handing in takes the needed things and gives the reward
--   editing    admins send a whole new config (checked by NW.npc.Sanitize)
-- Every NPC on the map is saved to data/network2/npcs/<map>.json and comes back after a restart.

util.AddNetworkString("nwNpcOpen")
util.AddNetworkString("nwNpcState")
util.AddNetworkString("nwNpcAction")
util.AddNetworkString("nwNpcSave")

NW.npcs = NW.npcs or {}

local NS = NW.npcs
local NPC = NW.npc
local INV = NW.inventory
local I = NW.items
local DIR = "network2/npcs"
local RANGE = 160

local function Notify(client, text)
	NW.Notify(client, text)
end

-- ------------------------------------------------------------------ quests --
local function Quests(client)
	local character = client.nwCharacter

	if (!character) then
		return {}
	end

	character.data = character.data or {}
	character.data.quests = istable(character.data.quests) and character.data.quests or {}

	return character.data.quests
end

-- the quest states of this NPC for this player: {[quest id] = "active" / "done"}
local function States(client, entity)
	local out = {}
	local all = Quests(client)

	for _, quest in ipairs(entity.nwConfig.quests) do
		out[quest.id] = all[entity.nwUID .. ":" .. quest.id]
	end

	return out
end

local function Stock(entity)
	local out = {}

	for index, line in ipairs(entity.nwConfig.shop) do
		out[index] = line.stock
	end

	return out
end

local function SendState(client, entity)
	net.Start("nwNpcState")
		net.WriteEntity(entity)
		net.WriteString(util.TableToJSON({quests = States(client, entity), stock = Stock(entity)}))
	net.Send(client)
end

function NS.Talk(client, entity)
	local data = util.Compress(util.TableToJSON(entity.nwConfig))

	net.Start("nwNpcOpen")
		net.WriteEntity(entity)
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)
		net.WriteString(util.TableToJSON({quests = States(client, entity), stock = Stock(entity)}))
		net.WriteBool(client:IsAdmin())
	net.Send(client)
end

-- -------------------------------------------------------------- the grid --
-- take `count` of an item from the grid (false when there are not enough)
local function Take(inventory, id, count)
	if (NPC.Count(inventory.grid, id) < count) then
		return false
	end

	for index = I.maxSize, 1, -1 do
		if (count <= 0) then
			break
		end

		local cell = inventory.grid[index]

		if (cell and cell.id == id) then
			inventory.grid[index] = nil
			count = count - 1
		end
	end

	return true
end

-- a new thing into the first cell it may lie in (a bag never in the bag's cells)
local function Give(inventory, id)
	local cell = {id = id, data = {}}
	local index = INV.FreeFor(inventory, cell)

	if (!index) then
		return false
	end

	inventory.grid[index] = cell

	return true
end

local function FreeCells(inventory)
	local free = 0

	for index = 1, I.Capacity(inventory.equip) do
		if (!inventory.grid[index]) then
			free = free + 1
		end
	end

	return free
end

-- -------------------------------------------------------------- actions --
local ACTIONS = {}

function ACTIONS.buy(client, entity, arg)
	local line = entity.nwConfig.shop[tonumber(arg) or 0]

	if (!line or !I.Get(line.item)) then
		return
	end

	if (line.stock == 0) then
		return Notify(client, "Этого больше нет")
	end

	local inventory = INV.Get(client)
	local tokens = NW.social.GetTokens(client)

	if (tokens < line.price) then
		return Notify(client, "Не хватает токенов")
	end

	if (line.priceItem != "" and NPC.Count(inventory.grid, line.priceItem) < line.priceCount) then
		return Notify(client, "Не хватает: " .. I.Get(line.priceItem).name)
	end

	-- the price in items frees cells first
	local backup = table.Copy(inventory.grid)

	if (line.priceItem != "") then
		Take(inventory, line.priceItem, line.priceCount)
	end

	if (!Give(inventory, line.item)) then
		inventory.grid = backup

		return Notify(client, "Нет места в инвентаре")
	end

	if (line.price > 0) then
		NW.social.SetTokens(client, tokens - line.price)
	end

	if (line.stock > 0) then
		line.stock = line.stock - 1
		NS.Changed()
	end

	client:EmitSound("network2/inv/handle_small_leather.wav", 60)
	INV.Changed(client)
	Notify(client, "Куплено: " .. I.Get(line.item).name)

	return true
end

function ACTIONS.sell(client, entity, arg)
	local line = entity.nwConfig.shop[tonumber(arg) or 0]

	if (!line or line.sell <= 0) then
		return
	end

	local inventory = INV.Get(client)

	if (!Take(inventory, line.item, 1)) then
		return Notify(client, "У вас нет: " .. I.Get(line.item).name)
	end

	NW.social.SetTokens(client, NW.social.GetTokens(client) + line.sell)
	client:EmitSound("network2/inv/drop_leather.wav", 60)
	INV.Changed(client)
	Notify(client, string.format("Продано: %s (+%d ток.)", I.Get(line.item).name, line.sell))

	return true
end

function ACTIONS.accept(client, entity, arg)
	local quest = NPC.Quest(entity.nwConfig, arg)

	if (!quest) then
		return
	end

	local quests = Quests(client)
	local key = entity.nwUID .. ":" .. quest.id

	if (quests[key] == "active" or (quests[key] == "done" and !quest.repeatable)) then
		return
	end

	quests[key] = "active"
	NW.char.SaveData(client)
	Notify(client, "Новое задание: " .. quest.name)

	return true
end

function ACTIONS.turnin(client, entity, arg)
	local quest = NPC.Quest(entity.nwConfig, arg)

	if (!quest) then
		return
	end

	local quests = Quests(client)
	local key = entity.nwUID .. ":" .. quest.id

	if (quests[key] != "active") then
		return
	end

	local inventory = INV.Get(client)

	for _, need in ipairs(quest.need) do
		if (NPC.Count(inventory.grid, need.item) < need.count) then
			return Notify(client, "Не хватает: " .. I.Get(need.item).name)
		end
	end

	local backup = table.Copy(inventory.grid)

	for _, need in ipairs(quest.need) do
		Take(inventory, need.item, need.count)
	end

	-- the reward things need room
	local rewardCount = 0

	for _, reward in ipairs(quest.rewardItems) do
		rewardCount = rewardCount + reward.count
	end

	if (FreeCells(inventory) < rewardCount) then
		inventory.grid = backup

		return Notify(client, "Освободите место для награды")
	end

	for _, reward in ipairs(quest.rewardItems) do
		for _ = 1, reward.count do
			if (!Give(inventory, reward.item)) then
				inventory.grid = backup

				return Notify(client, "Освободите место для награды")
			end
		end
	end

	if (quest.rewardTokens > 0) then
		NW.social.SetTokens(client, NW.social.GetTokens(client) + quest.rewardTokens)
	end

	quests[key] = "done"
	INV.Changed(client)
	NW.char.SaveData(client)
	Notify(client, "Задание выполнено: " .. quest.name)

	return true
end

function ACTIONS.abandon(client, entity, arg)
	local quests = Quests(client)
	local key = entity.nwUID .. ":" .. tostring(arg)

	if (quests[key] == "active") then
		quests[key] = nil
		NW.char.SaveData(client)
		Notify(client, "Задание отменено")

		return true
	end
end

net.Receive("nwNpcAction", function(_, client)
	local entity = net.ReadEntity()
	local action = net.ReadString()
	local arg = net.ReadString()

	if ((client.nwNpcNext or 0) > CurTime()) then
		return
	end

	client.nwNpcNext = CurTime() + 0.25

	if (!IsValid(entity) or entity:GetClass() != "nw_npc" or !ACTIONS[action] or !client:Alive() or
		client:GetCharacterID() == 0 or client:GetPos():DistToSqr(entity:GetPos()) > RANGE * RANGE) then
		return
	end

	ACTIONS[action](client, entity, arg)
	SendState(client, entity)
end)

-- ---------------------------------------------------------------- editing --
net.Receive("nwNpcSave", function(_, client)
	local entity = net.ReadEntity()
	local length = net.ReadUInt(32)

	if (!client:IsAdmin() or !IsValid(entity) or entity:GetClass() != "nw_npc" or length > 200000) then
		return
	end

	local json = util.Decompress(net.ReadData(length) or "")
	local config = json and util.JSONToTable(json)

	if (!config) then
		return Notify(client, "Не удалось прочитать настройки")
	end

	entity.nwConfig = NPC.Sanitize(config)
	entity:Apply()
	NS.Changed()
	Notify(client, "NPC сохранён: " .. entity.nwConfig.name)
	NS.Talk(client, entity)
end)

-- ------------------------------------------------------------------ saving --
local loading = false

local function Path()
	return DIR .. "/" .. game.GetMap() .. ".json"
end

local function Save()
	local list = {}

	for _, entity in ipairs(ents.FindByClass("nw_npc")) do
		if (entity.nwConfig) then
			local pos, ang = entity:GetPos(), entity:GetAngles()

			list[#list + 1] = {uid = entity.nwUID, pos = {pos.x, pos.y, pos.z}, yaw = ang.y, config = entity.nwConfig}
		end
	end

	file.CreateDir(DIR)
	file.Write(Path(), util.TableToJSON(list, true))
end

function NS.Changed()
	if (!loading) then
		timer.Create("nwNpcsSave", 1, 1, Save)
	end
end

local function Load()
	loading = true

	for _, saved in ipairs(util.JSONToTable(file.Read(Path(), "DATA") or "") or {}) do
		local entity = ents.Create("nw_npc")

		if (IsValid(entity) and istable(saved.pos)) then
			-- the config is checked again (items may be gone since)
			entity.nwConfig = NPC.Sanitize(saved.config)
			entity.nwUID = tostring(saved.uid or "")
			entity:SetPos(Vector(saved.pos[1], saved.pos[2], saved.pos[3]))
			entity:SetAngles(Angle(0, tonumber(saved.yaw) or 0, 0))
			entity:Spawn()
			entity:Activate()
		end
	end

	loading = false
end

hook.Add("InitPostEntity", "nwNpcs", Load)
hook.Add("PostCleanupMap", "nwNpcs", Load)

hook.Add("ShutDown", "nwNpcs", function()
	Save()
	loading = true
end)

hook.Add("PhysgunDrop", "nwNpcs", function(_, entity)
	if (IsValid(entity) and entity:GetClass() == "nw_npc") then
		NS.Changed()
	end
end)

-- admins can move NPCs and containers with the physgun
hook.Add("PhysgunPickup", "nwNpcs", function(client, entity)
	local class = IsValid(entity) and entity:GetClass()

	if (class == "nw_npc" or class == "nw_container") then
		return client:IsAdmin()
	end
end)
