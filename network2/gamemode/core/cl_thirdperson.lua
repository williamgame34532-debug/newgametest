-- Third person camera: over the shoulder, smoothed, never inside walls. With a raised weapon it
-- moves in closer, and the view always looks at the point the player is really aiming at, so
-- the centre of the screen is where shots land even though the camera is off to the side.
--   F3                  third / first person   (keys: sh_keys.lua, changeable in Бинды)
--   F4                  switch shoulder
--   Alt + wheel         distance
-- Convars: nw_thirdperson, nw_tp_distance, nw_tp_right, nw_tp_up, nw_tp_fov
-- With the inventory open (also from first person) the camera swings round in front of the
-- character, keeps it on the right of the screen, breathes a little and leans in while an item
-- is dragged.

local enabled = CreateClientConVar("nw_thirdperson", "1", true, false, "Вид от третьего лица")
local distance = CreateClientConVar("nw_tp_distance", "70", true, false, "Расстояние камеры", 30, 160)
local right = CreateClientConVar("nw_tp_right", "18", true, false, "Смещение камеры вбок")
local up = CreateClientConVar("nw_tp_up", "4", true, false, "Смещение камеры вверх")

local HULL = Vector(5, 5, 5)

local state = {pos = nil, dist = 0, side = 1, raise = 0}

local function Active(client)
	return enabled:GetBool() and IsValid(client) and client:Alive() and !client:InVehicle() and
		client:GetViewEntity() == client and client:GetObserverMode() == OBS_MODE_NONE
end

local function AimPoint(client, origin, angles)
	local trace = util.TraceLine({
		start = origin,
		endpos = origin + angles:Forward() * 8192,
		filter = client,
		mask = MASK_SHOT
	})

	return trace.HitPos
end

-- the inventory pose: in front of the character, the character on the right of the screen
local function InventoryView(client, fov)
	local inventory = NW.inventory or {}
	local scale = client:GetModelScale() or 1
	local yaw = Angle(0, inventory.yaw or client:EyeAngles().y, 0)
	local forward, right = yaw:Forward(), yaw:Right()
	local pivot = client:GetPos() + Vector(0, 0, 46 * scale)
	local lean = inventory.dragCamera or 0
	local t = RealTime()
	local want = pivot + forward * (96 - lean * 14) * scale - right * 12 * scale + Vector(0, 0, 9 * scale)

	-- slow breathing of the camera
	want = want + Vector(0, 0, math.sin(t * 0.7) * 1.1) + right * math.sin(t * 0.43) * 1.6

	local trace = util.TraceHull({
		start = pivot,
		endpos = want,
		filter = client,
		mins = -HULL,
		maxs = HULL,
		mask = MASK_SOLID_BRUSHONLY
	})

	local look = pivot + right * 30 * scale - Vector(0, 0, 4 * scale)

	return trace.HitPos, (look - trace.HitPos):Angle(), fov - 8 - lean * 3
end

local function ThirdPersonView(self, client, origin, angles, fov, znear, zfar)
	if (!Active(client)) then
		state.pos = nil

		return self.BaseClass.CalcView(self, client, origin, angles, fov, znear, zfar)
	end

	local frame = FrameTime()
	local bRaised = client:IsWeaponRaised()

	state.raise = Lerp(math.Clamp(frame * 6, 0, 1), state.raise, bRaised and 1 or 0)
	state.side = Lerp(math.Clamp(frame * 8, 0, 1), state.side, state.wantSide or 1)

	local dist = distance:GetFloat() * (1 - state.raise * 0.35)
	local side = right:GetFloat() * state.side * (1 + state.raise * 0.15)

	-- crouching lowers the eye already; keep the camera a bit above it
	local eye = client:EyePos()
	local target = eye - angles:Forward() * dist + angles:Right() * side + angles:Up() * up:GetFloat()

	-- keep the camera out of walls: hull trace from the eye
	local trace = util.TraceHull({
		start = eye,
		endpos = target,
		filter = client,
		mins = -HULL,
		maxs = HULL,
		mask = MASK_SOLID_BRUSHONLY
	})

	local pos = trace.HitPos

	-- the camera stays rigidly attached to the eye (a camera that trails behind makes the moving
	-- character look jerky); only the distance to it is smoothed, and it snaps in at once when a
	-- wall comes closer
	local want = pos:Distance(eye)

	if (!state.dist or state.dist == 0 or want < state.dist) then
		state.dist = want
	else
		state.dist = Lerp(math.Clamp(frame * 8, 0, 1), state.dist, want)
	end

	local direction = pos - eye

	direction:Normalize()
	state.pos = eye + direction * state.dist

	-- look at what the player aims at: shots land in the centre of the screen
	local aim = AimPoint(client, eye, angles)
	local view = (aim - state.pos):Angle()

	view.r = angles.r

	return {
		origin = state.pos,
		angles = view,
		fov = fov,
		znear = znear,
		zfar = zfar,
		drawviewer = true
	}
end

local function InventoryWeight()
	return NW.inventory and NW.inventory.CameraWeight and NW.inventory.CameraWeight() or 0
end

-- first person in a pose (sh_acts.lua): the view sits in the model's eyes and the body is seen
-- (the head is hidden for the local view so it does not cover the screen)
local function PoseEyes(client)
	return !enabled:GetBool() and IsValid(client) and client:Alive() and client.GetAct and client:GetAct() != nil and
		client:GetViewEntity() == client
end

local hiddenHead

hook.Add("Think", "nwPoseHead", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local head = client:LookupBone("ValveBiped.Bip01_Head1")
	local hide = PoseEyes(client)

	if (head and hide != (hiddenHead == true)) then
		client:ManipulateBoneScale(head, hide and Vector(0, 0, 0) or Vector(1, 1, 1))
		hiddenHead = hide
	end
end)

function GM:CalcView(client, origin, angles, fov, znear, zfar)
	local view = ThirdPersonView(self, client, origin, angles, fov, znear, zfar) or {}

	if (PoseEyes(client)) then
		local attachment = client:LookupAttachment("eyes")
		local eyes = attachment and attachment > 0 and client:GetAttachment(attachment)

		if (eyes) then
			view.origin = eyes.Pos + eyes.Ang:Forward() * 2
			view.angles = angles
			view.drawviewer = true
			view.znear = 2
		end
	end
	local weight = IsValid(client) and client:Alive() and !client:InVehicle() and InventoryWeight() or 0

	if (weight > 0.001) then
		local pos, ang, invFov = InventoryView(client, fov)

		view.origin = LerpVector(weight, view.origin or origin, pos)
		view.angles = LerpAngle(weight, view.angles or angles, ang)
		view.fov = Lerp(weight, view.fov or fov, invFov)
		view.drawviewer = true
	end

	return view
end

function GM:ShouldDrawLocalPlayer(client)
	return Active(client) or InventoryWeight() > 0.001 or PoseEyes(client)
end

hook.Add("NWKey", "nwThirdPerson", function(id)
	if (id == "camera") then
		RunConsoleCommand("nw_thirdperson", enabled:GetBool() and "0" or "1")
	elseif (id == "shoulder") then
		state.wantSide = -(state.wantSide or 1)
	end
end)

hook.Add("PlayerBindPress", "nwThirdPerson", function(client, bind, bPressed)
	if (!bPressed) then
		return
	end

	bind = string.lower(bind)

	-- F3 / F4 are the framework's keys now (sh_keys.lua): the old binds do nothing
	if (string.find(bind, "gm_showspare1", 1, true) or string.find(bind, "gm_showspare2", 1, true)) then
		return true
	end

	if (enabled:GetBool() and input.IsKeyDown(KEY_LALT) and (bind == "invnext" or bind == "invprev")) then
		local value = distance:GetFloat() + (bind == "invnext" and 8 or -8)

		RunConsoleCommand("nw_tp_distance", tostring(math.Clamp(value, 30, 160)))

		return true
	end
end)

-- the third person camera needs no view model
function GM:PreDrawViewModel(viewModel, client, weapon)
	if (Active(LocalPlayer()) or InventoryWeight() > 0.001 or PoseEyes(LocalPlayer())) then
		return true
	end

	return self.BaseClass.PreDrawViewModel and self.BaseClass.PreDrawViewModel(self, viewModel, client, weapon)
end
