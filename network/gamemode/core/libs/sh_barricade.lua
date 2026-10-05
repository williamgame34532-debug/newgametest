NETWORK.barricade = NETWORK.barricade or {}

local B = NETWORK.barricade

B.range = 120
B.labelRange = 200
B.maxBoards = 3
B.maxPerCharacter = 8
B.spawnClearance = 96
B.returnFraction = 0.5
B.rotateStep = 15

B.types = B.types or {}
B.order = B.order or {}

B.lastResort = "models/props_junk/wood_crate001a.mdl"

function B.Register(id, data)
	data.id = id
	data.name = data.name or id
	data.health = data.health or 300
	data.placeTime = data.placeTime or 4
	data.pickupTime = data.pickupTime or 3
	data.offset = data.offset or 0
	data.models = data.models or {}
	data.model = nil

	if (!B.types[id]) then
		B.order[#B.order + 1] = id
	end

	B.types[id] = data

	return data
end

function B.Get(id)
	return B.types[id]
end

function B.PickModel(data)
	if (!data) then
		return B.lastResort
	end

	if (data.model) then
		return data.model
	end

	for _, path in ipairs(data.models or {}) do
		if (file.Exists(path, "GAME")) then
			data.model = path

			util.PrecacheModel(path)

			return path
		end
	end

	data.model = B.lastResort

	return data.model
end

B.bounds = B.bounds or {}

function B.GetBounds(model)
	local cached = B.bounds[model]

	if (cached) then
		return cached[1], cached[2]
	end

	local mins, maxs = Vector(-16, -16, 0), Vector(16, 16, 32)
	local probe

	if (SERVER) then
		probe = ents.Create("prop_dynamic")

		if (IsValid(probe)) then
			probe:SetModel(model)
		end
	else
		probe = ClientsideModel(model, RENDERGROUP_OTHER)
	end

	if (IsValid(probe)) then
		mins, maxs = probe:OBBMins(), probe:OBBMaxs()

		probe:Remove()
	end

	B.bounds[model] = {mins, maxs}

	return mins, maxs
end

local function Axis(vector, index)
	return index == 1 and vector.x or (index == 2 and vector.y or vector.z)
end

function B.Orient(mins, maxs, across, normal, fixed)
	local size = maxs - mins
	local vectors = {}
	local long, thin

	if (fixed) then
		thin = fixed

		long = (Axis(size, 1) >= Axis(size, 2)) and 1 or 2
	else
		long = 1

		for index = 2, 3 do
			if (Axis(size, index) > Axis(size, long)) then
				long = index
			end
		end

		thin = nil

		for index = 1, 3 do
			if (index != long and (!thin or Axis(size, index) < Axis(size, thin))) then
				thin = index
			end
		end
	end

	local third = 6 - long - thin

	vectors[long] = across
	vectors[thin] = normal

	if (thin == long % 3 + 1) then
		vectors[third] = vectors[long]:Cross(vectors[thin])
	else
		vectors[third] = vectors[thin]:Cross(vectors[long])
	end

	local angles = vectors[1]:AngleEx(vectors[3])
	local center = (mins + maxs) * 0.5
	local offset = vectors[1] * center.x + vectors[2] * center.y + vectors[3] * center.z

	return angles, offset, Axis(size, thin) * 0.5, vectors
end

function B.GetLeaves(door)
	if (NETWORK.door and NETWORK.door.GetLeaves) then
		return NETWORK.door.GetLeaves(door)
	end

	return {door}
end

function B.GetBoards(door)
	local list = {}

	if (!IsValid(door)) then
		return list
	end

	local leaves = {}

	for _, leaf in ipairs(B.GetLeaves(door)) do
		leaves[leaf] = true
	end

	for _, entity in ipairs(ents.FindByClass("nw_barricade")) do
		local target = entity.GetDoor and entity:GetDoor()

		if (IsValid(target) and leaves[target] and entity:GetDurability() > 0) then
			list[#list + 1] = entity
		end
	end

	return list
end

function B.IsDoorBoarded(door)
	if (!NETWORK.door or !NETWORK.door.IsDoor(door)) then
		return false
	end

	return #B.GetBoards(door) > 0
end

function B.GetPadlock(door)
	if (!IsValid(door)) then
		return
	end

	local leaves = {}

	for _, leaf in ipairs(B.GetLeaves(door)) do
		leaves[leaf] = true
	end

	for _, entity in ipairs(ents.FindByClass("nw_padlock")) do
		local target = entity.GetDoor and entity:GetDoor()

		if (IsValid(target) and leaves[target]) then
			return entity
		end
	end
end

function B.IsDoorSealed(door)
	if (!NETWORK.door or !NETWORK.door.IsDoor(door)) then
		return
	end

	if (B.IsDoorBoarded(door)) then
		return "boarded"
	end

	local padlock = B.GetPadlock(door)

	if (IsValid(padlock) and padlock:GetLocked()) then
		return "padlock", padlock
	end
end

local UP = Vector(0, 0, 1)

B.boardLayout = {
	{height = 0.18, tilt = 7},
	{height = -0.16, tilt = -9},
	{height = 0.4, tilt = 3}
}

function B.DoorBoardTransform(door, index, eyePos, mins, maxs, rotation)
	local doorMins, doorMaxs = door:OBBMins(), door:OBBMaxs()
	local size = doorMaxs - doorMins
	local center = door:LocalToWorld(door:OBBCenter())
	local forward, left, up = door:GetForward(), -door:GetRight(), door:GetUp()
	local normal, across, half

	if (size.x <= size.y) then
		normal, across, half = forward, left, size.x * 0.5
	else
		normal, across, half = left, forward, size.y * 0.5
	end

	if ((eyePos - center):Dot(normal) < 0) then
		normal = -normal
	end

	local layout = B.boardLayout[math.Clamp(index, 1, #B.boardLayout)]
	local tilt = layout.tilt + (rotation or 0)
	local tilted = across:Angle()

	tilted:RotateAroundAxis(normal, tilt)
	across = tilted:Forward()

	local angles, offset, thickness = B.Orient(mins, maxs, across, normal)
	local target = center + normal * (half + thickness + 0.6) +
		up * (size.z * layout.height)

	return target - offset, angles
end

function B.GetSpot(client, data, rotation)
	rotation = rotation or 0

	local start = client:GetShootPos()
	local aim = client:GetAimVector()
	local trace = util.TraceLine({
		start = start,
		endpos = start + aim * B.range,
		filter = client,
		mask = MASK_SOLID
	})

	local model = B.PickModel(data)
	local mins, maxs = B.GetBounds(model)
	local fallbackAngles = Angle(0, client:EyeAngles().y + rotation, 0)

	if (!trace.Hit or trace.HitSky) then
		return trace.HitPos, fallbackAngles, false
	end

	if (data.bBoard) then
		local entity = trace.Entity

		if (IsValid(entity) and entity:GetClass() == "nw_barricade" and
			entity.GetDoor and IsValid(entity:GetDoor())) then
			entity = entity:GetDoor()
		end

		if (NETWORK.door and NETWORK.door.IsDoor(entity)) then
			local count = #B.GetBoards(entity)

			if (count >= B.maxBoards) then
				return trace.HitPos, fallbackAngles, false, entity
			end

			local position, angles = B.DoorBoardTransform(entity, count + 1, start, mins,
				maxs, rotation)

			return position, angles, true, entity
		end

		if (math.abs(trace.HitNormal.z) > 0.3 or !trace.HitWorld) then
			return trace.HitPos, fallbackAngles, false
		end

		local normal = trace.HitNormal
		local across = normal:Cross(UP):GetNormalized()
		local turned = across:Angle()

		turned:RotateAroundAxis(normal, rotation)
		across = turned:Forward()

		local angles, offset, thickness = B.Orient(mins, maxs, across, normal)

		return trace.HitPos + normal * (thickness + 0.6) - offset, angles, true
	end

	if (trace.HitNormal.z < 0.7) then
		return trace.HitPos, fallbackAngles, false
	end

	local yaw = Angle(0, client:EyeAngles().y + rotation, 0)
	local angles, offset = B.Orient(mins, maxs, yaw:Right(), UP, 3)
	local position = trace.HitPos - Vector(offset.x, offset.y, 0)

	position.z = trace.HitPos.z - mins.z + (data.offset or 0)

	local size = maxs - mins
	local radius = math.max(math.min(size.x, size.y) * 0.4, 4)
	local height = math.max(size.z - 6, 8)
	local base = trace.HitPos + Vector(0, 0, 4)
	local hull = util.TraceHull({
		start = base,
		endpos = base,
		mins = Vector(-radius, -radius, 0),
		maxs = Vector(radius, radius, height),
		filter = client,
		mask = MASK_SOLID
	})

	if (hull.Hit or hull.StartSolid) then
		return position, angles, false
	end

	return position, angles, true
end

B.Register("sandbags", {
	name = "barricadeSandbags",
	item = "barricade_sandbags",
	models = {
		"models/props_c17/concrete_barrier001a.mdl",
		"models/props_debris/barricade_short01a.mdl",
		"models/props_wasteland/barricade001a.mdl"
	},
	health = 600,
	placeTime = 5,
	pickupTime = 4,
	material = "concrete",
	repair = {items = {trash_bag = 1}, amount = 150, time = 3},
	damageScale = {bullet = 0.6, blast = 1.6, club = 0.5}
})

B.Register("metal", {
	name = "barricadeMetal",
	item = "barricade_metal",

	models = {
		"models/props_debris/metal_panel01a.mdl",
		"models/props_debris/metal_panel02a.mdl",
		"models/props_c17/concrete_barrier001a.mdl",
		"models/props_wasteland/interior_fence002d.mdl"
	},
	health = 900,
	placeTime = 6,
	pickupTime = 5,
	material = "metal",
	repair = {items = {scrap = 2}, amount = 200, time = 4},
	damageScale = {bullet = 0.45, blast = 1.4, club = 0.4}
})

B.Register("planks", {
	name = "barricadePlanks",
	item = "planks",
	models = {
		"models/props_debris/wood_board04a.mdl",
		"models/props_debris/wood_board05a.mdl",
		"models/props_debris/wood_board06a.mdl",
		"models/props_junk/wood_pallet001a.mdl"
	},
	health = 250,
	placeTime = 3,
	pickupTime = 3,
	material = "wood",
	bBoard = true,
	repair = {items = {scrap = 1}, amount = 80, time = 2.5},
	damageScale = {bullet = 0.8, blast = 2, club = 1.3}
})

NETWORK.padlock = NETWORK.padlock or {}

local P = NETWORK.padlock

P.range = 90
P.placeTime = 3
P.health = 200
P.models = {
	"models/props_c17/padlock001a.mdl",
	"models/props_wasteland/prison_padlock001a.mdl"
}
P.surfaceOffset = 2.5
P.angleOffset = Angle(0, 0, 0)

function P.GetModel()
	if (P.model) then
		return P.model
	end

	for _, path in ipairs(P.models) do
		if (file.Exists(path, "GAME")) then
			P.model = path

			return path
		end
	end

	P.model = P.models[1]

	return P.model
end

function P.ComputePosition(door, hitPos, hitNormal)
	local position = hitPos
	local index = door:LookupBone("handle")

	if (index and index >= 0) then
		local bone = door:GetBonePosition(index)

		if (bone and bone:DistToSqr(hitPos) < 48 * 48) then
			position = bone + hitNormal * ((bone - hitPos):Dot(-hitNormal))
		end
	end

	local angles = hitNormal:Angle()

	angles:RotateAroundAxis(angles:Up(), P.angleOffset.y)
	angles:RotateAroundAxis(angles:Right(), P.angleOffset.p)
	angles:RotateAroundAxis(angles:Forward(), P.angleOffset.r)

	return position + hitNormal * P.surfaceOffset, angles
end

local function IsBarricade(entity)
	return IsValid(entity) and entity:GetClass() == "nw_barricade"
end

local function InsideBarricade(position)
	for _, entity in ipairs(ents.FindInSphere(position, 4)) do
		if (IsBarricade(entity)) then
			local localPos = entity:WorldToLocal(position)
			local mins, maxs = entity:OBBMins(), entity:OBBMaxs()

			if (localPos:WithinAABox(mins - Vector(2, 2, 2), maxs + Vector(2, 2, 2))) then
				return true
			end
		end
	end

	return false
end

hook.Add("EntityFireBullets", "nwBarricadeBlock", function(shooter, data)
	if (!data or !data.Src or !data.Dir) then
		return
	end

	if (InsideBarricade(data.Src)) then
		return false
	end

	local distance = data.Distance or 56756
	local ignore = {shooter}

	if (IsValid(data.IgnoreEntity)) then
		ignore[2] = data.IgnoreEntity
	end

	local trace = util.TraceLine({
		start = data.Src,
		endpos = data.Src + data.Dir:GetNormalized() * distance,
		filter = ignore,
		mask = bit.bor(MASK_SHOT, CONTENTS_GRATE)
	})

	if (IsBarricade(trace.Entity)) then
		data.Distance = math.max(trace.Fraction * distance + 2, 1)

		return true
	end
end)

hook.Add("TFA_Bullet_Penetrate", "nwBarricadeBlock", function(weapon, attacker, trace)
	if (istable(trace) and IsBarricade(trace.Entity)) then
		return false
	end
end)
