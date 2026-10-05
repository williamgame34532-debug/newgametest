NETWORK.icon = NETWORK.icon or {}
NETWORK.icon.stored = NETWORK.icon.stored or {}

function NETWORK.icon.Get(id)
	return NETWORK.icon.stored[id]
end

function NETWORK.icon.Clean(data)
	if (!istable(data)) then
		return
	end

	local clean = {}

	for id, entry in pairs(data) do
		if (!NETWORK.item.Get(id) or !istable(entry)) then
			continue
		end

		clean[tostring(id)] = {
			pos = {
				tonumber(entry.pos and entry.pos[1]) or 0,
				tonumber(entry.pos and entry.pos[2]) or 0,
				tonumber(entry.pos and entry.pos[3]) or 0
			},
			ang = {
				tonumber(entry.ang and entry.ang[1]) or 0,
				tonumber(entry.ang and entry.ang[2]) or 0,
				tonumber(entry.ang and entry.ang[3]) or 0
			},

			center = {
				tonumber(entry.center and entry.center[1]) or 0,
				tonumber(entry.center and entry.center[2]) or 0,
				tonumber(entry.center and entry.center[3]) or 0
			},
			fov = math.Clamp(tonumber(entry.fov) or 40, 5, 120)
		}
	end

	return clean
end
