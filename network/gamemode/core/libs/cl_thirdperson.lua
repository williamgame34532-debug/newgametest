NETWORK.thirdperson = NETWORK.thirdperson or {}

local enabled = CreateClientConVar("network_thirdperson", "0", true, false,
	"Вид от третьего лица")

local DISTANCE_MAX = 80

local distance = CreateClientConVar("network_thirdperson_distance", "60", true, false,
	"Дистанция камеры")
local height = CreateClientConVar("network_thirdperson_height", "6", true, false,
	"Высота камеры")
local side = CreateClientConVar("network_thirdperson_side", "22", true, false,
	"Смещение камеры вбок")
local smooth = CreateClientConVar("network_thirdperson_smooth", "20", true, false,
	"Плавность камеры")

local dynamic = CreateClientConVar("network_thirdperson_dynamic", "1", true,
	false, "Живость камеры от третьего лица")

local current = Vector(0, 0, 0)
local blend = 0

local lagZ = 0
local lastZ
local lastYaw
local lagYawSmooth = 0
local rollSmooth = 0

function NETWORK.thirdperson.GetBlock()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	if (client:IsCombat()) then
		return "thirdBlockCombat"
	end

	local weapon = client:GetActiveWeapon()
	local bHands = IsValid(weapon) and weapon:GetClass() == NETWORK.weapon.hands

	if (client:IsWeaponRaised() and !bHands) then
		return "thirdBlockRaised"
	end
end

concommand.Add("network_thirdperson_why", function()
	local client = LocalPlayer()

	print("[Network] третье лицо: конвар " .. tostring(enabled:GetBool()))
	print("[Network] конфиг сервера thirdPerson: " .. tostring(NETWORK.config and
		NETWORK.config.Get and NETWORK.config.Get("thirdPerson")))
	print("[Network] персонаж: " .. tostring(IsValid(client) and client:HasCharacter()) ..
		", жив: " .. tostring(IsValid(client) and client:Alive()))
	print("[Network] меню открыто: " .. tostring(IsValid(NETWORK.gui.menu)) ..
		", в машине: " .. tostring(IsValid(client) and client:InVehicle()))
	print("[Network] блок: " .. tostring(NETWORK.thirdperson.GetBlock()) ..
		", итог IsEnabled: " .. tostring(NETWORK.thirdperson.IsEnabled()))
	print("[Network] модификаторов вида: " .. tostring(#(NETWORK.view.modifiers or {})) ..
		", дистанция " .. distance:GetFloat() .. ", доля " .. string.format("%.2f", blend))
end)

function NETWORK.thirdperson.IsEnabled()
	local client = LocalPlayer()

	if (!enabled:GetBool() or !IsValid(client) or !client:Alive()) then
		return false
	end

	if (NETWORK.config and NETWORK.config.Get and NETWORK.config.Get("thirdPerson") == false) then
		return false
	end

	if (IsValid(NETWORK.gui.menu) or client:InVehicle()) then
		return false
	end

	if (NETWORK.thirdperson.GetBlock()) then
		return false
	end

	return client:HasCharacter()
end

NETWORK.view.Register("thirdperson", 30, function(client, view)
	local bActive = NETWORK.thirdperson.IsEnabled()

	blend = NETWORK.util.Approach(blend, bActive and 1 or 0,
		math.Clamp(smooth:GetFloat(), 2, 30) * 0.8)

	if (blend < 0.005) then
		return
	end

	local live = math.Clamp(dynamic:GetFloat(), 0, 1)
	local speed = client:GetVelocity():Length2D()
	local run = math.Clamp(speed / math.max(NETWORK.movement.runSpeed, 1), 0, 1)

	local push = 1 + run * 0.3 * live

	local target = Vector(
		-math.Clamp(distance:GetFloat(), 0, DISTANCE_MAX) * push,
		math.Clamp(side:GetFloat(), -80, 80),
		math.Clamp(height:GetFloat(), -40, 60) + run * 4 * live
	) * blend

	local rate = math.Clamp(1 - math.exp(-math.Clamp(smooth:GetFloat(), 2, 30) *
		math.min(FrameTime(), 0.1)), 0, 1)

	current = LerpVector(rate, current, target)

	local forward = view.angles:Forward()
	local right = view.angles:Right()

	forward.z = 0
	right.z = 0

	forward:Normalize()
	right:Normalize()

	local frame = math.min(FrameTime(), 0.1)
	local eyeZ = view.origin.z

	if (lastZ) then
		lagZ = math.Clamp(lagZ + (eyeZ - lastZ) * 0.65 * live, -18, 18)
	end

	lastZ = eyeZ
	lagZ = lagZ * math.Clamp(1 - 7 * frame, 0, 1)

	local yawGoal = view.angles.y
	local lagYaw = math.AngleDifference(yawGoal, lastYaw or yawGoal)

	lagYaw = math.Clamp(lagYaw, -18, 18) * live

	lastYaw = yawGoal

	lagYawSmooth = math.Approach(lagYawSmooth or 0, lagYaw, frame * 90)
	lagYawSmooth = lagYawSmooth * math.Clamp(1 - 6 * frame, 0, 1)

	local sideSpeed = client:GetVelocity():Dot(view.angles:Right())
	local rollGoal = math.Clamp(sideSpeed / math.max(NETWORK.movement.runSpeed,
		1), -1, 1) * 1.6 * live

	rollSmooth = math.Approach(rollSmooth or 0, rollGoal, frame * 8)

	view.angles = Angle(view.angles.p, view.angles.y - lagYawSmooth * 0.35,
		view.angles.r + rollSmooth)

	forward = view.angles:Forward()
	right = view.angles:Right()

	forward.z = 0
	right.z = 0

	forward:Normalize()
	right:Normalize()

	local desired = view.origin + forward * current.x + right * current.y +
		vector_up * (current.z - lagZ * blend)

	local trace = util.TraceHull({
		start = view.origin,
		endpos = desired,
		mins = Vector(-6, -6, -6),
		maxs = Vector(6, 6, 6),
		filter = client,
		mask = MASK_SOLID_BRUSHONLY
	})

	view.origin = trace.HitPos
	view.drawviewer = true

	return true
end)

hook.Add("ShouldDrawLocalPlayer", "nwThirdPerson", function()
	if (blend > 0.05) then
		return true
	end
end)

hook.Add("NetworkShouldDrawLegs", "nwThirdPerson", function()
	if (blend > 0.05) then
		return false
	end
end)

function NETWORK.thirdperson.Toggle(bState)
	if (bState == nil) then
		bState = !enabled:GetBool()
	end

	RunConsoleCommand("network_thirdperson", bState and "1" or "0")

	NETWORK.sound.Click()

	NETWORK.gui.Notify(L(bState and "thirdOn" or "thirdOff"), NETWORK.theme.accentSoft)

	hook.Run("NetworkThirdPersonToggled", bState)
end

concommand.Add("network_thirdperson_toggle", function()
	NETWORK.thirdperson.Toggle()
end)

concommand.Add("+network_thirdperson", function()
	NETWORK.thirdperson.Toggle(true)
end)

concommand.Add("-network_thirdperson", function()
	NETWORK.thirdperson.Toggle(false)
end)

local keyConVar = CreateClientConVar("network_thirdperson_key", "0", true, false,
	"Клавиша переключения третьего лица")

local bHeld = false

hook.Add("Think", "nwThirdPersonKey", function()
	local key = keyConVar:GetInt()

	if (key <= 0) then
		bHeld = false

		return
	end

	if (!input.IsKeyDown(key)) then
		bHeld = false

		return
	end

	if (bHeld or vgui.CursorVisible()) then
		return
	end

	bHeld = true

	local client = LocalPlayer()

	if (IsValid(client) and client:HasCharacter()) then
		NETWORK.thirdperson.Toggle()
	end
end)

local bCapturing = false

concommand.Add("network_thirdperson_key_pick", function()
	bCapturing = true

	NETWORK.util.Print("Нажмите клавишу для третьего лица...")
	NETWORK.gui.Notify(L("optKeyPress"), NETWORK.theme.accent)
end)

hook.Add("Think", "nwThirdPersonCapture", function()
	if (!bCapturing) then
		return
	end

	for key = KEY_FIRST, BUTTON_CODE_LAST do
		if (!input.IsButtonDown(key)) then
			continue
		end

		bCapturing = false

		if (key == KEY_ESCAPE) then
			NETWORK.gui.Notify(L("optKeyCancelled"), NETWORK.theme.textDim)

			return
		end

		RunConsoleCommand("network_thirdperson_key", tostring(key))

		NETWORK.gui.Notify(L("optKeyBound") .. " " .. input.GetKeyName(key),
			NETWORK.theme.positive)

		return
	end
end)

concommand.Add("network_thirdperson_bind", function(_, _, arguments)
	local name = arguments[1]

	if (!name) then
		NETWORK.util.Print("Использование: network_thirdperson_bind <клавиша>")
		NETWORK.util.Print("Например: network_thirdperson_bind f4")

		return
	end

	local key = _G["KEY_" .. string.upper(name)]

	if (!key) then
		NETWORK.util.PrintWarning("Клавиша не найдена: " .. name)

		return
	end

	RunConsoleCommand("network_thirdperson_key", tostring(key))

	NETWORK.util.Print("Третье лицо теперь на клавише " .. string.upper(name))
end)

hook.Add("Think", "nwThirdPersonBlock", function()
	if (!enabled:GetBool()) then
		NETWORK.thirdperson.blocked = nil

		return
	end

	local reason = NETWORK.thirdperson.GetBlock()

	if (reason == NETWORK.thirdperson.blocked) then
		return
	end

	if (reason and !NETWORK.thirdperson.blocked) then
		NETWORK.gui.Notify(L(reason), NETWORK.theme.warning)
	end

	NETWORK.thirdperson.blocked = reason
end)
