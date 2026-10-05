NETWORK.spoil = NETWORK.spoil or {}

local S = NETWORK.spoil

S.rate = 1.2
S.containerScale = 0.5
S.fridgeScale = 0
S.fridgeID = "fridge"

S.stages = {
	[0] = {key = "spoilFresh", color = Color(96, 224, 140)},
	[1] = {key = "spoilAging", color = Color(240, 220, 90)},
	[2] = {key = "spoilBad", color = Color(240, 150, 60)},
	[3] = {key = "spoilRotten", color = Color(232, 84, 76)}
}

S.thresholds = {25, 50, 100}

function S.CanSpoil(base)
	if (!istable(base) or base.category != "food" or base.bNoSpoil) then
		return false
	end

	return (base.hunger or 0) >= (base.thirst or 0) and (base.hunger or 0) > 0
end

function S.Get(item)
	local data = item and item.data

	return istable(data) and tonumber(data.spoil) or 0
end

function S.GetStage(item)
	local value = isnumber(item) and item or S.Get(item)

	if (value < S.thresholds[1]) then
		return 0
	elseif (value < S.thresholds[2]) then
		return 1
	elseif (value < S.thresholds[3]) then
		return 2
	end

	return 3
end

function S.GetLabel(item)
	return S.stages[S.GetStage(item)].key
end

function S.GetColor(stage)
	return (S.stages[stage] or S.stages[0]).color
end

function S.GetRate(base, scale)
	return (base and base.spoilRate or S.rate) * (scale or 1)
end

function S.Tick(item, base, scale, minutes)
	if (!istable(item) or !S.CanSpoil(base)) then
		return false
	end

	local rate = S.GetRate(base, scale) * (minutes or 1)

	if (rate <= 0) then
		return false
	end

	item.data = item.data or {}

	local before = tonumber(item.data.spoil) or 0
	local after = math.min(before + rate, 100)

	if (after == before) then
		return false
	end

	item.data.spoil = after

	return true
end

local function OnlySpoil(data)
	if (!istable(data)) then
		return true
	end

	for key in pairs(data) do
		if (key != "spoil") then
			return false
		end
	end

	return true
end

function S.CanStack(a, b)
	if (!OnlySpoil(a.data) or !OnlySpoil(b.data)) then
		return false
	end

	return math.floor(S.Get(a) / 10) == math.floor(S.Get(b) / 10)
end

function S.IsFridge(entity)
	return IsValid(entity) and entity.GetContainerID != nil and
		entity:GetContainerID() == S.fridgeID
end

if (NETWORK.container and NETWORK.container.Register) then
	NETWORK.container.Register(S.fridgeID, {
		name = (NETWORK.lang and NETWORK.lang.Exists("containerFridge")) and
			L("containerFridge") or "Холодильник",
		description = "Еда внутри не портится.",
		model = "models/props_wasteland/kitchen_fridge001a.mdl",
		slots = 12,
		minItems = 0,
		maxItems = 0,
		loot = {}
	})
end
