-- Focus mode (client): the camera flies to the fabricator display and floats a little toward the
-- cursor; the mouse moves a cursor on the screen, LMB clicks, E feeds resin, «ЗАВЕРШИТЬ» leaves.
-- While focused the HUD and the view model are hidden and the player does not move.
local C = CFRework
local S = C.State
local F = {cursor = {512, 256}, blend = 0}
C.FocusState = F

function C.FocusEnt()
	local e = F.ent
	if IsValid(e) then return e end
end

net.Receive('cf_rework_focus', function()
	local e = net.ReadEntity()
	if IsValid(e) then
		if not IsValid(F.ent) then F.cursor = {C.Layout.W * 0.5, C.Layout.H * 0.45} end
		F.ent = e
	else
		-- the click that left the screen must not become a shot: hold fire until the button is up
		if IsValid(F.ent) then F.holdFire = true end
		F.ent = nil
	end
end)

-- the cursor follows the mouse instead of the view
hook.Add('InputMouseApply', 'CFReworkFocus', function(cmd, x, y)
	if not C.FocusEnt() then return end
	local k = 0.55 * (GetConVarNumber('sensitivity') / 3)
	F.cursor[1] = math.Clamp(F.cursor[1] + x * k, 0, C.Layout.W)
	F.cursor[2] = math.Clamp(F.cursor[2] + y * k, 0, C.Layout.H)
	cmd:SetMouseX(0)
	cmd:SetMouseY(0)
	return true
end)

-- no walking/shooting while at the screen; LMB becomes a click
local wasDown = false
hook.Add('CreateMove', 'CFReworkFocus', function(cmd)
	local e = C.FocusEnt()
	if not e then
		wasDown = false
		if F.holdFire then
			if bit.band(cmd:GetButtons(), bit.bor(IN_ATTACK, IN_ATTACK2)) ~= 0 then
				cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(bit.bor(IN_ATTACK, IN_ATTACK2))))
			else
				F.holdFire = nil
			end
		end
		return
	end
	local down = bit.band(cmd:GetButtons(), IN_ATTACK) ~= 0
	if down and not wasDown then
		net.Start('cf_rework_press')
		net.WriteFloat(F.cursor[1])
		net.WriteFloat(F.cursor[2])
		net.SendToServer()
	end
	wasDown = down
	cmd:ClearMovement()
	cmd:SetButtons(bit.band(cmd:GetButtons(), IN_USE))
end)

-- camera target for the current stage (world origin, angles)
local function target(e, eye)
	local origin, right, down, normal, _, scale = C.ScreenWorld(e)
	if not origin then return eye, (e:GetPos() - eye):Angle() end
	local W, H = C.Layout.W * scale, C.Layout.H * scale
	local center = origin + right * (W * 0.5) + down * (H * 0.5)
	local u = F.cursor[1] / C.Layout.W - 0.5
	local v = F.cursor[2] / C.Layout.H - 0.5
	local st = e:GetStage()
	local look, pos
	if st == S.PRINT then
		-- watch the chamber print
		-- watch the bay print from the working side (+X) of the station
		local item = C.ItemPoint(e)
		look = item
		pos = item + e:GetForward() * 30 + e:GetUp() * 16 - e:GetRight() * 8
	else
		local dist = 27
		look = center
		-- the camera drifts toward the cursor: lower-left on the screen moves it lower-left
		pos = look + normal * dist + right * (u * 4.5) + down * (v * 3.2)
		look = look + right * (u * W * 0.22) + down * (v * H * 0.22)
	end
	return pos, (look - pos):Angle()
end

local last
hook.Add('CalcView', 'CFReworkFocus', function(p, origin, angles, fov)
	local e = C.FocusEnt()
	local dt = FrameTime()
	F.blend = math.Clamp(F.blend + (e and dt or -dt) * 2.8, 0, 1)
	if e then F.lastEnt = e end
	local src = e or F.lastEnt
	if F.blend <= 0 or not IsValid(src) then last = nil return end
	local pos, ang = target(src, origin)
	if last then
		local k = math.min(dt * 7, 1)
		pos = LerpVector(k, last.pos, pos)
		ang = LerpAngle(k, last.ang, ang)
	end
	last = {pos = pos, ang = ang}
	local b = C.M.smooth(F.blend)
	return {origin = LerpVector(b, origin, pos), angles = LerpAngle(b, angles, ang), fov = Lerp(b, fov, 62), drawviewer = false}
end)

hook.Add('HUDShouldDraw', 'CFReworkFocus', function(name)
	if F.blend > 0 then return false end
end)

hook.Add('PreDrawViewModel', 'CFReworkFocus', function()
	if F.blend > 0 then return true end
end)

-- soft click when the cursor moves onto another button
local lastHover
hook.Add('Think', 'CFReworkFocusHover', function()
	local e = C.FocusEnt()
	if not e then lastHover = nil return end
	local b = C.Layout.ButtonAt(e:GetStage(), e:GetTab(), F.cursor[1], F.cursor[2])
	local key = b and (b.id .. (b.arg or '')) or nil
	if key and key ~= lastHover then
		surface.PlaySound(C.ClickSounds[math.random(3, 4)])
	end
	lastHover = key
end)

-- cursor for the screen drawing (pixel space), or nil when this entity is not focused
function C.FocusCursor(e)
	if F.ent == e and IsValid(e) then return F.cursor end
end
