NETWORK.alert = NETWORK.alert or {}

local A = NETWORK.alert

A.levels = {
	{id = "green", name = "alertGreen", color = Color(120, 200, 130)},
	{id = "yellow", name = "alertYellow", color = Color(226, 190, 70)},
	{id = "red", name = "alertRed", color = Color(226, 74, 66)}
}

function A.IsCommand(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	local class = NETWORK.classes and
		NETWORK.classes.Get(client:GetNWString("nwClass", ""))

	return class != nil and class.bCommand == true
end

function A.GetLevel()
	return GetGlobalString("nwAlert", "green")
end

function A.GetData(id)
	for _, entry in ipairs(A.levels) do
		if (entry.id == (id or A.GetLevel())) then
			return entry
		end
	end

	return A.levels[1]
end

function A.IsRed()
	return A.GetLevel() == "red"
end

function A.IsRaised()
	return A.GetLevel() != "green"
end
