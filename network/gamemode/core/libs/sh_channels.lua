NETWORK.channels = NETWORK.channels or {}

local CH = NETWORK.channels

CH.max = 40
CH.textMax = 200
CH.cooldown = 3

local function Alliance(client)
	return NETWORK.factions.IsAlliance(client)
end

local function CWU(client)
	return NETWORK.factions.IsCWU(client)
end

local function Staff(client)
	return Alliance(client) or CWU(client)
end

local function Anyone(client)
	return IsValid(client) and client:HasCharacter()
end

CH.list = {
	{id = "command", name = "chanCommand", color = Color(72, 196, 236),
		terminals = {cmb = true}, read = Alliance, write = Alliance},
	{id = "patrol", name = "chanPatrol", color = Color(120, 170, 255),
		terminals = {cmb = true}, read = Alliance, write = Alliance},
	{id = "supply", name = "chanSupply", color = Color(240, 178, 70),
		terminals = {cmb = true, cwu = true}, read = Staff, write = Staff},
	{id = "shift", name = "chanShift", color = Color(240, 178, 70),
		terminals = {cwu = true}, read = Staff, write = CWU},
	{id = "board", name = "chanBoard", color = Color(132, 214, 164),
		terminals = {cmb = true, cwu = true, civic = true, admin = true}, read = Anyone,
		write = Staff}
}

function CH.Get(id)
	for _, data in ipairs(CH.list) do
		if (data.id == id) then
			return data
		end
	end
end

function CH.GetFor(client, terminal)
	local list = {}

	for _, data in ipairs(CH.list) do
		if (data.terminals[terminal] and data.read(client)) then
			list[#list + 1] = data
		end
	end

	return list
end
