NETWORK.xenwatch = NETWORK.xenwatch or {}

local X = NETWORK.xenwatch

X.steps = {0, 12, 26, 44}

X.names = {"xenLevel0", "xenLevel1", "xenLevel2", "xenLevel3"}

function X.Count()
	return GetGlobalInt("nwXenCount", 0)
end

function X.Level()
	local count = X.Count()
	local level = 0

	for index, limit in ipairs(X.steps) do
		if (count >= limit) then
			level = index - 1
		end
	end

	return level
end

function X.LevelName()
	return X.names[X.Level() + 1] or X.names[1]
end

function X.Reward()
	return 2 + X.Level() * 3
end
