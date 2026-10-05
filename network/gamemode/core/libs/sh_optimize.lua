NETWORK.optimize = NETWORK.optimize or {}

NETWORK.optimize.maxRagdolls = 24
NETWORK.optimize.maxGibs = 48

if (CLIENT) then

	NETWORK.optimize.baseSafeRemove = NETWORK.optimize.baseSafeRemove or
		SafeRemoveEntity

	function SafeRemoveEntity(entity)
		if (!IsValid(entity)) then
			return
		end

		local bClientside = entity.IsClientside and entity:IsClientside() or
			entity:EntIndex() <= 0

		if (!bClientside) then
			return
		end

		return NETWORK.optimize.baseSafeRemove(entity)
	end

	return
end

hook.Add("OnEntityCreated", "nwOptimizeRagdoll", function(entity)
	if (!IsValid(entity) or entity:GetClass() != "hl2mp_ragdoll") then
		return
	end

	timer.Simple(0, function()
		if (IsValid(entity)) then
			entity:Remove()
		end
	end)
end)

local function Trim(class, limit)
	local list = ents.FindByClass(class)

	if (#list <= limit) then
		return
	end

	local aged = {}

	for _, entity in ipairs(list) do
		if (entity.nwSpawnTime and !entity.nwNoTrim) then
			aged[#aged + 1] = entity
		end
	end

	table.sort(aged, function(a, b)
		return a.nwSpawnTime < b.nwSpawnTime
	end)

	for index = 1, #aged - limit do
		local entity = aged[index]

		if (IsValid(entity)) then
			entity:Remove()
		end
	end
end

hook.Add("OnEntityCreated", "nwOptimizeStamp", function(entity)
	if (!IsValid(entity)) then
		return
	end

	local class = entity:GetClass()

	if (class == "prop_ragdoll" or class == "nw_ragdoll" or
		class == "hl2mp_ragdoll" or class == "gib" or class == "prop_physics") then
		entity.nwSpawnTime = CurTime()
	end
end)

timer.Create("nwOptimizeTrim", 30, 0, function()
	Trim("hl2mp_ragdoll", NETWORK.optimize.maxRagdolls)
	Trim("prop_ragdoll", NETWORK.optimize.maxRagdolls)
	Trim("nw_ragdoll", NETWORK.optimize.maxRagdolls)
	Trim("gib", NETWORK.optimize.maxGibs)
end)

hook.Add("PlayerDisconnected", "nwOptimizeClean", function(client)
	if (!IsValid(client)) then
		return
	end

	client:SetNWString("nwTyping", "")
	client:SetNWString("nwVortAura", "none")
end)
