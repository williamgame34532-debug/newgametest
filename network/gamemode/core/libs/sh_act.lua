NETWORK.act = NETWORK.act or {}

NETWORK.act.voiceModes = {
	{name = "voiceWhisper", range = 160},
	{name = "voiceNormal", range = 512},
	{name = "voiceYell", range = 1024}
}

NETWORK.act.gestures = {
	{name = "gestureClap", sequence = "g_clap"},
	{name = "gesturePoint", sequence = "g_lookatthis",
		alternates = {"plazapoint", "signal_forward"}},
	{name = "gestureLeft", sequence = "g_pointleft_l",
		alternates = {"plazathreat", "signal_group"}},
	{name = "gestureRight", sequence = "g_pointright_l",
		alternates = {"plazawave", "signal_halt"}},
	{name = "gestureWave", sequence = "g_wave", alternates = {"plazawave"}},
	{name = "gestureNo", sequence = "hg_headshake"},
	{name = "gestureYes", sequence = "hg_puncuate_down"}
}

NETWORK.act.acts = {
	{name = "actStand1", sequence = "lineidle02", bLoop = true},
	{name = "actStand2", sequence = "scaredidle", bLoop = true},
	{name = "actStand3", sequence = "plazaidle1", bLoop = true, check = "wall",
		hint = "actHintWall"},
	{name = "actComeHere", sequence = "wave"},
	{name = "actComeHere2", sequence = "wave_close"},
	{name = "actSit", sequence = "idle_to_sit_ground", hold = "sit_ground",
		exit = "sit_ground_to_idle", bLoop = true, hint = "actHintJump"},
	{name = "actCheer1", sequence = "cheer1"},
	{name = "actCheer2", sequence = "cheer2"}
}

NETWORK.act.moods = {
	{name = "moodNormal"},
	{
		name = "moodThoughtful",
		idle = {"lineidle02", "lineidle01", "plazaidle2", "idle_subtle"},
		run = {"run_all_panicked"}
	},
	{
		name = "moodScared",
		idle = {"scaredidle", "plazaidle3", "lineidle03"},
		run = {"run_all_panicked"}
	}
}

NETWORK.act.walks = {
	{name = "walkNormal"},
	{name = "walkEasy", sequence = "walkeasy_all"},
	{name = "walkMarch", sequence = "walkmarch_all"}
}

NETWORK.act.factionActs = {
	cp = {

		{name = "actCPThreat1", sequence = "plazathreat1", bLoop = true},
		{name = "actCPThreat2", sequence = "plazathreat2", bLoop = true},
		{name = "actCPPoint", sequence = "point"},
		{name = "actCPMove1", sequence = "motionright"},
		{name = "actCPMove2", sequence = "motionleft"},
		{name = "actCPMove3", sequence = "harassfront1"},
		{name = "actCPHalt", sequence = "harassfront2"},
		{name = "actCPBlock", sequence = "blockentry", bLoop = true, check = "wall",
			hint = "actHintWall"}
	},

	cmb = {
		{name = "actOTAAdvance", sequence = "signal_advance"},
		{name = "actOTAGroup", sequence = "signal_group"},
		{name = "actOTAHalt", sequence = "signal_halt"},
		{name = "actOTACover", sequence = "signal_takecover"},
		{name = "actOTALeft", sequence = "signal_left"},
		{name = "actOTARight", sequence = "signal_right"}
	}
}

NETWORK.act.factionUnarmed = {
	cmb = {idle = {"idle_unarmed"}, walk = {"walkunarmed_all"}}
}

NETWORK.act.noMood = {cp = true, cmb = true}
NETWORK.act.walkFactions = {cmb = true}
NETWORK.act.noWalkOverride = {cmb = true}

local function Faction(client)
	return IsValid(client) and client:GetCharacterFaction() or nil
end

function NETWORK.act.Match(source, client)
	local faction = Faction(client)

	return faction and source[faction] or nil
end

function NETWORK.act.GetActs(client)
	return NETWORK.act.Match(NETWORK.act.factionActs, client) or NETWORK.act.acts
end

function NETWORK.act.GetGestures(client)
	return NETWORK.act.gestures
end

function NETWORK.act.ResolveSequence(client, data)
	if (!data or !data.sequence) then
		return
	end

	if ((client:LookupSequence(data.sequence) or -1) > 0) then
		return data.sequence
	end

	for _, alternate in ipairs(data.alternates or {}) do
		if ((client:LookupSequence(alternate) or -1) > 0) then
			return alternate
		end
	end
end

function NETWORK.act.HasSequence(client, data)
	if (!data or !data.sequence) then
		return true
	end

	return NETWORK.act.ResolveSequence(client, data) != nil
end

function NETWORK.act.HasMood(client)
	return NETWORK.act.Match(NETWORK.act.noMood, client) != true
end

function NETWORK.act.HasWalk(client)
	return NETWORK.act.Match(NETWORK.act.walkFactions, client) == true
end

function NETWORK.act.IsWalkLocked(client)
	return NETWORK.act.Match(NETWORK.act.noWalkOverride, client) == true
end

function NETWORK.act.GetMood(client)
	return NETWORK.act.moods[client:GetNWInt("nwMood", 1)] or NETWORK.act.moods[1]
end

function NETWORK.act.GetWalk(client)
	return NETWORK.act.walks[client:GetNWInt("nwWalk", 1)] or NETWORK.act.walks[1]
end

function NETWORK.act.GetVoiceMode(client)

	local index = math.Clamp(tonumber(client:GetNWInt("nwVoiceMode", 2)) or 2, 1,
		#NETWORK.act.voiceModes)

	return NETWORK.act.voiceModes[index], index
end

function NETWORK.act.GetVoiceRange(client)
	return NETWORK.act.GetVoiceMode(client).range
end

function NETWORK.act.Resolve(client, list)
	if (!list) then
		return
	end

	for _, name in ipairs(list) do
		local sequence = client:LookupSequence(name)

		if (sequence and sequence > 0) then
			return sequence
		end
	end
end

function NETWORK.act.CanUseRadio(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (NETWORK.factions.IsAlliance(client)) then
		return true
	end

	if (SERVER) then
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({"items", "storage", "equipped"}) do
			for _, item in pairs(state[list]) do
				if (item.id == "radio") then
					return true
				end
			end
		end

		return false
	end

	return client:GetNWBool("nwHasRadio", false)
end

function NETWORK.act.IsRadioOn(client)
	return client:GetNWBool("nwRadio", false)
end

function NETWORK.act.CanStyle(client)
	if (!IsValid(client) or !client:Alive() or client:InVehicle() or
		!client:OnGround()) then
		return false
	end

	if (client:IsInSequence() or client:GetNWBool("nwActing", false)) then
		return false
	end

	if (client:IsWeaponRaised()) then
		return false
	end

	return true
end

function NETWORK.act.GetMoodSequence(client, velocity)
	if (!NETWORK.act.CanStyle(client)) then
		client.nwMoodStill = nil

		return
	end

	local speed = velocity:Length2D()
	local bMoving = speed > 12
	local bRunning = speed > 190
	local bForward = true

	if (bMoving) then
		local forward = client:EyeAngles():Forward()
		local direction = Vector(velocity.x, velocity.y, 0):GetNormalized()

		bForward = direction:Dot(Vector(forward.x, forward.y, 0):GetNormalized()) > 0.55
	end

	if (bMoving) then
		client.nwMoodStill = nil
	else
		client.nwMoodStill = client.nwMoodStill or CurTime()
	end

	local bStill = client.nwMoodStill and (CurTime() - client.nwMoodStill) > 0.35
	local weapon = client:GetActiveWeapon()
	local bUnarmed = !IsValid(weapon) or weapon:GetClass() == "weapon_nwhands"
	local sequence

	if (bUnarmed) then
		local unarmed = NETWORK.act.Match(NETWORK.act.factionUnarmed, client)

		if (unarmed) then
			if (bStill) then
				sequence = NETWORK.act.Resolve(client, unarmed.idle)
			elseif (bMoving and bForward and !bRunning and
				!NETWORK.act.IsWalkLocked(client)) then
				sequence = NETWORK.act.Resolve(client, unarmed.walk)
			end
		end

		if (!sequence and NETWORK.act.HasMood(client)) then
			local mood = NETWORK.act.GetMood(client)

			if (bRunning) then
				sequence = NETWORK.act.Resolve(client, mood.run)
			elseif (bStill) then
				sequence = NETWORK.act.Resolve(client, mood.idle)
			end
		end
	elseif (bMoving and bForward and !bRunning and NETWORK.act.HasWalk(client) and
		!NETWORK.act.IsWalkLocked(client)) then
		local walk = NETWORK.act.GetWalk(client)

		if (walk.sequence) then
			sequence = NETWORK.act.Resolve(client, {walk.sequence})
		end
	end

	if (!sequence) then
		return
	end

	if (bRunning or client:Crouching() or (bMoving and !bForward)) then
		return
	end

	return {
		sequence = sequence,
		activity = bMoving and ACT_MP_WALK or ACT_MP_STAND_IDLE
	}
end
