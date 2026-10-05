util.AddNetworkString("nwPMenuOpen")
util.AddNetworkString("nwPMenuAction")
util.AddNetworkString("nwPMenuIntro")
util.AddNetworkString("nwPMenuIntroReply")

local P = NETWORK.pmenu

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone, ...)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function BodyPos(target)
	if (target:IsPlayer()) then
		return NETWORK.medical.GetBodyPos(target)
	end

	return target:WorldSpaceCenter()
end

function P.InReach(client, target, extra)
	if (!IsValid(client) or !IsValid(target)) then
		return false
	end

	return client:WorldSpaceCenter():Distance(BodyPos(target)) <= P.range + (extra or 30)
end

function P.HasBodybag(client)
	local state = NETWORK.inventory.GetState(client)

	for _, list in ipairs({"items", "storage", "clothes"}) do
		for _, item in pairs(state[list] or {}) do
			if (istable(item) and item.id == "bodybag") then
				return true
			end
		end
	end

	return false
end

function P.GetDocuments(client)
	local list = {}

	for index, item in pairs(NETWORK.inventory.GetState(client).items or {}) do
		if (P.IsDocument(item)) then
			list[#list + 1] = index
		end
	end

	return list
end

function P.CanLendKey(client)
	for _, entry in ipairs(NETWORK.door.GetOwned(client:SteamID64())) do
		if (NETWORK.door.CanLend(entry.data)) then
			return true
		end
	end

	return false
end

function P.BuildOptions(client, target, kind)
	local list = {}

	local function Add(id)
		list[#list + 1] = id
	end

	if (kind == "corpse") then
		Add("search")
		Add("pulse")

		if (P.HasBodybag(client)) then
			Add("bodybag")
		end

		Add("treat")

		return list
	end

	local bAwake = !target:IsDowned() and !target:IsUnconscious()
	local bTied = NETWORK.restraint.IsTied(target)

	if (bAwake) then
		Add("tokens")

		if (!NETWORK.factions.IsAlliance(client) and
			!NETWORK.factions.IsAlliance(target)) then
			Add("recognise")
		end

		if (#P.GetDocuments(client) > 0) then
			Add("documents")
		end

		if (P.CanLendKey(client)) then
			Add("lendkey")
		end
	end

	if (NETWORK.search.CanSearch(client, target)) then
		Add("search")
	end

	if (bTied) then
		Add(NETWORK.restraint.GetLeader(target) == client and "release" or "lead")
		Add("untie")
	end

	if (!bAwake) then
		Add("pulse")

		if (P.HasBodybag(client)) then
			Add("bodybag")
		end
	end

	Add("treat")

	return list
end

function P.Open(client, target, kind)
	if ((client.nwNextPlayerMenu or 0) > CurTime()) then
		return
	end

	client.nwNextPlayerMenu = CurTime() + 0.6

	local options = P.BuildOptions(client, target, kind)

	if (#options == 0) then
		return
	end

	net.Start("nwPMenuOpen")
		net.WriteEntity(target)
		net.WriteString(kind)
		NETWORK.util.WriteTable(options)
	net.Send(client)
end

hook.Add("KeyPress", "nwPlayerMenu", function(client, key)
	if (key != IN_USE or !client:Alive() or !client:HasCharacter()) then
		return
	end

	client.nwPMenuHold = nil

	if (client:KeyDown(IN_SPEED) or client:IsDowned() or
		NETWORK.restraint.IsTied(client)) then
		return
	end

	local target, kind = P.GetTarget(client)

	if (!target) then
		return
	end

	client.nwPMenuHold = {
		start = CurTime(),
		target = target,
		kind = kind
	}
end)

hook.Add("KeyRelease", "nwPlayerMenu", function(client, key)
	if (key != IN_USE) then
		return
	end

	local hold = client.nwPMenuHold

	client.nwPMenuHold = nil

	if (!hold or hold.bOpened) then
		return
	end

	if (hold.kind != "corpse" and !P.IsHelpless(hold.target)) then
		return
	end

	if (CurTime() - hold.start >= P.holdTime) then
		return
	end

	local target = hold.target

	if (IsValid(target) and NETWORK.search.CanSearch(client, target)) then
		if ((client.nwNextPlayerMenu or 0) > CurTime()) then
			return
		end

		client.nwNextPlayerMenu = CurTime() + 0.6

		NETWORK.search.Open(client, target)
	end
end)

timer.Create("nwPlayerMenuHold", 0.05, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local hold = client.nwPMenuHold

		if (!hold or hold.bOpened) then
			continue
		end

		if (!client:Alive() or !client:KeyDown(IN_USE) or client:KeyDown(IN_SPEED)) then
			client.nwPMenuHold = nil

			continue
		end

		if (CurTime() - hold.start < P.holdTime) then
			continue
		end

		hold.bOpened = true

		local target, kind = P.GetTarget(client)

		if (target == hold.target and IsValid(target)) then
			P.Open(client, target, kind)
		end
	end
end)

local actions = {}

actions.tokens = function(client, target, argument)
	local amount = math.floor(tonumber(argument) or 0)

	if (amount <= 0 or amount > P.tokenMax) then
		return Notice(client, "pmTokensBad", "bad", P.tokenMax)
	end

	if (target:IsDowned() or target:IsUnconscious()) then
		return Notice(client, "pmTargetBusy", "warn")
	end

	if ((client.nwNextTokenGive or 0) > CurTime()) then
		return
	end

	client.nwNextTokenGive = CurTime() + 1

	if (!NETWORK.currency.Take(client, amount)) then
		return Notice(client, "pmTokensNotEnough", "bad")
	end

	NETWORK.currency.Add(target, amount)

	Notice(client, "pmTokensGiven", "good", amount, target:GetRecognisedName(client))
	Notice(target, "pmTokensReceived", "good", amount, client:GetRecognisedName(target))

	NETWORK.chat.Send(client, "me", L("pmTokensMe"))

	client:EmitSound("physics/metal/chain_impact_soft" .. math.random(1, 3) .. ".wav",
		50, 140, 0.5)

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("token", string.format("%s передал %d токенов -> %s",
			NETWORK.log.Name(client), amount, NETWORK.log.Name(target)), client:GetPos())
	end

	hook.Run("NetworkTokensTransferred", client, target, amount)
end

actions.recognise = function(client, target)
	if (NETWORK.factions.IsAlliance(client) or NETWORK.factions.IsAlliance(target)) then
		return Notice(client, "pmRecogAlliance", "warn")
	end

	if ((client.nwNextIntro or 0) > CurTime()) then
		return
	end

	client.nwNextIntro = CurTime() + 2

	if (!NETWORK.recognition.Add(target, client)) then
		return Notice(client, "pmRecogAlready", "info")
	end

	NETWORK.chat.Send(client, "me", L("pmRecogMe"))

	Notice(client, "pmRecogDone", "good")

	if (client:IsRecognised(target)) then
		return
	end

	target.nwIntroFrom = {client = client, time = CurTime()}

	net.Start("nwPMenuIntro")
		net.WriteEntity(client)
		net.WriteString(client:GetCharacterName())
	net.Send(target)
end

actions.documents = function(client, target, argument)
	local index = tonumber(argument)
	local state = NETWORK.inventory.GetState(client)
	local item = index and state.items[index]

	if (!P.IsDocument(item)) then
		return Notice(client, "pmDocGone", "bad")
	end

	if (target:IsDowned() or target:IsUnconscious() or
		(target.IsCombat and target:IsCombat())) then
		return Notice(client, "pmTargetBusy", "warn")
	end

	NETWORK.documents.Show(client, target, item)
end

actions.lendkey = function(client, target, argument)
	local key, minutes = string.match(argument or "", "^([^|]+)|?(%d*)$")

	if (!key) then
		return Notice(client, "pmNotNow", "warn")
	end

	minutes = math.Clamp(math.floor(tonumber(minutes) or P.lendMinutes), 1, P.lendMinutesMax)

	if (target:IsDowned() or target:IsUnconscious()) then
		return Notice(client, "pmTargetBusy", "warn")
	end

	local data = NETWORK.door.list[key]

	if (istable(data) and NETWORK.door.IsOwner(data, target:SteamID64())) then
		return Notice(client, "pmNotNow", "warn")
	end

	if ((client.nwNextLendKey or 0) > CurTime()) then
		return
	end

	client.nwNextLendKey = CurTime() + 1

	local bLent, title = NETWORK.door.LendKey(client, target, key, minutes)

	if (!bLent) then
		return Notice(client, "pmNotNow", "warn")
	end

	Notice(client, "doorKeyLent", "good", target:GetRecognisedName(client), title, minutes)
	Notice(target, "doorKeyBorrowed", "good", client:GetRecognisedName(target), title, minutes)

	NETWORK.chat.Send(client, "me", L("pmLendkeyMe"))

	client:EmitSound("physics/metal/chain_impact_soft" .. math.random(1, 3) .. ".wav",
		50, 160, 0.5)

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("door", string.format("%s дал ключ от %s (%s) на %d мин -> %s",
			NETWORK.log.Name(client), title, key, minutes, NETWORK.log.Name(target)),
			client:GetPos())
	end
end

actions.search = function(client, target)
	if (!NETWORK.search.CanSearch(client, target)) then
		return Notice(client, "searchDenied", "bad")
	end

	NETWORK.search.Open(client, target)
end

local function Lead(client, target)
	if (!NETWORK.restraint.IsTied(target)) then
		return
	end

	if (NETWORK.restraint.GetLeader(target) == client) then
		NETWORK.restraint.SetLeader(target, NULL)

		NETWORK.chat.Notice(client, "tieLetGo")
		NETWORK.chat.Notice(target, "tieLetGoThem")

		return
	end

	if (NETWORK.restraint.IsLed(target)) then
		return NETWORK.chat.Notice(client, "tieLedAlready")
	end

	NETWORK.restraint.SetLeader(target, client)

	NETWORK.chat.Notice(client, "tieLead")
	NETWORK.chat.Notice(target, "tieLedThem")
end

actions.lead = Lead
actions.release = Lead

actions.untie = function(client, target)
	if (NETWORK.restraint.IsTied(target)) then
		if (hook.Run("NetworkCanUntie", client, target) == false) then
			return
		end

		NETWORK.restraint.Begin(client, target, true)
	end
end

actions.treat = function(client, target, _, kind)

	if (kind == "corpse" or !IsValid(target) or !target:IsPlayer() or !target:Alive()) then
		if (client.nwTreatTask) then
			return
		end

		client.nwTreatTask = true

		Progress(client, "pmTreatProgress", P.pulseTime)
		NETWORK.chat.Send(client, "me", L("pmTreatMe"))

		timer.Simple(P.pulseTime, function()
			if (!IsValid(client)) then
				return
			end

			client.nwTreatTask = nil

			Progress(client, "", 0)

			if (!client:Alive() or !IsValid(target) or !P.InReach(client, target)) then
				return Notice(client, "pmPulseLost", "warn")
			end

			Notice(client, "pmTreatNoSigns", "bad")
		end)

		return
	end

	NETWORK.medical.OpenPanel(client, target)
end

actions.pulse = function(client, target, _, kind)
	if (client.nwPulseTask) then
		return
	end

	local bCorpse = kind == "corpse"

	if (!bCorpse and !target:IsDowned() and !target:IsUnconscious()) then
		return
	end

	client.nwPulseTask = target

	Progress(client, "pmPulseProgress", P.pulseTime)
	NETWORK.chat.Send(client, "me", L("pmPulseMe"))

	if (!bCorpse and !target:IsUnconscious()) then
		Notice(target, "pmPulseCheckedYou", "info")
	end

	timer.Simple(P.pulseTime, function()
		if (!IsValid(client)) then
			return
		end

		client.nwPulseTask = nil

		if (!client:Alive() or !IsValid(target) or !P.InReach(client, target)) then
			Progress(client, "", 0)

			return Notice(client, "pmPulseLost", "warn")
		end

		if (bCorpse or !target:IsPlayer() or !target:Alive()) then
			local age = bCorpse and (CurTime() - target:GetNWFloat("nwDeathTime",
				CurTime())) or 0

			return Notice(client, age > 120 and "pmPulseDeadCold" or "pmPulseDead", "bad")
		end

		local bpm, quality = NETWORK.medical.GetPulse(target)

		if (quality == "thready") then
			Notice(client, "pmPulseThready", "warn", bpm)
		elseif (quality == "weak") then
			Notice(client, "pmPulseWeak", "warn", bpm)
		elseif (quality == "fast") then
			Notice(client, "pmPulseFast", "good", bpm)
		else
			Notice(client, "pmPulseNormal", "good", bpm)
		end

		hook.Run("NetworkPulseChecked", client, target, bpm, quality)
	end)
end

net.Receive("nwPMenuAction", function(_, client)
	local action = net.ReadString()
	local entity = net.ReadEntity()
	local argument = net.ReadString()
	local callback = actions[action]

	if (!callback or !client:Alive() or !client:HasCharacter()) then
		return
	end

	if (client:IsDowned() or NETWORK.restraint.IsTied(client)) then
		return
	end

	local target, kind = P.Resolve(entity)

	if (!target or target == client) then
		return
	end

	if (kind == "player" and (!target:Alive() or !target:HasCharacter())) then
		return
	end

	if (!P.InReach(client, target)) then
		return Notice(client, "pmTooFar", "warn")
	end

	local bAllowed = false

	for _, id in ipairs(P.BuildOptions(client, target, kind)) do
		if (id == action) then
			bAllowed = true

			break
		end
	end

	if (!bAllowed) then
		return Notice(client, "pmNotNow", "warn")
	end

	callback(client, target, argument, kind)
end)

net.Receive("nwPMenuIntroReply", function(_, client)
	local bAccept = net.ReadBool()
	local pending = client.nwIntroFrom

	client.nwIntroFrom = nil

	if (!bAccept or !pending or !IsValid(pending.client)) then
		return
	end

	if (CurTime() - pending.time > P.introTime + 1) then
		return
	end

	local other = pending.client

	if (client:GetPos():Distance(other:GetPos()) > 400) then
		return Notice(client, "pmTooFar", "warn")
	end

	if (NETWORK.recognition.Add(other, client)) then
		NETWORK.chat.Send(client, "me", L("pmRecogMe"))
		Notice(client, "pmRecogDone", "good")
	end
end)
