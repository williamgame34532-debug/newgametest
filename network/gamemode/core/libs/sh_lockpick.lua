NETWORK.lockpick = NETWORK.lockpick or {}

local LP = NETWORK.lockpick

LP.range = 90
LP.cancelRange = 140
LP.turnTime = 0.9
LP.tryInterval = 0.2
LP.maxTime = 150
LP.sweetMin = 15
LP.sweetMax = 165

LP.bCombineLocks = false

LP.models = {
	"models/props_c17/tools_wrench01a.mdl",
	"models/props_c17/TrapPropeller_Lever.mdl",
	"models/props_junk/garbage_metalcan002a.mdl"
}

function LP.GetModel()
	if (LP.model) then
		return LP.model
	end

	for _, path in ipairs(LP.models) do
		if (file.Exists(path, "GAME")) then
			LP.model = path

			return path
		end
	end

	LP.model = LP.models[#LP.models]

	return LP.model
end

LP.difficulties = {
	easy = {name = "lockpickEasy", stages = 1, tolerance = 16, spread = 55, wear = 0.8, minTime = 2.5},
	medium = {name = "lockpickMedium", stages = 2, tolerance = 11, spread = 45, wear = 1, minTime = 4},
	hard = {name = "lockpickHard", stages = 3, tolerance = 7, spread = 35, wear = 1.25, minTime = 6},
	extreme = {name = "lockpickExtreme", stages = 4, tolerance = 4, spread = 25, wear = 1.5, minTime = 9}
}

function LP.GetDifficulty(id)
	return LP.difficulties[id] or LP.difficulties.medium
end

function LP.Fraction(angle, sweet, difficulty)
	local distance = math.abs((angle or 0) - (sweet or 0))

	if (distance <= difficulty.tolerance) then
		return 1
	end

	return math.Clamp(1 - (distance - difficulty.tolerance) / difficulty.spread, 0.04, 0.92)
end
