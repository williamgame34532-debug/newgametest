util.AddNetworkString("nwRecognise")
util.AddNetworkString("nwRecogniseSync")
util.AddNetworkString("nwRecogniseMenu")

function NETWORK.recognition.Sync(client)
	local list = {}

	for id in pairs(client.nwRecognised or {}) do
		list[#list + 1] = id
	end

	net.Start("nwRecogniseSync")
		NETWORK.util.WriteTable(list)
	net.Send(client)
end

function NETWORK.recognition.Add(observer, target)
	local id = target:GetCharacterID()

	if (id <= 0 or observer == target) then
		return false
	end

	if (NETWORK.factions.IsAlliance(target)) then
		return false
	end

	observer.nwRecognised = observer.nwRecognised or {}

	if (observer.nwRecognised[id]) then
		return false
	end

	observer.nwRecognised[id] = true

	NETWORK.recognition.Sync(observer)

	return true
end

function NETWORK.recognition.Introduce(client, modeID)
	if (!client:HasCharacter()) then
		return
	end

	if ((client.nwNextRecognise or 0) > CurTime()) then
		return
	end

	client.nwNextRecognise = CurTime() + 1.5

	local mode = NETWORK.recognition.GetMode(modeID)
	local targets = {}
	local R = NETWORK.radio

	if (mode.id == "radio") then

		if (!R or R.GetFreq(client) == "") then
			return NETWORK.notice.Send(client, "radioNoFreq", "warn")
		end

		for _, target in ipairs(player.GetAll()) do
			if (target != client and target:HasCharacter() and R.SameFreq(client, target)) then
				targets[#targets + 1] = target
			end
		end

		local count = 0

		for _, target in ipairs(targets) do
			if (NETWORK.recognition.Add(target, client)) then
				count = count + 1
			end
		end

		if (#targets > 0) then
			NETWORK.chat.Send(client, "radio", L("recogIntroduceRadio", client:GetCharacterName()))
		end

		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(count > 0 and "recogDone" or "recogRadioNobody")
		net.Send(client)

		return
	end

	if (mode.id == "target") then
		local trace = client:GetEyeTrace()
		local entity = trace.Entity

		if (IsValid(entity) and entity:IsPlayer() and entity:HasCharacter() and
			client:GetPos():Distance(entity:GetPos()) <= mode.range) then
			targets[#targets + 1] = entity
		end
	else
		for _, target in ipairs(player.GetAll()) do
			if (target == client or !target:HasCharacter() or !target:Alive()) then
				continue
			end

			if (client:GetPos():Distance(target:GetPos()) <= mode.range) then
				targets[#targets + 1] = target
			end
		end
	end

	local count = 0

	for _, target in ipairs(targets) do

		if (NETWORK.recognition.Add(target, client)) then
			count = count + 1
		end
	end

	if (count > 0) then
		NETWORK.chat.Send(client, "it", L("recogIntroduce"))
	end

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(count > 0 and "recogDone" or "recogNobody")
	net.Send(client)
end

net.Receive("nwRecognise", function(_, client)
	NETWORK.recognition.Introduce(client, net.ReadString())
end)

function GM:ShowSpare1(client)
	net.Start("nwRecogniseMenu")
	net.Send(client)
end

hook.Add("NetworkCharacterLoaded", "nwRecognition", function(client)
	client.nwRecognised = client.nwRecognised or {}

	timer.Simple(0.6, function()
		if (IsValid(client)) then
			NETWORK.recognition.Sync(client)
		end
	end)
end)

NETWORK.command.Register("recognise", {
	description = "cmdRecognise",
	usage = "/recognise",
	aliases = {"znak", "recognize"},
	OnRun = function(command, client)
		NETWORK.recognition.Introduce(client, "normal")
	end
})
