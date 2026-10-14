-- Doors (after the Helix "Doors" plugin): an admin looks at a door and types /door - a window
-- with the name of the door and its kind:
--   apartment   Квартира - bought for tokens (/doorbuy) or given through the Alliance terminal
--   business    Бизнес   - only through the Alliance terminal
--   alliance    Альянс   - only the Alliance opens it, even locked; no panel on the door
-- A panel with the name and what the door is shows on the door (cl_doors.lua). The owner locks
-- and unlocks it (/doorlock) and can sell it back (/doorsell, half the price). Doors with the same
-- map name next to each other (double doors) share the settings. Kept per map in
-- data/network2/doors/<map>.json (sv_doors.lua); the terminal will call NW.doors.SetOwner.
-- On the door (networked): nwDoorName, nwDoorKind, nwDoorMode ("buy" / "terminal"), nwDoorPrice,
-- nwDoorOwner (character id, 0 - free), nwDoorOwnerName, nwDoorCapacity (how many may live there: an
-- apartment given by the terminal can have several tenants), nwDoorTenants ("id,id,...").

NW.doors = NW.doors or {}

local D = NW.doors

D.classes = {prop_door_rotating = true, func_door = true, func_door_rotating = true}

D.kinds = {
	{id = "apartment", name = "Квартира", color = Color(120, 176, 226)},
	{id = "business", name = "Бизнес", color = Color(232, 196, 72)},
	{id = "alliance", name = "Альянс", color = Color(214, 92, 80)}
}

D.kindByID = {}

for _, kind in ipairs(D.kinds) do
	D.kindByID[kind.id] = kind
end

D.modes = {
	{id = "buy", name = "Покупная (за токены)"},
	{id = "terminal", name = "Через терминал Альянса"}
}

D.maxPrice = 100000

function D.IsDoor(entity)
	return IsValid(entity) and D.classes[entity:GetClass()] == true
end

function D.Kind(door)
	return D.kindByID[door:GetNW2String("nwDoorKind", "")]
end

-- how this door is taken: "buy", "terminal" or nil (not for sale)
function D.Mode(door)
	local kind = door:GetNW2String("nwDoorKind", "")

	if (kind == "business") then
		return "terminal"
	elseif (kind == "apartment") then
		return door:GetNW2String("nwDoorMode", "buy") == "terminal" and "terminal" or "buy"
	end
end

function D.Owner(door)
	return door:GetNW2Int("nwDoorOwner", 0)
end

-- the character ids living there (the owner first)
function D.Tenants(door)
	local out = {}

	for id in string.gmatch(door:GetNW2String("nwDoorTenants", ""), "%d+") do
		out[#out + 1] = tonumber(id)
	end

	if (#out == 0 and D.Owner(door) != 0) then
		out[1] = D.Owner(door)
	end

	return out
end

function D.Capacity(door)
	return math.max(1, door:GetNW2Int("nwDoorCapacity", 1))
end

function D.IsOwner(client, door)
	local id = client:GetCharacterID()

	if (id == 0) then
		return false
	end

	for _, tenant in ipairs(D.Tenants(door)) do
		if (tenant == id) then
			return true
		end
	end

	return false
end

-- the door the player looks at (within reach)
function D.Aimed(client, reach)
	local trace = util.TraceLine({start = client:EyePos(), endpos = client:EyePos() + client:GetAimVector() * (reach or 120),
		filter = client})

	return D.IsDoor(trace.Entity) and trace.Entity or nil
end
