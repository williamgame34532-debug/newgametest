-- Storages, server side: one window (cl_storage.lua) for everything that holds things next to
-- the player's own inventory - a container (nw_container), a body (sv_body.lua), another player
-- being searched. A storage is a source table:
--   key            unique string (who is looking at the same thing)
--   title, icon    the caption of the right half
--   cols, rows     its grid
--   Get(i), Set(i, cell)
--   GetTokens(), SetTokens(n)    optional: tokens kept in it
--   Valid(client)  still allowed to look (close, alive...)
--   Changed()      after every change (saving)
--   config         optional: the settings an admin may change (containers)
-- The client moves things: "g<n>" its own grid, "s<n>" the storage; "g0" / "s0" - the first free
-- cell on that side (double click).

util.AddNetworkString("nwStorageOpen")
util.AddNetworkString("nwStorageSync")
util.AddNetworkString("nwStorageMove")
util.AddNetworkString("nwStorageTokens")
util.AddNetworkString("nwStorageClose")

NW.storage = NW.storage or {}

local ST = NW.storage
local INV = NW.inventory
local I = NW.items

ST.viewers = ST.viewers or {}

local function Cells(source)
	local out = {}

	for index = 1, source.cols * source.rows do
		local cell = source.Get(index)

		if (cell) then
			out[#out + 1] = {index, cell.id, cell.data or {}}
		end
	end

	return util.TableToJSON(out)
end

local function Tokens(source)
	return source.GetTokens and source.GetTokens() or -1
end

-- everyone looking at this storage (a source or its key) gets its contents again
function ST.Refresh(source)
	local key = istable(source) and source.key or source

	for client in pairs(ST.viewers[key] or {}) do
		local own = IsValid(client) and client.nwStorage

		if (own and own.key == key) then
			net.Start("nwStorageSync")
				net.WriteString(Cells(own))
				net.WriteInt(Tokens(own), 32)
			net.Send(client)
		end
	end
end

function ST.Close(client, bQuiet)
	local source = client.nwStorage

	if (!source) then
		return
	end

	client.nwStorage = nil

	if (ST.viewers[source.key]) then
		ST.viewers[source.key][client] = nil
	end

	if (!bQuiet) then
		net.Start("nwStorageClose")
		net.Send(client)
	end

	if (source.OnClose) then
		source.OnClose(client)
	end
end

function ST.Open(client, source)
	ST.Close(client, true)

	client.nwStorage = source
	ST.viewers[source.key] = ST.viewers[source.key] or {}
	ST.viewers[source.key][client] = true

	net.Start("nwStorageOpen")
		net.WriteString(source.title or "Хранилище")
		net.WriteString(source.icon or "storage")
		net.WriteUInt(source.cols, 5)
		net.WriteUInt(source.rows, 5)
		net.WriteString(Cells(source))
		net.WriteInt(Tokens(source), 32)
		net.WriteEntity(source.entity or NULL)
		net.WriteString(source.config and client:IsAdmin() and util.TableToJSON(source.config()) or "")
	net.Send(client)

	INV.Sync(client)
end

-- refs: "g<n>" / "s<n>"
local function Parse(ref)
	local side, index = string.match(ref or "", "^([gs])(%d+)$")

	return side, tonumber(index)
end

local function Move(client, source, fromRef, toRef)
	local inventory = INV.Get(client)
	local fromSide, from = Parse(fromRef)
	local toSide, to = Parse(toRef)

	if (!fromSide or !toSide or from < 1) then
		return false
	end

	-- inside the own grid: the inventory's own rules
	if (fromSide == "g" and toSide == "g" and to > 0) then
		return INV.Move(client, "g" .. from, "g" .. to)
	end

	local function Get(side, index)
		if (side == "g") then
			return inventory.grid[index]
		end

		return source.Get(index)
	end

	local function Set(side, index, cell)
		if (side == "g") then
			inventory.grid[index] = cell
		else
			source.Set(index, cell)
		end
	end

	local function Fits(side, index, cell)
		if (side == "g") then
			return INV.FitsGrid(inventory, cell, index)
		end

		if (source.Fits) then
			return source.Fits(index, cell)
		end

		return index >= 1 and index <= source.cols * source.rows
	end

	local a = Get(fromSide, from)

	if (!a) then
		return false
	end

	-- "0": the first free cell on that side
	if (to == 0) then
		if (toSide == "g") then
			to = INV.FreeFor(inventory, a)
		else
			for index = 1, source.cols * source.rows do
				if (!source.Get(index)) then
					to = index

					break
				end
			end
		end

		if (!to or to == 0) then
			NW.Notify(client, "Нет места")

			return false
		end
	end

	if (fromSide == toSide and from == to) then
		return false
	end

	local b = Get(toSide, to)

	if (!Fits(toSide, to, a) or (b and !Fits(fromSide, from, b))) then
		return false
	end

	Set(toSide, to, a)
	Set(fromSide, from, b)

	return true
end

net.Receive("nwStorageMove", function(_, client)
	local fromRef, toRef = net.ReadString(), net.ReadString()
	local source = client.nwStorage

	if (!source or (client.nwStorageNext or 0) > CurTime()) then
		return
	end

	client.nwStorageNext = CurTime() + 0.08

	if (!source.Valid(client)) then
		return ST.Close(client)
	end

	if (Move(client, source, fromRef, toRef)) then
		client:EmitSound("network2/inv/inv_move" .. math.random(1, 3) .. ".wav", 55, math.random(96, 104), 0.6)
		INV.Changed(client)
		source.Changed()
		ST.Refresh(source)
	else
		INV.Sync(client)
		ST.Refresh(source)
	end
end)

-- tokens: true - put into the storage, false - take out
net.Receive("nwStorageTokens", function(_, client)
	local put = net.ReadBool()
	local amount = net.ReadUInt(24)
	local source = client.nwStorage

	if (!source or !source.GetTokens or amount < 1 or (client.nwStorageNext or 0) > CurTime()) then
		return
	end

	client.nwStorageNext = CurTime() + 0.2

	if (!source.Valid(client)) then
		return ST.Close(client)
	end

	local mine, there = NW.social.GetTokens(client), source.GetTokens()

	if (put) then
		amount = math.min(amount, mine)
		NW.social.SetTokens(client, mine - amount)
		source.SetTokens(there + amount)
	else
		amount = math.min(amount, there)
		source.SetTokens(there - amount)
		NW.social.SetTokens(client, mine + amount)
	end

	source.Changed()
	ST.Refresh(source)
end)

net.Receive("nwStorageClose", function(_, client)
	ST.Close(client, true)
end)

-- walked away, died...
timer.Create("nwStorageValid", 0.5, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local source = client.nwStorage

		if (source and (!client:Alive() or !source.Valid(client))) then
			ST.Close(client)
		end
	end
end)

hook.Add("PlayerDisconnected", "nwStorage", function(client)
	ST.Close(client, true)
end)

-- a searched player changed their own things: the searcher sees it
hook.Add("NWInventoryChanged", "nwStorage", function(client)
	ST.Refresh("player" .. client:EntIndex())
end)

-- the inventory of another player, while searching them (sv_body.lua)
function ST.PlayerSource(target, searcher)
	local inventory = INV.Get(target)

	return {
		key = "player" .. target:EntIndex(),
		title = NW.char.Knows(searcher, target) and target:Nick() or "Неизвестный",
		icon = "search",
		entity = target,
		cols = I.columns,
		rows = math.ceil(I.Capacity(inventory.equip) / I.columns),
		Get = function(index)
			if (index <= I.Capacity(inventory.equip)) then
				return inventory.grid[index]
			end
		end,
		Set = function(index, cell)
			if (index <= I.Capacity(inventory.equip)) then
				inventory.grid[index] = cell
			end
		end,
		Fits = function(index, cell)
			return INV.FitsGrid(inventory, cell, index)
		end,
		Valid = function(client)
			return IsValid(target) and target:Alive() and client:GetPos():DistToSqr(target:GetPos()) < 130 * 130
		end,
		Changed = function()
			INV.Changed(target)
		end
	}
end
