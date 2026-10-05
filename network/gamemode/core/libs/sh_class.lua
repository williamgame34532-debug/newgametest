NETWORK.classes = NETWORK.classes or {}
NETWORK.classes.list = NETWORK.classes.list or {}

function NETWORK.classes.Register(id, data)
	data.id = id

	NETWORK.classes.list[id] = data
end

function NETWORK.classes.Get(id)
	return id and NETWORK.classes.list[string.lower(id)]
end

function NETWORK.classes.HasCivilianHud(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	local class = NETWORK.classes.Get(client:GetNWString("nwClass", ""))

	return class != nil and class.bCivilianHud == true
end

function NETWORK.classes.IsAdministrativeID(id)
	local class = NETWORK.classes.Get(id)

	return class != nil and class.bAdministrative == true
end

function NETWORK.classes.IsAdministrative(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	return NETWORK.classes.IsAdministrativeID(client:GetNWString("nwClass", ""))
end

hook.Add("NetworkMovementSpeed", "nwClassSpeed", function(client, walk, run)
	local class = NETWORK.classes.Get(client:GetNWString("nwClass", ""))

	if (!class or !class.speed) then
		return
	end

	return math.Round(walk * (class.speed.walk or 1)),
		math.Round(run * (class.speed.run or 1))
end)

local function PlayClassFoley(client, filter)
	local class = NETWORK.classes.Get(client:GetNWString("nwClass", ""))

	if (!class or !istable(class.foley) or #class.foley == 0) then
		return
	end

	local speed = client:GetVelocity():Length2D()
	local loud = math.Clamp(speed / math.max(NETWORK.movement.runSpeed or 175, 1),
		0.35, 1)

	client:EmitSound(class.foley[math.random(#class.foley)],
		62 + 13 * loud, math.random(96, 104), 0.55 + 0.35 * loud,
		CHAN_AUTO, 0, 0, filter)
end

hook.Add("PlayerFootstep", "nwClassFoley", function(client, position, foot,
	soundName, volume)
	if (SERVER) then
		local filter = RecipientFilter()

		filter:AddPAS(position)
		filter:RemovePlayer(client)

		PlayClassFoley(client, filter)
	elseif (client == LocalPlayer() and IsFirstTimePredicted()) then
		PlayClassFoley(client)
	end
end)

local PLAYER = FindMetaTable("Player")

NETWORK.classes.baseGetCharacterName =
	NETWORK.classes.baseGetCharacterName or PLAYER.GetCharacterName

function PLAYER:GetCharacterName()
	local callsign = self:GetNWString("nwCallsign", "")

	if (callsign != "") then
		return callsign
	end

	return NETWORK.classes.baseGetCharacterName(self)
end

local STEP_WALK = 460
local STEP_RUN = 320
local STEP_MIN = 230
local STEP_MAX = 700

function NETWORK.classes.GetStepTime(client)
	local speed = client:GetVelocity():Length2D()
	local walk = math.max(NETWORK.movement.walkSpeed or 95, 1)
	local run = math.max(NETWORK.movement.runSpeed or 175, walk + 1)
	local time

	if (speed <= walk) then
		time = STEP_WALK * math.Clamp(walk / math.max(speed, 1), 1, 1.5)
	elseif (speed <= run) then
		time = Lerp((speed - walk) / (run - walk), STEP_WALK, STEP_RUN)
	else
		time = STEP_RUN * run / speed
	end

	return math.Clamp(math.Round(time), STEP_MIN, STEP_MAX)
end

function GM:PlayerStepSoundTime(client, kind, bWalking)
	if (kind != STEPSOUNDTIME_NORMAL and kind != STEPSOUNDTIME_WATER_FOOT) then
		return self.BaseClass.PlayerStepSoundTime(self, client, kind, bWalking)
	end

	return NETWORK.classes.GetStepTime(client)
end

local modelChecked = {}

function NETWORK.classes.GetModel(class)
	if (!class or !class.model or class.model == "") then
		return
	end

	local cached = modelChecked[class.model]

	if (cached != nil) then
		return cached or nil
	end

	local bValid = util.IsValidModel(class.model) or
		file.Exists(class.model, "GAME")

	if (bValid) then
		util.PrecacheModel(class.model)
	else
		NETWORK.util.PrintWarning("Модель класса " .. tostring(class.id) ..
			" не найдена на сервере: " .. class.model ..
			" — персонаж останется в своей модели.")
	end

	modelChecked[class.model] = bValid or false

	return bValid and class.model or nil
end
