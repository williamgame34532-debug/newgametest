util.AddNetworkString("nwDispLabel")

NETWORK.displabel = NETWORK.displabel or {}

local D = NETWORK.displabel

D.defaultTime = 180
D.titleMax = 32
D.textMax = 120

function D.Recipients()
	local list = {}

	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter() and NETWORK.factions.IsAlliance(client)) then
			list[#list + 1] = client
		end
	end

	return list
end

function D.Show(title, text, duration, sender)
	title = NETWORK.util.Sanitise(title or "", D.titleMax)
	text = NETWORK.util.Sanitise(text or "", D.textMax)
	duration = math.Clamp(tonumber(duration) or D.defaultTime, 3, 3600)

	local list = D.Recipients()

	net.Start("nwDispLabel")
		net.WriteString(title)
		net.WriteString(text)
		net.WriteFloat(duration)
	net.Send(list)

	if (NETWORK.log and NETWORK.log.Add and IsValid(sender)) then
		NETWORK.log.Add(sender:Nick() .. " вывесил надпись: " .. title .. " / " .. text)
	end

	return #list
end

function D.Clear()
	net.Start("nwDispLabel")
		net.WriteString("")
		net.WriteString("")
		net.WriteFloat(0)
	net.Send(D.Recipients())
end

NETWORK.command.Register("displabel", {
	adminOnly = true,
	description = "cmdDispLabel",
	usage = "/displabel <заголовок> / <указание> [/ секунды]",
	aliases = {"надпись"},
	OnRun = function(command, client, arguments)
		local parts = string.Explode("/", table.concat(arguments, " "))
		local title = string.Trim(parts[1] or "")
		local text = string.Trim(parts[2] or "")
		local seconds = tonumber(string.Trim(parts[3] or ""))

		if (title == "" and text == "") then
			return NETWORK.notice.Send(client, "dispLabelUsage", "warn")
		end

		if (text == "") then
			text = title
			title = L("patrolTitle")
		end

		local count = D.Show(title, text, seconds, client)

		NETWORK.notice.Send(client, "dispLabelSent", "good", count)
	end
})

NETWORK.command.Register("displabelclear", {
	adminOnly = true,
	description = "cmdDispLabelClear",
	usage = "/displabelclear",
	OnRun = function(command, client)
		D.Clear()

		NETWORK.notice.Send(client, "dispLabelCleared", "info")
	end
})
