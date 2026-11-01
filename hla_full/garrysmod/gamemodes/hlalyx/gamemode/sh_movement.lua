-- Movement: walking pace, sprint and jump limited by stamina (shown on the HUD).
local M = HLA.Menu
local ST = M.Stamina

if SERVER then
	hook.Add('PlayerSpawn', 'HLAMovement', function(p)
		local mv = M.Move
		p:SetWalkSpeed(mv.walk)
		p:SetRunSpeed(mv.run)
		p:SetSlowWalkSpeed(mv.slow)
		p:SetCrouchedWalkSpeed(mv.crouch)
		p:SetJumpPower(mv.jump)
		p:SetDTFloat(30, ST.max)
		p:SetDTBool(30, false)
	end)
end

-- stamina and the tired flag live in DT slots 30: they are predicted, so the client computes the
-- same values as the server every tick (NW2 vars changed by the server made the movement stutter)
local function stamina(p) return p:GetDTFloat(30) end
HLA.Stamina = stamina

hook.Add('SetupMove', 'HLAStamina', function(p, mv, cmd)
	if p:GetNWBool('hla_in_menu') then
		mv:SetForwardSpeed(0) mv:SetSideSpeed(0) mv:SetUpSpeed(0)
		mv:SetButtons(0)
		return
	end
	if not p:Alive() or p:GetMoveType() == MOVETYPE_NOCLIP then return end
	local s = stamina(p)
	local dt = FrameTime() -- inside SetupMove this is the tick interval on both sides
	local moving = mv:GetForwardSpeed() ~= 0 or mv:GetSideSpeed() ~= 0
	local onGround = p:IsOnGround()
	-- networked, so the client predicts exactly what the server allows (no rubber-banding when tired)
	local tired = p:GetDTBool(30)
	local sprint = mv:KeyDown(IN_SPEED) and moving and not p:Crouching()

	if sprint and (tired or s <= 0) then
		-- out of breath: no sprint until stamina recovers a little
		mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_SPEED)))
		mv:SetMaxClientSpeed(M.Move.walk)
		sprint = false
	end
	if mv:KeyPressed(IN_JUMP) and onGround then
		if tired or s < ST.jump then
			mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
		else
			s = s - ST.jump
			p:SetDTFloat(31, CurTime())
		end
	end
	if sprint and onGround then
		s = s - ST.drain * dt
		p:SetDTFloat(31, CurTime())
	elseif CurTime() - p:GetDTFloat(31) > ST.regenDelay then
		s = s + ST.regen * dt * (moving and 0.6 or 1)
	end
	s = math.Clamp(s, 0, ST.max)
	if s <= 0 then p:SetDTBool(30, true) elseif s >= ST.recover then p:SetDTBool(30, false) end
	p:SetDTFloat(30, s)
end)

-- server-wide acceleration: start and stop take a moment, little steering in the air
if SERVER then
	hook.Add('Initialize', 'HLAMoveAccel', function()
		RunConsoleCommand('sv_accelerate', tostring(M.Move.accel))
		RunConsoleCommand('sv_airaccelerate', tostring(M.Move.airaccel))
	end)
end

-- no speed from jumping: the HL2 movement adds a boost to every jump while running, and jumps one
-- after another kept gaining speed. In the air the horizontal speed stays at most what it was on
-- the ground (and never above the run speed). Predicted, the same on client and server.
hook.Add('FinishMove', 'HLANoJumpBoost', function(p, mv)
	if p:GetMoveType() ~= MOVETYPE_WALK then return end
	local vel = mv:GetVelocity()
	local flat = Vector(vel.x, vel.y, 0)
	local speed = flat:Length()
	if p:IsOnGround() then
		p.HLAGroundSpeed = speed
		return
	end
	local cap = math.min((p.HLAGroundSpeed or speed) * M.Move.airMax, p:GetRunSpeed())
	cap = math.max(cap, p:GetWalkSpeed() * 0.5)
	if speed > cap + 1 then
		flat:Mul(cap / speed)
		mv:SetVelocity(Vector(flat.x, flat.y, vel.z))
	end
end)
