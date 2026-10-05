local PLUGIN = PLUGIN

PLUGIN.name = "Защита от glua-steal"
PLUGIN.author = "Network"
PLUGIN.description = "Водяные знаки в клиентском коде, пульс клиентской части и аудит хуков."
PLUGIN.version = "1.0"

PLUGIN.config = {
	enabled = true,

	audit = true
}

local function Hash(text)
	if (util.SHA256) then
		return util.SHA256(text)
	end

	return util.CRC(text)
end

local A = {Hash = Hash}

PLUGIN.api = A

if (SERVER) then
	util.AddNetworkString("nwStealMark")
	util.AddNetworkString("nwStealReport")

	local DATA = "network/watermarks.txt"
	local LOG = "network/antisteal_log.txt"

	local function Log(text)
		local line = os.date("%Y-%m-%d %H:%M:%S") .. "  " .. text

		file.CreateDir("network")
		file.Append(LOG, line .. "\n")

		NETWORK.util.PrintWarning("[antisteal] " .. text)

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("admin", "[antisteal] " .. text)
		end

		for _, admin in ipairs(player.GetAll()) do
			if (admin:IsAdmin()) then
				NETWORK.chat.Notice(admin, L("antistealAdmin", text))
			end
		end
	end

	function A.MakeMark(client)
		local raw = client:SteamID64() .. "|" .. os.time() .. "|" .. math.random(1, 2 ^ 30) ..
			"|" .. SysTime()

		return string.sub(Hash(raw) .. Hash(raw .. "#"), 1, 16)
	end

	function A.Remember(mark, client)
		file.CreateDir("network")
		file.Append(DATA, util.TableToJSON({
			mark = mark,
			steamID = client:SteamID(),
			steamID64 = client:SteamID64(),
			name = client:Nick(),
			time = os.date("%Y-%m-%d %H:%M:%S")
		}) .. "\n")
	end

	function A.Find(mark)
		local contents = file.Read(DATA, "DATA") or ""
		local found = {}

		for line in string.gmatch(contents, "[^\n]+") do
			local entry = util.JSONToTable(line)

			if (entry and entry.mark == mark) then
				found[#found + 1] = entry
			end
		end

		return found
	end

	function A.Issue(client)
		if (!IsValid(client) or client:IsBot()) then
			return
		end

		local mark = A.MakeMark(client)

		client.nwStealMark = mark

		A.Remember(mark, client)

		local chunk = string.format(
			"NETWORK.antisteal = NETWORK.antisteal or {}\nNETWORK.antisteal.mark = %q\n-- build %s\n",
			mark, mark)

		net.Start("nwStealMark")
			net.WriteString(chunk)
		net.Send(client)
	end

	function PLUGIN:PlayerInitialSpawn(client)
		timer.Simple(20, function()
			if (IsValid(client) and self.config.enabled) then
				A.Issue(client)
			end
		end)
	end

	net.Receive("nwStealReport", function(_, client)
		if ((client.nwStealReportAt or 0) > CurTime()) then
			return
		end

		client.nwStealReportAt = CurTime() + 30

		local list = net.ReadTable()

		if (!istable(list) or #list == 0) then
			return
		end

		local sources = {}

		for index = 1, math.min(#list, 8) do
			sources[#sources + 1] = string.sub(tostring(list[index]), 1, 96)
		end

		Log(string.format("%s (%s): посторонний код в хуках: %s", client:Nick(),
			client:SteamID(), table.concat(sources, ", ")))
	end)

	NETWORK.command.Register("leakfind", {
		description = "cmdLeakFind",
		usage = "/leakfind <метка>",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local mark = string.Trim(arguments[1] or "")

			if (mark == "") then
				return NETWORK.chat.Notice(client, L("leakUsage"))
			end

			local found = A.Find(mark)

			if (#found == 0) then
				return NETWORK.chat.Notice(client, L("leakNone", mark))
			end

			for _, entry in ipairs(found) do
				NETWORK.chat.Notice(client, L("leakFound", entry.name or "?", entry.steamID or "?",
					entry.time or "?"))
			end
		end
	})

	NETWORK.command.Register("antisteal", {
		description = "cmdAntiSteal",
		usage = "/antisteal",
		adminOnly = true,
		OnRun = function(command, client)
			local marked = 0

			for _, target in ipairs(player.GetAll()) do
				if (!target:IsBot() and target.nwStealMark) then
					marked = marked + 1
				end
			end

			local logSize = file.Size(LOG, "DATA") or 0

			NETWORK.chat.Notice(client, L("antistealStatus", marked, #player.GetAll(),
				math.Round(math.max(logSize, 0) / 1024, 1)))
		end
	})
else
	NETWORK.antisteal = NETWORK.antisteal or {}

	net.Receive("nwStealMark", function()
		local chunk = net.ReadString()

		RunStringEx(chunk, "network/mark")
	end)

	local reported = {}

	local function IsOwnSource(source)
		source = string.gsub(source or "", "^[@=]", "")

		return string.find(source, "^lua/") != nil or string.find(source, "^addons/") != nil or
			string.find(source, "^gamemodes/") != nil or string.find(source, "^network/") != nil or
			source == "" or source == "?" or source == "[C]"
	end

	function A.Audit()
		if (!PLUGIN.config.enabled or !PLUGIN.config.audit) then
			return
		end

		local suspicious = {}

		for event, hooks in pairs(hook.GetTable()) do
			for name, callback in pairs(hooks) do
				if (!isfunction(callback)) then
					continue
				end

				local info = debug.getinfo(callback, "S")
				local source = info and (info.source or info.short_src) or ""

				if (!IsOwnSource(source) and !reported[source]) then
					reported[source] = true
					suspicious[#suspicious + 1] = tostring(event) .. ":" .. tostring(name) .. " <- " .. source
				end
			end
		end

		if (#suspicious > 0) then
			net.Start("nwStealReport")
				net.WriteTable(suspicious)
			net.SendToServer()
		end
	end

	timer.Create("nwAntiStealAudit", 90, 0, A.Audit)
end
