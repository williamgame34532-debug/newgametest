NETWORK.stashcode = NETWORK.stashcode or {}

local S = NETWORK.stashcode

local dataPath = "network/stashcodes.txt"

S.codes = S.codes or {}
S.grace = 600

function S.Save()
	timer.Create("nwStashCodeSave", 3, 1, function()
		file.CreateDir("network")
		file.Write(dataPath, util.TableToJSON(S.codes, true))
	end)
end

function S.Load()
	local raw = file.Read(dataPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	S.codes = istable(data) and data or {}
end

hook.Add("Initialize", "nwStashCode", S.Load)

function S.Key(entity)
	local position = entity:GetPos()

	return string.format("%d_%d_%d", math.Round(position.x),
		math.Round(position.y), math.Round(position.z))
end

function S.Get(entity)
	return S.codes[S.Key(entity)]
end

function S.Check(client, entity)
	local code = S.Get(entity)

	if (!code) then
		return true
	end

	local unlocked = (client.nwStashUnlocked or {})[S.Key(entity)]

	if (unlocked and unlocked > CurTime()) then
		return true
	end

	entity:EmitSound("buttons/combine_button_locked.wav", 60)

	NETWORK.notice.Send(client, "stashCodeNeeded", "warn")

	return false
end

NETWORK.command.Register("stashcode", {
	description = "cmdStashCode",
	usage = "/stashcode <4 цифры>",
	aliases = {"kodseifa"},
	OnRun = function(command, client, arguments)
		local entity = client:GetEyeTrace().Entity

		if (!IsValid(entity) or entity:GetClass() != "nw_stash" or
			client:GetPos():Distance(entity:GetPos()) > 120) then
			return NETWORK.notice.Send(client, "stashNoTarget", "warn")
		end

		local code = string.match(arguments[1] or "", "^%d%d%d%d$")

		if (!code) then

			if ((arguments[1] or "") == "" and S.Check(client, entity)) then
				S.codes[S.Key(entity)] = nil
				S.Save()

				return NETWORK.notice.Send(client, "stashCodeCleared", "good")
			end

			return NETWORK.notice.Send(client, "stashCodeFormat", "warn")
		end

		if (S.Get(entity) and !S.Check(client, entity)) then
			return
		end

		S.codes[S.Key(entity)] = code
		S.Save()

		client.nwStashUnlocked = client.nwStashUnlocked or {}
		client.nwStashUnlocked[S.Key(entity)] = CurTime() + S.grace

		NETWORK.notice.Send(client, "stashCodeSet", "good", code)
	end
})

NETWORK.command.Register("code", {
	description = "cmdCodeEnter",
	usage = "/code <4 цифры>",
	aliases = {"nabrat"},
	OnRun = function(command, client, arguments)
		local entity = client:GetEyeTrace().Entity

		if (!IsValid(entity) or entity:GetClass() != "nw_stash" or
			client:GetPos():Distance(entity:GetPos()) > 120) then
			return NETWORK.notice.Send(client, "stashNoTarget", "warn")
		end

		local code = S.Get(entity)

		if (!code) then
			return NETWORK.notice.Send(client, "stashCodeNone", "info")
		end

		if ((arguments[1] or "") != code) then
			entity:EmitSound("buttons/combine_button_locked.wav", 65)

			return NETWORK.notice.Send(client, "stashCodeWrong", "bad")
		end

		client.nwStashUnlocked = client.nwStashUnlocked or {}
		client.nwStashUnlocked[S.Key(entity)] = CurTime() + S.grace

		entity:EmitSound("buttons/combine_button3.wav", 60)

		NETWORK.notice.Send(client, "stashCodeOk", "good")
	end
})
