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

local hud = CreateClientConVar("nw_tp_hud", "1", true, false, "Интерфейс в виде от третьего лица")

-- in a fight (sv_music.lua nwCombat: hurt, hurting, shot at) third person is off for a while
local function InCombat()
	return NW.combatUntil != nil and NW.combatUntil > CurTime()
end

local function Active(client)
	return enabled:GetBool() and !InCombat() and IsValid(client) and client:Alive() and !client:InVehicle() and
		client:GetViewEntity() == client and client:GetObserverMode() == OBS_MODE_NONE
end

NW.thirdPersonActive = function()
	return Active(LocalPlayer())
end

-- the fight takes the camera: said once per fight
local combatSaid = false

hook.Add("Think", "nwThirdPersonCombat", function()
	local now = enabled:GetBool() and InCombat()

	if (now and !combatSaid and NW.notify) then
		NW.notify.Add("Бой: вид от первого лица")
	end

	combatSaid = now
end)

-- no interface while looking from behind (nw_tp_hud 0): the picture alone
hook.Add("HUDShouldDraw", "nwThirdPersonHud", function(name)
	if (!hud:GetBool() and Active(LocalPlayer())) then
		return false
	end
end)

-- the point the player aims at. The camera sits off to the side and looks at it, so a point that
-- jumps close (someone walking past, a carried prop, a thin pole) would swing the whole view for a
-- moment: what is carried and other players do not catch the ray, the distance never goes under
-- 80 units and follows changes smoothly (a quick approach, a gentler step back).
local AIM_MIN = 80

local function AimPoint(client, origin, angles)
	local held = client:GetNW2Entity("nwHeldEntity")
	local trace = util.TraceLine({
		start = origin,
		endpos = origin + angles:Forward() * 8192,
		filter = function(entity)
			return entity != client and entity != held and !entity:IsPlayer() and entity:GetClass() != "prop_ragdoll"
		end,
		mask = MASK_SHOT
	})
	local want = math.max(trace.Fraction * 8192, AIM_MIN)
	local frame = math.min(FrameTime(), 0.1)

	if (!state.aim) then
		state.aim = want
	else
		-- in log space: from 100 to 3000 units as smoothly as from 100 to 200
		local now, goal = math.log(state.aim), math.log(want)
		local rate = goal < now and 10 or 5

		state.aim = math.exp(Lerp(math.Clamp(frame * rate, 0, 1), now, goal))
	end

	return origin + angles:Forward() * state.aim
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

-- first person with a weapon in the hands (not the hands, not a pose): the view from the eyes of the model
-- (it follows the head with the steps and the aiming); the body above is not drawn, the legs below are
-- (cl_legs.lua)
local FREE = {nw_hands = true, gmod_camera = true}

local function WeaponEyes(client)
	if (Active(client) or !IsValid(client) or !client:Alive() or client:InVehicle() or
		client:GetViewEntity() != client or (client.GetAct and client:GetAct() != nil)) then
		return false
	end

	local weapon = client:GetActiveWeapon()

	return IsValid(weapon) and !FREE[weapon:GetClass()]
end

NW.weaponEyes = WeaponEyes

local eyeOffset = Vector(0, 0, 0)

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
	-- a weapon in the hands in first person: from the eyes of the model (smoothed: the attachment jitters)
	if (WeaponEyes(client)) then
		-- the body is not drawn: its bones are set up here for the attachment
		client:SetupBones()

		local attachment = client:LookupAttachment("eyes")
		local eyes = attachment and attachment > 0 and client:GetAttachment(attachment)

		if (eyes) then
			local wanted = eyes.Pos + angles:Forward() * 2 - origin

			-- not too far from the real eyes (a strange model)
			if (wanted:LengthSqr() < 24 * 24) then
				eyeOffset = LerpVector(math.Clamp(FrameTime() * 18, 0, 1), eyeOffset, wanted)
				view.origin = origin + eyeOffset
				view.angles = view.angles or angles
				view.drawviewer = false
				view.znear = 3
			end
		end
	else
		eyeOffset = Vector(0, 0, 0)
	end

	-- the dynamic camera: steps, lean, landing (cl_dyncam.lua)
	if (NW.dyncam and view.origin and view.angles) then
		view = NW.dyncam.Apply(client, view, Active(client))
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

-- the view model goes with the camera from the eyes (the same offset, or it stays behind the view and is not
-- seen) and is carried low and aside on safety (sh_raise.lua)
local lowered = 0

function GM:CalcViewModelView(weapon, viewModel, oldPos, oldAng, pos, ang)
	local newPos, newAng = self.BaseClass.CalcViewModelView(self, weapon, viewModel, oldPos, oldAng, pos, ang)
	local client = LocalPlayer()

	newPos, newAng = newPos or pos, newAng or ang

	if (WeaponEyes(client)) then
		newPos = newPos + eyeOffset
	end

	local bSafe = IsValid(client) and client.IsSafetyOn and client:IsSafetyOn() and !(IsValid(weapon) and
		weapon.IsAlwaysRaised)

	lowered = math.Approach(lowered, bSafe and 1 or 0, FrameTime() * 3.5)

	if (lowered > 0) then
		local ease = math.ease.InOutSine(lowered)
		local base = Angle(newAng)

		newAng = Angle(newAng)
		newAng:RotateAroundAxis(base:Right(), -24 * ease)
		newAng:RotateAroundAxis(base:Up(), 18 * ease)
		newPos = newPos - base:Up() * 4 * ease + base:Right() * 2 * ease - base:Forward() * 2 * ease
	end

	return newPos, newAng
end

-- the third person camera needs no view model
function GM:PreDrawViewModel(viewModel, client, weapon)
	if (Active(LocalPlayer()) or InventoryWeight() > 0.001 or PoseEyes(LocalPlayer())) then
		return true
	end

	return self.BaseClass.PreDrawViewModel and self.BaseClass.PreDrawViewModel(self, viewModel, client, weapon)
end
