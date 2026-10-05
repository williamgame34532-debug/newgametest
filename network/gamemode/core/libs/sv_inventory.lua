util.AddNetworkString("nwInventorySync")
util.AddNetworkString("nwInventoryAction")
util.AddNetworkString("nwAppearance")

function NETWORK.inventory.GetState(client)
	client.nwInventory = client.nwInventory or NETWORK.inventory.NewState()

	return client.nwInventory
end

NETWORK.weapon = NETWORK.weapon or {}

NETWORK.weapon.adminTools = NETWORK.weapon.adminTools or {
	weapon_physgun = true,
	gmod_tool = true,
	gmod_camera = true
}

function NETWORK.inventory.GetAllowedWeapons(client)
	local state = NETWORK.inventory.GetState(client)
	local character = client:GetCharacter()
	local wanted = {}

	if (NETWORK.weapon.hands) then
		wanted[NETWORK.weapon.hands] = "hands"
	end

	for _, item in pairs(state.equipped) do
		local base = NETWORK.item.Get(item.id)

		if (base and base.weaponClass and !base.bConsumeOnEquip) then
			wanted[base.weaponClass] = "item"
		end
	end

	-- КПК в руках есть, пока у игрока есть предмет КПК своей фракции.
	if (NETWORK.city and NETWORK.city.HasPDA and NETWORK.city.HasPDA(client)) then
		wanted[NETWORK.city.pdaWeapon or "weapon_nw_pda"] = "pda"
	end

	if (character) then
		local class = NETWORK.classes and NETWORK.classes.GetAssigned and
			NETWORK.classes.GetAssigned(character)

		if (class and class.faction == character:GetFaction()) then
			for _, weaponClass in ipairs(class.weapons or {}) do
				wanted[weaponClass] = "class"
			end
		end

		local faction = character:GetFactionTable()

		for _, weaponClass in ipairs(faction and faction.alwaysWeapons or {}) do
			wanted[weaponClass] = "faction"
		end
	end

	for weaponClass in pairs(NETWORK.weapon.always or {}) do
		wanted[weaponClass] = "always"
	end

	return wanted
end

function NETWORK.inventory.RefreshWeapons(client)
	if (!client:HasCharacter()) then
		return
	end

	local wanted = NETWORK.inventory.GetAllowedWeapons(client)
	local bAdmin = client:IsAdmin()

	for _, weapon in ipairs(client:GetWeapons()) do
		local class = weapon:GetClass()
		local bKeep = wanted[class] != nil or weapon.nwConsumable or weapon.nwKeep or
			(bAdmin and NETWORK.weapon.adminTools[class])

		if (!bKeep) then
			client:StripWeapon(class)
		end
	end

	for class in pairs(wanted) do
		if (!client:HasWeapon(class)) then
			local weapon = client:Give(class)

			if (IsValid(weapon)) then
				weapon.nwFromInventory = true
			end
		end
	end

	if (NETWORK.weapon.hands and !client:HasWeapon(NETWORK.weapon.hands)) then
		client:Give(NETWORK.weapon.hands)
	end
end

function NETWORK.inventory.RefreshAppearance(client)
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local state = NETWORK.inventory.GetState(client)
	local model = character:GetModel()
	local skin = 0
	local groups = {}

	local class = NETWORK.classes and NETWORK.classes.GetAssigned and
		NETWORK.classes.GetAssigned(character)

	if (class and class.faction != character:GetFaction()) then
		class = nil
	end

	local classModel = class and NETWORK.classes.ResolveModel and NETWORK.classes.ResolveModel(class)

	if (class and !(classModel and util.IsValidModel(classModel))) then
		class = nil
	end

	if (character.IsModelForced and character:IsModelForced()) then
		class = nil
	end

	if (class) then
		model = classModel

		for index, value in pairs(class.bodygroups or {}) do
			groups[tonumber(index)] = value
		end
	end

	for _, item in pairs(state.equipped) do
		local base = NETWORK.item.Get(item.id)

		if (!base) then
			continue
		end

		if (base.replaceModel and util.IsValidModel(base.replaceModel)) then
			model = base.replaceModel
		end

		if (base.skin) then
			skin = base.skin
		end

		for index, value in pairs(base.bodygroups or {}) do
			groups[tonumber(index)] = value
		end

		for index, value in pairs(istable(item.data) and item.data.bodygroups or {}) do
			groups[tonumber(index)] = tonumber(value) or 0
		end
	end

	if (client:GetNWBool("nwGasmask", false)) then
		local mask = NETWORK.item.Get("gasmask")

		for index, value in pairs(mask and mask.bodygroups or {}) do
			groups[tonumber(index)] = value
		end
	end

	if (!util.IsValidModel(model)) then
		model = NETWORK.player.fallbackModel or "models/humans/group01/male_02.mdl"
	end

	if (client:GetModel() != model) then
		local previous = client:GetModel()

		client:SetModel(model)

		if ((client:GetSequenceCount() or 0) < 2 and previous != model) then
			local base = character:GetModel()

			client:SetModel(util.IsValidModel(base) and base or NETWORK.player.fallbackModel)
			model = client:GetModel()
			class = nil
		end

		client:SetupHands()
	end

	local chosen = client.nwBodygroups or character:GetBodygroups()
	local chosenSkin = client.nwSkin or character:GetSkin()

	client.nwBodygroups = chosen
	client.nwSkin = chosenSkin

	for _, data in pairs(client:GetBodyGroups()) do
		local value = groups[data.id]

		if (value == nil and !class) then
			value = chosen[data.id]
		end

		client:SetBodygroup(data.id, math.Clamp(value or 0, 0,
			math.max(data.num - 1, 0)))
	end

	client:SetSkin(class and skin or (skin != 0 and skin or chosenSkin))

	if (client:GetNWString("nwCharacterModel", "") != model) then
		client:SetNWString("nwCharacterModel", model)
	end

	local signature = util.TableToJSON({client:GetModel(), client:GetSkin(), client:GetModelScale(), client:GetBodyGroups(), groups, chosen})
	if (client.nwAppearanceSignature == signature) then return end
	client.nwAppearanceSignature = signature
	timer.Create("nwAppearance" .. client:EntIndex(), 0.15, 1, function()
		if (IsValid(client)) then
			net.Start("nwAppearance")
			net.Send(client)
		end
	end)

	hook.Run("NetworkAppearanceChanged", client)
end

local function Guarded(client, label, fn, ...)
	local arguments = {...}
	local count = select("#", ...)
	local ok, err = xpcall(function()
		return fn(unpack(arguments, 1, count))
	end, debug.traceback)

	if (!ok) then
		local text = "[Network] Ошибка инвентаря (" .. label .. "): " .. tostring(err)

		if (IsValid(client)) then
			client.nwInventoryError = string.sub(tostring(err), 1, 300)
			client.nwInventoryErrorAt = CurTime()
		end

		ErrorNoHalt(text .. "\n")
	end

	return ok
end

NETWORK.inventory.Guarded = Guarded

function NETWORK.inventory.Sync(client)
	Guarded(client, "оружие", NETWORK.inventory.RefreshWeapons, client)
	Guarded(client, "внешность", NETWORK.inventory.RefreshAppearance, client)

	net.Start("nwInventorySync")
		NETWORK.util.WriteTable(NETWORK.inventory.GetState(client))
	net.Send(client)
end

function NETWORK.inventory.Insert(state, item, size)
	size = size or NETWORK.inventory.GetSize()

	local columns, rows = NETWORK.inventory.columns, NETWORK.inventory.rows
	local maximum = NETWORK.item.GetMaxStack(item)
	local left = item.amount or 1

	while (left > 0) do
		local stack = NETWORK.inventory.FindStack(state.items, item, size)

		if (!stack) then
			break
		end

		local existing = state.items[stack]
		local room = maximum - (existing.amount or 1)
		local moved = math.min(room, left)

		existing.amount = (existing.amount or 1) + moved
		left = left - moved
	end

	while (left > 0) do
		local slot = NETWORK.inventory.FindSpot(state.items, columns, rows, item)

		if (!slot) then
			break
		end

		local moved = math.min(maximum, left)

		state.items[slot] = {id = item.id, amount = moved, data = table.Copy(item.data or {})}
		left = left - moved
	end

	return left
end

function NETWORK.inventory.Give(client, id, amount, data)
	local state = NETWORK.inventory.GetState(client)
	local item = NETWORK.item.New(id, amount)

	if (!item) then
		return
	end

	if (istable(data)) then
		table.Merge(item.data, data)
	end

	NETWORK.item.OnCreated(item, client, client:GetCharacter())

	if (NETWORK.inventory.Insert(state, item) > 0) then
		return
	end

	NETWORK.inventory.Sync(client)

	return item
end

function NETWORK.inventory.Take(client, id, amount)
	amount = amount or 1

	local state = NETWORK.inventory.GetState(client)

	for _, list in ipairs({"items", "clothes"}) do
		for index, item in pairs(state[list] or {}) do
			if (istable(item) and item.id == id) then
				local have = item.amount or 1

				if (have > amount) then
					item.amount = have - amount

					NETWORK.inventory.Sync(client)

					return true
				elseif (have == amount) then
					NETWORK.inventory.Put(state, list, index, nil, nil)
					NETWORK.inventory.Sync(client)

					return true
				end
			end
		end
	end

	return false
end

function NETWORK.inventory.IsEmpty(client)
	local state = NETWORK.inventory.GetState(client)

	return table.Count(state.items) == 0 and table.Count(state.equipped) == 0 and
		table.Count(state.storage) == 0
end

function NETWORK.inventory.Setup(client)
	client.nwInventory = NETWORK.inventory.NewState()
	client.nwStarted = true

	for _, id in ipairs(NETWORK.inventory.starter) do
		NETWORK.inventory.Give(client, id)
	end

	local character = client:GetCharacter()
	local kit = character and NETWORK.creation.GetKit(character:GetKit())

	for _, id in ipairs(kit and kit.give or {}) do
		if (NETWORK.item.Get(id)) then
			NETWORK.inventory.Give(client, id)
		end
	end

	NETWORK.inventory.Sync(client)

	NETWORK.util.Print(string.format("%s получил стартовый набор (%d предметов)",
		client:SteamID(), table.Count(NETWORK.inventory.GetState(client).items)))
end

function NETWORK.inventory.Drop(client, list, index, slot)
	local state = NETWORK.inventory.GetState(client)
	local item = NETWORK.inventory.At(state, list, index, slot)

	if (!item) then
		return
	end

	if (list == "equipped" and NETWORK.item.IsContainer(item) and
		next(state.storage) != nil) then
		return
	end

	if (NETWORK.issued and NETWORK.issued.Is(item)) then
		NETWORK.notice.Send(client, "issuedNoDrop", "warn")

		return
	end

	local trace = client:GetEyeTrace()

	if (client:GetPos():Distance(trace.HitPos) > 110) then
		trace.HitPos = client:GetPos() + client:GetAimVector() * 50 + Vector(0, 0, 20)
	end

	local entity = ents.Create("nw_item")

	if (!IsValid(entity)) then
		return
	end

	entity:SetPos(trace.HitPos + Vector(0, 0, 6))
	entity:SetAngles(Angle(0, client:EyeAngles().y, 0))
	entity:SetItem(item)
	entity:Spawn()
	entity:Activate()

	NETWORK.inventory.Put(state, list, index, slot, nil)

	NETWORK.inventory.Sync(client)

	hook.Run("NetworkItemDropped", client, entity, item)
end

function NETWORK.inventory.Pickup(client, entity)
	do
		local pickupBase = NETWORK.item.Get(entity.nwItemID or
			(entity.GetItemID and entity:GetItemID()) or "")

		if (pickupBase and pickupBase.bNoInventory) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("itemNoInventory")
			net.Send(client)

			return
		end
	end

	if (!IsValid(entity) or entity:GetClass() != "nw_item") then
		return false
	end

	local item = entity:GetItem()

	if (!item) then
		return false
	end

	if (!NETWORK.restraint.CanAct(client)) then
		return false, "tieHands"
	end

	local base = NETWORK.item.Get(item.id)
	local factions = base and (base.pickupFactions or base.factions)

	if (!NETWORK.dialogue.FactionAllowed(client, factions)) then
		return false, "itemWrongFaction"
	end

	local state = NETWORK.inventory.GetState(client)

	if (NETWORK.zone.IsOutlands and NETWORK.zone.IsOutlands(entity:GetPos())) then
		item.data = item.data or {}
		item.data.sector = "outlands"
	end

	if (NETWORK.inventory.Insert(state, item) > 0) then
		return false, "errSlotsFull"
	end

	entity:Remove()

	NETWORK.inventory.Sync(client)

	hook.Run("NetworkItemPickedUp", client, item)

	return true
end

local actions = {}

actions.ping = function()
end

function actions.move(client, state, payload)
	local fromList = payload.fromList or "items"
	local toList = payload.toList or "items"
	local item = NETWORK.inventory.At(state, fromList, payload.fromIndex, payload.fromSlot)

	if (!item) then
		return
	end

	if (payload.rotate and NETWORK.item.CanRotate(item)) then
		item.rotated = !item.rotated or nil
	end

	local target = NETWORK.inventory.At(state, toList, payload.toIndex, payload.toSlot)

	if (target == item) then
		local columns, rows = NETWORK.inventory.columns, NETWORK.inventory.rows

		if (payload.rotate and !NETWORK.inventory.Fits(state[fromList] or state.items,
			columns, rows, item, payload.fromIndex, payload.fromIndex)) then
			item.rotated = !item.rotated or nil

			return "invNoRoom"
		end

		return
	end

	if (!target and (toList == "items" or toList == "storage")) then
		local columns = NETWORK.inventory.columns
		local rows = toList == "items" and NETWORK.inventory.rows or
			math.ceil(NETWORK.item.GetStorageSlots(
				NETWORK.inventory.ContainerOf(state) or {}) / columns)
		local overlapping, count = NETWORK.inventory.GetOverlapping(state[toList], columns,
			rows, item, payload.toIndex,
			fromList == toList and payload.fromIndex or nil)

		if (count == 1) then
			for owner in pairs(overlapping) do
				target = state[toList][owner]
				payload.toIndex = owner
			end
		elseif (count > 1) then
			return "invNotAllowed"
		end
	end

	if (target) then
		local targetBase = NETWORK.item.Get(target.id)
		local itemBase = NETWORK.item.Get(item.id)
		local bContainer = targetBase and
			(targetBase.contents or target.id == "ration_empty")
		local bFood = itemBase and itemBase.category == "food"

		if (bContainer and bFood and (item.amount or 1) >= 1) then
			target.data = target.data or {}

			if (target.id == "ration_empty") then
				local origin = target.data.origin

				if (!origin or !NETWORK.item.Get(origin)) then
					origin = "ration_basic"
				end

				target.id = origin
				target.data.origin = nil
				target.data.left = {}

				targetBase = NETWORK.item.Get(target.id) or targetBase
			elseif (!target.data.left) then
				target.data.left = {}

				for _, entry in ipairs(targetBase.contents or {}) do
					local id = istable(entry) and (entry[1] or entry.id) or entry
					local count = istable(entry) and (entry[2] or entry.amount or 1) or 1
					for _ = 1, count do target.data.left[#target.data.left + 1] = id end
				end
			end

			local capacity = targetBase.foodCapacity or 4

			if (targetBase and targetBase.contents) then
				local slots = 0

				for _, entry in ipairs(targetBase.contents) do
					slots = slots + (istable(entry) and
						math.max(math.Round(tonumber(entry[2] or
						entry.amount) or 1), 1) or 1)
				end

				capacity = math.max(capacity, slots)
			end

			if (#target.data.left >= capacity) then
				return "rationFull"
			end

			target.data.left[#target.data.left + 1] = item.id

			if ((item.amount or 1) > 1) then
				item.amount = item.amount - 1
			else
				NETWORK.inventory.Put(state, fromList, payload.fromIndex,
					payload.fromSlot, nil)
			end

			client:EmitSound("framework/inv/inv_move" ..
				math.random(3) .. ".wav", 50)

			return
		end
	end

	if (target and NETWORK.item.CanStack(target, item)) then
		local maximum = NETWORK.item.GetMaxStack(item)
		local room = maximum - (target.amount or 1)
		local moved = math.min(room, item.amount or 1)

		target.amount = (target.amount or 1) + moved

		if ((item.amount or 1) > moved) then
			item.amount = item.amount - moved
		else
			NETWORK.inventory.Put(state, fromList, payload.fromIndex, payload.fromSlot, nil)
		end

		return
	end

	if (!NETWORK.inventory.CanPlace(state, item, toList, payload.toIndex, payload.toSlot,
		fromList, payload.fromIndex)) then
		return "invNoRoom"
	end

	if (target and !NETWORK.inventory.CanPlace(state, target, fromList, payload.fromIndex,
		payload.fromSlot, toList, payload.toIndex)) then
		return "invNoRoom"
	end

	NETWORK.inventory.Put(state, toList, payload.toIndex, payload.toSlot, item)
	NETWORK.inventory.Put(state, fromList, payload.fromIndex, payload.fromSlot, target)
end

local function GridOf(state, list)
	local columns = NETWORK.inventory.columns

	if (list == "items") then
		return columns, NETWORK.inventory.rows
	end

	if (list == "storage") then
		local container = NETWORK.inventory.ContainerOf(state)

		if (!container) then
			return
		end

		return columns, math.ceil(NETWORK.item.GetStorageSlots(container) / columns)
	end
end

function NETWORK.inventory.SplitStack(state, payload)
	local fromList = payload.fromList or "items"
	local toList = payload.toList or fromList
	local item = NETWORK.inventory.At(state, fromList, payload.fromIndex, payload.fromSlot)

	if (!item) then
		return
	end

	local total = item.amount or 1

	if (total <= 1) then
		return "invNoStack"
	end

	local amount = math.Clamp(math.Round(tonumber(payload.amount) or 1), 1, total - 1)
	local columns, rows = GridOf(state, toList)

	if (!columns and toList != "storage") then
		toList = "items"
		columns, rows = GridOf(state, toList)
	end

	if (!columns) then
		return "invNotAllowed"
	end

	local piece = {
		id = item.id,
		amount = amount,
		data = table.Copy(item.data or {}),
		rotated = item.rotated
	}

	if (toList == "storage") then
		local container = NETWORK.inventory.ContainerOf(state)

		if (!container or !NETWORK.item.CanStore(container, piece)) then
			return "invNotAllowed"
		end
	end

	local index = tonumber(payload.toIndex)
	local list = state[toList]

	if (!list) then
		return "invNotAllowed"
	end

	if (index) then
		local target = list[index]

		if (target and target != item and NETWORK.item.CanStack(target, piece)) then
			local room = NETWORK.item.GetMaxStack(piece) - (target.amount or 1)

			amount = math.min(amount, room)

			if (amount <= 0) then
				return "invNoRoom"
			end

			target.amount = (target.amount or 1) + amount
			item.amount = total - amount

			return
		end

		if (target or !NETWORK.inventory.Fits(list, columns, rows, piece, index)) then
			return "invNoRoom"
		end
	else
		index = NETWORK.inventory.FindSpot(list, columns, rows, piece)

		if (!index) then
			return "invNoRoom"
		end
	end

	list[index] = piece
	item.amount = total - amount
end

function actions.split(client, state, payload)
	return NETWORK.inventory.SplitStack(state, payload)
end

function actions.drop(client, state, payload)
	NETWORK.inventory.Drop(client, payload.fromList or "items", payload.fromIndex,
		payload.fromSlot)
end

function NETWORK.inventory.Unpack(client, base)
	local state = NETWORK.inventory.GetState(client)
	local position = client:GetPos() + client:GetForward() * 26 + Vector(0, 0, 16)

	for _, entry in ipairs(base.contents or {}) do
		local id = entry
		local amount = 1

		if (istable(entry)) then
			id = entry[1] or entry.id
			amount = math.max(math.Round(tonumber(entry[2] or entry.amount) or 1), 1)
		end

		local item = NETWORK.item.New(id, amount)

		if (!item) then
			NETWORK.util.PrintWarning("Нет предмета для распаковки: " .. tostring(id))

			continue
		end

		NETWORK.item.OnCreated(item, client, client:GetCharacter())

		local left = NETWORK.inventory.Insert(state, item)

		if (left > 0) then
			NETWORK.item.Spawn(id, position, nil, left)
		end
	end

	if ((base.tokens or 0) > 0) then
		NETWORK.currency.Add(client, base.tokens)
	end
end

function actions.use(client, state, payload)
	local list = payload.fromList or "items"
	local item = NETWORK.inventory.At(state, list, payload.fromIndex, payload.fromSlot)

	if (!item) then
		return
	end

	local base = NETWORK.item.Get(item.id)

	if (!base) then
		return
	end

	local bConsume = false

	if (NETWORK.blogextras and base.useCooldown) then
		local left = NETWORK.blogextras.OnCooldown(client, base.id)

		if (left) then
			NETWORK.notice.Send(client, "itemCooldown", "warn", left)

			return
		end
	end

	if (!NETWORK.dialogue.FactionAllowed(client, base.factions)) then
		return "itemWrongFaction"
	end

	if (base.contents) then

		item.data = item.data or {}

		if (!item.data.left) then
			item.data.left = {}

			for _, entry in ipairs(base.contents) do
				item.data.left[#item.data.left + 1] =
					istable(entry) and (entry[1] or entry.id) or entry
			end

			if ((base.tokens or 0) > 0) then
				NETWORK.currency.Add(client, base.tokens)
			end
		end

		local nextID = table.remove(item.data.left, 1)

		if (nextID) then
			if (!NETWORK.inventory.Give(client, nextID, 1)) then
				NETWORK.item.Spawn(nextID, client:GetPos() +
					client:GetForward() * 26 + Vector(0, 0, 16))
			end

			client:EmitSound(base.useSound or
				"physics/cardboard/cardboard_box_impact_soft2.wav", 55)
		end

		if (#item.data.left == 0) then
			local empty = NETWORK.item.New("ration_empty", 1)

			if (empty) then
				empty.data.origin = item.id
				empty.rotated = item.rotated

				NETWORK.inventory.Put(state, list, payload.fromIndex,
					payload.fromSlot, empty)
			else
				NETWORK.inventory.Put(state, list, payload.fromIndex,
					payload.fromSlot, nil)
			end
		end

		NETWORK.inventory.Sync(client)

		do return end

		if (false) then
		NETWORK.inventory.Unpack(client, base)

		if (base.useSound) then
			client:EmitSound(base.useSound, 60, math.random(95, 105))
		end

		return
		end
	end

	if (base.weaponClass) then
		local slot = NETWORK.item.GetEquipSlot(item)

		if (!NETWORK.dialogue.FactionAllowed(client, base.factions)) then
			return "itemWrongFaction"
		end

		if (base.bConsumeOnEquip) then
			if ((item.amount or 1) > 1) then
				item.amount = item.amount - 1
			else
				NETWORK.inventory.Put(state, list, payload.fromIndex,
					payload.fromSlot, nil)
			end

			local weapon = client:Give(base.weaponClass)

			if (IsValid(weapon)) then

				weapon.nwConsumable = true
				client:SelectWeapon(base.weaponClass)
			end

			return
		end

		if (slot and !state.equipped[slot] and (item.amount or 1) == 1) then
			state.equipped[slot] = item

			NETWORK.inventory.Put(state, list, payload.fromIndex, payload.fromSlot, nil)

			client:SelectWeapon(base.weaponClass)
		end

		return
	end

	-- Предметы с эффектом лечения идут через NETWORK.medical (OnUse ниже).
	local bTreatment = NETWORK.medical and NETWORK.medical.IsTreatment and
		NETWORK.medical.IsTreatment(item.id)

	if ((base.healWound or 0) > 0 and !bTreatment) then
		local worst, amount

		for _, part in ipairs(NETWORK.wound.parts) do
			local value = NETWORK.wound.Get(client, part.id)

			if (value > 0 and (!amount or value > amount)) then
				worst = part.id
				amount = value
			end
		end

		if (worst) then
			NETWORK.wound.Heal(client, worst, base.healWound)

			bConsume = true
		else

			return "itemNoWounds"
		end
	end

	local hungerScale = 1

	if (base.category == "food" and NETWORK.spoil and NETWORK.spoil.OnConsume) then
		local refuse, scale = NETWORK.spoil.OnConsume(client, item, base)

		if (refuse) then
			return refuse
		end

		hungerScale = scale or 1
	end

	if ((base.hunger or 0) != 0) then
		NETWORK.needs.Add(client, "nwHunger", base.hunger * hungerScale)

		bConsume = true
	end

	if ((base.thirst or 0) != 0) then
		NETWORK.needs.Add(client, "nwThirst", base.thirst)

		bConsume = true
	end

	if (bConsume and NETWORK.needs and NETWORK.needs.PlayConsume) then
		NETWORK.needs.PlayConsume(client,
			(base.thirst or 0) > (base.hunger or 0))

		hook.Run("NetworkItemConsumed", client, base, item)
	end

	if (bConsume and base.trash) then
		if (!NETWORK.inventory.Give(client, base.trash, 1)) then
			NETWORK.item.Spawn(base.trash, client:GetPos() +
				client:GetForward() * 20 + Vector(0, 0, 12))
		end
	end

	if (NETWORK.combine and NETWORK.combine.TryUse(client, item.id)) then
		return
	end

	if (base.OnUse) then
		if (base:OnUse(client, item) == false) then
			return
		end

		bConsume = base.bConsumeOnUse or bConsume
	end

	if (base.useSound and (base.hunger or 0) == 0 and
		(base.thirst or 0) == 0) then
		client:EmitSound(base.useSound, 60, math.random(95, 105))
	end

	if (!bConsume) then
		return
	end

	if ((item.amount or 1) > 1) then
		item.amount = item.amount - 1
	else
		NETWORK.inventory.Put(state, list, payload.fromIndex, payload.fromSlot, nil)
	end
end

local MOVE_SOUNDS = {
	"framework/inv/inv_move1.wav",
	"framework/inv/inv_move2.wav",
	"framework/inv/inv_move3.wav"
}

local CLOTH_SOUNDS = {
	"framework/inv/cloth.wav",
	"framework/inv/cloth2.wav"
}

local function RunAction(client, action, payload)
	local callback = actions[action]

	if (!callback or !IsValid(client) or !client:HasCharacter()) then
		return
	end

	local state = NETWORK.inventory.GetState(client)

	if (istable(payload)) then
		payload.fromIndex = tonumber(payload.fromIndex) or payload.fromIndex
		payload.toIndex = tonumber(payload.toIndex) or payload.toIndex
	end

	local ok, key = xpcall(function()
		return callback(client, state, payload)
	end, debug.traceback)

	if (!ok) then
		client.nwInventoryError = string.sub(tostring(key), 1, 300)
		client.nwInventoryErrorAt = CurTime()

		ErrorNoHalt("[Network] Ошибка действия инвентаря «" .. tostring(action) ..
			"»: " .. tostring(key) .. "\n")

		key = "invActionFailed"
	end

	if (action == "move" and !key) then
		local bCloth = payload.toList == "equipped" or
			payload.fromList == "equipped"
		local sounds = bCloth and CLOTH_SOUNDS or MOVE_SOUNDS

		client:EmitSound(sounds[math.random(#sounds)], 55,
			math.random(96, 104), 0.7)
	end

	NETWORK.inventory.Sync(client)

	if (key) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(key)
		net.Send(client)
	end
end

NETWORK.inventory.RunAction = RunAction

net.Receive("nwInventoryAction", function(_, client)
	if (!NETWORK.restraint.CanAct(client)) then
		return NETWORK.chat.Notice(client, "tieHands")
	end

	if (!client:HasCharacter()) then
		return
	end

	local action = net.ReadString()
	local payload = NETWORK.util.ReadTable()

	local ready = client.nwNextInventory or 0

	client.nwNextInventory = math.max(ready, CurTime()) + 0.05

	if (ready > CurTime()) then
		local queued = client.nwInventoryQueue or 0

		if (queued >= 12) then
			return
		end

		client.nwInventoryQueue = queued + 1

		timer.Simple(ready - CurTime(), function()
			if (IsValid(client)) then
				client.nwInventoryQueue = math.max((client.nwInventoryQueue or 1) - 1, 0)

				RunAction(client, action, payload)
			end
		end)

		return
	end

	RunAction(client, action, payload)
end)

hook.Add("NetworkCharacterLoaded", "nwInventory", function(client, character)

	timer.Simple(0.4, function()
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		if (client:GetCharacter() != character) then
			return
		end

		if (client.nwRestore or client.nwStarted or
			!NETWORK.inventory.IsEmpty(client)) then
			return
		end

		NETWORK.inventory.Setup(client)
	end)
end)

concommand.Add("network_inv_diag_sv", function(client)
	if (!IsValid(client)) then
		return
	end

	local function Say(text)
		client:PrintMessage(HUD_PRINTCONSOLE, "[Network/сервер] " .. text)
	end

	local state = client.nwInventory
	local bTied = NETWORK.restraint and NETWORK.restraint.IsTied and
		NETWORK.restraint.IsTied(client) or false

	Say("сборка " .. tostring(NETWORK.buildTag) .. ", sv_inventory загружен, " ..
		"RunAction=" .. tostring(NETWORK.inventory.RunAction != nil) ..
		", RefreshAppearance=" .. tostring(NETWORK.inventory.RefreshAppearance != nil))
	Say("персонаж: " .. tostring(client:HasCharacter()) .. ", связан (nwTied): " ..
		tostring(bTied) .. ", руки: " .. tostring(NETWORK.weapon and NETWORK.weapon.hands))
	Say("сумка: " .. (state and (table.Count(state.items or {}) .. " вещей, " ..
		table.Count(state.equipped or {}) .. " надето, " ..
		table.Count(state.storage or {}) .. " в рюкзаке") or "состояние ещё не создано"))
	Say("модель: " .. client:GetModel() .. ", сетевая: " ..
		client:GetNWString("nwCharacterModel", "-"))

	if (client.nwInventoryError) then
		Say("последняя ошибка (" .. math.Round(CurTime() - (client.nwInventoryErrorAt or 0)) ..
			" с назад): " .. client.nwInventoryError)
	else
		Say("ошибок инвентаря не было")
	end

	NETWORK.inventory.Sync(client)
	Say("Sync отправлен")
end)

concommand.Add("network_item_give", function(client, _, arguments)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	local target = IsValid(client) and client or player.GetAll()[1]

	if (IsValid(target)) then
		NETWORK.inventory.Give(target, arguments[1], tonumber(arguments[2]))
	end
end)

concommand.Add("network_bodygroups", function(client)
	if (!IsValid(client)) then
		return
	end

	NETWORK.util.Print("Модель: " .. client:GetModel())
	NETWORK.util.Print("Скинов: " .. client:SkinCount())

	for _, data in pairs(client:GetBodyGroups()) do
		NETWORK.util.Print(string.format("  группа %d (%s): вариантов %d", data.id, data.name,
			data.num))
	end
end)

concommand.Add("network_item_spawn", function(client, _, arguments)
	if (!IsValid(client) or !client:IsAdmin()) then
		return
	end

	local trace = client:GetEyeTrace()

	NETWORK.item.Spawn(arguments[1] or "scrap", trace.HitPos + Vector(0, 0, 8))
end)

util.AddNetworkString("nwInventoryRepair")

net.Receive("nwInventoryRepair", function(_, client)
	if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
		return
	end

	if ((client.nwNextRepair or 0) > CurTime()) then
		return
	end

	client.nwNextRepair = CurTime() + 30

	local state = NETWORK.inventory.GetState(client)
	local position = client:GetPos() + client:GetForward() * 16 + Vector(0, 0, 16)
	local dropped = 0

	for _, list in ipairs({"items", "storage", "equipped", "clothes"}) do
		for index, item in pairs(state[list] or {}) do
			if (istable(item) and item.id) then
				NETWORK.item.Spawn(item.id, position + VectorRand() * 8, nil,
					item.amount, item.data)

				dropped = dropped + 1
			end

			state[list][index] = nil
		end
	end

	client.nwInventory = NETWORK.inventory.NewState()

	NETWORK.inventory.Sync(client)

	NETWORK.chat.Notice(client, L("helpRepairDone", dropped))

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("admin", string.format(
			"%s сбросил инвентарь (выпало предметов: %d)",
			NETWORK.log.Name(client), dropped), client:GetPos())
	end
end)

util.AddNetworkString("nwItemBodygroup")

net.Receive("nwItemBodygroup", function(_, client)
	local slot = net.ReadString()
	local group = net.ReadUInt(6)
	local delta = net.ReadInt(4)

	if (!client:HasCharacter()) then
		return
	end

	local state = NETWORK.inventory.GetState(client)
	local item = state.equipped[slot]

	if (!istable(item)) then
		return
	end

	local count = client:GetBodygroupCount(group)

	if (!count or count <= 1) then
		return NETWORK.notice.Send(client, "itemBodygroupNone", "warn")
	end

	item.data = item.data or {}
	item.data.bodygroups = item.data.bodygroups or {}

	local base = NETWORK.item.Get(item.id)
	local current = tonumber(item.data.bodygroups[group] or item.data.bodygroups[tostring(group)]) or
		(base and base.bodygroups and base.bodygroups[group]) or client:GetBodygroup(group) or 0

	item.data.bodygroups[tostring(group)] = (current + delta) % count

	NETWORK.inventory.RefreshAppearance(client)
	NETWORK.inventory.Sync(client)
	NETWORK.notice.Send(client, "itemBodygroupSet", "good", group, item.data.bodygroups[tostring(group)])
end)
