NETWORK.cmbterm = NETWORK.cmbterm or {}

NETWORK.cmbterm.model = "models/hla_prop/combine_terminal.mdl"
NETWORK.cmbterm.range = 110

NETWORK.cmbterm.bootMin = 3
NETWORK.cmbterm.bootMax = 6

NETWORK.cmbterm.background = "framework/background/cmb_terminal.png"
NETWORK.cmbterm.logo = "framework/icons/cp.png"

NETWORK.cmbterm.sounds = {
	open = "framework/cmb/cmbterminal/dissapear.mp3",
	hover = "framework/cmb/cmbterminal/hover.mp3",
	back = "framework/cmb/cmbterminal/return.mp3",
	select = "framework/cmb/cmbterminal/select.mp3",
	loop = "framework/cmb/cmbterminal/loop.wav"
}

NETWORK.cmbterm.cameraMarks = {
	{id = "watch", key = 1, name = "camMarkWatch", color = Color(240, 210, 90), kind = "point", time = 90},
	{id = "follow", key = 2, name = "camMarkFollow", color = Color(126, 176, 220), kind = "point", time = 90},
	{id = "move", key = 3, name = "camMarkMove", color = Color(120, 220, 235), kind = "point", time = 60},
	{id = "contact", key = 4, name = "camMarkContact", color = Color(232, 92, 92), kind = "alert", time = 120},
	{id = "suspect", key = 5, name = "camMarkSuspect", color = Color(240, 160, 74), kind = "point", time = 90}
}

NETWORK.cmbterm.markRange = 4096

function NETWORK.cmbterm.GetCameraMark(id)
	for _, entry in ipairs(NETWORK.cmbterm.cameraMarks) do
		if (entry.id == id) then
			return entry
		end
	end
end

NETWORK.cmbterm.noteMax = 200
NETWORK.cmbterm.notesPerSubject = 12
NETWORK.cmbterm.orderTime = 4

function NETWORK.cmbterm.CanUse(client, entity)
	if (!IsValid(entity) or !IsValid(client) or !client:Alive() or
		!client:HasCharacter()) then
		return false
	end

	if (!NETWORK.factions.IsAlliance(client)) then
		return false
	end

	return client:GetPos():Distance(entity:GetPos()) <= NETWORK.cmbterm.range
end
