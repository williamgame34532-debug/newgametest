NETWORK.cutscene = NETWORK.cutscene or {}
NETWORK.cutscene.stored = NETWORK.cutscene.stored or {}

NETWORK.cutscene.maxShots = 12
NETWORK.cutscene.maxScenes = 24

function NETWORK.cutscene.Get(id)
	return NETWORK.cutscene.stored[string.lower(id or "")]
end

function NETWORK.cutscene.GetLength(scene)
	local total = 0

	for _, shot in ipairs(scene.shots or {}) do
		total = total + (shot.travel or 2) + (shot.hold or 1)
	end

	return total
end

function NETWORK.cutscene.Resolve(scene, time)
	local shots = scene.shots or {}
	local cursor = 0

	for index, shot in ipairs(shots) do
		local travel = shot.travel or 2
		local hold = shot.hold or 1

		if (time < cursor + travel) then

			local fraction = travel > 0 and (time - cursor) / travel or 1

			return shots[index - 1] or shot, shot, fraction, index
		end

		if (time < cursor + travel + hold) then
			return shot, shot, 1, index
		end

		cursor = cursor + travel + hold
	end

	return shots[#shots], shots[#shots], 1, #shots
end
