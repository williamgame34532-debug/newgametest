-- Third person over the shoulder: F3 on / off, F4 the other shoulder (also TAB > НАСТРОЙКИ).
-- The camera stays close to the unit and lives a little: it lags behind turns and steps, pulls back and
-- widens when running, comes in when aiming (right mouse), sits lower when crouching, tilts slightly when
-- strafing, slides smoothly from one shoulder to the other and never goes into walls.
local TP = {side = 1, dist = 0, pos = nil, roll = 0, fov = 0}
HLA.ThirdPerson = TP

local cvOn = CreateClientConVar('hla_thirdperson', '0', true, false, 'Third person (0/1), F3')
local cvSide = CreateClientConVar('hla_tp_side', '1', true, false, 'Shoulder: 1 right, -1 left, F4')

function TP.Active(p)
	p = p or LocalPlayer()
	return cvOn:GetBool() and IsValid(p) and p:Alive() and not p:InVehicle() and p:GetViewEntity() == p
		and p:GetObserverMode() == OBS_MODE_NONE and not p:GetNWBool('hla_in_menu')
		and not (HLA.TerminalFocus and HLA.TerminalFocus.blend > 0)
		and not (CFRework and CFRework.FocusState and CFRework.FocusState.blend > 0)
end

function TP.Toggle()
	surface.PlaySound('hla/ui/textline_end.wav')
	local v = cvOn:GetBool() and '0' or '1'
	-- a short black blink around the camera change
	if HLA.FadeSwap then HLA.FadeSwap(function() RunConsoleCommand('hla_thirdperson', v) end)
	else RunConsoleCommand('hla_thirdperson', v) end
end
function TP.Swap()
	RunConsoleCommand('hla_tp_side', cvSide:GetInt() < 0 and '1' or '-1')
	surface.PlaySound('hla/ui/textline_6.wav')
end
concommand.Add('hla_tp_toggle', TP.Toggle)
concommand.Add('hla_tp_swap', TP.Swap)

-- F3 / F4 (when nothing is being typed)
local was = {}
hook.Add('Think', 'HLAThirdPersonKeys', function()
	if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or gui.IsConsoleVisible() then return end
	for key, fn in pairs({[KEY_F3] = TP.Toggle, [KEY_F4] = TP.Swap}) do
		local down = input.IsKeyDown(key)
		if down and not was[key] then fn() end
		was[key] = down
	end
end)

local function damp(k, dt) return 1 - math.exp(-k * dt) end
local HULL = Vector(5, 5, 5)

function TP.View(p, origin, angles, fov)
	local dt = math.min(FrameTime(), 0.1)
	local vel = p:GetVelocity()
	local speed = vel:Length2D()
	local running = p:KeyDown(IN_SPEED) and speed > p:GetWalkSpeed() * 1.05
	local aiming = p:KeyDown(IN_ATTACK2)
	local crouch = p:Crouching()
	-- the shoulder slides over, the distance breathes with the pace
	TP.side = Lerp(damp(8, dt), TP.side, cvSide:GetInt() < 0 and -1 or 1)
	local want = aiming and 34 or running and 66 or 52
	TP.dist = Lerp(damp(6, dt), TP.dist > 0 and TP.dist or want, want)
	local right, up, fwd = angles:Right(), angles:Up(), angles:Forward()
	local pivot = origin + up * (crouch and -2 or 2)
	local goal = pivot - fwd * TP.dist + right * (aiming and 15 or 19) * TP.side + up * (aiming and 3 or 5)
	-- no camera inside walls: a small hull from the head to the goal
	local tr = util.TraceHull({start = pivot, endpos = goal, mins = -HULL, maxs = HULL, filter = p, mask = MASK_SOLID})
	local pos = tr.HitPos
	-- lag: follows the body a little behind (not past walls: the traced point is the limit)
	if TP.pos and TP.pos:DistToSqr(pos) < 200 * 200 then
		TP.pos = LerpVector(damp(tr.Hit and 40 or 18, dt), TP.pos, pos)
	else
		TP.pos = pos
	end
	-- a slight roll into strafes, a little wider view when running, narrower when aiming
	local strafe = vel:Dot(right) / math.max(p:GetRunSpeed(), 1)
	TP.roll = Lerp(damp(5, dt), TP.roll, -strafe * 2.2)
	TP.fov = Lerp(damp(5, dt), TP.fov, aiming and -10 or running and 5 or 0)
	local ang = Angle(angles.p, angles.y, angles.r + TP.roll)
	return {origin = TP.pos, angles = ang, fov = fov + TP.fov, drawviewer = true, znear = 3}
end

hook.Add('ShouldDrawLocalPlayer', 'HLAThirdPerson', function(p)
	if TP.Active(p) then return true end
end)

-- the crosshair goes where the shots go: the point the eyes aim at, seen from the camera
function TP.AimScreen()
	local p = LocalPlayer()
	local tr = util.TraceLine({start = p:EyePos(), endpos = p:EyePos() + p:GetAimVector() * 8000, filter = p, mask = MASK_SHOT})
	local s = tr.HitPos:ToScreen()
	return s.x, s.y, s.visible
end
