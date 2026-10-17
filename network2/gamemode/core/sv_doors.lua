-- Doors, server side (sh_doors.lua): the admin window (/door), buying, selling, locking, the
-- Alliance doors, saving.
--   nwDoorMenu   server → client   open the admin window for a door
--   nwDoorSave   client → server   an admin applies ("save", JSON), resets ("reset") or frees ("free") it

util.AddNetworkString("nwDoorMenu")
util.AddNetworkString("nwDoorSave")

local D = NW.doors
local SO = NW.social
local DIR = "network2/doors"
local limit = CreateConVar("nw_door_limit", "2", FCVAR_ARCHIVE, "Сколько дверей может купить один персонаж")
local sellRatio = CreateConVar("nw_door_sell", "0.5", FCVAR_ARCHIVE, "Какая доля цены возвращается при продаже")

local VARS = {
	{"nwDoorName", "String", ""}, {"nwDoorKind", "String", ""}, {"nwDoorMode", "String", ""},
	{"nwDoorPrice", "Int", 0}, {"nwDoorOwner", "Int", 0}, {"nwDoorOwnerName", "String", ""},
	{"nwDoorCapacity", "Int", 1}, {"nwDoorTenants", "String", ""}
}

local function Notify(client, text)
	NW.Notify(client, text)
end

local function Path()
	return DIR .. "/" .. game.GetMap() .. ".json"
end

-- ------------------------------------------------------------------ saving --
local function Read(door)
	local data = {}

	for _, var in ipairs(VARS) do
		data[var[1]] = door["GetNW2" .. var[2]](door, var[1], var[3])
	end

	return data
end

local function Write(door, data)
	for _, var in ipairs(VARS) do
		local value = data[var[1]]

		if (value == nil) then
			value = var[3]
		end

		door["SetNW2" .. var[2]](door, var[1], value)
	end
end

function D.Save()
	local list = {}

	for _, door in ipairs(ents.GetAll()) do
		if (D.IsDoor(door) and door:GetNW2String("nwDoorKind", "") != "" and door:MapCreationID() > 0) then
			list[tostring(door:MapCreationID())] = Read(door)
		end
	end

	file.CreateDir(DIR)
	file.Write(Path(), util.TableToJSON(list, true))
end

local function Changed()
	timer.Create("nwDoorsSave", 1, 1, D.Save)
end

function D.Load()
	for id, data in pairs(util.JSONToTable(file.Read(Path(), "DATA") or "") or {}) do
		local door = ents.GetMapCreatedEntity(tonumber(id) or -1)

		if (D.IsDoor(door) and istable(data)) then
			Write(door, data)
		end
	end
end

hook.Add("InitPostEntity", "nwDoors", function()
	timer.Simple(1, D.Load)
end)

hook.Add("PostCleanupMap", "nwDoors", function()
	timer.Simple(0.5, D.Load)
end)

-- the doors that go with this one: the same map name, close by (double doors)
function D.Group(door)
	local out = {door}
	local name = door:GetName()

	if (name and name != "") then
		for _, other in ipairs(ents.FindInSphere(door:GetPos(), 192)) do
			if (other != door and D.IsDoor(other) and other:GetName() == name) then
				out[#out + 1] = other
			end
		end
	end

	return out
end

local function Apply(door, data)
	for _, member in ipairs(D.Group(door)) do
		Write(member, data)
	end

	Changed()
end

-- the terminal (later) and the buying: give the door to a character (nil - free it)
function D.SetOwner(door, client)
	local data = Read(door)

	data.nwDoorOwner = IsValid(client) and client:GetCharacterID() or 0
	data.nwDoorOwnerName = IsValid(client) and client:Nick() or ""
	data.nwDoorTenants = data.nwDoorOwner != 0 and tostring(data.nwDoorOwner) or ""

	if (data.nwDoorOwner == 0) then
		for _, member in ipairs(D.Group(door)) do
			member:Fire("Unlock")
		end
	end

	Apply(door, data)
end

-- a tenant moves in (the terminal): the first one becomes the owner
function D.AddTenant(door, client)
	local tenants = D.Tenants(door)

	tenants[#tenants + 1] = client:GetCharacterID()

	local data = Read(door)

	if (data.nwDoorOwner == 0) then
		data.nwDoorOwner = client:GetCharacterID()
		data.nwDoorOwnerName = client:Nick()
	end

	data.nwDoorTenants = table.concat(tenants, ",")
	Apply(door, data)
end

-- a tenant moves out; the next one becomes the owner, the last one frees the door
function D.RemoveTenant(door, client)
	local id = client:GetCharacterID()
	local left = {}

	for _, tenant in ipairs(D.Tenants(door)) do
		if (tenant != id) then
			left[#left + 1] = tenant
		end
	end

	if (#left == 0) then
		return D.SetOwner(door, nil)
	end

	local data = Read(door)

	if (data.nwDoorOwner == id) then
		data.nwDoorOwner = left[1]
		data.nwDoorOwnerName = ""

		for _, other in ipairs(player.GetAll()) do
			if (other:GetCharacterID() == left[1]) then
				data.nwDoorOwnerName = other:Nick()
			end
		end
	end

	data.nwDoorTenants = table.concat(left, ",")
	Apply(door, data)
end

-- how many doors this character lives in or owns (a double door counts once)
function D.Owned(client)
	local seen, count = {}, 0

	for _, door in ipairs(ents.GetAll()) do
		if (D.IsDoor(door) and !seen[door] and D.IsOwner(client, door)) then
			count = count + 1

			for _, member in ipairs(D.Group(door)) do
				seen[member] = true
			end
		end
	end

	return count
end

-- ------------------------------------------------------------- the window --
NW.AddChatCommand("door", {admin = true, run = function(client)
	local door = D.Aimed(client, 192)

	if (!door) then
		return Notify(client, "Посмотрите на дверь")
	end

	net.Start("nwDoorMenu")
		net.WriteEntity(door)
	net.Send(client)
end})

net.Receive("nwDoorSave", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local door = net.ReadEntity()
	local action = net.ReadString()

	if (!D.IsDoor(door) or client:GetPos():DistToSqr(door:GetPos()) > 600 * 600) then
		return
	end

	if (action == "reset") then
		for _, member in ipairs(D.Group(door)) do
			Write(member, {})
			member:Fire("Unlock")
		end

		Changed()

		return Notify(client, "Настройки двери сброшены")
	elseif (action == "free") then
		D.SetOwner(door, nil)

		return Notify(client, "Дверь освобождена")
	elseif (action != "save") then
		return
	end

	local input = util.JSONToTable(net.ReadString() or "") or {}
	local name = string.Trim(string.gsub(tostring(input.name or ""), "[%c]", " "))
	local kind = D.kindByID[input.kind or ""] and input.kind or nil

	if (!kind) then
		return Notify(client, "Выберите вид двери")
	end

	if (name == "") then
		name = D.kindByID[kind].name
	end

	if (utf8.len(name) and utf8.len(name) > 40) then
		name = string.sub(name, 1, utf8.offset(name, 41) - 1)
	end

	local data = Read(door)

	data.nwDoorName = name
	data.nwDoorKind = kind
	data.nwDoorMode = kind == "apartment" and (input.mode == "terminal" and "terminal" or "buy") or
		(kind == "business" and "terminal" or "")
	-- a price: an apartment for sale, a business (paid at the terminal)
	data.nwDoorPrice = (data.nwDoorMode == "buy" or kind == "business") and
		math.Clamp(math.floor(tonumber(input.price) or 0), 0, D.maxPrice) or 0
	-- how many may live there: any apartment (bought: each buys in for the price, up to this many)
	data.nwDoorCapacity = kind == "apartment" and
		math.Clamp(math.floor(tonumber(input.capacity) or 1), 1, 8) or 1

	-- the Alliance's doors have no owner
	if (kind == "alliance") then
		data.nwDoorOwner, data.nwDoorOwnerName = 0, ""
	end

	Apply(door, data)
	Notify(client, "Дверь сохранена: " .. name)
end)

-- ------------------------------------------------------------ the players --
NW.AddChatCommand("doorbuy", {run = function(client)
	local door = D.Aimed(client)

	if (!door or client:GetCharacterID() == 0) then
		return Notify(client, "Посмотрите на дверь")
	end

	local mode = D.Mode(door)

	if (mode == "terminal") then
		return Notify(client, "Эту дверь выдают только через терминал Альянса")
	elseif (mode != "buy") then
		return Notify(client, "Эта дверь не продаётся")
	end

	if (D.IsOwner(client, door)) then
		return Notify(client, "Это уже ваша дверь")
	end

	-- taken: there may still be places (an apartment for several)
	local taken = D.Owner(door) != 0

	if (taken and #D.Tenants(door) >= D.Capacity(door)) then
		return Notify(client, "Эта дверь уже занята")
	end

	if (D.Owned(client) >= limit:GetInt()) then
		return Notify(client, "Больше дверей купить нельзя: " .. limit:GetInt())
	end

	local price = door:GetNW2Int("nwDoorPrice", 0)
	local tokens = SO.GetTokens(client)

	if (tokens < price) then
		return Notify(client, "Не хватает токенов: нужно " .. price)
	end

	SO.SetTokens(client, tokens - price)

	if (taken) then
		D.AddTenant(door, client)
	else
		D.SetOwner(door, client)
	end

	door:EmitSound("doors/door_latch3.wav", 60)
	Notify(client, "Куплено: " .. door:GetNW2String("nwDoorName", "дверь") .. " за " .. price .. " ток.")
end})

NW.AddChatCommand("doorsell", {run = function(client)
	local door = D.Aimed(client)

	if (!door or !D.IsOwner(client, door)) then
		return Notify(client, "Посмотрите на свою дверь")
	end

	-- given by the terminal: it is not sold back; a tenant just moves out
	local refund = D.Mode(door) == "buy" and math.floor(door:GetNW2Int("nwDoorPrice", 0) * sellRatio:GetFloat()) or 0

	D.RemoveTenant(door, client)
	SO.SetTokens(client, SO.GetTokens(client) + refund)
	Notify(client, refund > 0 and ("Дверь продана: +" .. refund .. " ток.") or "Вы отказались от двери")
end})

NW.AddChatCommand("doorlock", {run = function(client)
	local door = D.Aimed(client)

	if (!door) then
		return Notify(client, "Посмотрите на дверь")
	end

	local kind = door:GetNW2String("nwDoorKind", "")
	local allowed = D.IsOwner(client, door) or (kind == "alliance" and NW.zones.IsAlliance(client))

	if (!allowed) then
		return Notify(client, "Это не ваша дверь")
	end

	local locked = !door.nwLocked

	for _, member in ipairs(D.Group(door)) do
		member:Fire(locked and "Lock" or "Unlock")
		member.nwLocked = locked
	end

	door:EmitSound(locked and "doors/door_locked2.wav" or "doors/latchunlocked1.wav", 60)
	Notify(client, locked and "Заперто" or "Открыто")
end})

-- sliding and brush doors of the maps (func_door, func_door_rotating) often do not react to E at all
-- (no "Use Opens" flag: the engine never offers them for use, so PlayerUse never runs). For the
-- Alliance their doors open on E anyway: the key press is caught here, the door unlocked and toggled.
local BRUSH = {func_door = true, func_door_rotating = true}

hook.Add("KeyPress", "nwAllianceDoors", function(client, key)
	if (key != IN_USE or !client:Alive() or (client.nwDoorKey or 0) > CurTime()) then
		return
	end

	local door = D.Aimed(client, 110)

	if (!door or !BRUSH[door:GetClass()] or door:GetNW2String("nwDoorKind", "") != "alliance") then
		return
	end

	client.nwDoorKey = CurTime() + 0.6

	if (!NW.zones.IsAlliance(client)) then
		door:EmitSound("buttons/combine_button_locked.wav", 60)

		return
	end

	local locked = door:GetInternalVariable("m_bLocked") == true

	for _, member in ipairs(D.Group(door)) do
		member:Input("Unlock", client, client)
		member:Input("Toggle", client, client)
	end

	door:EmitSound("buttons/combine_button1.wav", 55)

	if (locked) then
		timer.Create("nwDoorRelock" .. door:EntIndex(), 0.3, 1, function()
			if (IsValid(door)) then
				for _, member in ipairs(D.Group(door)) do
					member:Input("Lock")
				end
			end
		end)
	end
end)

-- the Alliance's doors open only for the Alliance - and for them even when locked: the lock opens for
-- the moment of the use and closes again, so for everyone else the door stays locked
hook.Add("PlayerUse", "nwDoors", function(client, entity)
	if (!D.IsDoor(entity) or entity:GetNW2String("nwDoorKind", "") != "alliance") then
		return
	end

	-- brush doors: handled on the key press above
	if (BRUSH[entity:GetClass()]) then
		return false
	end

	if (!NW.zones.IsAlliance(client)) then
		if ((client.nwDoorDenied or 0) < CurTime()) then
			client.nwDoorDenied = CurTime() + 1
			entity:EmitSound("buttons/combine_button_locked.wav", 60)
		end

		return false
	end

	if (entity:GetInternalVariable("m_bLocked") == true) then
		for _, member in ipairs(D.Group(entity)) do
			member:Input("Unlock", client, client)
		end

		if ((client.nwDoorGranted or 0) < CurTime()) then
			client.nwDoorGranted = CurTime() + 1
			entity:EmitSound("buttons/combine_button1.wav", 55)
		end

		timer.Create("nwDoorRelock" .. entity:EntIndex(), 0.3, 1, function()
			if (IsValid(entity)) then
				for _, member in ipairs(D.Group(entity)) do
					member:Input("Lock")
				end
			end
		end)
	end
end)

-- ------------------------------------------------------- knock / kick down --
-- Hold E on a door: the wheel (cl_doors.lua). Постучать - anyone; Выбить дверь - the Alliance, a
-- locked door: the unit kicks (kickdoorbaton, on the Civil Protection models), the lock breaks, the
-- door swings open.
util.AddNetworkString("nwDoorAction")
util.AddNetworkString("nwDoorKick")

local function Locked(door)
	return door.nwLocked == true or door:GetInternalVariable("m_bLocked") == true
end

net.Receive("nwDoorAction", function(_, client)
	local action = net.ReadString()
	local door = net.ReadEntity()

	if ((client.nwDoorAct or 0) > CurTime() or !D.IsDoor(door) or !client:Alive() or
		(NW.Incapable and NW.Incapable(client)) or client:GetPos():DistToSqr(door:GetPos()) > 140 * 140) then
		return
	end

	client.nwDoorAct = CurTime() + 1.5

	if (action == "knock") then
		NW.SayMe(client, "стучит в дверь")
		client:SetAnimation(PLAYER_ATTACK1)

		for i = 0, 2 do
			timer.Simple(i * 0.28, function()
				if (IsValid(door)) then
					door:EmitSound("physics/wood/wood_crate_impact_hard" .. math.random(2, 3) .. ".wav", 65, math.random(95, 105))
				end
			end)
		end
	elseif (action == "kick") then
		if (!NW.zones.IsAlliance(client)) then
			return
		end

		if (!Locked(door)) then
			return Notify(client, "Дверь не заперта")
		end

		client.nwDoorAct = CurTime() + 3

		net.Start("nwDoorKick")
			net.WriteEntity(client)
		net.SendPVS(client:GetPos())

		NW.SayMe(client, "выбивает дверь ногой")

		timer.Simple(0.55, function()
			if (!IsValid(door) or !IsValid(client)) then
				return
			end

			door:EmitSound("physics/wood/wood_furniture_break" .. math.random(1, 2) .. ".wav", 75)
			door:EmitSound("doors/heavy_metal_stop1.wav", 70)

			local lock = door.nwCombineLock

			if (IsValid(lock) and lock:GetLocked()) then
				lock:SetState(false)
			end

			for _, member in ipairs(D.Group(door)) do
				member.nwLocked = false
				member:Fire("Unlock")
				member:Fire("Open")
			end

			util.ScreenShake(door:GetPos(), 3, 8, 0.4, 300)

			if (NW.skills) then
				NW.skills.Add(client, "strength", 6)
			end
		end)
	end
end)
