-- Markers of the visor (as on the Combine HUD): a round badge with an icon, the title between two dashes over
-- it («— БИОСИГНАЛ ПОТЕРЯН —»), the distance, the name and a small line (the zone) under it. Off the screen a
-- small badge with an arrow sits at the edge.
--   ТОЧКА        a squad member's mark (middle mouse), cyan ring with a dot
--   ВЫДВИЖЕНИЕ   the leader's mark, cyan double chevron (the leader has 3, a member 1, the oldest goes)
--   КОНТАКТ      a mark put on a player / NPC, orange crosshair
--   БИОСИГНАЛ ПОТЕРЯН   where a unit died — sent to EVERYONE, red broken heart, 90 s
--   БИОСИГНАЛ КРИТИЧЕСКИЙ   a squad mate with little health, orange heart (from the client, always current)
-- Squad marks are seen by the squad, through walls; a click on one's own mark removes it. Marks live 60 s.
-- Top right of the visor: «ПОТЕРЯ БИОСИГНАЛА :: ЭХО-443» for every unit that dies.
HLA = HLA or {}
local MK = {list = {}}
HLA.Markers = MK
MK.Life, MK.DeathLife = 60, 90
MK.PerMember, MK.PerLeader = 1, 3

if SERVER then
	util.AddNetworkString('hla_mark')     -- client -> server: put / remove
	util.AddNetworkString('hla_marks')    -- server -> player: the marks this player sees
	util.AddNetworkString('hla_biosig')   -- server -> all: a unit died (top right)
	local nextID = 0

	local function visible(m, p)
		if m.squad == 0 then return true end
		local sq = HLA.Squads and HLA.Squads.Of(p)
		return sq ~= nil and sq.id == m.squad
	end

	function MK.SendAll()
		for _, p in ipairs(player.GetAll()) do
			local list = {}
			for _, m in ipairs(MK.list) do if visible(m, p) then list[#list + 1] = m end end
			net.Start('hla_marks')
			net.WriteUInt(#list, 7)
			for _, m in ipairs(list) do
				net.WriteUInt(m.id, 16)
				net.WriteString(m.kind)
				net.WriteVector(m.pos)
				net.WriteEntity(IsValid(m.owner) and m.owner or NULL)
				net.WriteString(m.name or '')
				net.WriteFloat(m.t)
			end
			net.Send(p)
		end
	end

	local function add(m)
		nextID = (nextID + 1) % 65535
		m.id, m.t = nextID, CurTime()
		MK.list[#MK.list + 1] = m
		MK.SendAll()
	end
	MK.Add = add

	net.Receive('hla_mark', function(_, p)
		if (p.HLAMarkNext or 0) > CurTime() or not p:Alive() then return end
		p.HLAMarkNext = CurTime() + 0.35
		local SQ = HLA.Squads
		local sq = SQ and SQ.Of(p)
		if not sq then p:ChatPrint('Метки: вы не в отряде') return end
		local tr = util.TraceLine({start = p:EyePos(), endpos = p:EyePos() + p:GetAimVector() * 6000, filter = p, mask = MASK_SHOT})
		if not tr.Hit then return end
		local pos = tr.HitPos
		for i = #MK.list, 1, -1 do
			local m = MK.list[i]
			if m.owner == p and m.squad ~= 0 and m.pos:DistToSqr(pos) < 60 * 60 then
				table.remove(MK.list, i)
				MK.SendAll()
				return
			end
		end
		local leader = sq.leader == p
		local own = {}
		for i, m in ipairs(MK.list) do if m.owner == p and m.squad ~= 0 then own[#own + 1] = i end end
		local limit = leader and MK.PerLeader or MK.PerMember
		while #own >= limit do table.remove(MK.list, table.remove(own, 1)) for k = 1, #own do own[k] = own[k] - 1 end end
		local e = tr.Entity
		local kind, name = leader and 'move' or 'point', nil
		if IsValid(e) and (e:IsPlayer() or e:IsNPC() or e:IsNextBot()) then
			kind = 'target'
			pos = e:WorldSpaceCenter() + Vector(0, 0, e:OBBMaxs().z * 0.45)
			name = e:IsPlayer() and e:GetNWString('hla_name', e:Nick()) or (language and language.GetPhrase and e:GetClass()) or e:GetClass()
		end
		add({kind = kind, pos = pos, owner = p, squad = sq.id, name = name})
	end)

	-- a unit died: a mark for everyone where it fell, and the line top right
	hook.Add('PlayerDeath', 'HLADeathMark', function(p)
		if p.HLAInMenu or not p.HLACharID then return end
		local name = p:GetNWString('hla_name', p:Nick())
		add({kind = 'death', pos = p:GetPos() + Vector(0, 0, 40), owner = p, squad = 0, name = name, life = MK.DeathLife})
		net.Start('hla_biosig') net.WriteString(name) net.Broadcast()
	end)

	timer.Create('HLAMarks', 1, 0, function()
		local changed = false
		for i = #MK.list, 1, -1 do
			local m = MK.list[i]
			local sqGone = m.squad ~= 0 and not (HLA.Squads and HLA.Squads.list[m.squad])
			if CurTime() - m.t > (m.life or MK.Life) or sqGone or (m.squad ~= 0 and not IsValid(m.owner)) then
				table.remove(MK.list, i)
				changed = true
			end
		end
		if changed then MK.SendAll() end
	end)
	hook.Add('PlayerInitialSpawn', 'HLAMarks', function() timer.Simple(2, MK.SendAll) end)
	return
end

---------------------------------------------------------------------------------------------------
-- client
MK.marks = {}
local LIFE = {death = MK.DeathLife}
net.Receive('hla_marks', function()
	local fresh = {}
	for _ = 1, net.ReadUInt(7) do
		local m = {id = net.ReadUInt(16), kind = net.ReadString(), pos = net.ReadVector(), owner = net.ReadEntity(), name = net.ReadString(), t = net.ReadFloat()}
		local old
		for _, o in ipairs(MK.marks) do if o.id == m.id then old = o end end
		m.born = old and old.born or RealTime()
		if not old then surface.PlaySound(m.kind == 'death' and 'hla/ui/textline_end.wav' or 'hla/ui/textline_6.wav') end
		fresh[#fresh + 1] = m
	end
	MK.marks = fresh
end)

function MK.Put() net.Start('hla_mark') net.SendToServer() end
concommand.Add('hla_mark', MK.Put)

local wasDown = false
hook.Add('Think', 'HLAMarkKey', function()
	local down = input.IsMouseDown(MOUSE_MIDDLE) and not vgui.CursorVisible() and not gui.IsGameUIVisible()
	if down and not wasDown then
		local p = LocalPlayer()
		if IsValid(p) and p:Alive() and not p:GetNWBool('hla_in_menu') then MK.Put() end
	end
	wasDown = down
end)

local STYLE = {
	point = {title = 'ТОЧКА', col = Color(110, 210, 255)},
	move = {title = 'ВЫДВИЖЕНИЕ', col = Color(90, 200, 255)},
	target = {title = 'КОНТАКТ', col = Color(255, 150, 60)},
	death = {title = 'БИОСИГНАЛ ПОТЕРЯН', col = Color(255, 72, 64)},
	critical = {title = 'БИОСИГНАЛ КРИТИЧЕСКИЙ', col = Color(255, 140, 60)},
}

local function sc() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local s = sc()
	surface.CreateFont('hla_mk_title', {font = 'Exo 2', size = math.max(12, math.floor(17 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_mk_name', {font = 'Exo 2', size = math.max(12, math.floor(17 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_mk_dist', {font = 'Exo 2', size = math.max(11, math.floor(15 * s)), weight = 600, extended = true})
	surface.CreateFont('hla_mk_sub', {font = 'Exo 2', size = math.max(10, math.floor(12 * s)), weight = 600, extended = true})
	surface.CreateFont('hla_bs', {font = 'Exo 2', size = math.max(12, math.floor(19 * s)), weight = 700, extended = true})
end

local function poly(pts, c, a)
	draw.NoTexture()
	surface.SetDrawColor(c.r, c.g, c.b, (c.a or 255) * (a or 1))
	surface.DrawPoly(pts)
end
local function circle(x, y, r, c, a, seg)
	seg = seg or 28
	local pts = {}
	for i = 0, seg - 1 do
		local t = i / seg * math.pi * 2
		pts[#pts + 1] = {x = x + math.cos(t) * r, y = y + math.sin(t) * r}
	end
	poly(pts, c, a)
end
local function ring(x, y, r, th, c, a, from, to)
	from, to = from or 0, to or 360
	local seg = math.max(6, math.floor((to - from) / 10))
	for i = 0, seg - 1 do
		local t0, t1 = math.rad(from + (to - from) * i / seg), math.rad(from + (to - from) * (i + 1) / seg)
		poly({{x = x + math.cos(t0) * r, y = y + math.sin(t0) * r}, {x = x + math.cos(t1) * r, y = y + math.sin(t1) * r},
			{x = x + math.cos(t1) * (r - th), y = y + math.sin(t1) * (r - th)}, {x = x + math.cos(t0) * (r - th), y = y + math.sin(t0) * (r - th)}}, c, a)
	end
end
local heartMat = Material('hla/ui/heart', 'smooth')
local function heart(x, y, r, c, a, broken)
	if not heartMat:IsError() and not broken then
		surface.SetMaterial(heartMat)
		surface.SetDrawColor(c.r, c.g, c.b, 255 * a)
		surface.DrawTexturedRect(x - r, y - r, r * 2, r * 2)
		return
	end
	-- two lobes and a point
	local lr = r * 0.5
	circle(x - lr * 0.95, y - r * 0.15, lr, c, a, 16)
	circle(x + lr * 0.95, y - r * 0.15, lr, c, a, 16)
	poly({{x = x - r * 0.98, y = y - r * 0.05}, {x = x + r * 0.98, y = y - r * 0.05}, {x = x, y = y + r * 0.95}}, c, a)
	if broken then -- the crack
		local k = Color(18, 4, 4)
		poly({{x = x - 1, y = y - r * 0.55}, {x = x + r * 0.18, y = y - r * 0.1}, {x = x - r * 0.12, y = y + r * 0.15}, {x = x + r * 0.1, y = y + r * 0.7},
			{x = x - r * 0.04, y = y + r * 0.7}, {x = x - r * 0.26, y = y + r * 0.15}, {x = x + r * 0.02, y = y - r * 0.12}, {x = x - r * 0.16, y = y - r * 0.55}}, k, a)
	end
end
local function icon(kind, x, y, r, c, a)
	if kind == 'death' then heart(x, y, r * 0.62, c, a, true)
	elseif kind == 'critical' then heart(x, y, r * 0.62, c, a, false)
	elseif kind == 'move' then
		for k = 0, 1 do
			local yy = y - r * 0.32 + k * r * 0.42
			poly({{x = x - r * 0.5, y = yy - r * 0.12}, {x = x, y = yy + r * 0.3}, {x = x + r * 0.5, y = yy - r * 0.12}, {x = x + r * 0.5, y = yy + r * 0.08}, {x = x, y = yy + r * 0.5}, {x = x - r * 0.5, y = yy + r * 0.08}}, c, a)
		end
	elseif kind == 'target' then
		ring(x, y, r * 0.5, math.max(2, r * 0.1), c, a)
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			surface.SetDrawColor(c.r, c.g, c.b, 255 * a)
			local w, h = d[1] ~= 0 and r * 0.3 or math.max(2, r * 0.1), d[2] ~= 0 and r * 0.3 or math.max(2, r * 0.1)
			surface.DrawRect(x + d[1] * r * 0.55 - (d[1] < 0 and w or 0) - (d[1] == 0 and w / 2 or 0), y + d[2] * r * 0.55 - (d[2] < 0 and h or 0) - (d[2] == 0 and h / 2 or 0), w, h)
		end
	else
		ring(x, y, r * 0.45, math.max(2, r * 0.1), c, a)
		circle(x, y, r * 0.16, c, a, 12)
	end
end

-- the badge: dark disc, coloured ring with a slow sweep, the icon
local function badge(kind, x, y, r, c, a)
	circle(x, y, r, Color(4, 10, 16), a * 0.75)
	ring(x, y, r, math.max(2, r * 0.1), c, a * 0.9)
	ring(x, y, r + math.max(3, r * 0.22), math.max(1, r * 0.06), c, a * 0.55, (RealTime() * 90) % 360, (RealTime() * 90) % 360 + 70)
	icon(kind, x, y, r, c, a)
end

local function titleLine(text, x, y, c, a, s)
	surface.SetFont('hla_mk_title')
	local tw = surface.GetTextSize(text)
	local spaced = text
	draw.SimpleText(spaced, 'hla_mk_title', x, y, Color(c.r, c.g, c.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	surface.SetDrawColor(c.r, c.g, c.b, 200 * a)
	local lw, gap = math.floor(22 * s), math.floor(8 * s)
	surface.DrawRect(x - tw / 2 - gap - lw, y, lw, math.max(1, math.floor(2 * s)))
	surface.DrawRect(x + tw / 2 + gap, y, lw, math.max(1, math.floor(2 * s)))
end

local function zoneOf(pos) return HLA.Story and HLA.Story.ZoneAt and HLA.Story.ZoneAt(pos) or nil end

local function drawMark(m, s, W, H)
	local st = STYLE[m.kind] or STYLE.point
	local c = st.col
	local life = m.life or LIFE[m.kind] or MK.Life
	local a = m.persistent and 1 or math.Clamp(math.min((RealTime() - m.born) * 5, (life - (CurTime() - m.t)) / 3), 0, 1)
	if a <= 0 then return end
	local sp = m.pos:ToScreen()
	local margin = 70 * s
	local r = math.floor(20 * s)
	local dist = math.floor(m.pos:Distance(EyePos()) / 52.5 + 0.5)
	local off = not sp.visible or sp.x < margin or sp.x > W - margin or sp.y < margin or sp.y > H - margin
	if off then
		local dir = (m.pos - EyePos()):GetNormalized()
		local ang = EyeAngles()
		local rx, ry = dir:Dot(ang:Right()), -dir:Dot(ang:Up())
		local len = math.max(0.001, math.sqrt(rx * rx + ry * ry))
		rx, ry = rx / len, ry / len
		local k = math.min((W / 2 - margin) / math.max(math.abs(rx), 0.001), (H / 2 - margin) / math.max(math.abs(ry), 0.001))
		local x, y = W / 2 + rx * k, H / 2 + ry * k
		local rr = math.floor(r * 0.8)
		badge(m.kind, x, y, rr, c, a)
		local th = math.atan2(ry, rx)
		local tx, ty = x + math.cos(th) * (rr + 12 * s), y + math.sin(th) * (rr + 12 * s)
		poly({{x = tx + math.cos(th) * 7 * s, y = ty + math.sin(th) * 7 * s}, {x = tx + math.cos(th + 2.3) * 6 * s, y = ty + math.sin(th + 2.3) * 6 * s},
			{x = tx + math.cos(th - 2.3) * 6 * s, y = ty + math.sin(th - 2.3) * 6 * s}}, c, a)
		draw.SimpleText(dist .. 'м', 'hla_mk_dist', x, y + rr + 4 * s, Color(c.r, c.g, c.b, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		return
	end
	local x, y = sp.x, sp.y
	titleLine(st.title, x, y - r - 22 * s, c, a, s)
	badge(m.kind, x, y, r, c, a)
	local yy = y + r + 6 * s
	draw.SimpleText(dist .. 'м', 'hla_mk_dist', x, yy, Color(c.r, c.g, c.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	yy = yy + 16 * s
	local name = m.name ~= '' and m.name or (IsValid(m.owner) and m.owner:GetNWString('hla_name', '') or '')
	if name ~= '' then
		draw.SimpleText(string.upper(name), 'hla_mk_name', x, yy, Color(236, 244, 250, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		yy = yy + 18 * s
	end
	local sub = m.kind == 'death' and 'ЮНИТ ВЫВЕДЕН ИЗ СТРОЯ' or (m.kind ~= 'critical' and IsValid(m.owner) and m.kind ~= 'death' and ('ОТМЕТИЛ ' .. string.upper(m.owner:GetNWString('hla_name', '')))) or nil
	local zone = zoneOf(m.pos)
	local line = table.concat({sub or '', zone and string.upper(zone) or ''}, (sub and zone) and '  ::  ' or '')
	if line ~= '' then
		draw.SimpleText(line, 'hla_mk_sub', x, yy, Color(170, 196, 214, 200 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

local function critical()
	local out = {}
	local SQ = HLA.Squads
	local me = LocalPlayer()
	local sq = SQ and SQ.Of(me)
	if not sq then return out end
	for _, p in ipairs(sq.members) do
		if IsValid(p) and p ~= me and p:Alive() and p:Health() > 0 and p:Health() <= 30 then
			out[#out + 1] = {kind = 'critical', pos = p:GetPos() + Vector(0, 0, 84), owner = p, name = p:GetNWString('hla_name', ''), persistent = true, born = 0, t = CurTime()}
		end
	end
	return out
end

hook.Add('HUDPaint', 'HLAMarks', function()
	local p = LocalPlayer()
	if not IsValid(p) or p:GetNWBool('hla_in_menu') then return end
	if HLA.Tab and HLA.Tab.fade > 0 then return end
	if HLA.Binoculars and HLA.Binoculars.k > 0.2 then return end
	fonts()
	local s, W, H = sc(), ScrW(), ScrH()
	for _, m in ipairs(MK.marks) do drawMark(m, s, W, H) end
	for _, m in ipairs(critical()) do drawMark(m, s, W, H) end
end)

---------------------------------------------------------------------------------------------------
-- top right of the visor: the lost biosignals (drawn on the curved HUD)
local feed = {}
net.Receive('hla_biosig', function()
	table.insert(feed, 1, {name = net.ReadString(), t = RealTime(), time = os.date('%H:%M:%S')})
	while #feed > 5 do table.remove(feed) end
end)
hook.Add('HLAHUDPaint', 'HLABiosignalFeed', function()
	if #feed == 0 then return end
	fonts()
	local s = sc()
	local x, y = ScrW() - math.floor(66 * s), HLA.HudRightBottom or math.floor(48 * s)
	for i = #feed, 1, -1 do
		if RealTime() - feed[i].t > 12 then table.remove(feed, i) end
	end
	for _, f in ipairs(feed) do
		local age = RealTime() - f.t
		local a = math.Clamp(math.min(age * 4, (12 - age) / 1.5), 0, 1)
		local blink = age < 2 and (math.floor(age * 6) % 2 == 0) and 1 or 0.85
		draw.SimpleText('ПОТЕРЯ БИОСИГНАЛА  ::  ' .. string.upper(f.name), 'hla_bs', x, y, Color(255, 72, 64, 255 * a * blink), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText(f.time, 'hla_mk_sub', x, y + math.floor(22 * s), Color(255, 140, 130, 170 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		y = y + math.floor(44 * s)
	end
end)
