-- Main menu, server side. A player who joins is "in the menu": not spawned (silently dead, no
-- respawn on click), the client flies a camera through the menu points of the map. A character
-- (sv_character.lua) takes him into the world.
--
-- Camera points (superadmins in the game; saved per map in data/network2/menu_<map>.json):
--   main menu:            nw_menu_point_set / _add / _remove <n> / _clear / _list
--   character creation:   nw_charcam_point_set / _add / _remove <n> / _clear / _list
--     _set  - one fixed point (your current view, with a slight drift)
--     _add  - your current view as the next point; 2+ points: a smooth endless flight
--   nw_menu_speed <units/s>   flight speed (default 70)
--   nw_community_url <url>    what "Сообщество" opens
-- Players: nw_menu goes back to the menu (the character is saved first).

util.AddNetworkString("nwMenuReady")
util.AddNetworkString("nwMenuPoints")
util.AddNetworkString("nwMenuOpen")

NW.menu = NW.menu or {}

local M = NW.menu

M.sets = M.sets or {main = {}, char = {}}

local function Path()
	return "network2/menu_" .. game.GetMap() .. ".json"
end

local function ReadPoints(list)
	local out = {}

	for _, point in ipairs(list or {}) do
		out[#out + 1] = {pos = Vector(point.pos[1], point.pos[2], point.pos[3]), ang = Angle(point.ang[1], point.ang[2], 0)}
	end

	return out
end

local function WritePoints(list)
	local out = {}

	for _, point in ipairs(list) do
		out[#out + 1] = {pos = {point.pos.x, point.pos.y, point.pos.z}, ang = {point.ang.p, point.ang.y}}
	end

	return out
end

local function Load()
	local raw = file.Read(Path(), "DATA")
	local data = raw and util.JSONToTable(raw) or {}

	-- older files are a plain list of main menu points
	if (data[1]) then
		data = {main = data}
	end

	M.sets = {main = ReadPoints(data.main), char = ReadPoints(data.char)}
end

local function Save()
	file.CreateDir("network2")
	file.Write(Path(), util.TableToJSON({main = WritePoints(M.sets.main), char = WritePoints(M.sets.char)}, true))
end

local function Send(target)
	net.Start("nwMenuPoints")
		for _, set in ipairs({"main", "char"}) do
			net.WriteUInt(#M.sets[set], 8)

			for _, point in ipairs(M.sets[set]) do
				net.WriteVector(point.pos)
				net.WriteAngle(point.ang)
			end
		end

	if (target) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

hook.Add("Initialize", "nwMenu", Load)

local function Allowed(client)
	if (!IsValid(client) or client:IsSuperAdmin()) then
		return true
	end

	client:ChatPrint("[Network] Точки камеры может менять только суперадмин.")

	return false
end

local function Reply(client, text)
	if (IsValid(client)) then
		client:ChatPrint("[Network] " .. text)
	else
		print("[Network] " .. text)
	end
end

local function View(client)
	local ang = client:EyeAngles()

	return {pos = client:EyePos(), ang = Angle(ang.p, ang.y, 0)}
end

for prefix, set in pairs({nw_menu_point = "main", nw_charcam_point = "char"}) do
	local label = set == "main" and "главного меню" or "создания персонажа"

	local function Changed(client, text)
		Save()
		Send()
		Reply(client, text .. " Точек камеры " .. label .. ": " .. #M.sets[set] .. ".")
	end

	concommand.Add(prefix .. "_set", function(client)
		if (!IsValid(client)) then
			return Reply(client, "Встаньте в нужное место в игре и выполните команду там.")
		end

		if (Allowed(client)) then
			M.sets[set] = {View(client)}
			Changed(client, "Камера " .. label .. " — ваш текущий вид.")
		end
	end)

	concommand.Add(prefix .. "_add", function(client)
		if (!IsValid(client)) then
			return Reply(client, "Встаньте в нужное место в игре и выполните команду там.")
		end

		if (Allowed(client)) then
			table.insert(M.sets[set], View(client))
			Changed(client, "Точка " .. #M.sets[set] .. " добавлена.")
		end
	end)

	concommand.Add(prefix .. "_remove", function(client, _, arguments)
		local index = tonumber(arguments[1] or "")

		if (Allowed(client) and index and M.sets[set][index]) then
			table.remove(M.sets[set], index)
			Changed(client, "Точка " .. index .. " удалена.")
		end
	end)

	concommand.Add(prefix .. "_clear", function(client)
		if (Allowed(client)) then
			M.sets[set] = {}
			Changed(client, "Точки удалены.")
		end
	end)

	concommand.Add(prefix .. "_list", function(client)
		for index, point in ipairs(M.sets[set]) do
			Reply(client, string.format("%d: %s  %s", index, tostring(point.pos), tostring(point.ang)))
		end

		Reply(client, #M.sets[set] .. " точек (" .. label .. ")")
	end)
end

-- --------------------------------------------------------------- state --
function M.Enter(client)
	hook.Run("NWEnterMenu", client)

	client:SetNW2Bool("nwInMenu", true)

	if (client:Alive()) then
		client:KillSilent()
	end

	NW.char.SendList(client)

	net.Start("nwMenuOpen")
	net.Send(client)
end

hook.Add("PlayerInitialSpawn", "nwMenu", function(client)
	client:SetNW2Bool("nwInMenu", true)
end)

hook.Add("PlayerSpawn", "nwMenu", function(client)
	if (client:GetNW2Bool("nwInMenu", false)) then
		timer.Simple(0, function()
			if (IsValid(client) and client:GetNW2Bool("nwInMenu", false) and client:Alive()) then
				client:KillSilent()
			end
		end)
	end
end)

hook.Add("PlayerDeathThink", "nwMenu", function(client)
	if (client:GetNW2Bool("nwInMenu", false)) then
		return false
	end
end)

net.Receive("nwMenuReady", function(_, client)
	if (client.nwMenuReady) then
		return
	end

	client.nwMenuReady = true

	Send(client)
	NW.char.SendList(client)

	if (client:GetNW2Bool("nwInMenu", false)) then
		net.Start("nwMenuOpen")
		net.Send(client)
	end
end)

concommand.Add("nw_menu", function(client)
	if (IsValid(client) and !client:GetNW2Bool("nwInMenu", false)) then
		M.Enter(client)
	end
end)
