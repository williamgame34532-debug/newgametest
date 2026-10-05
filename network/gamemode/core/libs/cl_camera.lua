NETWORK.camera = NETWORK.camera or {}

NETWORK.camera.position = NETWORK.camera.position or Vector(0, 0, 0)
NETWORK.camera.angles = NETWORK.camera.angles or Angle(0, 0, 0)
NETWORK.camera.fov = NETWORK.camera.fov or 70
NETWORK.camera.look = NETWORK.camera.look or {yaw = 20, pitch = 10}
NETWORK.camera.bConfigured = false
NETWORK.camera.bFromServer = false

local localPath = "network/menucamera.txt"
local currentYaw = 0
local currentPitch = 0
local easedYaw = 0
local easedPitch = 0
local targetYaw = 0
local targetPitch = 0

function NETWORK.camera.Apply(position, angles, fov, yawRange, pitchRange)
	NETWORK.camera.position = position
	NETWORK.camera.angles = Angle(angles.p, angles.y, 0)
	NETWORK.camera.fov = math.Clamp(tonumber(fov) or 70, 20, 120)
	NETWORK.camera.look.yaw = math.Clamp(tonumber(yawRange) or 20, 0, 70)
	NETWORK.camera.look.pitch = math.Clamp(tonumber(pitchRange) or 10, 0, 45)
	NETWORK.camera.bConfigured = true
end

function NETWORK.camera.Clear()
	NETWORK.camera.bConfigured = false
	NETWORK.camera.bFromServer = false
end

function NETWORK.camera.SaveLocal()
	local data = {
		position = {NETWORK.camera.position.x, NETWORK.camera.position.y,
			NETWORK.camera.position.z},
		angles = {NETWORK.camera.angles.p, NETWORK.camera.angles.y},
		fov = NETWORK.camera.fov,
		yaw = NETWORK.camera.look.yaw,
		pitch = NETWORK.camera.look.pitch,
		map = game.GetMap()
	}

	file.CreateDir("network")
	file.Write(localPath, util.TableToJSON(data, true))
end

function NETWORK.camera.LoadLocal()

	if (NETWORK.camera.bFromServer) then
		return false
	end

	local contents = file.Read(localPath, "DATA")

	if (!contents) then
		return false
	end

	local data = util.JSONToTable(contents)

	if (!istable(data) or !istable(data.position) or !istable(data.angles)) then
		return false
	end

	if (data.map and data.map != game.GetMap()) then
		return false
	end

	NETWORK.camera.Apply(
		Vector(data.position[1], data.position[2], data.position[3]),
		Angle(data.angles[1], data.angles[2], 0),
		data.fov, data.yaw, data.pitch)

	return true
end

function NETWORK.camera.SetFromPlayer()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	NETWORK.camera.Apply(client:EyePos(), client:EyeAngles(), NETWORK.camera.fov,
		NETWORK.camera.look.yaw, NETWORK.camera.look.pitch)
	NETWORK.camera.SaveLocal()

	NETWORK.util.Print(string.format("Локальная точка меню: %s | %s",
		tostring(NETWORK.camera.position), tostring(NETWORK.camera.angles)))
end

function NETWORK.camera.IsActive()
	return NETWORK.camera.bConfigured and IsValid(NETWORK.gui.menu)
end

function NETWORK.camera.Think()
	local menu = NETWORK.gui.menu
	local bLive = NETWORK.camera.IsActive() and !menu.bClosing

	if (bLive and vgui.CursorVisible()) then
		local x, y = input.GetCursorPos()

		targetYaw = -math.Clamp((x / ScrW() - 0.5) * 2, -1, 1) * NETWORK.camera.look.yaw
		targetPitch = math.Clamp((y / ScrH() - 0.5) * 2, -1, 1) * NETWORK.camera.look.pitch
	else
		targetYaw = 0
		targetPitch = 0
	end

	local lead = math.Clamp(FrameTime() * 0.9, 0, 1)
	local follow = math.Clamp(FrameTime() * 0.6, 0, 1)

	easedYaw = Lerp(lead, easedYaw, targetYaw)
	easedPitch = Lerp(lead, easedPitch, targetPitch)

	currentYaw = Lerp(follow, currentYaw, easedYaw)
	currentPitch = Lerp(follow, currentPitch, easedPitch)
end

function NETWORK.camera.GetOffset()
	return currentPitch, currentYaw
end

function NETWORK.camera.ResetOffset()
	currentYaw = 0
	currentPitch = 0
	easedYaw = 0
	easedPitch = 0
	targetYaw = 0
	targetPitch = 0
end

NETWORK.view.Register("menucamera", 0, function(client, view)
	NETWORK.camera.Think()

	if (!NETWORK.camera.IsActive()) then
		return
	end

	local time = CurTime()
	local base = NETWORK.camera.angles
	local breathYaw = math.sin(time * 0.09) * 0.9
	local breathPitch = math.sin(time * 0.06) * 0.5

	view.origin = NETWORK.camera.position
	view.angles = Angle(base.p + currentPitch + breathPitch,
		base.y + currentYaw + breathYaw, 0)
	view.fov = NETWORK.camera.fov
	view.drawviewer = true

	return "stop"
end)

hook.Add("ShouldDrawLocalPlayer", "nwMenuCamera", function()
	if (NETWORK.camera.IsActive()) then
		return true
	end
end)

net.Receive("nwMenuCamera", function()
	if (!net.ReadBool()) then
		NETWORK.camera.Clear()
		NETWORK.camera.LoadLocal()

		return
	end

	NETWORK.camera.Apply(net.ReadVector(), net.ReadAngle(),
		net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))

	NETWORK.camera.bFromServer = true
end)

hook.Add("InitPostEntity", "nwMenuCamera", function()
	NETWORK.camera.LoadLocal()

	net.Start("nwMenuCameraRequest")
	net.SendToServer()
end)

concommand.Add("network_camera_here", function()
	NETWORK.camera.SetFromPlayer()
end)

concommand.Add("network_camera_fov", function(client, command, arguments)
	NETWORK.camera.fov = math.Clamp(tonumber(arguments[1]) or 70, 20, 120)

	NETWORK.camera.SaveLocal()
end)

concommand.Add("network_camera_look", function(client, command, arguments)
	NETWORK.camera.look.yaw = math.Clamp(tonumber(arguments[1]) or 20, 0, 70)
	NETWORK.camera.look.pitch = math.Clamp(tonumber(arguments[2]) or 10, 0, 45)

	NETWORK.camera.SaveLocal()
end)

concommand.Add("network_camera_reset", function()
	NETWORK.camera.Clear()

	file.Delete(localPath)
	NETWORK.util.Print("Локальная точка меню сброшена.")
end)

concommand.Add("network_camera_print", function()
	local position = NETWORK.camera.position
	local angles = NETWORK.camera.angles

	NETWORK.util.Print(string.format(
		"pos: %.1f %.1f %.1f | ang: %.1f %.1f | fov: %d | обзор: %d/%d | источник: %s",
		position.x, position.y, position.z, angles.p, angles.y, NETWORK.camera.fov,
		NETWORK.camera.look.yaw, NETWORK.camera.look.pitch,
		NETWORK.camera.bFromServer and "сервер" or
			(NETWORK.camera.bConfigured and "локально" or "нет точки")))
end)
