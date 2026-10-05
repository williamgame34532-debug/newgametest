local LP = NETWORK.lockpick

local function Close()
	if (IsValid(LP.game)) then
		LP.game:Remove()
	end

	LP.game = nil
	LP.state = nil
end

net.Receive("nwLockpickStart", function()
	local entity = net.ReadEntity()
	local token = net.ReadUInt(32)
	local stages = net.ReadUInt(3)
	local difficultyName = net.ReadString()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local minigame = NETWORK.minigame

	Close()

	if (!minigame or !minigame.BasePanel) then
		return
	end

	if (IsValid(NETWORK.gui.menu) and NETWORK.gui.menu.Close) then
		NETWORK.gui.menu:Close()
	end

	local state = {
		token = token,
		stages = stages,
		done = 0,
		angle = 90,
		cylinder = 0,
		limit = 0,
		bTurning = false,
		bWaiting = false,
		bFinished = false,
		heldFull = 0,
		jammed = 0,
		shake = 0,
		wear = 0,
		lastTick = 90
	}

	LP.state = state

	local function Cancel()
		if (!state.bFinished) then
			state.bFinished = true

			net.Start("nwLockpickCancel")
				net.WriteUInt(token, 32)
			net.SendToServer()
		end

		Close()
	end

	local panel = minigame.BasePanel(entity, Cancel, function(this)
		LP.game = this
	end)

	local function Try()
		if (state.bFinished) then
			return
		end

		local wait = (state.nextTry or 0) - RealTime()

		state.bWaiting = true

		if (wait > 0) then
			timer.Simple(wait + 0.02, function()
				if (state.bTurning and !state.bFinished and LP.state == state) then
					Try()
				end
			end)

			return
		end

		state.nextTry = RealTime() + LP.tryInterval + 0.03

		net.Start("nwLockpickTry")
			net.WriteUInt(token, 32)
			net.WriteFloat(state.angle)
		net.SendToServer()
	end

	local function StartTurn()
		if (state.bTurning or state.bFinished) then
			return
		end

		state.bTurning = true
		state.limit = 0.12
		state.heldFull = 0
		state.jammed = 0

		Try()
	end

	local function StopTurn()
		state.bTurning = false
		state.bWaiting = false
		state.heldFull = 0
		state.jammed = 0
	end

	panel.OnMousePressed = function(_, code)
		if (code == MOUSE_LEFT) then
			StartTurn()
		end
	end

	panel.OnMouseReleased = function(_, code)
		if (code == MOUSE_LEFT) then
			StopTurn()
		end
	end

	panel.OnKeyCodePressed = function(_, key)
		if (key == KEY_ESCAPE) then
			Cancel()
		elseif (key == KEY_SPACE) then
			StartTurn()
		end
	end

	panel.OnKeyCodeReleased = function(_, key)
		if (key == KEY_SPACE) then
			StopTurn()
		end
	end

	state.Feedback = function(fraction, wear)
		state.bWaiting = false
		state.wear = wear

		if (state.bTurning) then
			state.limit = fraction
		end
	end

	state.Stage = function(done)
		state.done = done
		state.cylinder = 0
		state.limit = 0
		state.bTurning = false
		state.heldFull = 0

		panel:Flash(true)

		surface.PlaySound("doors/door_latch1.wav")
	end

	state.Finish = function(result)
		state.bFinished = true
		state.bTurning = false

		if (result == 1) then
			state.done = state.stages
			state.cylinder = 1

			panel:Flash(true)
			minigame.Sound("done")
		elseif (result == 2) then
			panel:Flash(false)
			state.shake = 1

			surface.PlaySound("physics/metal/metal_solid_impact_bullet1.wav")
		end

		timer.Simple(result == 0 and 0 or 0.6, Close)
	end

	local function Layout(width, height)
		local radius = math.Round(math.min(width, height) * 0.2)

		return width * 0.5, height * 0.54, radius
	end

	panel.Think = function(this)
		this:BaseThink()

		if (!IsValid(this) or state.bFinished) then
			return
		end

		local dt = FrameTime()
		local cx, _, radius = Layout(this:GetWide(), this:GetTall())

		if (!state.bTurning and state.cylinder < 0.02) then
			local mx = this:CursorPos()
			local angle = math.Clamp((mx - (cx - radius * 1.3)) / (radius * 2.6) * 180, 0, 180)

			state.angle = angle

			if (math.abs(angle - state.lastTick) >= 9) then
				state.lastTick = angle

				minigame.Sound("tick")
			end
		end

		if (state.bTurning) then
			local target = state.limit

			state.cylinder = math.Approach(state.cylinder, target, dt * 1.6)

			if (state.cylinder >= target - 0.001 and !state.bWaiting) then
				if (target >= 1) then
					state.heldFull = state.heldFull + dt

					if (state.heldFull >= LP.turnTime and !state.bSentTurn) then
						state.bSentTurn = true

						net.Start("nwLockpickTurn")
							net.WriteUInt(token, 32)
						net.SendToServer()

						timer.Simple(0.5, function()
							state.bSentTurn = false
						end)
					end
				else

					state.jammed = state.jammed + dt
					state.shake = math.max(state.shake, 0.6)

					if (state.jammed >= 0.55) then
						state.jammed = 0

						surface.PlaySound("physics/metal/metal_box_strain" ..
							math.random(1, 4) .. ".wav")

						Try()
					end
				end
			end
		else
			state.cylinder = math.Approach(state.cylinder, 0, dt * 3)
		end

		state.shake = math.max(0, state.shake - dt * 2.5)
	end

	panel.Paint = function(this, width, height)
		local ease = minigame.Veil(this, width, height, L("lockpickTitle"), state.done,
			state.stages, math.floor(state.wear * 5 + 0.001), 5)
		local cx, cy, radius = Layout(width, height)
		local jolt = state.shake > 0 and math.sin(RealTime() * 70) * state.shake * Sc(3) or 0
		local line = math.max(Sc(1), 1)

		draw.SimpleText(L(difficultyName), "nwTagDesc", width * 0.5,
			math.Round(height * 0.12) + Sc(40), ColorAlpha(theme.textDim, 220 * ease),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local plate = math.Round(radius * 1.25)

		surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b, 235 * ease)
		surface.DrawRect(cx - plate, cy - plate, plate * 2, plate * 2)

		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 200 * ease)
		surface.DrawOutlinedRect(cx - plate, cy - plate, plate * 2, plate * 2, line)

		surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 230 * ease)
		surface.DrawRect(cx - plate, cy - plate, plate * 2, math.max(Sc(2), 2))

		for degree = 0, 180, 15 do
			local radian = math.rad(180 + degree)
			local x = cx + math.cos(radian) * radius * 1.12
			local y = cy + math.sin(radian) * radius * 1.12

			surface.SetDrawColor(255, 255, 255, 40 * ease)
			surface.DrawRect(x - Sc(1), y - Sc(1), Sc(3), Sc(3))
		end

		local core = math.Round(radius * 0.55)
		local rotation = -state.cylinder * 90

		draw.NoTexture()

		surface.SetDrawColor(theme.plateBright.r, theme.plateBright.g, theme.plateBright.b,
			250 * ease)
		surface.DrawTexturedRectRotated(cx, cy, core * 2, core * 2, rotation)

		local slotColour = state.cylinder >= 0.999 and theme.positive or theme.textFaint

		surface.SetDrawColor(slotColour.r, slotColour.g, slotColour.b, 240 * ease)
		surface.DrawTexturedRectRotated(cx, cy, math.max(Sc(6), 4), core * 1.3, rotation)

		local radian = math.rad(180 + state.angle)
		local tipX = cx + math.cos(radian) * radius * 0.2
		local tipY = cy + math.sin(radian) * radius * 0.2
		local endX = cx + math.cos(radian) * radius * 1.45 + jolt
		local endY = cy + math.sin(radian) * radius * 1.45
		local pickColour = state.shake > 0.3 and theme.danger or theme.text
		local length = math.Distance(tipX, tipY, endX, endY)

		surface.SetDrawColor(pickColour.r, pickColour.g, pickColour.b, 245 * ease)
		surface.DrawTexturedRectRotated((tipX + endX) * 0.5, (tipY + endY) * 0.5, length,
			math.max(Sc(3), 2), -(180 + state.angle))

		surface.DrawRect(endX - Sc(5), endY - Sc(5), Sc(10), Sc(10))

		local turn = math.rad(state.cylinder * 90)
		local reach = core * 1.3

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 220 * ease)
		surface.DrawTexturedRectRotated(cx - math.sin(turn) * reach, cy + math.cos(turn) * reach,
			math.max(Sc(4), 3), core * 0.9, rotation)

		local barWidth = plate * 2
		local barY = cy + plate + Sc(22)
		local wearColour = state.wear > 0.66 and theme.danger or
			(state.wear > 0.33 and theme.warning or theme.textDim)

		draw.SimpleText(NETWORK.util.Upper(L("lockpickWear")), "nwInvKey", cx - plate,
			barY - Sc(10), ColorAlpha(theme.textFaint, 230 * ease), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 24 * ease)
		surface.DrawRect(cx - plate, barY, barWidth, math.max(Sc(3), 2))

		surface.SetDrawColor(wearColour.r, wearColour.g, wearColour.b, 240 * ease)
		surface.DrawRect(cx - plate, barY, math.Round(barWidth * math.Clamp(state.wear, 0, 1)),
			math.max(Sc(3), 2))

		draw.SimpleText(L("lockpickHint"), "nwTagDesc", width * 0.5,
			math.Round(height * 0.88) + Sc(20), ColorAlpha(theme.textDim, 220 * ease),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

net.Receive("nwLockpickFeedback", function()
	local token = net.ReadUInt(32)
	local fraction = net.ReadFloat()
	local wear = net.ReadFloat()
	local state = LP.state

	if (state and state.token == token and state.Feedback) then
		state.Feedback(fraction, wear)
	end
end)

net.Receive("nwLockpickStage", function()
	local token = net.ReadUInt(32)
	local done = net.ReadUInt(3)
	local state = LP.state

	if (state and state.token == token and state.Stage) then
		state.Stage(done)
	end
end)

net.Receive("nwLockpickEnd", function()
	local token = net.ReadUInt(32)
	local result = net.ReadUInt(2)
	local state = LP.state

	if (state and state.token == token and state.Finish) then
		state.Finish(result)
	end
end)
