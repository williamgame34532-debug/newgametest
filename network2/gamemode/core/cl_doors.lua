-- Doors, client side (sh_doors.lua): the panel on a set door and the admin window (/door).
-- The panel hangs in the middle of the door on the side the player stands, fades in within about
-- 3 metres: a dark plate, a strip in the colour of the kind, the name, what the door is and
-- whether it is free (the price and /doorbuy), taken, given through the terminal or the Alliance's.

local D = NW.doors
local U = NW.ui
local W = NW.widgets

surface.CreateFont("nwDoorName", {font = "Oswald Light", size = 64, weight = 300, extended = true, antialias = true})
surface.CreateFont("nwDoorKind", {font = "Jura", size = 30, weight = 700, extended = true, antialias = true})
surface.CreateFont("nwDoorInfo", {font = "Exo 2", size = 30, weight = 500, extended = true, antialias = true})

local RANGE = 300
local SCALE = 0.05

-- the lines under the name
local function Status(door)
	local kind = door:GetNW2String("nwDoorKind", "")
	local mode = D.Mode(door)
	local owner = D.Owner(door)

	if (kind == "alliance") then
		return "Только для Альянса", Color(214, 120, 110)
	end

	-- an apartment for several (the terminal, or bought by several): how many live there
	if (kind == "apartment" and mode == "buy" and D.Capacity(door) > 1) then
		local count, capacity = #D.Tenants(door), D.Capacity(door)
		local price = door:GetNW2Int("nwDoorPrice", 0)

		if (D.IsOwner(LocalPlayer(), door)) then
			return "Ваша · жильцов " .. count .. "/" .. capacity .. " · /doorlock", Color(150, 214, 138)
		elseif (count >= capacity) then
			return "Занята · жильцов " .. count .. "/" .. capacity, U.color.dim
		end

		return "Мест " .. (capacity - count) .. "/" .. capacity .. " · " .. (price > 0 and (price .. " ток.") or
			"бесплатно") .. " · /doorbuy", U.color.hint
	end

	if (kind == "apartment" and mode == "terminal") then
		local count, capacity = #D.Tenants(door), D.Capacity(door)
		local mine = D.IsOwner(LocalPlayer(), door)

		if (mine) then
			return "Ваша · жильцов " .. count .. "/" .. capacity .. " · /doorlock", Color(150, 214, 138)
		end

		return (count >= capacity and "Заселена" or "Через терминал Альянса") .. " · жильцов " .. count .. "/" ..
			capacity, U.color.dim
	end

	if (owner != 0) then
		if (D.IsOwner(LocalPlayer(), door)) then
			return "Ваша · /doorlock — замок", Color(150, 214, 138)
		end

		return "Занята", U.color.dim
	end

	if (mode == "terminal") then
		local price = door:GetNW2Int("nwDoorPrice", 0)

		return "Свободна · аренда через терминал" .. (price > 0 and (" · " .. price .. " ток.") or ""), U.color.dim
	end

	local price = door:GetNW2Int("nwDoorPrice", 0)

	return "Свободна · " .. (price > 0 and (price .. " ток.") or "бесплатно") .. " · /doorbuy", U.color.hint
end

local function DrawPanel(door, alpha)
	local kind = D.Kind(door)

	if (!kind) then
		return
	end

	local name = U.Upper(door:GetNW2String("nwDoorName", kind.name))
	local status, statusColor = Status(door)

	surface.SetFont("nwDoorName")

	local nw, nh = surface.GetTextSize(name)

	surface.SetFont("nwDoorInfo")

	local sw = surface.GetTextSize(status)
	local w = math.max(nw, sw, 360) + 80
	local h = nh + 96
	local x, y = -w / 2, -h / 2

	draw.RoundedBox(10, x, y, w, h, Color(12, 14, 17, 215 * alpha))
	draw.RoundedBoxEx(10, x, y, 10, h, ColorAlpha(kind.color, 235 * alpha), true, false, true, false)
	draw.SimpleText(U.Upper(kind.name), "nwDoorKind", x + 40, y + 22, ColorAlpha(kind.color, 255 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(name, "nwDoorName", x + 40, y + 50, ColorAlpha(U.color.text, 255 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)
	surface.SetDrawColor(255, 255, 255, 22 * alpha)
	surface.DrawRect(x + 40, y + 52 + nh, w - 80, 2)
	draw.SimpleText(status, "nwDoorInfo", x + 40, y + h - 18, ColorAlpha(statusColor, 255 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_BOTTOM)
end

-- where on the door and which way (after Helix: a trace from the thin side to the centre)
local function Placement(door, eye)
	local center = door:LocalToWorld(door:OBBCenter())
	local mins, maxs = door:GetCollisionBounds()
	local size = maxs - mins
	local start

	if (size.z < size.x and size.z < size.y) then
		start = center - door:GetUp() * size.z
	elseif (size.x < size.y) then
		start = center - door:GetForward() * size.x
	else
		start = center - door:GetRight() * size.y
	end

	local trace = util.TraceLine({start = start, endpos = center, ignoreworld = true,
		collisiongroup = COLLISION_GROUP_WORLD})

	if (!trace.Hit or trace.Entity != door) then
		return
	end

	local normal = trace.HitNormal
	local front = normal:Dot((eye - center):GetNormalized()) < 0
	local angles = normal:Angle()

	angles:RotateAroundAxis(angles:Forward(), 90)
	angles:RotateAroundAxis(angles:Right(), front and 90 or -90)

	local thickness = (center - trace.HitPos):Length()
	local pos = front and (trace.HitPos - (thickness * 2 + 0.6) * normal) or (trace.HitPos + normal * 0.6)

	-- a little above the middle, at eye level for a standing person
	pos.z = math.Clamp(eye.z - 6, door:LocalToWorld(mins).z + 30, door:LocalToWorld(maxs).z - 12)

	return pos, angles
end

hook.Add("PostDrawTranslucentRenderables", "nwDoors", function(bDepth, bSkybox)
	if (bDepth or bSkybox) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or client:GetNW2Bool("nwInMenu", false)) then
		return
	end

	local eye = EyePos()

	for _, door in ipairs(ents.FindInSphere(eye, RANGE)) do
		local kind = D.IsDoor(door) and door:GetNW2String("nwDoorKind", "") or ""

		-- the Alliance's doors carry no panel
		if (kind != "" and kind != "alliance" and !door:GetNoDraw()) then
			local alpha = math.Clamp(1 - (eye:Distance(door:WorldSpaceCenter()) - RANGE * 0.55) / (RANGE * 0.45), 0, 1)

			if (alpha > 0.01) then
				local pos, angles = Placement(door, eye)

				if (pos) then
					cam.Start3D2D(pos, angles, SCALE)
						DrawPanel(door, alpha)
					cam.End3D2D()
				end
			end
		end
	end
end)

-- ------------------------------------------------------------ the window --
local form

local function Send(door, action, data)
	net.Start("nwDoorSave")
		net.WriteEntity(door)
		net.WriteString(action)

		if (data) then
			net.WriteString(util.TableToJSON(data))
		end
	net.SendToServer()
end

local function Open(door)
	if (IsValid(form)) then
		form:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(sh * 0.56), math.Round(sh * 0.56)
	local frame, box = W.Window("Дверь", w, h)

	form = frame

	local pad = math.Round(sh * 0.022)
	local fieldH = math.Round(sh * 0.038)
	local inner = w - pad * 2
	local y = box.top
	local kindID = door:GetNW2String("nwDoorKind", "")

	W.Label(box, "Название двери", pad, y)
	y = y + math.Round(sh * 0.02)

	local name = W.Entry(box, door:GetNW2String("nwDoorName", ""), "Например: Квартира 12, Аптека")

	name:SetPos(pad, y)
	name:SetSize(inner, fieldH)
	y = y + fieldH + math.Round(sh * 0.016)

	W.Label(box, "Вид двери", pad, y)
	y = y + math.Round(sh * 0.02)

	local kinds = {}

	for _, kind in ipairs(D.kinds) do
		kinds[#kinds + 1] = {kind.id, kind.name}
	end

	local kind = W.Combo(box, kinds, kindID != "" and kindID or "apartment")

	kind:SetPos(pad, y)
	kind:SetSize(inner, fieldH)
	y = y + fieldH + math.Round(sh * 0.02)

	local settings = box:Add("EditablePanel")

	settings:SetPos(pad, y)
	settings:SetSize(inner, math.Round(sh * 0.02) * 2 + fieldH * 2 + math.Round(sh * 0.012))

	local mode, price, capacity

	local function Build()
		settings:Clear()
		mode, price, capacity = nil, nil, nil

		local which = kind:GetSelectedValue() or "apartment"

		if (which == "apartment") then
			W.Label(settings, "Как получить", 0, 0)

			local modes = {}

			for _, entry in ipairs(D.modes) do
				modes[#modes + 1] = {entry.id, entry.name}
			end

			mode = W.Combo(settings, modes, door:GetNW2String("nwDoorMode", "buy") == "terminal" and "terminal" or "buy")
			mode:SetPos(0, math.Round(sh * 0.02))
			mode:SetSize(inner, fieldH)

			-- the price (for sale: each who buys in pays it) and how many may live there, together
			local row = math.Round(sh * 0.02) + fieldH + math.Round(sh * 0.012)
			local priceLabel = W.Label(settings, "Цена, ток. (с жильца)", 0, row)

			W.Label(settings, "Мест (игроков)", inner * 0.52, row)

			price = W.Number(settings, door:GetNW2Int("nwDoorPrice", 100), 0, D.maxPrice)
			price:SetPos(0, row + math.Round(sh * 0.02))
			price:SetSize(inner * 0.48, fieldH)

			capacity = W.Number(settings, D.Capacity(door), 1, 8)
			capacity:SetPos(inner * 0.52, row + math.Round(sh * 0.02))
			capacity:SetSize(inner * 0.48, fieldH)

			-- through the terminal there is no price here
			local function Toggle()
				local buy = mode:GetSelectedValue() == "buy"

				price:SetVisible(buy)
				priceLabel:SetVisible(buy)
			end

			mode.OnSelect = Toggle
			Toggle()
		elseif (which == "business") then
			W.Label(settings, "Аренда на терминале Альянса, цена в токенах", 0, 0)

			price = W.Number(settings, door:GetNW2Int("nwDoorPrice", 100), 0, D.maxPrice)
			price:SetPos(0, math.Round(sh * 0.02))
			price:SetSize(inner * 0.38, fieldH)
		else
			W.Label(settings, "Открывают только Альянс и ГО; /doorlock — замок", 0, 0)
		end
	end

	kind.OnSelect = Build
	Build()

	-- the owner, if any
	local owner = D.Owner(door)

	if (owner != 0) then
		local label = W.Label(box, "Владелец: " .. door:GetNW2String("nwDoorOwnerName", "?") .. " (#" .. owner .. ")",
			pad, h - fieldH * 2 - pad * 2)

		label:SetTextColor(U.color.hint)
	end

	local by = h - fieldH - pad
	local save = W.Button(box, "Сохранить", function()
		Send(door, "save", {
			name = name:GetValue(),
			kind = kind:GetSelectedValue(),
			mode = mode and mode:GetSelectedValue() or nil,
			price = price and price:GetNumber() or 0,
			capacity = capacity and capacity:GetNumber() or 1
		})
		frame:Remove()
	end, true)

	save:SetPos(w - pad - inner * 0.34, by)
	save:SetSize(inner * 0.34, fieldH)

	local reset = W.Button(box, "Сбросить", function()
		Send(door, "reset")
		frame:Remove()
	end)

	reset:SetPos(pad, by)
	reset:SetSize(inner * 0.3, fieldH)

	if (owner != 0) then
		local free = W.Button(box, "Освободить", function()
			Send(door, "free")
			frame:Remove()
		end)

		free:SetPos(pad + inner * 0.32, by)
		free:SetSize(inner * 0.3, fieldH)
	end
end

net.Receive("nwDoorMenu", function()
	local door = net.ReadEntity()

	if (D.IsDoor(door)) then
		Open(door)
	end
end)

-- -------------------------------------------------------- hold E on a door --
-- held for half a second: the wheel of the door (cl_social.lua: Постучать, Выбить дверь)
local held = {}

hook.Add("Think", "nwDoorHold", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or vgui.CursorVisible() or (NW.social and NW.social.IsOpen()) or
		(NW.Incapable and NW.Incapable(client))) then
		held.since = nil

		return
	end

	local key = input.GetKeyCode(input.LookupBinding("+use", true) or "e")
	local door = key and key > 0 and input.IsKeyDown(key) and D.Aimed(client, 110)

	if (!door) then
		held.since, held.door = nil, nil

		return
	end

	if (held.door != door) then
		held.door, held.since = door, RealTime()
	elseif (held.since and RealTime() - held.since > 0.5) then
		held.since = nil

		if (NW.social and NW.social.Open) then
			NW.social.Open(door)
		end
	end
end)

-- the kick: kickdoorbaton on the Civil Protection models
net.Receive("nwDoorKick", function()
	local client = net.ReadEntity()

	if (!IsValid(client)) then
		return
	end

	local sequence = client:LookupSequence("kickdoorbaton")

	if (sequence and sequence > 0) then
		client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, sequence, 0, true)
	end
end)
