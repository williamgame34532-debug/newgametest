-- TAB (held): the biosignal index of the units, in the look of the visor. Squads together (their name over
-- them, the leader marked), then the units without a squad; status (В СТРОЮ / ВЫВЕДЕН / НАБЛЮДАЕТ / В МЕНЮ),
-- the zone of the units one sees, kills and ping; in PvP by teams the team colour on the left.
local SB = {shown = false, k = 0}
HLA.Scoreboard = SB

local CYAN = Color(110, 200, 255)
local CYAN_HI = Color(170, 230, 255)
local WHITE = Color(226, 236, 244)
local GREY = Color(122, 150, 170)
local GREEN = Color(96, 228, 150)
local RED = Color(255, 90, 76)
local logo = Material('hla/ui/combine_logo', 'smooth')

function GM:ScoreboardShow() SB.shown = true end
function GM:ScoreboardHide() SB.shown = false end

local function sc() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local s = sc()
	surface.CreateFont('hla_sb_title', {font = 'Exo 2', size = math.max(18, math.floor(34 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_sb_head', {font = 'Exo 2', size = math.max(11, math.floor(15 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_sb_row', {font = 'Exo 2', size = math.max(13, math.floor(20 * s)), weight = 600, extended = true})
	surface.CreateFont('hla_sb_sq', {font = 'Exo 2', size = math.max(12, math.floor(17 * s)), weight = 700, extended = true, italic = true})
end

local function status(p)
	if p:GetNWBool('hla_in_menu') then return 'В МЕНЮ', GREY end
	if p:Alive() then return 'В СТРОЮ', GREEN end
	if p:GetObserverMode() ~= OBS_MODE_NONE then return 'НАБЛЮДАЕТ', CYAN end
	return 'ВЫВЕДЕН', RED
end

-- the rows: {kind = 'squad', name} / {kind = 'unit', p, leader}
local function rows()
	local SQ = HLA.Squads
	local out, used = {}, {}
	if SQ then
		for id, s in SortedPairs(SQ.list or {}) do
			out[#out + 1] = {kind = 'squad', name = s.name, n = #s.members}
			for _, m in ipairs(s.members) do
				if IsValid(m) then out[#out + 1] = {kind = 'unit', p = m, leader = m == s.leader} used[m] = true end
			end
		end
	end
	local rest = {}
	for _, p in ipairs(player.GetAll()) do if not used[p] then rest[#rest + 1] = p end end
	table.sort(rest, function(a, b) return a:GetNWString('hla_name', a:Nick()) < b:GetNWString('hla_name', b:Nick()) end)
	if #rest > 0 then
		out[#out + 1] = {kind = 'squad', name = 'БЕЗ ОТРЯДА', n = #rest, dim = true}
		for _, p in ipairs(rest) do out[#out + 1] = {kind = 'unit', p = p} end
	end
	return out
end

hook.Add('HUDPaint', 'HLAScoreboard', function()
	SB.k = math.Clamp(SB.k + (SB.shown and 1 or -1) * FrameTime() * 7, 0, 1)
	if SB.k <= 0 then return end
	fonts()
	local s = sc()
	local a = SB.k * SB.k * (3 - 2 * SB.k)
	local W, H = ScrW(), ScrH()
	local w = math.floor(1040 * s)
	local x = math.floor(W / 2 - w / 2)
	local y = math.floor(H * 0.12 + (1 - a) * 30 * s)
	local list = rows()
	local rowH = math.floor(34 * s)
	local h = math.floor(120 * s) + #list * rowH + math.floor(30 * s)
	h = math.min(h, H - y - math.floor(40 * s))
	-- the glass
	surface.SetDrawColor(3, 10, 16, 215 * a)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 230 * a)
	surface.DrawRect(x, y, w, math.max(2, math.floor(3 * s)))
	for _, c in ipairs({{x, y + h}, {x + w, y + h}}) do
		surface.DrawRect(c[1] - (c[1] > x and math.floor(24 * s) or 0), c[2] - 2, math.floor(24 * s), 2)
	end
	-- head: the symbol, the title, the counter
	local tx = x + math.floor(24 * s)
	if not logo:IsError() then
		local ls = math.floor(46 * s)
		surface.SetMaterial(logo)
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 230 * a)
		surface.DrawTexturedRect(tx, y + math.floor(18 * s), ls, ls)
		tx = tx + ls + math.floor(16 * s)
	end
	draw.SimpleText('ИНДЕКС БИОСИГНАЛОВ', 'hla_sb_title', tx, y + math.floor(22 * s), Color(CYAN_HI.r, CYAN_HI.g, CYAN_HI.b, 255 * a))
	draw.SimpleText(string.upper(GetHostName() or ''), 'hla_sb_head', tx, y + math.floor(62 * s), Color(GREY.r, GREY.g, GREY.b, 230 * a))
	draw.SimpleText('В СЕТИ  ' .. #player.GetAll() .. ' / ' .. game.MaxPlayers(), 'hla_sb_row', x + w - math.floor(24 * s), y + math.floor(30 * s), Color(CYAN.r, CYAN.g, CYAN.b, 255 * a), TEXT_ALIGN_RIGHT)
	-- columns
	local cy = y + math.floor(92 * s)
	local cols = {{'ЮНИТ', 0.04}, {'СТАТУС', 0.42}, {'ЗОНА', 0.58}, {'УБИЙСТВ', 0.82, TEXT_ALIGN_RIGHT}, {'ПИНГ', 0.95, TEXT_ALIGN_RIGHT}}
	for _, c in ipairs(cols) do
		draw.SimpleText(c[1], 'hla_sb_head', x + w * c[2], cy, Color(GREY.r, GREY.g, GREY.b, 220 * a), c[3] or TEXT_ALIGN_LEFT)
	end
	surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 60 * a)
	surface.DrawRect(x + math.floor(16 * s), cy + math.floor(20 * s), w - math.floor(32 * s), 1)
	local ry = cy + math.floor(28 * s)
	local me = LocalPlayer()
	local teams = HLA.Story and HLA.Story.State and HLA.Story.State() == 'pvp' and HLA.Story.Mode() == 'teams'
	for i, r in ipairs(list) do
		if ry + rowH > y + h - math.floor(10 * s) then break end
		if r.kind == 'squad' then
			draw.SimpleText('<:: ' .. string.upper(r.name) .. '  [' .. r.n .. ']', 'hla_sb_sq', x + w * 0.03, ry + rowH / 2, r.dim and Color(GREY.r, GREY.g, GREY.b, 220 * a) or Color(CYAN.r, CYAN.g, CYAN.b, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			local p = r.p
			if p == me then
				surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 28 * a)
				surface.DrawRect(x + math.floor(12 * s), ry + 2, w - math.floor(24 * s), rowH - 4)
			end
			if teams then
				local tc = team.GetColor(p:Team())
				surface.SetDrawColor(tc.r, tc.g, tc.b, 230 * a)
				surface.DrawRect(x + math.floor(12 * s), ry + 4, math.max(2, math.floor(4 * s)), rowH - 8)
			end
			local name = string.upper(p:GetNWString('hla_name', p:Nick())) .. (r.leader and '  (К)' or '')
			draw.SimpleText(name, 'hla_sb_row', x + w * 0.04, ry + rowH / 2, Color(WHITE.r, WHITE.g, WHITE.b, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local st, sc2 = status(p)
			draw.SimpleText(st, 'hla_sb_head', x + w * 0.42, ry + rowH / 2, Color(sc2.r, sc2.g, sc2.b, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local zone = (not p:IsDormant()) and HLA.Story and HLA.Story.ZoneAt and HLA.Story.ZoneAt(p:GetPos()) or nil
			draw.SimpleText(zone and string.upper(zone) or '—', 'hla_sb_head', x + w * 0.58, ry + rowH / 2, Color(GREY.r, GREY.g, GREY.b, 230 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(tostring(p:Frags()), 'hla_sb_row', x + w * 0.82, ry + rowH / 2, Color(WHITE.r, WHITE.g, WHITE.b, 230 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			local ping = p:Ping()
			local pc = ping < 80 and GREEN or ping < 160 and CYAN or RED
			draw.SimpleText(tostring(ping), 'hla_sb_row', x + w * 0.95, ry + rowH / 2, Color(pc.r, pc.g, pc.b, 230 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		ry = ry + rowH
	end
end)
