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
		p:SetNW2Float('hla_stamina', ST.max)
		p:SetNW2Bool('hla_tired', false)
	end)
end

local function stamina(p) return p:GetNW2Float('hla_stamina', ST.max) end

hook.Add('SetupMove', 'HLAStamina', function(p, mv, cmd)
	if p:GetNWBool('hla_in_menu') then
		mv:SetForwardSpeed(0) mv:SetSideSpeed(0) mv:SetUpSpeed(0)
		mv:SetButtons(0)
		return
	end
	if not p:Alive() or p:GetMoveType() == MOVETYPE_NOCLIP then return end
	local s = stamina(p)
	local dt = FrameTime()
	local moving = mv:GetForwardSpeed() ~= 0 or mv:GetSideSpeed() ~= 0
	local onGround = p:IsOnGround()
	-- networked, so the client predicts exactly what the server allows (no rubber-banding when tired)
	local tired = p:GetNW2Bool('hla_tired', false)
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
		elseif SERVER then
			s = s - ST.jump
			p.HLAStaminaUsed = CurTime()
		end
	end
	if not SERVER then return end
	if sprint and onGround then
		s = s - ST.drain * dt
		p.HLAStaminaUsed = CurTime()
	elseif CurTime() - (p.HLAStaminaUsed or 0) > ST.regenDelay then
		s = s + ST.regen * dt * (moving and 0.6 or 1)
	end
	s = math.Clamp(s, 0, ST.max)
	if s <= 0 then p:SetNW2Bool('hla_tired', true) elseif s >= ST.recover then p:SetNW2Bool('hla_tired', false) end
	if math.abs(s - stamina(p)) > 0.05 then p:SetNW2Float('hla_stamina', s) end
end)
