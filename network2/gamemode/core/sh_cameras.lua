-- The combine cameras (npc_combine_camera) at the terminal of the Alliance (the page КАМЕРЫ):
--   the list       every camera on the map: its number, the zone it looks at
--   the view       the picture of the chosen camera in the panel (the place of the camera is added
--                  to what the server sends this player while the terminal is used)
--   turning        the arrows (←→ yaw, ↑↓ pitch), within the field of the camera
--   Enter          a photo: the picture is taken (jpeg, 480x270) and sent to every unit of the
--                  Alliance; it shows at the middle of the left side for a while (number, zone, time,
--                  who took it). Once in nw_camera_photo_cooldown seconds (4).

NW.cameras = NW.cameras or {}

local CA = NW.cameras

CA.class = "npc_combine_camera"
CA.yaw = 70
CA.pitchUp, CA.pitchDown = 15, 55

local cooldown = CreateConVar("nw_camera_photo_cooldown", "4", {FCVAR_ARCHIVE, FCVAR_REPLICATED},
	"Как часто можно делать снимок камерой (секунды)")

-- the place and the base direction of a camera ({pos, ang} from the list or the entity itself)
function CA.Eye(entry)
	local entity = Entity(entry.index or 0)

	if (IsValid(entity) and entity:GetClass() == CA.class) then
		local ang = entity:GetAngles()

		return entity:GetPos() + ang:Forward() * 14 - ang:Up() * 10, ang
	end

	return entry.pos + entry.ang:Forward() * 14 - entry.ang:Up() * 10, entry.ang
end

if (SERVER) then
	util.AddNetworkString("nwCamList")
	util.AddNetworkString("nwCamPhoto")
	util.AddNetworkString("nwCamPhotoShow")

	local ACTIONS = NW.cmbTerminalActions

	local function List()
		local out = {}

		for _, camera in ipairs(ents.FindByClass(CA.class)) do
			local zone = NW.zones.At(camera:GetPos())

			out[#out + 1] = {index = camera:EntIndex(), pos = camera:GetPos(), ang = camera:GetAngles(),
				zone = zone and zone.name or ""}
		end

		table.SortByMember(out, "index", true)

		return out
	end

	function ACTIONS.cam_list(client)
		local list = List()

		net.Start("nwCamList")
			net.WriteUInt(#list, 8)

			for _, entry in ipairs(list) do
				net.WriteUInt(entry.index, 16)
				net.WriteVector(entry.pos)
				net.WriteAngle(entry.ang)
				net.WriteString(entry.zone)
			end
		net.Send(client)
	end

	function ACTIONS.cam_view(client, terminal, arg)
		local camera = Entity(tonumber(arg) or 0)

		if (IsValid(camera) and camera:GetClass() == CA.class) then
			client.nwCamView, client.nwCamTerminal = camera, terminal
		else
			client.nwCamView, client.nwCamTerminal = nil, nil
		end
	end

	local close = ACTIONS.close

	function ACTIONS.close(client, terminal)
		client.nwCamView, client.nwCamTerminal = nil, nil
		close(client, terminal)
	end

	-- the camera watched: its place is sent too
	hook.Add("SetupPlayerVisibility", "nwCameras", function(client)
		local camera, terminal = client.nwCamView, client.nwCamTerminal

		if (!IsValid(camera)) then
			return
		end

		if (!IsValid(terminal) or terminal:GetUser() != client) then
			client.nwCamView, client.nwCamTerminal = nil, nil

			return
		end

		AddOriginToPVS(camera:GetPos())
	end)

	net.Receive("nwCamPhoto", function(len, client)
		local index = net.ReadUInt(16)
		local size = net.ReadUInt(16)
		local camera = client.nwCamView

		if (!IsValid(camera) or camera:EntIndex() != index or size == 0 or size > 60000 or len / 8 < size or
			(client.nwCamPhotoNext or 0) > CurTime()) then
			return
		end

		client.nwCamPhotoNext = CurTime() + cooldown:GetFloat()

		local data = net.ReadData(size)
		local number = 0

		for position, entry in ipairs(List()) do
			if (entry.index == index) then
				number = position
			end
		end

		local zone = NW.zones.At(camera:GetPos())
		local units = {}

		for _, target in ipairs(player.GetAll()) do
			if (target:GetCharacterID() != 0 and NW.zones.IsAlliance(target)) then
				units[#units + 1] = target
			end
		end

		net.Start("nwCamPhotoShow")
			net.WriteUInt(number, 8)
			net.WriteString(zone and zone.name or "")
			net.WriteString(client:Nick())
			net.WriteUInt(#data, 16)
			net.WriteData(data, #data)
		net.Send(units)

		MsgN(string.format("[CAMERA] %s (%s): снимок камеры %d", client:Nick(), client:SteamName(), number))
	end)

	return
end

-- ------------------------------------------------------------------ client --
local CT = NW.cmbTerminal
local C = CT.colors

CA.list = CA.list or {}
CA.aim = CA.aim or {}

net.Receive("nwCamList", function()
	local list = {}

	for _ = 1, net.ReadUInt(8) do
		list[#list + 1] = {index = net.ReadUInt(16), pos = net.ReadVector(), ang = net.ReadAngle(), zone = net.ReadString()}
	end

	CA.list = list

	if (CT.page == "cameras") then
		CT.Refresh()
	end
end)

local function Up(text)
	return NW.terminal.Upper(tostring(text or ""))
end

-- where the chosen camera looks now
local function View(entry)
	local pos, ang = CA.Eye(entry)
	local aim = CA.aim[entry.index] or {yaw = 0, pitch = 20}
	local view = Angle(ang.p, ang.y, 0)

	view:RotateAroundAxis(view:Up(), aim.yaw)
	view:RotateAroundAxis(view:Right(), -aim.pitch)

	return pos, view
end

-- --------------------------------------------------------------- the photo --
local RT_W, RT_H = 480, 270
local target = GetRenderTarget("nwCamPhoto", RT_W, RT_H)
local pending

function CA.TakePhoto(entry)
	if ((CA.nextPhoto or 0) > CurTime()) then
		return NW.notify.Add("Камера перезаряжает затвор: " .. math.ceil(CA.nextPhoto - CurTime()) .. " с")
	end

	CA.nextPhoto = CurTime() + cooldown:GetFloat()
	pending = entry
	surface.PlaySound("npc/scanner/scanner_photo1.wav")
end

hook.Add("PostRender", "nwCameras", function()
	if (!pending) then
		return
	end

	local entry = pending
	local pos, ang = View(entry)

	pending = nil

	render.PushRenderTarget(target)
		render.Clear(0, 0, 0, 255, true, true)
		render.RenderView({origin = pos, angles = ang, x = 0, y = 0, w = RT_W, h = RT_H, fov = 70,
			drawviewmodel = false, drawhud = false, dopostprocess = false})
		local data = render.Capture({format = "jpeg", x = 0, y = 0, w = RT_W, h = RT_H, quality = 55})
	render.PopRenderTarget()

	if (!data or #data == 0 or #data > 60000) then
		return
	end

	net.Start("nwCamPhoto")
		net.WriteUInt(entry.index, 16)
		net.WriteUInt(#data, 16)
		net.WriteData(data, #data)
	net.SendToServer()
end)

-- the photos of the others: on the left, one under another
local photos = {}
local serial = 0
local LIFE = 14

net.Receive("nwCamPhotoShow", function()
	local number = net.ReadUInt(8)
	local zone = net.ReadString()
	local who = net.ReadString()
	local data = net.ReadData(net.ReadUInt(16))

	serial = serial + 1

	local name = "network2/photos/" .. os.time() .. "_" .. serial .. ".jpg"

	file.CreateDir("network2/photos")
	file.Write(name, data)

	table.insert(photos, 1, {material = Material("../data/" .. name, "smooth"), number = number, zone = zone, who = who,
		time = os.date("%H:%M:%S"), born = RealTime(), file = name})

	while (#photos > 3) do
		local old = table.remove(photos)

		file.Delete(old.file)
	end

	surface.PlaySound("network2/cmbterminal/combine_tech_click_0" .. math.random(1, 5) .. ".wav")
end)

hook.Add("ShutDown", "nwCameras", function()
	for _, name in ipairs(file.Find("network2/photos/*.jpg", "DATA")) do
		file.Delete("network2/photos/" .. name)
	end
end)

hook.Add("HUDPaint", "nwCameraPhotos", function()
	if (#photos == 0) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local w = math.Round(sh * 0.3)
	local h = math.Round(w * RT_H / RT_W)
	local cap = math.Round(sh * 0.028)
	local total = #photos * (h + cap + 10)
	local x, y = math.Round(sw * 0.015), math.Round(sh * 0.5 - total / 2)
	local now = RealTime()

	for index = #photos, 1, -1 do
		if (now - photos[index].born > LIFE) then
			file.Delete(photos[index].file)
			table.remove(photos, index)
		end
	end

	for _, photo in ipairs(photos) do
		local age = now - photo.born
		local a = math.min(math.Clamp(age / 0.3, 0, 1), math.Clamp((LIFE - age) / 1, 0, 1))
		local flash = math.Clamp(1 - age / 0.4, 0, 1)

		surface.SetDrawColor(4, 14, 20, 220 * a)
		surface.DrawRect(x - 4, y - 4, w + 8, h + cap + 8)
		surface.SetMaterial(photo.material)
		surface.SetDrawColor(255, 255, 255, 255 * a)
		surface.DrawTexturedRect(x, y, w, h)
		surface.SetDrawColor(255, 255, 255, 200 * flash * a)
		surface.DrawRect(x, y, w, h)
		surface.SetDrawColor(92, 204, 242, 160 * a)
		surface.DrawOutlinedRect(x - 4, y - 4, w + 8, h + cap + 8, 1)
		draw.SimpleText(string.format("КАМ-%02d  ·  %s  ·  %s", photo.number, Up(photo.zone != "" and photo.zone or
			"вне зон"), photo.time), "nwCmtSmall", x + 2, y + h + cap * 0.3, Color(150, 220, 245, 255 * a), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(Up(photo.who), "nwCmtSmall", x + 2, y + h + cap * 0.8, Color(110, 160, 180, 255 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		-- the REC mark
		draw.SimpleText("● СНИМОК", "nwCmtSmall", x + w - 6, y + 6, Color(236, 84, 72, 230 * a), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_TOP)
		y = y + h + cap + 10
	end
end)

-- --------------------------------------------------------------- the page --
local CMB = CT.screens.cmb

CMB.pages.cameras = {
	title = "Камеры",
	subtitle = "Наблюдение / ←→↑↓ поворот / Enter снимок",
	Build = function(area, w, h)
		local gap = math.Round(h * 0.02)
		local listW = math.Round(w * 0.24)
		local rowH = math.Round(h * 0.07)

		if (!CA.asked or CA.asked < RealTime() - 5) then
			CA.asked = RealTime()
			CT.Send("cam_list")
		end

		local scroll = CT.Scroll(area, 0, 0, listW, h)

		if (#CA.list == 0) then
			CT.Label(scroll, "Камер нет", 0, 0, "nwCmtText", C.dim)
		end

		for number, entry in ipairs(CA.list) do
			local button = CT.Button(scroll, string.format("КАМ-%02d", number), 0, 0, listW - 10, rowH, function()
				CA.current = entry
				CA.number = number
				CT.Send("cam_view", entry.index)
			end, CA.current and CA.current.index == entry.index)

			button:Dock(TOP)
			button:DockMargin(0, 0, 8, gap * 0.5)

			local zone = button:Add("DLabel")
			zone:SetText("")
			zone:Dock(FILL)
			zone:SetMouseInputEnabled(false)
			zone.Paint = function(_, zw, zh)
				draw.SimpleText(Up(entry.zone != "" and entry.zone or "вне зон"), "nwCmtSmall", zw - 8, zh / 2, C.dim,
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		local vx = listW + gap
		local vw = w - vx
		local vh = math.min(h - rowH - gap, math.Round(vw * 9 / 16))
		local view = vgui.Create("DPanel", area)

		view:SetPos(vx, 0)
		view:SetSize(vw, vh)
		view.enterDown = true
		view.Think = function(self)
			local entry = CA.current

			if (!entry) then
				return
			end

			-- turning with the arrows, the photo with Enter (not while typing)
			local focus = vgui.GetKeyboardFocus()

			if (IsValid(focus) and focus:GetClassName() == "TextEntry") then
				return
			end

			local aim = CA.aim[entry.index] or {yaw = 0, pitch = 20}
			local step = FrameTime() * 40

			aim.yaw = aim.yaw + ((input.IsKeyDown(KEY_LEFT) and step or 0) - (input.IsKeyDown(KEY_RIGHT) and step or 0))
			aim.pitch = aim.pitch + ((input.IsKeyDown(KEY_DOWN) and step or 0) - (input.IsKeyDown(KEY_UP) and step or 0))

			aim.yaw = math.Clamp(aim.yaw, -CA.yaw, CA.yaw)
			aim.pitch = math.Clamp(aim.pitch, -CA.pitchUp, CA.pitchDown)
			CA.aim[entry.index] = aim

			local enter = input.IsKeyDown(KEY_ENTER) or input.IsKeyDown(KEY_PAD_ENTER)

			if (enter and !self.enterDown) then
				CA.TakePhoto(entry)
			end

			self.enterDown = enter
		end
		view.Paint = function(self, pw, ph)
			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(0, 0, pw, ph)

			local entry = CA.current

			if (!entry) then
				draw.SimpleText("ВЫБЕРИТЕ КАМЕРУ", "nwCmtHead", pw / 2, ph / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				return
			end

			local sx, sy = self:LocalToScreen(0, 0)
			local pos, ang = View(entry)

			render.RenderView({origin = pos, angles = ang, x = sx, y = sy, w = pw, h = ph, fov = 70, drawviewmodel = false,
				drawhud = false, dopostprocess = false})

			-- the overlay of the camera: lines, the corners, the time, the number
			local now = RealTime()

			surface.SetDrawColor(0, 0, 0, 40)

			for line = 0, ph, 4 do
				surface.DrawRect(0, line, pw, 1)
			end

			surface.SetDrawColor(C.cyan.r, C.cyan.g, C.cyan.b, 200)

			local corner = ph * 0.08

			for _, c in ipairs({{0, 0, 1, 1}, {pw, 0, -1, 1}, {0, ph, 1, -1}, {pw, ph, -1, -1}}) do
				surface.DrawRect(c[3] > 0 and c[1] + 8 or c[1] - 8 - corner, c[4] > 0 and c[2] + 8 or c[2] - 10, corner, 2)
				surface.DrawRect(c[3] > 0 and c[1] + 8 or c[1] - 10, c[4] > 0 and c[2] + 8 or c[2] - 8 - corner, 2, corner)
			end

			surface.DrawRect(pw / 2 - 10, ph / 2, 20, 1)
			surface.DrawRect(pw / 2, ph / 2 - 10, 1, 20)

			draw.SimpleText(string.format("КАМ-%02d  ·  %s", CA.number or 0, Up(entry.zone != "" and entry.zone or "вне зон")),
				"nwCmtText", 18, 20, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(os.date("%H:%M:%S"), "nwCmtText", pw - 18, 20, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

			if (math.floor(now * 2) % 2 == 0) then
				draw.SimpleText("● REC", "nwCmtText", pw - 18, ph - 20, Color(236, 84, 72), TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_BOTTOM)
			end

			local aim = CA.aim[entry.index] or {yaw = 0, pitch = 20}

			draw.SimpleText(string.format("АЗ %+04d  ·  УМ %+03d", math.Round(-aim.yaw), math.Round(-aim.pitch)), "nwCmtSmall",
				18, ph - 20, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			-- the photo: a white flash
			local since = CurTime() - ((CA.nextPhoto or 0) - cooldown:GetFloat())

			if (since >= 0 and since < 0.3) then
				surface.SetDrawColor(255, 255, 255, 200 * (1 - since / 0.3))
				surface.DrawRect(0, 0, pw, ph)
			end

			surface.SetDrawColor(C.cyan.r, C.cyan.g, C.cyan.b, 120)
			surface.DrawOutlinedRect(0, 0, pw, ph, 1)
		end

		local by = vh + gap

		CT.Button(area, "Снимок (Enter)", vx, by, vw * 0.3, rowH, function()
			if (CA.current) then
				CA.TakePhoto(CA.current)
			end
		end, true)
		CT.Button(area, "Сбросить поворот", vx + vw * 0.32, by, vw * 0.3, rowH, function()
			if (CA.current) then
				CA.aim[CA.current.index] = nil
			end
		end)
		CT.Button(area, "Обновить список", vx + vw * 0.64, by, vw * 0.36, rowH, function()
			CA.asked = nil
			CT.Send("cam_list")
		end)
	end
}

-- the terminal closed: the camera is let go
hook.Add("Think", "nwCamerasClosed", function()
	if (CA.current and !IsValid(CT.frame)) then
		CA.current = nil
	end
end)
