NETWORK.prompt = NETWORK.prompt or {}

NETWORK.prompt.keys = {
	{id = "j", key = KEY_J, label = "J"},
	{id = "k", key = KEY_K, label = "K"},
	{id = "l", key = KEY_L, label = "L"},
	{id = "n", key = KEY_N, label = "N"},
	{id = "b", key = KEY_B, label = "B"},
	{id = "m", key = KEY_M, label = "M"},
	{id = "h", key = KEY_H, label = "H"},
	{id = "insert", key = KEY_INSERT, label = "INS"},
	{id = "delete", key = KEY_DELETE, label = "DEL"},
	{id = "end", key = KEY_END, label = "END"},
	{id = "pgup", key = KEY_PAGEUP, label = "PGUP"},
	{id = "pgdn", key = KEY_PAGEDOWN, label = "PGDN"}
}

function NETWORK.prompt.IsTaken(key)
	if (!key or key <= KEY_NONE) then
		return false
	end

	for _, data in ipairs(NETWORK.bind.GetAll()) do
		if (NETWORK.bind.GetKey(data) == key) then
			return true, data
		end
	end

	if (key == KEY_H) then
		return true
	end

	return false
end

local accept = CreateClientConVar("network_key_accept", "j", true, false,
	"Клавиша согласия в быстрых запросах")

local decline = CreateClientConVar("network_key_decline", "n", true, false,
	"Клавиша отказа в быстрых запросах")

local function Find(id)
	for _, entry in ipairs(NETWORK.prompt.keys) do
		if (entry.id == id) then
			return entry
		end
	end

	return NETWORK.prompt.keys[1]
end

function NETWORK.prompt.GetAccept()
	return Find(accept:GetString()).key
end

function NETWORK.prompt.GetDecline()
	return Find(decline:GetString()).key
end

function NETWORK.prompt.AcceptLabel()
	return Find(accept:GetString()).label
end

function NETWORK.prompt.DeclineLabel()
	return Find(decline:GetString()).label
end

function NETWORK.prompt.IsBlocked()
	return vgui.GetKeyboardFocus() != nil or gui.IsGameUIVisible() or
		gui.IsConsoleVisible()
end

function NETWORK.prompt.AcceptDown()
	return !NETWORK.prompt.IsBlocked() and
		input.IsKeyDown(NETWORK.prompt.GetAccept())
end

function NETWORK.prompt.DeclineDown()
	return !NETWORK.prompt.IsBlocked() and
		input.IsKeyDown(NETWORK.prompt.GetDecline())
end

local options = {}

local function BuildOptions()
	local list = {}

	for _, entry in ipairs(NETWORK.prompt.keys) do
		if (!NETWORK.prompt.IsTaken(entry.key)) then
			list[#list + 1] = {value = entry.id, label = entry.label}
		end
	end

	if (#list < 2) then
		list = {}

		for _, entry in ipairs(NETWORK.prompt.keys) do
			list[#list + 1] = {value = entry.id, label = entry.label}
		end
	end

	return list
end

for _, entry in ipairs(BuildOptions()) do
	options[#options + 1] = entry
end

local migrated = CreateClientConVar("network_key_migrated", "0", true, false)

local function Migrate()
	if (migrated:GetBool()) then
		return false
	end

	RunConsoleCommand("network_key_migrated", "1")

	local bTaken = NETWORK.prompt.IsTaken(NETWORK.prompt.GetAccept())

	if (!bTaken) then
		return false
	end

	for _, entry in ipairs(NETWORK.prompt.keys) do
		if (!NETWORK.prompt.IsTaken(entry.key) and
			entry.key != NETWORK.prompt.GetDecline()) then
			RunConsoleCommand("network_key_accept", entry.id)

			NETWORK.gui.Notify(L("promptKeyMoved", entry.label),
				NETWORK.theme.positive)

			return true
		end
	end

	return false
end

hook.Add("InitPostEntity", "nwPromptCheck", function()
	timer.Simple(5, function()
		if (Migrate()) then
			return
		end

		local bTaken, data = NETWORK.prompt.IsTaken(NETWORK.prompt.GetAccept())

		if (!bTaken) then
			return
		end

		NETWORK.gui.Notify(L("promptKeyTaken", NETWORK.prompt.AcceptLabel(),
			data and L(data.name) or "?"), NETWORK.theme.warning)
	end)
end)

NETWORK.option.Register("network_key_accept", {
	name = "optKeyAccept",
	description = "optKeyAcceptDesc",
	category = "interface",
	type = "choice",
	convar = "network_key_accept",
	options = options
})

NETWORK.option.Register("network_key_decline", {
	name = "optKeyDecline",
	description = "optKeyDeclineDesc",
	category = "interface",
	type = "choice",
	convar = "network_key_decline",
	options = options
})

hook.Add("InitPostEntity", "nwPromptKeyMigrate", function()
	timer.Simple(6, function()
		local chosen = accept:GetString()
		local data = Find(chosen)

		if (!data or !NETWORK.prompt.IsTaken(data.key)) then
			return
		end

		RunConsoleCommand("network_key_accept", "j")

		NETWORK.gui.Notify(L("promptKeyMoved", string.upper(chosen), "J"),
			NETWORK.theme.warning)
	end)
end)
