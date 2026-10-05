NETWORK.placer = NETWORK.placer or {}

local P = NETWORK.placer

P.kinds = P.kinds or {}
P.range = 140

function P.Register(kind, data)
	P.kinds[kind] = data
end

if (SERVER) then
	util.AddNetworkString("nwPlacerBegin")
	util.AddNetworkString("nwPlacerPlace")

	function P.Begin(client, kind, model, payload)
		client.nwPlacerState = {kind = kind, model = model, payload = payload}

		net.Start("nwPlacerBegin")
			net.WriteString(kind)
			net.WriteString(model)
		net.Send(client)
	end

	local debugVar = CreateConVar("network_placer_debug", "0", FCVAR_ARCHIVE,
		"Печатать шаги установки предметов")

	local function Log(client, text)
		if (debugVar:GetBool()) then
			MsgN("[Network:placer] " .. (IsValid(client) and client:Nick() or "?") .. ": " .. text)
		end
	end

	net.Receive("nwPlacerPlace", function(_, client)
		local bPlace = net.ReadBool()
		local position = net.ReadVector()
		local angles = net.ReadAngle()
		local placing = client.nwPlacerState

		client.nwPlacerState = nil

		if (!placing) then
			Log(client, "пришёл ответ без активной установки")

			return
		end

		if (!bPlace) then
			Log(client, "отмена или невалидная позиция (" .. tostring(placing.kind) .. ")")

			return
		end

		local handler = P.kinds[placing.kind]

		if (!handler) then
			Log(client, "нет обработчика вида " .. tostring(placing.kind))

			return NETWORK.notice.Send(client, "placerDenied", "bad")
		end

		Log(client, "ставим " .. tostring(placing.kind) .. " / " .. tostring(placing.payload) ..
			" в " .. tostring(position))

		if (position:Distance(client:GetShootPos()) > P.range + 40) then
			return NETWORK.notice.Send(client, "placerTooFar", "warn")
		end

		if (!handler.CanPlace or !handler.OnPlace) then
			return NETWORK.notice.Send(client, "placerDenied", "bad")
		end

		local bCalled, bOk, key = pcall(handler.CanPlace, client, placing, position)

		if (!bCalled) then
			ErrorNoHalt("[Network] Ошибка проверки установки (" .. tostring(placing.kind) .. "): " ..
				tostring(bOk) .. "\n")

			return NETWORK.notice.Send(client, "placerError", "bad")
		end

		if (bOk == false) then
			Log(client, "отказ: " .. tostring(key))

			return NETWORK.notice.Send(client, key or "placerDenied", "bad")
		end

		local bPlaced, err = pcall(handler.OnPlace, client, placing, position, angles)

		if (!bPlaced) then
			ErrorNoHalt("[Network] Ошибка установки (" .. tostring(placing.kind) .. "): " ..
				tostring(err) .. "\n")

			return NETWORK.notice.Send(client, "placerError", "bad")
		end

		Log(client, "поставлено")
	end)

	return
end

local ghost, active

local function Stop(bPlace)
	if (!active) then
		return
	end

	local position, angles = Vector(0, 0, 0), Angle(0, 0, 0)

	if (IsValid(ghost)) then
		position, angles = ghost:GetPos(), ghost:GetAngles()
		ghost:Remove()
	end

	ghost = nil

	net.Start("nwPlacerPlace")
		net.WriteBool(bPlace == true and active.bValid == true)
		net.WriteVector(position)
		net.WriteAngle(angles)
	net.SendToServer()

	active = nil
end

function P.IsPlacing()
	return active != nil
end

net.Receive("nwPlacerBegin", function()
	local kind = net.ReadString()
	local model = net.ReadString()

	if (active) then
		Stop(false)
	end

	ghost = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)

	if (!IsValid(ghost)) then
		return
	end

	ghost:SetRenderMode(RENDERMODE_TRANSCOLOR)
	ghost:SetColor(Color(90, 220, 120, 150))

	active = {kind = kind, yaw = 0, bValid = false}

	surface.PlaySound("buttons/lightswitch2.wav")
end)

hook.Add("Think", "nwPlacerGhost", function()
	if (!active or !IsValid(ghost)) then
		return
	end

	local client = LocalPlayer()
	local trace = util.TraceLine({
		start = client:GetShootPos(),
		endpos = client:GetShootPos() + client:GetAimVector() * P.range,
		filter = {client, ghost}
	})

	local position = trace.HitPos
	local angles = Angle(0, client:EyeAngles().y + active.yaw, 0)

	ghost:SetPos(position - Vector(0, 0, ghost:OBBMins().z))
	ghost:SetAngles(angles)

	active.bValid = trace.Hit and trace.HitNormal.z > 0.7
	ghost:SetColor(active.bValid and Color(90, 220, 120, 150) or Color(220, 80, 70, 150))
end)

hook.Add("Think", "nwPlacerMouse", function()
	if (!active) then
		return
	end

	active.born = active.born or RealTime()

	if (RealTime() - active.born < 0.5) then
		return
	end

	local bLeft = input.IsMouseDown(MOUSE_LEFT)
	local bRight = input.IsMouseDown(MOUSE_RIGHT)

	if (bLeft and !active.bLeftHeld) then
		if (active.bValid) then
			Stop(true)
		else
			NETWORK.gui.Notify(L("placerInvalid"), NETWORK.theme.warning)
			surface.PlaySound("buttons/button10.wav")
		end
	elseif (bRight and !active.bRightHeld) then
		Stop(false)
	end

	if (active) then
		active.bLeftHeld = bLeft
		active.bRightHeld = bRight
	end
end)

hook.Add("PlayerBindPress", "nwPlacer", function(_, bind, bPressed)
	if (!active or !bPressed) then
		return
	end

	if (bind == "+attack" or bind == "+attack2") then

		return true
	elseif (bind == "invnext") then
		active.yaw = active.yaw + 15

		return true
	elseif (bind == "invprev") then
		active.yaw = active.yaw - 15

		return true
	end
end)

hook.Add("HUDPaint", "nwPlacerHint", function()
	if (!active) then
		return
	end

	local Sc = NETWORK.util.Scale

	NETWORK.gui.DrawBlackGlass(nil, math.Round(ScrW() * 0.5) - Sc(220), ScrH() - Sc(90), Sc(440),
		Sc(36), 1, Sc(18))
	draw.SimpleText("ЛКМ — поставить  ·  колесо — повернуть  ·  ПКМ — отмена", "nwHudSmall",
		math.Round(ScrW() * 0.5), ScrH() - Sc(72), active.bValid and NETWORK.theme.text or
		NETWORK.theme.danger, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
