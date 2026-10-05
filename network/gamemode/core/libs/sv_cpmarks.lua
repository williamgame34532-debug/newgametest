NETWORK.cpmarks = NETWORK.cpmarks or {}

local M = NETWORK.cpmarks

M.range = 4096

M.presets = {
	{id = "1013", name = "markSuspect", color = Color(226, 190, 70), kind = "point"},
	{id = "1031", name = "markCrime", color = Color(232, 92, 92), kind = "alert"},
	{id = "1099", name = "markBackup", color = Color(232, 74, 66), kind = "alert"},
	{id = "sbor", name = "markRally", color = Color(120, 220, 235), kind = "squad"},
	{id = "med", name = "markWounded", color = Color(140, 230, 160), kind = "point"},
	{id = "flora", name = "markFlora", color = Color(160, 220, 120), kind = "point"},
	{id = "post", name = "markPost", color = Color(126, 176, 220), kind = "point"}
}

function M.Get(id)
	for _, entry in ipairs(M.presets) do
		if (entry.id == id) then
			return entry
		end
	end
end

function M.List()
	local list = {}

	for _, entry in ipairs(M.presets) do
		list[#list + 1] = entry.id
	end

	return table.concat(list, ", ")
end

NETWORK.command.Register("mark", {
	description = "cmdMark",
	usage = "/mark <" .. "код" .. ">",
	aliases = {"metka", "tag"},
	OnRun = function(command, client, arguments)
		if (!NETWORK.waypoint.CanPlace(client)) then
			return NETWORK.notice.Send(client, "waypointNoAccess", "warn")
		end

		local entry = M.Get(string.lower(arguments[1] or ""))

		if (!entry) then
			return NETWORK.notice.Send(client, "markList", "info", M.List())
		end

		local trace = util.TraceLine({
			start = client:EyePos(),
			endpos = client:EyePos() + client:GetAimVector() * M.range,
			filter = client
		})

		local kind = NETWORK.waypoint.GetKind(entry.kind)
		local bOk, reason = NETWORK.waypoint.Add(client, trace.HitPos,
			L(entry.name), entry.color, kind.time, false, entry.kind)

		if (!bOk) then
			return NETWORK.notice.Send(client, reason or "waypointFull", "warn")
		end

		for _, target in ipairs(player.GetAll()) do
			if (NETWORK.waypoint.CanSee(target)) then
				target:EmitSound("buttons/button17.wav", 55, 120, 0.4)
			end
		end

		NETWORK.notice.Send(client, "markPlaced", "good", L(entry.name))
	end
})
