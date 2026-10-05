NETWORK.deploy = NETWORK.deploy or {}

NETWORK.deploy.range = 130
NETWORK.deploy.clearance = 48
NETWORK.deploy.types = NETWORK.deploy.types or {}
NETWORK.deploy.order = NETWORK.deploy.order or {}

function NETWORK.deploy.Register(id, data)
	data.id = id
	data.time = data.time or 4
	data.pickupTime = data.pickupTime or 3

	if (!NETWORK.deploy.types[id]) then
		NETWORK.deploy.order[#NETWORK.deploy.order + 1] = id
	end

	NETWORK.deploy.types[id] = data

	return data
end

function NETWORK.deploy.Get(id)
	return NETWORK.deploy.types[id]
end

local function InList(list, value)
	if (!istable(list) or value == nil or value == "") then
		return false
	end

	if (list[value] == true) then
		return true
	end

	for _, entry in ipairs(list) do
		if (entry == value) then
			return true
		end
	end

	return false
end

function NETWORK.deploy.CanUseType(client, id)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return false
	end

	local data = istable(id) and id or NETWORK.deploy.Get(id)

	if (!data) then
		return false
	end

	if (data.CanUse) then
		return data.CanUse(client, data) == true
	end

	if (data.factions or data.classes) then
		local faction = client:GetCharacterFaction() or ""

		if (InList(data.factions, faction) or
			(InList(data.factions, "alliance") and NETWORK.factions.IsAlliance(client))) then
			return true
		end

		return InList(data.classes, client:GetNWString("nwClass", ""))
	end

	return NETWORK.factions.IsAlliance(client)
end

function NETWORK.deploy.CanUse(client)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return false
	end

	for _, id in ipairs(NETWORK.deploy.order) do
		if (NETWORK.deploy.CanUseType(client, id)) then
			return true
		end
	end

	return false
end

function NETWORK.deploy.GetModel(data)
	if (!data) then
		return "models/props_junk/popcan01a.mdl"
	end

	if (data.resolvedModel) then
		return data.resolvedModel
	end

	for _, model in ipairs(data.models or {}) do
		if (util.IsValidModel(model)) then
			data.resolvedModel = model

			return model
		end
	end

	data.resolvedModel = data.model or "models/props_junk/popcan01a.mdl"

	return data.resolvedModel
end

function NETWORK.deploy.GetSpot(client, data)
	if (!IsValid(client)) then
		return
	end

	local start = client:GetShootPos()
	local trace = util.TraceLine({
		start = start,
		endpos = start + client:GetAimVector() * NETWORK.deploy.range,
		filter = client,
		mask = MASK_SOLID
	})

	local position = trace.HitPos + trace.HitNormal * (data and data.offset or 0)
	local angles = Angle(0, client:EyeAngles().y, 0)
	local mount = data and data.mount or "floor"

	if (!trace.Hit) then
		return position, angles, false
	end

	if (mount != "floor") then
		if (trace.HitSky or (IsValid(trace.Entity) and
			(trace.Entity:IsPlayer() or trace.Entity:IsNPC()))) then
			return position, angles, false
		end

		if (mount == "wall" and math.abs(trace.HitNormal.z) > 0.35) then
			return position, angles, false
		end

		if (trace.HitNormal.z < 0.7) then
			angles = trace.HitNormal:Angle()
		end

		for _, entity in ipairs(ents.FindInSphere(position, data.spacing or 24)) do
			if (entity:GetNWString("nwDeploy", "") != "") then
				return position, angles, false
			end
		end

		return position, angles, true, trace.HitNormal
	end

	if (trace.HitSky or trace.HitNormal.z < 0.7) then
		return position, angles, false
	end

	local size = data and data.hullSize or 16
	local height = data and data.hullHeight or NETWORK.deploy.clearance
	local hull = util.TraceHull({
		start = position + Vector(0, 0, height * 0.5),
		endpos = position + Vector(0, 0, height * 0.5),
		mins = Vector(-size, -size, 0),
		maxs = Vector(size, size, height),
		filter = client,
		mask = MASK_SOLID
	})

	if (hull.Hit) then
		return position, angles, false
	end

	for _, entity in ipairs(ents.FindInSphere(position, data and data.spacing or 48)) do
		if (entity:GetNWString("nwDeploy", "") != "") then
			return position, angles, false
		end
	end

	return position, angles, true, trace.HitNormal
end

NETWORK.deploy.Register("turret", {
	item = "turret",
	class = "npc_turret_floor",
	model = "models/combine_turrets/floor_turret.mdl",
	time = 4,
	pickupTime = 3,
	offset = 0,
	name = "deployTurret"
})

NETWORK.deploy.Register("mine", {
	item = "mine",
	class = "nw_mine",
	model = "models/props_combine/combine_mine01.mdl",
	time = 3,
	pickupTime = 2,
	offset = 2,
	name = "deployMine"
})

NETWORK.deploy.Register("scanner", {
	item = "scanner",
	class = "npc_cscanner",
	model = "models/combine_scanner.mdl",
	time = 4,
	pickupTime = 3,
	offset = 24,
	name = "deployScanner"
})
