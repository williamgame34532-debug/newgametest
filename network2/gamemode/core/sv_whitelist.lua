-- Whitelists: which factions a player may join where the profession NPC asks for one (sv_npc.lua).
-- Kept per Steam account (every character of the player) in sqlite (sv.db, nw_whitelist).
--   /whitelist <игрок> <фракция>     admins: allow the faction
--   /unwhitelist <игрок> <фракция>   admins: take it away
--   /whitelists [игрок]              what the player has (without a name - yourself)

NW.whitelist = NW.whitelist or {}

local WL = NW.whitelist
local C = NW.char

sql.Query([[CREATE TABLE IF NOT EXISTS nw_whitelist (
	steamid TEXT NOT NULL,
	faction TEXT NOT NULL,
	given INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (steamid, faction)
)]])

local cache = {}

function WL.List(client)
	local steamid = client:SteamID64() or ""

	if (!cache[steamid]) then
		local out = {}

		for _, row in ipairs(sql.Query("SELECT faction FROM nw_whitelist WHERE steamid = " .. sql.SQLStr(steamid)) or {}) do
			out[row.faction] = true
		end

		cache[steamid] = out
	end

	return cache[steamid]
end

function WL.Has(client, faction)
	return WL.List(client)[faction] == true
end

function WL.Set(client, faction, bAllowed)
	local steamid = client:SteamID64() or ""

	if (bAllowed) then
		sql.Query(string.format("INSERT OR REPLACE INTO nw_whitelist (steamid, faction, given) VALUES (%s, %s, %d)",
			sql.SQLStr(steamid), sql.SQLStr(faction), os.time()))
	else
		sql.Query(string.format("DELETE FROM nw_whitelist WHERE steamid = %s AND faction = %s", sql.SQLStr(steamid),
			sql.SQLStr(faction)))
	end

	cache[steamid] = nil
end

hook.Add("PlayerDisconnected", "nwWhitelist", function(client)
	cache[client:SteamID64() or ""] = nil
end)

local function Parse(client, rest, usage)
	local who, which = string.match(rest or "", "^(%S+)%s+(.+)$")
	local target = NW.FindPlayer(who)
	local faction = C.FindFaction(which)

	if (!target) then
		NW.Notify(client, "Игрок не найден. " .. usage)

		return
	end

	if (!faction) then
		NW.Notify(client, "Фракция не найдена. " .. usage)

		return
	end

	return target, faction
end

NW.AddChatCommand("whitelist", {admin = true, run = function(client, rest)
	local target, faction = Parse(client, rest, "/whitelist <имя> <фракция>")

	if (!target) then
		return
	end

	WL.Set(target, faction, true)

	local name = C.factions[faction].name

	NW.Notify(client, "Вайтлист выдан: " .. target:SteamName() .. " → " .. name)
	NW.Notify(target, "Вам открыт доступ к фракции: " .. name)
	MsgN(string.format("[Whitelist] %s выдал %s доступ к %s", client:SteamName(), target:SteamName(), faction))
end})

NW.AddChatCommand("unwhitelist", {admin = true, run = function(client, rest)
	local target, faction = Parse(client, rest, "/unwhitelist <имя> <фракция>")

	if (!target) then
		return
	end

	WL.Set(target, faction, false)
	NW.Notify(client, "Вайтлист снят: " .. target:SteamName() .. " → " .. C.factions[faction].name)
	MsgN(string.format("[Whitelist] %s снял у %s доступ к %s", client:SteamName(), target:SteamName(), faction))
end})

NW.AddChatCommand("whitelists", {run = function(client, rest)
	local target = client

	if (string.Trim(rest or "") != "") then
		if (!client:IsAdmin()) then
			return NW.Notify(client, "Смотреть чужие вайтлисты могут только админы")
		end

		target = NW.FindPlayer(rest)

		if (!target) then
			return NW.Notify(client, "Игрок не найден")
		end
	end

	local names = {}

	for faction in pairs(WL.List(target)) do
		names[#names + 1] = C.factions[faction] and C.factions[faction].name or faction
	end

	table.sort(names)
	NW.Notify(client, (target == client and "Ваши вайтлисты: " or (target:SteamName() .. ": ")) ..
		(#names > 0 and table.concat(names, ", ") or "нет"))
end})
