-- Squad markers: any member and the leader put a mark where they aim — middle mouse button (or bind a key
-- to «hla_mark»). Only the own squad sees them, through walls. A member has one mark at a time, the leader
-- three (the oldest goes). A mark lives 60 s; a click on one's own mark removes it.
-- Look (Combine visor): a member's mark — a cyan rhombus with a dot, the leader's — a green triangle with «К»;
-- aimed at a player / NPC — «ЦЕЛЬ» with a red frame. A thin leg down to the point, the owner and the distance
-- over it; off the screen the mark sticks to the edge as an arrow.
HLA = HLA or {}
local MK = {list = {}}
HLA.Markers = MK
MK.Life = 60
MK.PerMember, MK.PerLeader = 1, 3

if SERVER then
	util.AddNetworkString('hla_mark')     -- client -> server: put / remove
	util.AddNetworkString('hla_marks')    -- server -> squad: the list of the squad
	local nextID = 0

	local function sendSquad(sq)
		if not sq then return end
		local list = {}
		for _, m in ipairs(MK.list) do if m.squad == sq.id then list[#list + 1] = m end end
		net.Start('hla_marks')
		net.WriteUInt(#list, 6)
		for _, m in ipairs(list) do
			net.WriteUInt(m.id, 16)
			net.WriteVector(m.pos)
			net.WriteEntity(m.owner)
			net.WriteBool(m.leader)
			net.WriteBool(m.target)
			net.WriteFloat(m.t)
		end
		local to = {}
		for _, p in ipairs(sq.members) do if IsValid(p) then to[#to + 1] = p end end
		net.Send(to)
	end
	MK.SendSquad = sendSquad

	net.Receive('hla_mark', function(_, p)
		if (p.HLAMarkNext or 0) > CurTime() or not p:Alive() then return end
		p.HLAMarkNext = CurTime() + 0.35
		local SQ = HLA.Squads
		local sq = SQ and SQ.Of(p)
		if not sq then p:ChatPrint('Метки: вы не в отряде') return end
		local tr = util.TraceLine({start = p:EyePos(), endpos = p:EyePos() + p:GetAimVector() * 6000, filter = p, mask = MASK_SHOT})
		if not tr.Hit then return end
		local pos = tr.HitPos
		-- a click on one's own mark removes it
		for i = #MK.list, 1, -1 do
			local m = MK.list[i]
			if m.owner == p and m.pos:DistToSqr(pos) < 60 * 60 then
				table.remove(MK.list, i)
				sendSquad(sq)
				return
			end
		end
		local leader = sq.leader == p
		local own = {}
		for i, m in ipairs(MK.list) do if m.owner == p then own[#own + 1] = i end end
		local limit = leader and MK.PerLeader or MK.PerMember
		while #own >= limit do table.remove(MK.list, table.remove(own, 1)) end
		local e = tr.Entity
		local target = IsValid(e) and (e:IsPlayer() or e:IsNPC() or e:IsNextBot())
		if target then pos = e:WorldSpaceCenter() + Vector(0, 0, e:OBBMaxs().z * 0.45) end
		nextID = (nextID + 1) % 65535
		MK.list[#MK.list + 1] = {id = nextID, pos = pos, owner = p, leader = leader, target = target, t = CurTime(), squad = sq.id}
		sendSquad(sq)
	end)

	-- old marks go; marks of a squad that is gone too
	timer.Create('HLAMarks', 1, 0, function()
		local changed = {}
		for i = #MK.list, 1, -1 do
			local m = MK.list[i]
			local sq = HLA.Squads and HLA.Squads.list[m.squad]
			if CurTime() - m.t > MK.Life or not sq or not IsValid(m.owner) then
				table.remove(MK.list, i)
				if sq then changed[sq] = true end
			end
		end
		for sq in pairs(changed) do sendSquad(sq) end
	end)
	return
end

---------------------------------------------------------------------------------------------------
-- client
MK.marks = {}
net.Receive('hla_marks', function()
	local fresh = {}
	for _ = 1, net.ReadUInt(6) do
		local m = {id = net.ReadUInt(16), pos = net.ReadVector(), owner = net.ReadEntity(), leader = net.ReadBool(), target = net.ReadBool(), t = net.ReadFloat()}
		local old
		for _, o in ipairs(MK.marks) do if o.id == m.id then old = o end end
		m.born = old and old.born or RealTime()
		if not old then surface.PlaySound(m.leader and 'hla/ui/textline_end.wav' or 'hla/ui/textline_6.wav') end
		fresh[#fresh + 1] = m
	end
	MK.marks = fresh
end)

function MK.Put()
	net.Start('hla_mark') net.SendToServer()
end
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

local CYAN = Color(110, 200, 255)
local GREEN = Color(96, 228, 150)
local RED = Color(255, 90, 76)
local function sc() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	surface.CreateFont('hla_mk', {font = 'Roboto Condensed', size = math.max(13, math.floor(19 * sc())), weight = 700, extended = true})
	surface.CreateFont('hla_mk_s', {font = 'Roboto Condensed', size = math.max(11, math.floor(15 * sc())), weight = 500, extended = true})
end

local function poly(pts, col)
	surface.SetDrawColor(col)
	draw.NoTexture()
	surface.DrawPoly(pts)
end
local function ring(x, y, pts, th, col) -- an outline of a closed polygon, th thick
	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]
		local dx, dy = b.x - a.x, b.y - a.y
		local len = math.max(0.001, math.sqrt(dx * dx + dy * dy))
		local nx, ny = -dy / len * th / 2, dx / len * th / 2
		poly({{x = a.x - nx, y = a.y - ny}, {x = b.x - nx, y = b.y - ny}, {x = b.x + nx, y = b.y + ny}, {x = a.x + nx, y = a.y + ny}}, col)
	end
end

hook.Add('HUDPaint', 'HLAMarks', function()
	local p = LocalPlayer()
	if not IsValid(p) or #MK.marks == 0 or p:GetNWBool('hla_in_menu') then return end
	if HLA.Tab and HLA.Tab.fade > 0 then return end
	fonts()
	local s = sc()
	local W, H = ScrW(), ScrH()
	local margin = 60 * s
	for _, m in ipairs(MK.marks) do
		local age = RealTime() - m.born
		local left = MK.Life - (CurTime() - m.t)
		local a = math.Clamp(math.min(age * 5, left / 3), 0, 1)
		local col = m.target and RED or m.leader and GREEN or CYAN
		local top = m.pos + Vector(0, 0, m.target and 10 or 46)
		local sp, base = top:ToScreen(), m.pos:ToScreen()
		local off = not sp.visible or sp.x < margin or sp.x > W - margin or sp.y < margin or sp.y > H - margin
		local x, y = sp.x, sp.y
		if off then
			-- to the edge, as an arrow pointing to it
			local dir = (m.pos - EyePos()):GetNormalized()
			local ang = EyeAngles()
			local rx, ry = dir:Dot(ang:Right()), -dir:Dot(ang:Up())
			local len = math.max(0.001, math.sqrt(rx * rx + ry * ry))
			rx, ry = rx / len, ry / len
			local k = math.min((W / 2 - margin) / math.max(math.abs(rx), 0.001), (H / 2 - margin) / math.max(math.abs(ry), 0.001))
			x, y = W / 2 + rx * k, H / 2 + ry * k
			local r = 14 * s
			local th = math.atan2(ry, rx)
			poly({{x = x + math.cos(th) * r, y = y + math.sin(th) * r},
				{x = x + math.cos(th + 2.4) * r, y = y + math.sin(th + 2.4) * r},
				{x = x + math.cos(th - 2.4) * r, y = y + math.sin(th - 2.4) * r}}, Color(col.r, col.g, col.b, 220 * a))
		else
			-- the leg down to the point
			if base.visible and not m.target then
				surface.SetDrawColor(col.r, col.g, col.b, 110 * a)
				surface.DrawRect(x - 1, y + 12 * s, 2, math.max(0, base.y - y - 12 * s))
				surface.DrawRect(base.x - 5 * s, base.y - 1, 10 * s, 2)
			end
			local pulse = 1 + 0.12 * math.sin(RealTime() * 5) * (age < 3 and 1 or 0.3)
			local r = 12 * s * pulse
			if m.leader then
				local tri = {{x = x, y = y + r}, {x = x - r * 1.1, y = y - r * 0.8}, {x = x + r * 1.1, y = y - r * 0.8}}
				poly({{x = x, y = y + r}, {x = x - r * 1.1, y = y - r * 0.8}, {x = x + r * 1.1, y = y - r * 0.8}}, Color(col.r, col.g, col.b, 60 * a))
				ring(x, y, tri, math.max(2, 2.5 * s), Color(col.r, col.g, col.b, 240 * a))
				draw.SimpleText('К', 'hla_mk_s', x, y - r * 0.15, Color(255, 255, 255, 240 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				local rh = {{x = x, y = y - r}, {x = x + r, y = y}, {x = x, y = y + r}, {x = x - r, y = y}}
				poly(rh, Color(col.r, col.g, col.b, 50 * a))
				ring(x, y, rh, math.max(2, 2.5 * s), Color(col.r, col.g, col.b, 240 * a))
				poly({{x = x, y = y - 3 * s}, {x = x + 3 * s, y = y}, {x = x, y = y + 3 * s}, {x = x - 3 * s, y = y}}, Color(255, 255, 255, 230 * a))
			end
			if m.target then
				local q = r * 1.7
				for _, c in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
					surface.SetDrawColor(col.r, col.g, col.b, 230 * a)
					surface.DrawRect(x + c[1] * q - (c[1] > 0 and 8 * s or 0), y + c[2] * q - (c[2] > 0 and 2 or 0), 8 * s, 2)
					surface.DrawRect(x + c[1] * q - (c[1] > 0 and 2 or 0), y + c[2] * q - (c[2] > 0 and 8 * s or 0), 2, 8 * s)
				end
			end
			-- owner and distance
			local who = IsValid(m.owner) and string.gsub(string.upper(m.owner:GetNWString('hla_name', m.owner:Nick())), '^ЮНИТ%s+', '') or '?'
			local dist = math.floor(m.pos:Distance(EyePos()) / 52.5 + 0.5)
			local label = (m.target and 'ЦЕЛЬ' or m.leader and 'ПРИКАЗ' or 'ТОЧКА') .. '  ::  ' .. dist .. ' М'
			draw.SimpleTextOutlined(label, 'hla_mk', x, y - 20 * s, Color(col.r, col.g, col.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 6, 12, 160 * a))
			draw.SimpleText(who, 'hla_mk_s', x, y - 38 * s, Color(220, 236, 246, 200 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
	end
end)
