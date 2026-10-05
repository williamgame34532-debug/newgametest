local A = NETWORK.alert

local dataPath = "network/alert.txt"

function A.Save()
	file.CreateDir("network")
	file.Write(dataPath, A.GetLevel())
end

function A.Set(client, id)
	local data = A.GetData(id)

	if (!data or data.id == A.GetLevel()) then
		return false
	end

	SetGlobalString("nwAlert", data.id)
	A.Save()

	for _, target in ipairs(player.GetAll()) do
		net.Start("nwChatMessage")
			net.WriteString("cityannounce")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(L("alertAnnounce", L(data.name)))
		net.Send(target)

		target:EmitSound(data.id == "red" and "ambient/alarms/klaxon1.wav" or
			"buttons/button17.wav", 60, 100, 0.5)
	end

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("city", string.format("%s объявил уровень «%s»",
			IsValid(client) and NETWORK.log.Name(client) or "Система",
			L(data.name)))
	end

	hook.Run("NetworkAlertChanged", data.id)

	return true
end

hook.Add("Initialize", "nwAlert", function()
	local saved = file.Read(dataPath, "DATA")

	SetGlobalString("nwAlert", saved and A.GetData(saved).id or "green")
end)

NETWORK.schedule.baseIsCurfew = NETWORK.schedule.baseIsCurfew or
	NETWORK.schedule.IsCurfew

function NETWORK.schedule.IsCurfew()
	local level = A.GetLevel()

	if (level == "red") then
		return true
	end

	if (level == "yellow") then
		local hours = NETWORK.time.GetHours()

		return hours >= 16 or hours < 6
	end

	return NETWORK.schedule.baseIsCurfew()
end

NETWORK.command.Register("alert", {
	description = "cmdAlert",
	usage = "/alert <green|yellow|red>",
	aliases = {"code", "kod"},
	OnRun = function(command, client, arguments)
		if (!A.IsCommand(client)) then
			return NETWORK.notice.Send(client, "alertNoAccess", "warn")
		end

		local id = string.lower(arguments[1] or "")

		if (!A.Set(client, id)) then
			return NETWORK.notice.Send(client, "alertUsage", "info",
				A.GetData().id and L(A.GetData().name) or "")
		end
	end
})
