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

-- in the world: a column of light and a ring on the ground
hook.Add("PostDrawTranslucentRenderables", "nwSquadMarks", function(_, bSkybox)
	if (bSkybox or #SM.list == 0 or !SQ.Of(LocalPlayer())) then
		return
	end

	local now = CurTime()

	for _, mark in ipairs(SM.list) do
		local kind = SM.byID[mark.kind]
		local fade = math.Clamp((SM.life - (now - mark.born)) / 5, 0, 1)
		local color = ColorAlpha(kind.color, 200 * fade)
		local pulse = (now * 0.8) % 1

		render.SetMaterial(BEAM)
		render.DrawBeam(mark.pos, mark.pos + Vector(0, 0, 70), 2, 0, 1, color)

		local last

		for step = 0, 20 do
			local angle = step / 20 * math.pi * 2
			local radius = 10 + pulse * 18
			local point = mark.pos + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 1)

			if (last) then
				render.DrawBeam(last, point, 1.2, 0, 1, ColorAlpha(kind.color, 180 * (1 - pulse) * fade))
			end

			last = point
		end

		render.SetMaterial(GLOW)
		render.DrawSprite(mark.pos, 18, 18, color)
	end
end)

-- on the screen: the marker, its name and the distance; at the edge when it is behind
surface.CreateFont("nwSquadMarkText", {font = "JetBrains Mono ExtraBold", size = math.max(10, math.Round(ScrH() * 0.013)),
	weight = 800, extended = true, antialias = true})

hook.Add("HUDPaint", "nwSquadMarks", function()
	if (#SM.list == 0 or !SQ.Of(LocalPlayer())) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local eye = EyePos()
	local now = CurTime()
	local size = math.Round(sh * 0.045)
	local margin = sh * 0.05

	for _, mark in ipairs(SM.list) do
		local kind = SM.byID[mark.kind]
		local top = mark.pos + Vector(0, 0, 80)
		local screen = top:ToScreen()
		local fade = math.Clamp((SM.life - (now - mark.born)) / 5, 0, 1)
		local appear = math.Clamp((now - mark.born) / 0.3, 0, 1)
		local x, y = screen.x, screen.y

		-- behind or off the screen: held at the edge
		local behind = (mark.pos - eye):Dot(EyeAngles():Forward()) < 0

		if (behind) then
			x, y = sw - x, sh - margin
		end

		x = math.Clamp(x, margin, sw - margin)
		y = math.Clamp(y, margin, sh - margin)

		local s = size * (1.4 - 0.4 * appear)

		surface.SetMaterial(MATERIALS[mark.kind])
		surface.SetDrawColor(kind.color.r, kind.color.g, kind.color.b, 255 * fade * appear)
		surface.DrawTexturedRect(x - s / 2, y - s, s, s)
		draw.SimpleTextOutlined(kind.name .. "  " .. math.Round(eye:Distance(mark.pos) / 52.5) .. " м", "nwSquadMarkText",
			x, y + 2, ColorAlpha(kind.color, 230 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 170 * fade))
	end
end)
