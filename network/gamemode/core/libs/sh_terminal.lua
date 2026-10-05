NETWORK.terminal = NETWORK.terminal or {}

NETWORK.terminal.range = 90
NETWORK.terminal.model = "models/combine/combine_terminal.mdl"

NETWORK.terminal.alarmColor = Color(226, 62, 58)

NETWORK.terminal.sounds = {
	select = "framework/cmb/civicterminal/select.mp3",
	denied = "framework/cmb/civicterminal/denied.mp3",
	hover = "framework/cmb/civicterminal/hover.mp3",
	alarm = "framework/cmb/civicterminal/alarm.wav",
	loop = "framework/cmb/civicterminal/loop.wav"
}

NETWORK.terminal.pages = {
	root = {
		{id = "info", label = "termInfo"},
		{id = "housing", label = "termHousing"},
		{id = "call", label = "termCall"},
		{id = "bank", label = "termBank"},
		{id = "business", label = "termBusiness"},
		{id = "mail", label = "termMail"},
		{id = "board", label = "termBoard"},
		{id = "exit", label = "termExit"}
	}
}

function NETWORK.terminal.IsUsable(client, entity)
	if (!IsValid(entity) or !IsValid(client) or !client:Alive() or
		!client:HasCharacter()) then
		return false
	end

	return client:GetPos():Distance(entity:GetPos()) <= NETWORK.terminal.range
end

function NETWORK.terminal.CanOpen(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	return !NETWORK.factions.IsAlliance(client)
end

function NETWORK.terminal.GetCitizenID(character)
	if (!character) then
		return "00000"
	end

	if (NETWORK.cid and NETWORK.cid.Get) then
		return NETWORK.cid.Get(character:GetID())
	end

	if (NETWORK.cid) then
		return NETWORK.cid.Get(character:GetID())
	end

	return string.format("%05d", character:GetID() % 100000)
end

NETWORK.terminal.reasons = {
	"termReasonAssault",
	"termReasonTheft",
	"termReasonSuspicious",
	"termReasonContraband",
	"termReasonOther"
}
