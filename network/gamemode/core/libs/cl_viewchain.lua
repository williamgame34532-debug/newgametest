NETWORK.view = NETWORK.view or {}
NETWORK.view.modifiers = NETWORK.view.modifiers or {}

function NETWORK.view.Register(id, order, callback)
	for _, data in ipairs(NETWORK.view.modifiers) do
		if (data.id == id) then
			data.order = order
			data.callback = callback

			table.sort(NETWORK.view.modifiers, function(a, b)
				return a.order < b.order
			end)

			return
		end
	end

	NETWORK.view.modifiers[#NETWORK.view.modifiers + 1] = {
		id = id,
		order = order,
		callback = callback
	}

	table.sort(NETWORK.view.modifiers, function(a, b)
		return a.order < b.order
	end)
end

hook.Add("CalcView", "nwViewChain", function(client, origin, angles, fov)
	local view = {
		origin = origin,
		angles = angles,
		fov = fov,
		drawviewer = false
	}

	local bOverride = false

	for _, data in ipairs(NETWORK.view.modifiers) do
		local result = data.callback(client, view)

		if (result == "stop") then
			bOverride = true

			break
		end

		if (result) then
			bOverride = true
		end
	end

	if (!bOverride) then
		return
	end

	return view
end)
