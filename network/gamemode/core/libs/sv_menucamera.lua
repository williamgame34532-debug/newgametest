NETWORK.camera = NETWORK.camera or {}
NETWORK.camera.menu = NETWORK.camera.menu or nil

util.AddNetworkString("nwMenuCamera")
util.AddNetworkString("nwMenuCameraRequest")

local folder = "network/menucam"

local function GetPath()
	return folder .. "/" .. game.GetMap() .. ".json"
end

function NETWORK.camera.LoadMenu()
	local contents = file.Read(GetPath(), "DATA")

	if (!contents) then
		return
	end

	local data = util.JSONToTable(contents)

	if (!istable(data) or !istable(data.position) or !istable(data.angles)) then
		return
	end

	NETWORK.camera.menu = {
		position = Vector(data.position[1], data.position[2], data.position[3]),
		angles = Angle(data.angles[1], data.angles[2], 0),
		fov = math.Clamp(tonumber(data.fov) or 70, 20, 120),
		yaw = math.Clamp(tonumber(data.yaw) or 20, 0, 70),
		pitch = math.Clamp(tonumber(data.pitch) or 10, 0, 45)
	}
end

function NETWORK.camera.SaveMenu()
	local point = NETWORK.camera.menu

	file.CreateDir("network")
	file.CreateDir(folder)

	if (!point) then
		file.Delete(GetPath())

		return
	end

	file.Write(GetPath(), util.TableToJSON({
		position = {point.position.x, point.position.y, point.position.z},
		angles = {point.angles.p, point.angles.y},
		fov = point.fov,
		yaw = point.yaw,
		pitch = point.pitch
	}, true))
end

function NETWORK.camera.SendMenu(target)
	local point = NETWORK.camera.menu

	net.Start("nwMenuCamera")
		net.WriteBool(point != nil)

		if (point) then
			net.WriteVector(point.position)
			net.WriteAngle(point.angles)
			net.WriteUInt(math.Round(point.fov), 8)
			net.WriteUInt(math.Round(point.yaw), 8)
			net.WriteUInt(math.Round(point.pitch), 8)
		end

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

function NETWORK.camera.SetMenuFrom(client)
	local angles = client:EyeAngles()
	local point = NETWORK.camera.menu

	NETWORK.camera.menu = {
		position = client:EyePos(),
		angles = Angle(angles.p, angles.y, 0),
		fov = point and point.fov or 70,
		yaw = point and point.yaw or 20,
		pitch = point and point.pitch or 10
	}

	NETWORK.camera.SaveMenu()
	NETWORK.camera.SendMenu()
end

net.Receive("nwMenuCameraRequest", function(length, client)
	NETWORK.camera.SendMenu(client)
end)

hook.Add("InitPostEntity", "nwMenuCamera", function()
	NETWORK.camera.LoadMenu()
end)

if (game.GetMap() and game.GetMap() != "") then
	NETWORK.camera.LoadMenu()
end

local function Notice(client, text)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

NETWORK.command.Register("menucamera", {
	adminOnly = true,
	description = "cmdMenuCamera",
	usage = "/menucamera",
	aliases = {"setmenucamera"},
	OnRun = function(command, client)
		NETWORK.camera.SetMenuFrom(client)

		Notice(client, L("menuCameraSet"))
	end
})

NETWORK.command.Register("menucamerafov", {
	adminOnly = true,
	description = "cmdMenuCameraFov",
	usage = "/menucamerafov <20-120>",
	OnRun = function(command, client, arguments)
		local point = NETWORK.camera.menu

		if (!point) then
			return Notice(client, L("menuCameraNone"))
		end

		point.fov = math.Clamp(tonumber(arguments[1]) or 70, 20, 120)

		NETWORK.camera.SaveMenu()
		NETWORK.camera.SendMenu()

		Notice(client, L("menuCameraFov", point.fov))
	end
})

NETWORK.command.Register("menucameralook", {
	adminOnly = true,
	description = "cmdMenuCameraLook",
	usage = "/menucameralook <градусы по горизонтали> <по вертикали>",
	OnRun = function(command, client, arguments)
		local point = NETWORK.camera.menu

		if (!point) then
			return Notice(client, L("menuCameraNone"))
		end

		point.yaw = math.Clamp(tonumber(arguments[1]) or 20, 0, 70)
		point.pitch = math.Clamp(tonumber(arguments[2]) or 10, 0, 45)

		NETWORK.camera.SaveMenu()
		NETWORK.camera.SendMenu()

		Notice(client, L("menuCameraLook", point.yaw, point.pitch))
	end
})

NETWORK.command.Register("menucameraclear", {
	adminOnly = true,
	description = "cmdMenuCameraClear",
	usage = "/menucameraclear",
	OnRun = function(command, client)
		NETWORK.camera.menu = nil

		NETWORK.camera.SaveMenu()
		NETWORK.camera.SendMenu()

		Notice(client, L("menuCameraCleared"))
	end
})
