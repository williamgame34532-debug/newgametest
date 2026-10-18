-- The markers of the leader of a squad: the key "Метка отряда" (J) - a tap puts «Сюда» where the leader
-- looks; held - the choice: Сюда / Атаковать / Осмотреть / Опасность / Снять метки. The members see the
-- marker at its place (its own material, materials/network2/squad/marker_<kind>.png,
-- branding/make_squad_markers.py): on the screen with the distance (at the edge when out of sight),
-- a thin column of light and a ring in the world. Up to 3 markers, each for 90 s; a new one pushes out the
-- oldest. Only the leader.

NW.squadMarks = NW.squadMarks or {}

local SM = NW.squadMarks
local SQ = NW.squads

SM.kinds = {
	{id = "move", name = "Сюда", color = Color(96, 200, 255)},
	{id = "attack", name = "Атаковать", color = Color(236, 84, 72)},
	{id = "look", name = "Осмотреть", color = Color(240, 200, 80)},
	{id = "danger", name = "Опасность", color = Color(255, 140, 40)}
}

SM.byID = {}

for index, kind in ipairs(SM.kinds) do
	kind.index = index
	SM.byID[kind.id] = kind
end

SM.life = 90

if (SERVER) then
	util.AddNetworkString("nwSquadMark")
	util.AddNetworkString("nwSquadMarks")

	local function Send(squad)
		local out = {}

		for _, mark in ipairs(squad.marks or {}) do
			out[#out + 1] = {kind = mark.kind, pos = {mark.pos.x, mark.pos.y, mark.pos.z}, born = mark.born}
		end

		net.Start("nwSquadMarks")
			net.WriteString(util.TableToJSON(out))
		net.Send(SQ.Members(squad))
	end

	net.Receive("nwSquadMark", function(_, client)
		local kind = net.ReadString()
		local pos = net.ReadVector()
		local squad = SQ.Of(client)

		if (!squad or squad.leader != client or (client.nwMarkNext or 0) > CurTime()) then
			return
		end

		client.nwMarkNext = CurTime() + 0.6
		squad.marks = squad.marks or {}

		if (kind == "clear") then
			squad.marks = {}
		elseif (SM.byID[kind] and pos:DistToSqr(client:GetPos()) < 8000 * 8000) then
			table.insert(squad.marks, {kind = kind, pos = pos, born = CurTime()})

			while (#squad.marks > 3) do
				table.remove(squad.marks, 1)
			end
		else
			return
		end

		Send(squad)
	end)

	-- old markers go away
	timer.Create("nwSquadMarks", 5, 0, function()
		for _, squad in pairs(SQ.list) do
			local changed = false

			for index = #(squad.marks or {}), 1, -1 do
				if (CurTime() - squad.marks[index].born > SM.life) then
					table.remove(squad.marks, index)
					changed = true
				end
			end

			if (changed) then
				Send(squad)
			end
		end
	end)

	-- the squad changed: the members get the markers again (a new one sees them, one who left loses them)
	hook.Add("NWSquadChanged", "nwSquadMarks", function(squad)
		if (SQ.list[squad.id]) then
			Send(squad)
		end
	end)

	return
end

-- ------------------------------------------------------------------ client --
SM.list = SM.list or {}

local MATERIALS = {}

for _, kind in ipairs(SM.kinds) do
	MATERIALS[kind.id] = Material("network2/squad/marker_" .. kind.id .. ".png", "smooth mips")
end

local GLOW = Material("sprites/light_glow02_add")
local BEAM = Material("trails/laser")

net.Receive("nwSquadMarks", function()
	local list = util.JSONToTable(net.ReadString() or "") or {}
	local out = {}

	for _, mark in ipairs(list) do
		-- the server time is the same CurTime on the client
		out[#out + 1] = {kind = mark.kind, pos = Vector(mark.pos[1], mark.pos[2], mark.pos[3]), born = mark.born}
	end

	if (#out > #SM.list) then
		surface.PlaySound("buttons/blip1.wav")
	end

	SM.list = out
end)

local function Place(kind)
	local trace = LocalPlayer():GetEyeTrace()

	net.Start("nwSquadMark")
		net.WriteString(kind)
		net.WriteVector(trace.HitPos + trace.HitNormal * 2)
	net.SendToServer()
end

local function Leader()
	local squad = SQ.Of(LocalPlayer())

	return squad and squad.leader == LocalPlayer()
end

-- the key: a tap - «Сюда»; held - the choice
local held, chooser

local function Close(pick)
	if (IsValid(chooser)) then
		chooser:Remove()
	end

	gui.EnableScreenClicker(false)

	if (pick) then
		Place(pick)
	end
end

local function Open()
	local sh = ScrH()
	local size = math.Round(sh * 0.1)
	local options = {}

	for _, kind in ipairs(SM.kinds) do
		options[#options + 1] = kind
	end

	options[#options + 1] = {id = "clear", name = "Снять метки", color = Color(180, 186, 190)}

	chooser = vgui.Create("EditablePanel")
	chooser:SetSize(#options * (size + 8), size + sh * 0.04)
	chooser:Center()

	for index, kind in ipairs(options) do
		local card = chooser:Add("DButton")

		card:SetText("")
		card:SetPos((index - 1) * (size + 8), 0)
		card:SetSize(size, size + sh * 0.04)
		card.kind = kind.id
		card.Paint = function(self, w, h)
			draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(30, 40, 50, 240) or Color(10, 14, 18, 220))

			local material = MATERIALS[kind.id]

			if (material) then
				surface.SetMaterial(material)
				surface.SetDrawColor(kind.color)
				surface.DrawTexturedRect(w * 0.15, h * 0.06, w * 0.7, w * 0.7)
			else
				draw.SimpleText("✕", "nwWidgetTitle", w / 2, h * 0.38, kind.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			draw.SimpleText(kind.name, "nwWidget", w / 2, h * 0.86, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		card.DoClick = function()
			Close(kind.id)
		end
	end

	gui.EnableScreenClicker(true)
	surface.PlaySound("network2/ui/hover.wav")
end

hook.Add("NWKey", "nwSquadMarks", function(id)
	if (id != "squad_mark") then
		return
	end

	if (!Leader()) then
		return NW.notify.Add("Метки ставит лидер отряда")
	end

	held = RealTime()
end)

hook.Add("NWKeyUp", "nwSquadMarks", function(id)
	if (id != "squad_mark" or !held) then
		return
	end

	held = nil

	if (IsValid(chooser)) then
		local hovered = vgui.GetHoveredPanel()

		Close(IsValid(hovered) and hovered.kind or nil)
	else
		Place("move")
	end
end)

hook.Add("Think", "nwSquadMarkChooser", function()
	if (held and !IsValid(chooser) and RealTime() - held > 0.3) then
		Open()
	end
end)

-- in the world: a column of light, a ring on the ground and the marker itself standing over the place,
-- seen through the walls, the same size on the screen at any distance
hook.Add("PostDrawTranslucentRenderables", "nwSquadMarks", function(_, bSkybox)
	if (bSkybox or #SM.list == 0 or !SQ.Of(LocalPlayer())) then
		return
	end

	local now = CurTime()
	local eye = EyePos()

	for _, mark in ipairs(SM.list) do
		local kind = SM.byID[mark.kind]
		local fade = math.Clamp((SM.life - (now - mark.born)) / 5, 0, 1)
		local appear = math.Clamp((now - mark.born) / 0.35, 0, 1)
		local color = ColorAlpha(kind.color, 200 * fade)
		local pulse = (now * 0.8) % 1
		local distance = eye:Distance(mark.pos)

		render.SetMaterial(BEAM)
		render.DrawBeam(mark.pos, mark.pos + Vector(0, 0, 60), 2.5, 0, 1, color)

		local last

		for step = 0, 24 do
			local angle = step / 24 * math.pi * 2
			local radius = 10 + pulse * 22
			local point = mark.pos + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 1)

			if (last) then
				render.DrawBeam(last, point, 1.5, 0, 1, ColorAlpha(kind.color, 200 * (1 - pulse) * fade))
			end

			last = point
		end

		render.SetMaterial(GLOW)
		render.DrawSprite(mark.pos, 22, 22, color)

		-- the marker: over the column, a little bounce when it appears, over the walls
		local size = math.Clamp(distance * 0.05, 18, 260) * (1.5 - 0.5 * appear)
		local top = mark.pos + Vector(0, 0, 60 + size * 0.55 + math.sin(now * 3) * size * 0.04)

		cam.IgnoreZ(true)
			render.SetMaterial(MATERIALS[mark.kind])
			render.DrawSprite(top, size, size, ColorAlpha(kind.color, 255 * fade * appear))
		cam.IgnoreZ(false)
	end
end)

-- on the screen: the name and the distance in a plate under the marker; out of sight - at the edge, with
-- an arrow to it
surface.CreateFont("nwSquadMarkText", {font = "JetBrains Mono ExtraBold", size = math.max(11, math.Round(ScrH() * 0.015)),
	weight = 800, extended = true, antialias = true})

hook.Add("HUDPaint", "nwSquadMarks", function()
	if (#SM.list == 0 or !SQ.Of(LocalPlayer())) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local eye = EyePos()
	local now = CurTime()
	local margin = sh * 0.06

	surface.SetFont("nwSquadMarkText")

	for _, mark in ipairs(SM.list) do
		local kind = SM.byID[mark.kind]
		local distance = eye:Distance(mark.pos)
		local size = math.Clamp(distance * 0.05, 18, 260)
		local screen = (mark.pos + Vector(0, 0, 60)):ToScreen()
		local fade = math.Clamp((SM.life - (now - mark.born)) / 5, 0, 1)
		local behind = (mark.pos - eye):Dot(EyeAngles():Forward()) < 0
		local text = kind.name .. "  " .. math.Round(distance / 52.5) .. " м"
		local tw, th = surface.GetTextSize(text)
		local off = behind or screen.x < margin or screen.x > sw - margin or screen.y < margin or screen.y > sh - margin

		if (off) then
			-- at the edge: the direction to it from the middle of the screen
			local dx, dy = screen.x - sw / 2, screen.y - sh / 2

			if (behind) then
				dx, dy = -dx, -dy
			end

			local length = math.max(math.sqrt(dx * dx + dy * dy), 1)
			local scale = math.min((sw / 2 - margin) / math.max(math.abs(dx), 1), (sh / 2 - margin) / math.max(math.abs(dy), 1))
			local x, y = sw / 2 + dx * scale, sh / 2 + dy * scale
			local s = sh * 0.05

			surface.SetMaterial(MATERIALS[mark.kind])
			surface.SetDrawColor(kind.color.r, kind.color.g, kind.color.b, 255 * fade)
			surface.DrawTexturedRect(x - s / 2, y - s / 2, s, s)

			local ax, ay = x + dx / length * s * 0.75, y + dy / length * s * 0.75
			local nx, ny = -dy / length, dx / length

			draw.NoTexture()
			surface.DrawPoly({{x = ax + dx / length * 10, y = ay + dy / length * 10}, {x = ax + nx * 7, y = ay + ny * 7},
				{x = ax - nx * 7, y = ay - ny * 7}})
			draw.RoundedBox(4, x - tw / 2 - 6, y + s / 2 + 2, tw + 12, th + 4, Color(0, 0, 0, 170 * fade))
			draw.SimpleText(text, "nwSquadMarkText", x, y + s / 2 + 4, ColorAlpha(kind.color, 255 * fade), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP)
		else
			local y = screen.y + 6

			draw.RoundedBox(4, screen.x - tw / 2 - 6, y, tw + 12, th + 4, Color(0, 0, 0, 170 * fade))
			draw.SimpleText(text, "nwSquadMarkText", screen.x, y + 2, ColorAlpha(kind.color, 255 * fade), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP)
		end
	end
end)
