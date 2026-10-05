local D = NETWORK.disease

local function Notice(client, key, tone, ...)
	if (NETWORK.notice and NETWORK.notice.Send) then
		NETWORK.notice.Send(client, key, tone, ...)
	end
end

local function Push(client)
	local state = client.nwDisease

	client:SetNWString("nwDisease", state and state.id or "")
	client:SetNWFloat("nwDiseaseEnd", state and state.ends or 0)

	if (NETWORK.movement and NETWORK.movement.Apply) then
		NETWORK.movement.Apply(client)
	end
end

function D.GetState(client)
	return IsValid(client) and client.nwDisease or nil
end

function D.Give(client, id, bSilent, duration)
	local data = D.Get(id)

	if (!data or !IsValid(client) or !client:HasCharacter()) then
		return false
	end

	local current = client.nwDisease
	local currentData = current and D.Get(current.id)

	if (currentData and currentData.severity > data.severity) then
		return false
	end

	local bSame = current and current.id == id

	client.nwDisease = {
		id = id,
		since = bSame and current.since or CurTime(),
		ends = CurTime() + (duration or data.duration)
	}

	Push(client)

	if (!bSilent and !bSame) then
		Notice(client, "diseaseCaught", "warn", data.name)
	end

	return true
end

function D.Roll(client, id, chance)
	if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
		return false
	end

	local faction = NETWORK.factions and NETWORK.factions.Get(client:GetCharacterFaction())

	if (faction and faction.bCombine) then
		return false
	end

	if (math.random() >= (chance or 0)) then
		return false
	end

	return D.Give(client, id)
end

function D.Cure(client, bSilent, key)
	if (!IsValid(client)) then
		return false
	end

	local bHad = client.nwDisease != nil

	client.nwDisease = nil

	Push(client)

	if (bHad and !bSilent) then
		Notice(client, key or "diseaseCured", "good")
	end

	return bHad
end

timer.Create("nwDisease", D.interval, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local state = client.nwDisease

		if (!state or !client:HasCharacter()) then
			continue
		end

		if (state.ends <= CurTime()) then
			D.Cure(client, false, "diseaseOver")

			continue
		end

		if (!client:Alive()) then
			continue
		end

		local data = D.Get(state.id)

		if (!data) then
			client.nwDisease = nil
			Push(client)

			continue
		end

		if (data.escalateTo and !state.bEscalateRolled and
			CurTime() - state.since >= (data.escalateAfter or 480)) then
			state.bEscalateRolled = true

			if (math.random() < (data.escalateChance or 0) and
				D.Give(client, data.escalateTo, true)) then
				Notice(client, "diseaseWorse", "bad", D.Get(data.escalateTo).name)

				continue
			end
		end

		local bOk, err = pcall(data.Tick, client, state)

		if (!bOk) then
			ErrorNoHalt("[Network] disease/" .. state.id .. ": " .. tostring(err) .. "\n")
		end
	end
end)

hook.Add("PlayerDeath", "nwDisease", function(client)
	D.Cure(client, true)
end)

hook.Add("NetworkCharacterUnloaded", "nwDisease", function(client)
	if (IsValid(client)) then
		client.nwDisease = nil
		client:SetNWString("nwDisease", "")
		client:SetNWFloat("nwDiseaseEnd", 0)
	end
end)

hook.Add("NetworkPersistenceCollect", "nwDisease", function(client, data)
	local state = client.nwDisease

	if (!state or !D.Get(state.id)) then
		data.disease = nil

		return
	end

	data.disease = {
		id = state.id,
		left = math.max(state.ends - CurTime(), 0),
		age = math.max(CurTime() - state.since, 0),
		bEscalateRolled = state.bEscalateRolled and true or nil
	}
end)

hook.Add("NetworkPersistenceRestore", "nwDisease", function(client, data)
	local saved = istable(data) and data.disease

	if (!istable(saved) or !D.Get(saved.id) or (tonumber(saved.left) or 0) <= 0) then
		return
	end

	if (D.Give(client, saved.id, true, tonumber(saved.left))) then
		client.nwDisease.since = CurTime() - (tonumber(saved.age) or 0)
		client.nwDisease.bEscalateRolled = saved.bEscalateRolled and true or nil
	end
end)

hook.Add("NetworkPlayerTreated", "nwDisease", function(medic, patient)
	if (!IsValid(medic) or !IsValid(patient) or medic == patient) then
		return
	end

	if (patient.nwDisease and math.random() < 0.3) then
		D.Cure(patient)
		Notice(medic, "diseaseCured", "good")
	end
end)

NETWORK.command.Register("disease", {
	adminOnly = true,
	description = "cmdDisease",
	usage = "/disease <игрок> <poisoning|infection|cure>",
	OnRun = function(command, client, arguments)
		local target = arguments[1] and NETWORK.permission.Find(arguments[1])

		if (!IsValid(target)) then
			return Notice(client, "permNoTarget", "bad")
		end

		local id = string.lower(arguments[2] or "poisoning")

		if (id == "cure") then
			D.Cure(target)

			return Notice(client, "diseaseCured", "good")
		end

		if (!D.Get(id)) then
			return Notice(client, "cmdDisease", "info")
		end

		D.Give(target, id)
		Notice(client, "diseaseCaught", "info", D.Get(id).name)
	end
})
