NETWORK.movement = NETWORK.movement or {}

NETWORK.movement.walkSpeed = 135
NETWORK.movement.runSpeed = 240
NETWORK.movement.slowSpeed = 90

NETWORK.movement.crouchFraction = 0.7
NETWORK.movement.duckSpeed = 0.35
NETWORK.movement.unDuckSpeed = 0.4
NETWORK.movement.ladderSpeed = 90
NETWORK.movement.jumpPower = 150
NETWORK.movement.jumpCooldown = 0.45

NETWORK.movement.airSpeedCap = 190
NETWORK.movement.stepSize = 18

function NETWORK.movement.GetSpeeds(client)
	local walk, run = NETWORK.movement.walkSpeed, NETWORK.movement.runSpeed
	local hooks = hook.GetTable()["NetworkMovementSpeed"] or {}
	local ids = table.GetKeys(hooks)

	table.sort(ids, function(a, b)
		return tostring(a) < tostring(b)
	end)

	for _, id in ipairs(ids) do
		local callback = hooks[id]
		local bOk, newWalk, newRun

		if (isstring(id)) then
			bOk, newWalk, newRun = pcall(callback, client, walk, run)
		elseif (IsValid(id)) then
			bOk, newWalk, newRun = pcall(callback, id, client, walk, run)
		end

		if (bOk and isnumber(newWalk)) then
			walk = newWalk
			run = isnumber(newRun) and newRun or run
		elseif (bOk == false) then
			ErrorNoHalt("[Network] NetworkMovementSpeed/" .. tostring(id) .. ": " ..
				tostring(newWalk) .. "\n")
		end
	end

	return math.max(math.Round(walk), 1), math.max(math.Round(run), 1)
end

function NETWORK.movement.Apply(client)
	if (!IsValid(client)) then
		return
	end

	local config = NETWORK.movement
	local walk, run = NETWORK.movement.GetSpeeds(client)

	client:SetWalkSpeed(walk)
	client:SetRunSpeed(math.max(run, walk))
	client:SetSlowWalkSpeed(math.min(config.slowSpeed, walk))
	client:SetMaxSpeed(math.max(run, walk))
	client:SetCrouchedWalkSpeed(config.crouchFraction)
	client:SetDuckSpeed(config.duckSpeed)
	client:SetUnDuckSpeed(config.unDuckSpeed)
	client:SetLadderClimbSpeed(config.ladderSpeed)
	client:SetJumpPower(config.jumpPower)
	client:SetStepSize(config.stepSize)
end

hook.Add("SetupMove", "nwMovement", function(client, mv, cmd)
	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local config = NETWORK.movement
	local velocity = mv:GetVelocity()

	if (client:IsExhausted() and client:IsOnGround()) then
		mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(bit.bor(IN_SPEED, IN_JUMP))))
		mv:SetMaxSpeed(config.walkSpeed)
		mv:SetMaxClientSpeed(config.walkSpeed)
	end

	if (client:IsOnGround()) then
		if (mv:KeyDown(IN_JUMP)) then
			if ((client.nwNextJump or 0) > CurTime()) then
				mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
			else
				client.nwNextJump = CurTime() + config.jumpCooldown
			end
		end

		return
	end

	local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)

	local cap = math.max(config.airSpeedCap, config.runSpeed * 1.15)

	if (speed > cap) then

		local scale = math.max(cap / speed, 1 - FrameTime() * 4)

		mv:SetVelocity(Vector(velocity.x * scale, velocity.y * scale, velocity.z))
	end
end)
