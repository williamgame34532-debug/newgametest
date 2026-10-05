NETWORK.startkit = NETWORK.startkit or {}
NETWORK.startkit.stored = NETWORK.startkit.stored or {}

function NETWORK.startkit.Register(faction, data)
	NETWORK.startkit.stored[faction] = data
end

NETWORK.startkit.Register("citizen", {
	guaranteed = {"idcard"},
	count = 2,
	pool = {"rag", "wire", "scrap", "can", "bandage", "bottle_empty"}
})

NETWORK.startkit.Register("worker", {
	guaranteed = {"idcard", "toolkit"},
	count = 2,
	pool = {"rag", "wire", "scrap", "battery"}
})

NETWORK.startkit.Register("disinfector", {
	guaranteed = {"idcard", "gasmask"},
	count = 1,
	pool = {"rag", "bandage", "gasmask_filter"}
})

NETWORK.startkit.Register("cp", {
	guaranteed = {"zipties", "flashlight"},
	count = 1,
	pool = {"bandage", "painkillers"}
})

NETWORK.startkit.Register("cmb", {
	guaranteed = {},
	count = 1,
	pool = {"bandage", "medkit"}
})

NETWORK.startkit.Register("combine", {
	guaranteed = {},
	count = 1,
	pool = {"bandage", "medkit"}
})

if (SERVER) then

	local function Has(client, id)
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({"items", "storage", "equipped", "clothes"}) do
			for _, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == id) then
					return true
				end
			end
		end

		return false
	end

	local function GiveSafe(client, id)
		if (!NETWORK.item.Get(id) or Has(client, id)) then
			return false
		end

		return NETWORK.inventory.Give(client, id, 1) == true
	end

	local kitPath = "network/startkit.txt"

	NETWORK.startkit.given = NETWORK.startkit.given or {}

	function NETWORK.startkit.Save()
		file.CreateDir("network")
		file.Write(kitPath, util.TableToJSON(NETWORK.startkit.given, true))
	end

	function NETWORK.startkit.Load()
		local raw = file.Read(kitPath, "DATA")

		NETWORK.startkit.given = raw and util.JSONToTable(raw) or {}
	end

	hook.Add("Initialize", "nwStartKit", function()
		NETWORK.startkit.Load()
	end)

	hook.Add("NetworkCharacterLoaded", "nwStartKit", function(client, character)
		if (!character) then
			return
		end

		local key = tostring(character:GetID())

		if (NETWORK.startkit.given[key]) then
			return
		end

		NETWORK.startkit.given[key] = true

		NETWORK.startkit.Save()

		local kit = NETWORK.startkit.stored[character:GetFaction()]

		if (!kit) then
			return
		end

		timer.Simple(1, function()
			if (!IsValid(client) or !client:HasCharacter()) then
				return
			end

			for _, id in ipairs(kit.guaranteed or {}) do
				GiveSafe(client, id)
			end

			local pool = table.Copy(kit.pool or {})
			local count = math.min(kit.count or 0, #pool)

			for _ = 1, count do
				local index = math.random(#pool)

				GiveSafe(client, pool[index])

				table.remove(pool, index)
			end

			NETWORK.inventory.Sync(client)
		end)
	end)
end
