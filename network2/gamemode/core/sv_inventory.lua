-- Inventory, server. Every character has a grid (NW.items.gridSize cells) and the equipment
-- slots (NW.items.slots); both live in the character's data and are saved on every change.
-- A cell holds {id = item id, data = {}}. The client asks, the server decides:
--   nwInvMove   from, to          move / swap ("g<n>" grid cell, "e<slot>" equipment slot,
--                                 "c<n>_<k>" the k-th thing inside the opened package in cell n)
--   nwInvAction ref, action       "use" (Взаимодействовать; opens a package), "drop" (Выбросить)
-- The bag in the "Сумка" slot adds cells under the grid (NW.items.Capacity); a bag never lies in
-- those cells; when it leaves its slot, what lies in them moves into the free cells (or it stays
-- on if there is no room). A package (ration) opened once shows what is inside; things
-- are taken out by dragging, the empty package disappears.
--   nwInvTake   entity            take a world item (nw_item) after E
-- An item in a weapon slot gives its SWEP; taking it out takes the SWEP away.
-- Commands (superadmin): nw_testitems, nw_giveitem <id> [amount], nw_spawnitem <id>,
-- nw_clearinv.

util.AddNetworkString("nwInvSync")
util.AddNetworkString("nwInvMove")
util.AddNetworkString("nwInvAction")
util.AddNetworkString("nwInvTake")
util.AddNetworkString("nwItemOpen")

NW.inventory = NW.inventory or {}

local INV = NW.inventory
local I = NW.items

local SOUND = {
	pickup = {"network2/inv/handle_small_leather.wav", "network2/inv/handle_small_leather2.wav"},
	drop = {"network2/inv/drop_leather.wav"},
	weapon = {"network2/inv/metal_latch.wav", "network2/inv/belt_handle1.wav"},
	melee = {"network2/inv/draw_knife1.wav"},
	clothing = {"network2/inv/choreo_foley_jacket1.wav", "network2/inv/choreo_foley_jacket2.wav",
		"network2/inv/cloth_belt.wav", "network2/inv/cloth_belt2.wav"},
	unequip = {"network2/inv/belt_handle2.wav", "network2/inv/cloth_belt2.wav"}
}

local function Play(client, kind, level)
	local list = SOUND[kind]

	if (list) then
		client:EmitSound(list[math.random(#list)], level or 62, math.random(96, 104), 0.8)
	end
end

local function Notice(client, text)
	net.Start("nwChatNotice")
		net.WriteString(text)
	net.Send(client)
end

-- --------------------------------------------------------------- storage --
local function Fresh()
	return {grid = {}, equip = {}}
end

local function Serialize(inventory)
	local out = {grid = {}, equip = {}}

	for index = 1, I.maxSize do
		local cell = inventory.grid[index]

		if (cell) then
			out.grid[#out.grid + 1] = {index, cell.id, cell.data or {}}
		end
	end

	for _, slot in ipairs(I.slots) do
		local cell = inventory.equip[slot.id]

		if (cell) then
			out.equip[#out.equip + 1] = {slot.id, cell.id, cell.data or {}}
		end
	end

	return out
end

local Parse, Settle, SpawnWorldItem

-- the inventory of the character loaded right now (read from its data the first time)
function INV.Get(client)
	local character = client.nwCharacter

	if (client.nwInvOwner != character or !client.nwInv) then
		client.nwInvOwner = character
		client.nwInv = Parse(character)

		-- an old save can hold things past the cells there are now: into the free cells, and
		-- what does not fit falls on the ground
		local left = Settle(client.nwInv)

		if (#left > 0) then
			timer.Simple(2, function()
				if (IsValid(client) and client:Alive()) then
					for _, cell in ipairs(left) do
						SpawnWorldItem(client, cell)
					end
				end
			end)
		end
	end

	return client.nwInv
end

function INV.Sync(client)
	net.Start("nwInvSync")
		net.WriteString(util.TableToJSON(Serialize(INV.Get(client))))
	net.Send(client)
end

function INV.Changed(client)
	local character = client.nwCharacter

	if (character) then
		character.data = character.data or {}
		character.data.inv = Serialize(INV.Get(client))
		NW.char.SaveData(client)
	end

	INV.Sync(client)
	hook.Run("NWInventoryChanged", client)
end

Parse = function(character)
	local inventory = Fresh()
	local saved = character and character.data and character.data.inv

	if (istable(saved)) then
		for _, entry in ipairs(saved.grid or {}) do
			local index = tonumber(entry[1])

			if (index and index >= 1 and index <= I.maxSize and I.Get(entry[2])) then
				inventory.grid[index] = {id = entry[2], data = istable(entry[3]) and entry[3] or {}}
			end
		end

		for _, entry in ipairs(saved.equip or {}) do
			local item = I.Get(entry[2])

			if (I.slotByID[entry[1]] and item and item.slot == entry[1]) then
				inventory.equip[entry[1]] = {id = entry[2], data = istable(entry[3]) and entry[3] or {}}
			end
		end
	end

	return inventory
end

-- the character is set before its spawn, so the loadout already gives its equipped weapons
hook.Add("NWCharacterLoaded", "nwInventory", function(client)
	INV.Get(client)
	INV.Sync(client)
end)

hook.Add("NWEnterMenu", "nwInventory", function(client)
	timer.Simple(0, function()
		if (IsValid(client)) then
			INV.Sync(client)
		end
	end)
end)

-- --------------------------------------------------------------- equipment --
-- the clothes on the character: every managed bodygroup back to 0, then what is equipped, then
-- the bags that are carried (satchel, backpack)
function INV.Dress(client)
	if (!IsValid(client) or !client.nwCharacter) then
		return
	end

	local inventory = INV.Get(client)

	for _, name in ipairs(I.dressGroups) do
		local group = client:FindBodygroupByName(name)

		if (group >= 0) then
			client:SetBodygroup(group, 0)
		end
	end

	local function Wear(cell)
		local item = cell and I.Get(cell.id)

		if (item and item.wear) then
			local group, index = I.WearIndex(client, item.wear)

			if (group) then
				client:SetBodygroup(group, index)
			end
		end
	end

	for _, slot in ipairs(I.slots) do
		Wear(inventory.equip[slot.id])
	end
end

hook.Add("NWModelApplied", "nwInventory", function(client)
	INV.Dress(client)
end)

local function Equip(client, slot, cell, bQuiet)
	local item = I.Get(cell.id)

	if (!item) then
		return
	end

	if (item.weapon and client:Alive()) then
		client:Give(item.weapon)
	end

	if (item.wear) then
		INV.Dress(client)
	end

	if (!bQuiet) then
		Play(client, item.slot == "melee" and "melee" or (item.weapon and "weapon" or "clothing"))
	end

	hook.Run("NWItemEquipped", client, slot, cell, item)
end

local function Unequip(client, slot, cell, bQuiet)
	local item = I.Get(cell.id)

	if (!item) then
		return
	end

	if (item.weapon and client:HasWeapon(item.weapon)) then
		client:StripWeapon(item.weapon)
	end

	if (item.wear) then
		INV.Dress(client)
	end

	if (!bQuiet) then
		Play(client, "unequip")
	end

	hook.Run("NWItemUnequipped", client, slot, cell, item)
end

-- things put down on the floor around the player (no room for them anywhere)
local function DropAround(client, cells)
	local base = client:GetPos()

	for index, cell in ipairs(cells) do
		local item = I.Get(cell.id)
		local entity = item and ents.Create("nw_item")

		if (IsValid(entity)) then
			local angle = math.rad(index * 360 / math.max(#cells, 1))
			local spot = base + Vector(math.cos(angle) * 28, math.sin(angle) * 28, 24)
			local trace = util.TraceLine({start = base + Vector(0, 0, 24), endpos = spot, filter = client})

			entity:SetItem(cell.id, cell.data)
			entity:SetPos(trace.HitPos - (spot - base):GetNormalized() * 6)
			entity:SetAngles(Angle(0, math.random(0, 359), 0))
			entity:Spawn()
		end
	end
end

-- a change of faction (NW.char.SetFaction): every piece of clothing and every weapon comes off into
-- free cells; what does not fit is put down next to the player - now, or, when dead, on the next spawn
function INV.StripEquipment(client)
	local inventory = INV.Get(client)
	local left = {}

	for _, slot in ipairs(I.slots) do
		local cell = inventory.equip[slot.id]

		if (cell and (slot.group == "clothing" or slot.group == "weapon")) then
			inventory.equip[slot.id] = nil
			Unequip(client, slot, cell, true)

			local index = INV.FreeFor(inventory, cell)

			if (index) then
				inventory.grid[index] = cell
			else
				left[#left + 1] = cell
			end
		end
	end

	INV.Dress(client)
	INV.Changed(client)

	if (#left == 0) then
		return
	end

	if (client:Alive()) then
		DropAround(client, left)
		Notice(client, "Не поместилось в инвентарь — лежит рядом: " .. #left)
	else
		local character = client.nwCharacter

		if (character) then
			character.data = character.data or {}
			character.data.pendingDrop = character.data.pendingDrop or {}

			for _, cell in ipairs(left) do
				table.insert(character.data.pendingDrop, cell)
			end

			NW.char.SaveData(client)
		end
	end
end

-- what waited for the spawn falls out next to the player
hook.Add("PlayerSpawn", "nwPendingDrop", function(client)
	local character = client.nwCharacter
	local pending = character and character.data and character.data.pendingDrop

	if (!istable(pending) or #pending == 0) then
		return
	end

	character.data.pendingDrop = nil

	timer.Simple(0.5, function()
		if (IsValid(client) and client:Alive()) then
			DropAround(client, pending)
			Notice(client, "Ваши вещи лежат рядом: " .. #pending)
			NW.char.SaveData(client)
		end
	end)
end)

-- equipped weapons come back on every spawn
hook.Add("NWPlayerLoadout", "nwInventory", function(client)
	for _, slot in ipairs(I.slots) do
		local cell = INV.Get(client).equip[slot.id]
		local item = cell and I.Get(cell.id)

		if (item and item.weapon) then
			client:Give(item.weapon)
		end
	end
end)

-- -------------------------------------------------------------- references --
local function Resolve(ref)
	ref = tostring(ref or "")

	local index = tonumber(string.match(ref, "^g(%d+)$") or "")

	if (index and index >= 1 and index <= I.maxSize) then
		return "grid", index
	end

	local cellIndex, k = string.match(ref, "^c(%d+)_(%d+)$")

	if (cellIndex) then
		return "pack", {tonumber(cellIndex), tonumber(k)}
	end

	local slot = string.match(ref, "^e(%a+)$")

	if (slot and I.slotByID[slot]) then
		return "equip", slot
	end
end

local function Fits(cell, kind, key)
	if (!cell) then
		return true
	end

	local item = I.Get(cell.id)

	if (kind == "grid") then
		-- a bag never lies in the cells a bag gives
		return !(item and item.bag and key > I.gridSize)
	end

	return item != nil and item.slot == key
end

-- the thing inside an opened package: its cell and position
local function PackGet(inventory, key)
	local cell = inventory.grid[key[1]]
	local items = cell and cell.data and cell.data.open and cell.data.items

	if (istable(items) and isstring(items[key[2]]) and items[key[2]] != "" and I.Get(items[key[2]])) then
		return {id = items[key[2]], data = {}}, cell, items
	end
end

-- take it out; an empty package disappears
local function PackTake(inventory, key)
	local _, cell, items = PackGet(inventory, key)

	if (!cell) then
		return
	end

	items[key[2]] = ""

	for _, id in ipairs(items) do
		if (id != "") then
			return
		end
	end

	inventory.grid[key[1]] = nil
end

local function Capacity(inventory)
	return I.Capacity(inventory.equip)
end

-- nothing lies past the cells the inventory has now
local function Overflows(inventory)
	local capacity = Capacity(inventory)

	for index in pairs(inventory.grid) do
		if (index > capacity) then
			return true
		end
	end

	return false
end

local function FreeCell(inventory, limit)
	for index = 1, limit or Capacity(inventory) do
		if (!inventory.grid[index]) then
			return index
		end
	end
end

-- for the storages (sv_storage.lua): may this cell lie in grid cell index of this inventory? the
-- first free cell for it
function INV.FitsGrid(inventory, cell, index)
	return index >= 1 and index <= Capacity(inventory) and Fits(cell, "grid", index)
end

function INV.FreeFor(inventory, cell)
	local item = cell and I.Get(cell.id)

	for index = 1, item and item.bag and I.gridSize or Capacity(inventory) do
		if (!inventory.grid[index]) then
			return index
		end
	end
end

-- what lies past the cells the inventory has now (or a bag in the cells a bag gives) moves into
-- free cells; returns what did not fit
Settle = function(inventory)
	local capacity = Capacity(inventory)
	local loose, left = {}, {}

	for index, cell in pairs(inventory.grid) do
		if (index > capacity or !Fits(cell, "grid", index)) then
			loose[#loose + 1] = index
		end
	end

	table.sort(loose)

	for _, index in ipairs(loose) do
		local cell = inventory.grid[index]
		local item = I.Get(cell.id)

		inventory.grid[index] = nil

		local free = FreeCell(inventory, item and item.bag and I.gridSize or nil)

		if (free) then
			inventory.grid[free] = cell
		else
			left[#left + 1] = cell
		end
	end

	return left
end

-- after the bag slot changed: the things from the bag's cells go into the free ones; false (and
-- nothing changed) when there is no room for them
local function Repack(client, inventory)
	if (!Overflows(inventory)) then
		return true
	end

	local before = table.Copy(inventory.grid)

	if (#Settle(inventory) > 0) then
		inventory.grid = before
		Notice(client, "Нет места, чтобы выложить вещи из сумки")

		return false
	end

	Notice(client, "Вещи из сумки переложены в инвентарь")

	return true
end

function INV.Add(client, id, data)
	if (!I.Get(id)) then
		return false
	end

	local inventory = INV.Get(client)
	local index = FreeCell(inventory)

	if (!index) then
		return false
	end

	inventory.grid[index] = {id = id, data = data or {}}

	return true
end

-- move a -> b (swap when b is taken); equipment changes apply their effects
function INV.Move(client, fromRef, toRef)
	local inventory = INV.Get(client)
	local fromKind, fromKey = Resolve(fromRef)
	local toKind, toKey = Resolve(toRef)

	if (!fromKind or !toKind or (fromKind == toKind and fromKey == toKey)) then
		return false
	end

	-- out of an opened package: only into an empty cell or a fitting empty slot
	if (fromKind == "pack") then
		local a = PackGet(inventory, fromKey)

		if (!a or toKind == "pack" or inventory[toKind][toKey] or !Fits(a, toKind, toKey) or
			(toKind == "grid" and toKey > Capacity(inventory))) then
			return false
		end

		PackTake(inventory, fromKey)
		inventory[toKind][toKey] = a

		if (toKind == "equip") then
			Equip(client, toKey, a)
		end

		return true
	end

	if (toKind == "pack") then
		return false
	end

	local a = inventory[fromKind][fromKey]
	local b = inventory[toKind][toKey]

	if (!a or !Fits(a, toKind, toKey) or !Fits(b, fromKind, fromKey)) then
		return false
	end

	-- only into the cells there are
	if (toKind == "grid" and toKey > Capacity(inventory)) then
		return false
	end

	inventory[toKind][toKey] = a
	inventory[fromKind][fromKey] = b

	-- the bag slot changed: what was in its cells moves into the free ones
	if (!Repack(client, inventory)) then
		inventory[toKind][toKey] = b
		inventory[fromKind][fromKey] = a

		return false
	end

	-- what left and what came into the equipment
	if (fromKind == "equip") then
		Unequip(client, fromKey, a, b != nil)

		if (b) then
			Equip(client, fromKey, b)
		end
	end

	if (toKind == "equip") then
		if (b) then
			Unequip(client, toKey, b, true)
		end

		Equip(client, toKey, a)
	end

	return true
end

SpawnWorldItem = function(client, cell)
	local item = I.Get(cell.id)
	local eye = client:EyePos()
	local trace = util.TraceLine({start = eye, endpos = eye + client:GetAimVector() * 56, filter = client})
	local entity = ents.Create("nw_item")

	if (!IsValid(entity)) then
		return
	end

	entity:SetItem(cell.id, cell.data)
	entity:SetPos(trace.HitPos - client:GetAimVector() * 10)
	entity:SetAngles(Angle(0, client:EyeAngles().y + 90, 0))
	entity:Spawn()

	local physics = entity:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:SetVelocity(client:GetVelocity() + client:GetAimVector() * 60)
	end

	return entity
end

INV.SpawnWorldItem = SpawnWorldItem

-- ------------------------------------------------------------------ actions --
local function Use(client, kind, key)
	local inventory = INV.Get(client)
	local cell, item

	if (kind == "pack") then
		cell = PackGet(inventory, key)
	else
		cell = inventory[kind][key]
	end

	item = cell and I.Get(cell.id)

	if (!item) then
		return false
	end

	-- a package: open it (the client shows what is inside)
	if (item.contents and kind == "grid") then
		if (!cell.data.open) then
			cell.data.open = true
			cell.data.items = table.Copy(item.contents)
			client:EmitSound("network2/inv/cloth" .. math.random(1, 4) .. ".wav", 60, math.random(96, 104), 0.8)
		end

		return true
	end

	if (item.slot and kind == "pack") then
		return false
	end

	-- wearables and weapons: in or out of their slot
	if (item.slot) then
		if (kind == "equip") then
			local index = FreeCell(inventory, item.bag and I.gridSize or nil)

			if (!index) then
				Notice(client, "Нет места в инвентаре")

				return false
			end

			return INV.Move(client, "e" .. key, "g" .. index)
		end

		return INV.Move(client, "g" .. key, "e" .. item.slot)
	end

	if (!client:Alive()) then
		return false
	end

	if (item.heal) then
		if (client:Health() >= client:GetMaxHealth()) then
			Notice(client, "Вы и так здоровы")

			return false
		end

		client:SetHealth(math.min(client:GetMaxHealth(), client:Health() + item.heal))
	end

	if (item.hunger) then
		NW.needs.Add(client, "hunger", item.hunger)
	end

	if (item.thirst) then
		NW.needs.Add(client, "thirst", item.thirst)
	end

	if (item.OnUse and item.OnUse(client, cell) == false) then
		return false
	end

	if (item.useSound) then
		client:EmitSound(item.useSound, 60, math.random(96, 104), 0.8)
	end

	if (kind == "pack") then
		PackTake(inventory, key)
	else
		inventory[kind][key] = nil
	end

	-- what is left (an empty bottle): in its cell, or the first free one, or on the ground
	if (item.leaves and I.Get(item.leaves)) then
		local rest = {id = item.leaves, data = {}}

		if (kind == "grid" and !inventory.grid[key]) then
			inventory.grid[key] = rest
		elseif (!INV.Add(client, item.leaves)) then
			SpawnWorldItem(client, rest)
		end
	end

	return true
end

local function Drop(client, kind, key)
	local inventory = INV.Get(client)

	if (kind == "pack") then
		local cell = PackGet(inventory, key)

		if (!cell) then
			return false
		end

		PackTake(inventory, key)
		SpawnWorldItem(client, cell)
		Play(client, "drop", 60)

		return true
	end

	local cell = inventory[kind][key]

	if (!cell) then
		return false
	end

	inventory[kind][key] = nil

	-- the bag: what was in its cells moves into the free ones
	if (!Repack(client, inventory)) then
		inventory[kind][key] = cell

		return false
	end

	if (kind == "equip") then
		Unequip(client, key, cell, true)
	end

	SpawnWorldItem(client, cell)
	Play(client, "drop", 60)

	return true
end

local function Throttle(client)
	if ((client.nwInvNext or 0) > CurTime()) then
		return false
	end

	client.nwInvNext = CurTime() + 0.12

	return true
end

local function CanAct(client)
	return client:GetCharacterID() != 0 and !client:GetNW2Bool("nwInMenu", false)
end

-- putting on / taking off takes time (sh_progress.lua): what the ring says and how long
local TIMES = {clothing = 1.6, weapon = 1.0, gear = 1.3}
local ON = {clothing = "Одеваю", weapon = "Экипирую", gear = "Надеваю сумку"}
local OFF = {clothing = "Снимаю", weapon = "Убираю оружие", gear = "Снимаю сумку"}

local function Timing(fromRef, toRef)
	local fromKind, fromKey = Resolve(fromRef)
	local toKind, toKey = Resolve(toRef or "")
	local slot = (toKind == "equip" and I.slotByID[toKey]) or (fromKind == "equip" and I.slotByID[fromKey])

	if (!slot or (fromKind == "equip" and toKind == "equip")) then
		return
	end

	local text = toKind == "equip" and ON[slot.group] or OFF[slot.group]

	return text, TIMES[slot.group] or 1.2
end

-- runs fn now, or after the time with the ring when it puts on / takes off something
local function Timed(client, fromRef, toRef, fn)
	local text, seconds = Timing(fromRef, toRef)

	if (!text) then
		if (fn()) then
			INV.Changed(client)
		else
			INV.Sync(client)
		end

		return
	end

	-- one thing at a time
	if (NW.progress.Busy(client)) then
		INV.Sync(client)

		return
	end

	NW.progress.Start(client, text, seconds, function()
		if (CanAct(client) and fn()) then
			INV.Changed(client)
		else
			INV.Sync(client)
		end
	end)

	INV.Sync(client)
end

net.Receive("nwInvMove", function(_, client)
	local fromRef, toRef = net.ReadString(), net.ReadString()

	if (!Throttle(client) or !CanAct(client)) then
		return
	end

	Timed(client, fromRef, toRef, function()
		return INV.Move(client, fromRef, toRef)
	end)
end)

net.Receive("nwInvAction", function(_, client)
	local ref, action = net.ReadString(), net.ReadString()

	if (!Throttle(client) or !CanAct(client)) then
		return
	end

	local kind, key = Resolve(ref)

	if (!kind) then
		return
	end

	-- "use" on something with a slot is putting it on / taking it off
	local cell = kind != "pack" and INV.Get(client)[kind][key]
	local item = cell and I.Get(cell.id)
	local target

	if (action == "use" and item and item.slot) then
		target = kind == "equip" and "g0" or ("e" .. item.slot)
	elseif (action == "drop" and kind == "equip") then
		target = "g0"
	end

	Timed(client, ref, target, function()
		if (action == "use") then
			return Use(client, kind, key)
		elseif (action == "drop" and client:Alive()) then
			return Drop(client, kind, key)
		end

		return false
	end)
end)

-- E on a world item: the client shows the take panel; "Взять" comes back here
net.Receive("nwInvTake", function(_, client)
	local entity = net.ReadEntity()

	if (!Throttle(client) or !CanAct(client) or !client:Alive() or !IsValid(entity) or
		entity:GetClass() != "nw_item" or entity.nwTaken) then
		return
	end

	if (entity:GetPos():DistToSqr(client:EyePos()) > 150 * 150) then
		return
	end

	if (!INV.Add(client, entity:GetItemID(), entity.nwItemData)) then
		Notice(client, "Нет места в инвентаре")

		return
	end

	entity.nwTaken = true
	entity:Remove()
	Play(client, "pickup")
	INV.Changed(client)
end)

-- ---------------------------------------------------------------- commands --
local function Admin(client)
	return !IsValid(client) or client:IsSuperAdmin()
end

concommand.Add("nw_testitems", function(client)
	if (!IsValid(client) or !Admin(client) or client:GetCharacterID() == 0) then
		return
	end

	local given = 0

	for _, id in ipairs(I.testSet) do
		if (INV.Add(client, id)) then
			given = given + 1
		end
	end

	INV.Changed(client)
	Notice(client, "Выдано тестовых предметов: " .. given)
end)

concommand.Add("nw_giveitem", function(client, _, arguments)
	if (!IsValid(client) or !Admin(client) or client:GetCharacterID() == 0) then
		return
	end

	local id = arguments[1] or ""

	if (!I.Get(id)) then
		Notice(client, "Нет такого предмета: " .. id)

		return
	end

	for _ = 1, math.Clamp(tonumber(arguments[2] or "") or 1, 1, I.maxSize) do
		if (!INV.Add(client, id)) then
			break
		end
	end

	INV.Changed(client)
end)

concommand.Add("nw_spawnitem", function(client, _, arguments)
	if (!IsValid(client) or !Admin(client)) then
		return
	end

	local id = arguments[1] or ""

	if (!I.Get(id)) then
		Notice(client, "Нет такого предмета: " .. id)

		return
	end

	SpawnWorldItem(client, {id = id, data = {}})
end)

concommand.Add("nw_clearinv", function(client)
	if (!IsValid(client) or !Admin(client)) then
		return
	end

	local inventory = INV.Get(client)

	for _, slot in ipairs(I.slots) do
		if (inventory.equip[slot.id]) then
			Unequip(client, slot.id, inventory.equip[slot.id], true)
		end
	end

	inventory.grid = {}
	inventory.equip = {}
	INV.Changed(client)
end)

-- ------------------------------------------------------------- flashlight --
-- the HL2 flashlight only with a flashlight item (framework/items/tools/flashlight.lua)
function INV.Has(client, id)
	local inventory = INV.Get(client)

	for index = 1, I.maxSize do
		if (inventory.grid[index] and inventory.grid[index].id == id) then
			return true
		end
	end

	for _, cell in pairs(inventory.equip) do
		if (cell.id == id) then
			return true
		end
	end

	return false
end

hook.Add("PlayerSpawn", "nwFlashlight", function(client)
	client:AllowFlashlight(true)
end)

hook.Add("PlayerSwitchFlashlight", "nwFlashlight", function(client, bEnabled)
	if (bEnabled and (client:GetCharacterID() == 0 or !INV.Has(client, "flashlight"))) then
		return false
	end
end)

-- dropped or gone: the light goes out
timer.Create("nwFlashlight", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (client:FlashlightIsOn() and (client:GetCharacterID() == 0 or !INV.Has(client, "flashlight"))) then
			client:Flashlight(false)
		end
	end
end)

