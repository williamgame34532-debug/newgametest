NETWORK.npclook = NETWORK.npclook or {}

local LOOK = NETWORK.npclook

LOOK.range = 220
LOOK.speed = 5
LOOK.maxYaw = 60
LOOK.maxPitch = 30

local function FindTarget(entity)
	local origin = entity:GetPos()
	local forward = entity:GetForward()
	local best, bestDistance

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or client:GetNoDraw()) then
			continue
		end

		local offset = client:GetPos() - origin
		local distance = offset:Length()

		if (distance > LOOK.range) then
			continue
		end

		offset.z = 0

		if (distance > 40 and forward:Dot(offset:GetNormalized()) < -0.2) then
			continue
		end

		if (!bestDistance or distance < bestDistance) then
			best, bestDistance = client, distance
		end
	end

	return best
end

function LOOK.Update(entity)
	if (!IsValid(entity)) then
		return
	end

	local now = RealTime()
	local delta = math.min(now - (entity.nwLookTime or now), 0.1)

	entity.nwLookTime = now

	if ((entity.nwLookNext or 0) < now) then
		entity.nwLookNext = now + 0.25
		entity.nwLookTarget = FindTarget(entity)
	end

	local target = entity.nwLookTarget
	local wantYaw, wantPitch = 0, 0
	local headBone = entity.nwHeadBone

	if (headBone == nil) then
		headBone = entity:LookupBone("ValveBiped.Bip01_Head1") or false
		entity.nwHeadBone = headBone
	end

	local headPos = headBone and entity:GetBonePosition(headBone) or
		(entity:GetPos() + Vector(0, 0, 64))

	if (IsValid(target)) then
		local eye = target:EyePos()
		local angle = entity:WorldToLocalAngles((eye - headPos):Angle())

		wantYaw = math.Clamp(math.NormalizeAngle(angle.y), -LOOK.maxYaw, LOOK.maxYaw)
		wantPitch = math.Clamp(math.NormalizeAngle(angle.p), -LOOK.maxPitch, LOOK.maxPitch)

		entity:SetEyeTarget(eye)
	end

	local fraction = math.Clamp(delta * LOOK.speed, 0, 1)

	entity.nwLookYaw = Lerp(fraction, entity.nwLookYaw or 0, wantYaw)
	entity.nwLookPitch = Lerp(fraction, entity.nwLookPitch or 0, wantPitch)

	local yawIndex = entity:LookupPoseParameter("head_yaw")
	local pitchIndex = entity:LookupPoseParameter("head_pitch")

	if (yawIndex and yawIndex >= 0) then
		local minimum, maximum = entity:GetPoseParameterRange(yawIndex)

		entity:SetPoseParameter("head_yaw", math.Clamp(entity.nwLookYaw, minimum, maximum))

		if (pitchIndex and pitchIndex >= 0) then
			local pMin, pMax = entity:GetPoseParameterRange(pitchIndex)

			entity:SetPoseParameter("head_pitch",
				math.Clamp(entity.nwLookPitch, pMin, pMax))
		end

		entity:InvalidateBoneCache()

		return
	end

	if (headBone) then
		entity:ManipulateBoneAngles(headBone,
			Angle(0, -entity.nwLookPitch * 0.8, entity.nwLookYaw * 0.8))
	end
end
