NETWORK.mech2 = NETWORK.mech2 or {}

local M = NETWORK.mech2

NETWORK.config.Register("thirdPerson", {
	name = "cfgThirdPerson",
	description = "cfgThirdPersonDesc",
	category = "general",
	type = "bool",
	default = true
})

M.moods = {
	{id = "calm", name = "moodCalm", idle = "lineidle01"},
	{id = "tired", name = "moodTired", idle = "lineidle02"},
	{id = "afraid", name = "moodAfraid", idle = "lineidle03"},
	{id = "angry", name = "moodAngry", idle = "idle_angry"}
}

function M.GetMood(id)
	for _, entry in ipairs(M.moods) do
		if (entry.id == id) then
			return entry
		end
	end
end

function M.MoodList()
	local list = {}

	for _, entry in ipairs(M.moods) do
		list[#list + 1] = entry.id
	end

	return table.concat(list, ", ")
end

M.voiceModes = {
	{id = "whisper", name = "voiceWhisper", index = 1},
	{id = "normal", name = "voiceNormal", index = 2},
	{id = "yell", name = "voiceYell", index = 3}
}

function M.GetVoiceMode(id)
	for _, entry in ipairs(M.voiceModes) do
		if (entry.id == id) then
			return entry
		end
	end

	return M.voiceModes[2]
end

function M.VoiceRange(client)
	return NETWORK.act.GetVoiceRange(client) or 512
end

if (SERVER) then
	NETWORK.command.Register("mood", {
		description = "cmdMood",
		usage = "/mood <" .. "настроение" .. ">",
		aliases = {"nastroenie"},
		OnRun = function(command, client, arguments)
			local entry = M.GetMood(string.lower(arguments[1] or ""))

			if (!entry) then
				return NETWORK.notice.Send(client, "moodList", "info", M.MoodList())
			end

			client:SetNWString("nwMood", entry.id)

			NETWORK.notice.Send(client, "moodSet", "good", L(entry.name))
		end
	})

	NETWORK.command.Register("voicemode", {
		description = "cmdVoiceMode",
		usage = "/voicemode <whisper|normal|yell>",
		aliases = {"golos"},
		OnRun = function(command, client, arguments)
			local entry = M.GetVoiceMode(string.lower(arguments[1] or ""))

			client:SetNWInt("nwVoiceMode", entry.index)

			NETWORK.notice.Send(client, "voiceModeSet", "good", L(entry.name),
				math.Round(M.VoiceRange(client) / 40))
		end
	})

	hook.Remove("PlayerCanHearPlayersVoice", "nwVoiceModes")

	M.rappelRange = 900

	NETWORK.command.Register("rappel", {
		description = "cmdRappel",
		usage = "/rappel",
		aliases = {"tros", "spusk"},
		OnRun = function(command, client)
			if (!NETWORK.factions.IsAlliance(client)) then
				return NETWORK.notice.Send(client, "rappelNoAccess", "warn")
			end

			if (!client:IsOnGround()) then
				return NETWORK.notice.Send(client, "rappelGround", "warn")
			end

			local forward = client:GetAimVector()

			forward.z = 0
			forward:Normalize()

			local edge = client:GetPos() + forward * 60 + Vector(0, 0, 8)
			local down = util.TraceLine({
				start = edge,
				endpos = edge - Vector(0, 0, M.rappelRange),
				filter = client
			})

			if (!down.Hit or client:GetPos().z - down.HitPos.z < 90) then
				return NETWORK.notice.Send(client, "rappelNoEdge", "warn")
			end

			if (client.nwRappel) then
				return
			end

			client.nwRappel = true

			client:EmitSound("physics/metal/metal_box_strain3.wav", 65, 110)
			NETWORK.chat.Send(client, "me", L("rappelMe"))

			local target = down.HitPos + Vector(0, 0, 8)

			client:SetPos(edge)
			client:SetMoveType(MOVETYPE_NOCLIP)
			client:SetNoDraw(false)

			local step = 0

			timer.Create("nwRappel" .. client:EntIndex(), 0.05, 0, function()
				if (!IsValid(client) or !client:Alive()) then
					timer.Remove("nwRappel" .. client:EntIndex())

					return
				end

				step = step + 1

				local position = client:GetPos()

				if (position.z - target.z < 16 or step > 400) then
					timer.Remove("nwRappel" .. client:EntIndex())

					client:SetMoveType(MOVETYPE_WALK)
					client:SetPos(target)
					client:EmitSound("physics/body/body_medium_impact_soft6.wav", 60)

					client.nwRappel = nil

					return
				end

				client:SetPos(position - Vector(0, 0, 14))
			end)
		end
	})

	return
end

local turnRate = 6

hook.Add("CalcMainActivity", "nwTurning", function(client, velocity)
	if (!IsValid(client) or velocity:Length2D() > 8) then
		client.nwTurnAngle = nil

		return
	end

	local eye = client:EyeAngles().y
	local current = client.nwTurnAngle or eye
	local diff = math.AngleDifference(eye, current)

	if (math.abs(diff) > 45) then
		current = math.ApproachAngle(current, eye, FrameTime() * turnRate * 20)
	end

	client.nwTurnAngle = current

	client:SetRenderAngles(Angle(0, current, 0))
end)

hook.Add("CalcMainActivity", "nwMoods", function(client, velocity)
	if (!IsValid(client) or velocity:Length2D() > 8) then
		return
	end

	local mood = M.GetMood(client:GetNWString("nwMood", ""))

	if (!mood) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and weapon:GetClass() != NETWORK.weapon.hands) then
		return
	end

	local sequence = client:LookupSequence(mood.idle)

	if (sequence and sequence > 0) then
		return ACT_MP_STAND_IDLE, sequence
	end
end)
