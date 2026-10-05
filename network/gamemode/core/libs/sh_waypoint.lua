NETWORK.waypoint = NETWORK.waypoint or {}

NETWORK.waypoint.max = 12
NETWORK.waypoint.range = 4096

NETWORK.waypoint.defaultTime = 40
NETWORK.waypoint.maxTime = 1800

NETWORK.waypoint.colors = {
	red = Color(232, 92, 92),
	orange = Color(240, 160, 74),
	yellow = Color(240, 210, 90),
	green = Color(120, 220, 140),
	blue = Color(126, 176, 220),
	cyan = Color(120, 220, 235),
	white = Color(226, 236, 248)
}

NETWORK.waypoint.kinds = {
	point = {color = Color(126, 176, 220), radius = 0, time = 40},
	squad = {color = Color(120, 220, 235), radius = 110, time = 60},
	alert = {color = Color(232, 92, 92), radius = 0, time = 120}
}

function NETWORK.waypoint.GetKind(id)
	return NETWORK.waypoint.kinds[id or ""] or NETWORK.waypoint.kinds.point
end

function NETWORK.waypoint.GetColor(name)
	return NETWORK.waypoint.colors[string.lower(name or "")]
end

function NETWORK.waypoint.ListColors()
	local list = {}

	for name in pairs(NETWORK.waypoint.colors) do
		list[#list + 1] = name
	end

	table.sort(list)

	return table.concat(list, ", ")
end

function NETWORK.waypoint.CanSee(client)

	return IsValid(client) and client:HasCharacter()
end

function NETWORK.waypoint.CanPlace(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	return client.IsSquadLeader != nil and client:IsSquadLeader()
end

function NETWORK.waypoint.CanQuickPlace(client)
	return NETWORK.waypoint.CanPlace(client)
end
