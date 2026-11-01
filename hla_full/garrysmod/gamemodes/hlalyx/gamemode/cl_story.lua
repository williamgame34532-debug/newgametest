-- Story / rounds (client): the chapter card, the vote (keys 1..3), the spectator line, round info and the
-- big result lines. Everything is scaled from 1920x1080 by the smaller side, so it keeps its place on any
-- screen (16:9, 21:9, 16:10, 4:3).
local S = HLA.Story
local BLUE = HLA.Hud.AMBER_C
local WHITE = Color(226, 236, 244)
local GREY = Color(122, 150, 170)
local RED = Color(236, 64, 52)

local function sc() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local s = sc()
	surface.CreateFont('hla_st_small', {font = 'Play', size = math.max(14, math.floor(24 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_st_mid', {font = 'Play', size = math.max(18, math.floor(34 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_st_big', {font = 'Russo One', size = math.max(28, math.floor(78 * s)), weight = 400, extended = true})
	surface.CreateFont('hla_st_mono', {font = 'IBM Plex Mono', size = math.max(13, math.floor(20 * s)), weight = 500, extended = true})
end

local function hiddenUI()
	local p = LocalPlayer()
	return not IsValid(p) or p:GetNWBool('hla_in_menu') or (HLA.Menu and HLA.Menu.State and HLA.Menu.State.fade > 0)
end

---------------------------------------------------------------------------------------------------
-- chapter card: letterbox bars slide in, «ГЛАВА 1» small, the name big, the subtitle under it
local card
net.Receive('hla_story_card', function()
	card = {title = net.ReadString(), name = net.ReadString(), sub = net.ReadString(), life = net.ReadFloat(), t = RealTime()}
	surface.PlaySound('hla/ui/textline_end.wav')
end)

local function typed(text, n)
	local len = utf8.len(text) or #text
	if n >= len then return text end
	local o = utf8.offset(text, math.max(0, math.floor(n)) + 1)
	return o and string.sub(text, 1, o - 1) or text
end

hook.Add('HUDPaint', 'HLAStoryCard', function()
	if not card or hiddenUI() then return end
	local age = RealTime() - card.t
	local life = card.life or 7
	if age > life then card = nil return end
	fonts()
	local s = sc()
	local k = math.Clamp(math.min(age / 0.6, (life - age) / 0.8), 0, 1)
	local ease = k * k * (3 - 2 * k)
	local W, H = ScrW(), ScrH()
	local bar = math.floor(H * 0.11 * ease)
	surface.SetDrawColor(0, 0, 0, 235)
	surface.DrawRect(0, 0, W, bar)
	surface.DrawRect(0, H - bar, W, bar)
	-- the plate in the middle
	local cy = H * 0.42
	local pw = math.floor(900 * s)
	surface.SetDrawColor(4, 12, 20, 170 * ease)
	surface.DrawRect(W / 2 - pw / 2, cy - 70 * s, pw, 170 * s)
	surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 220 * ease)
	surface.DrawRect(W / 2 - pw / 2, cy - 70 * s, pw * math.min(1, age / 1.2), math.max(1, 2 * s))
	surface.DrawRect(W / 2 + pw / 2 - pw * math.min(1, age / 1.2), cy + 100 * s - math.max(1, 2 * s), pw * math.min(1, age / 1.2), math.max(1, 2 * s))
	local a = 255 * ease
	draw.SimpleText(typed(string.upper(card.title), age * 30), 'hla_st_mid', W / 2, cy - 40 * s, Color(BLUE.r, BLUE.g, BLUE.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(typed(string.upper(card.name), (age - 0.4) * 24), 'hla_st_big', W / 2, cy + 18 * s, Color(WHITE.r, WHITE.g, WHITE.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	if card.sub ~= '' then
		draw.SimpleText(typed(card.sub, (age - 1) * 40), 'hla_st_mono', W / 2, cy + 74 * s, Color(GREY.r, GREY.g, GREY.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

-- big result lines (ПОБЕДА …, ОТРЯД ПОТЕРЯН …)
local msg
net.Receive('hla_story_msg', function()
	msg = {text = net.ReadString(), sub = net.ReadString(), t = RealTime()}
	surface.PlaySound('hla/ui/textline_end.wav')
end)
hook.Add('HUDPaint', 'HLAStoryMsg', function()
	if not msg or hiddenUI() then return end
	local age = RealTime() - msg.t
	if age > 6 then msg = nil return end
	fonts()
	local s = sc()
	local a = 255 * math.Clamp(math.min(age * 3, (6 - age) / 0.8), 0, 1)
	draw.SimpleTextOutlined(msg.text, 'hla_st_big', ScrW() / 2, ScrH() * 0.3, Color(WHITE.r, WHITE.g, WHITE.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 6, 12, a * 0.7))
	if msg.sub ~= '' then
		draw.SimpleText(string.upper(msg.sub), 'hla_st_small', ScrW() / 2, ScrH() * 0.3 + 56 * s, Color(BLUE.r, BLUE.g, BLUE.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

---------------------------------------------------------------------------------------------------
-- the vote: keys 1..3 while it runs (the weapon slots are free again after it)
function S.VoteKey(bind)
	if S.State() ~= S.VOTE or hiddenUI() then return false end
	local n = tonumber(string.match(bind, '^slot(%d)$') or '')
	if not n or not S.CHOICES[n] then return false end
	net.Start('hla_vote') net.WriteUInt(n, 3) net.SendToServer()
	surface.PlaySound('hla/ui/textline_end.wav')
	return true
end

hook.Add('HUDPaint', 'HLAStoryVote', function()
	if S.State() ~= S.VOTE or hiddenUI() then return end
	fonts()
	local s = sc()
	local left = math.max(0, GetGlobal2Float('hla_vote_end', 0) - CurTime())
	local w = math.floor(640 * s)
	local rowH = math.floor(46 * s)
	local x = ScrW() / 2 - w / 2
	local y = math.floor(ScrH() * 0.16)
	local h = math.floor(64 * s) + rowH * #S.CHOICES + math.floor(16 * s)
	surface.SetDrawColor(4, 12, 20, 200)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 220)
	surface.DrawRect(x, y, w, math.max(1, 2 * s))
	surface.DrawRect(x, y, math.max(2, 3 * s), h)
	draw.SimpleText('ГОЛОСОВАНИЕ', 'hla_st_mid', x + 20 * s, y + 32 * s, BLUE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(string.format('%d С', math.ceil(left)), 'hla_st_mid', x + w - 20 * s, y + 32 * s, left < 5 and RED or WHITE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	-- time bar
	local total = GetGlobal2Int('hla_vote_time', 20)
	surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 120)
	surface.DrawRect(x + 20 * s, y + 56 * s, (w - 40 * s) * math.Clamp(left / total, 0, 1), math.max(1, 2 * s))
	local mine = LocalPlayer():GetNW2Int('hla_my_vote', 0)
	local sum = 0
	for i = 1, #S.CHOICES do sum = sum + GetGlobal2Int('hla_vote_' .. i, 0) end
	for i, c in ipairs(S.CHOICES) do
		local ry = y + 64 * s + (i - 1) * rowH
		local n = GetGlobal2Int('hla_vote_' .. i, 0)
		if sum > 0 then
			surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 34)
			surface.DrawRect(x + 12 * s, ry + 4 * s, (w - 24 * s) * n / sum, rowH - 8 * s)
		end
		if mine == i then
			surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 220)
			surface.DrawRect(x + 12 * s, ry + 4 * s, math.max(2, 3 * s), rowH - 8 * s)
		end
		draw.SimpleText('[' .. i .. ']', 'hla_st_mono', x + 26 * s, ry + rowH / 2, mine == i and WHITE or BLUE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(c.label, 'hla_st_small', x + 80 * s, ry + rowH / 2, mine == i and WHITE or Color(196, 220, 236), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(tostring(n), 'hla_st_small', x + w - 26 * s, ry + rowH / 2, BLUE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	if mine == 0 then
		draw.SimpleText('нажмите 1, 2 или 3', 'hla_st_mono', ScrW() / 2, y + h + 18 * s, GREY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

---------------------------------------------------------------------------------------------------
-- round info at the top: waiting for players, chapter, PvP time and teams
hook.Add('HUDPaint', 'HLAStoryInfo', function()
	if hiddenUI() then return end
	fonts()
	local s = sc()
	local st = S.State()
	local text, col
	if st == S.WAIT then
		local need = GetGlobal2Int('hla_min_players', 2)
		local n = 0
		for _, p in ipairs(player.GetAll()) do if not p:GetNWBool('hla_in_menu') then n = n + 1 end end
		if n < need then text = string.format('ОЖИДАНИЕ ИГРОКОВ  %d / %d', n, need) end
	elseif st == S.PVP then
		local left = math.max(0, GetGlobal2Float('hla_round_end', 0) - CurTime())
		text = string.format('ПВП  ::  %02d:%02d', math.floor(left / 60), math.floor(left % 60))
		local p = LocalPlayer()
		if S.Mode() == 'teams' and (p:Team() == S.TEAM1 or p:Team() == S.TEAM2) then
			local tn = GetGlobal2String(p:Team() == S.TEAM1 and 'hla_team1' or 'hla_team2', '')
			text = text .. '  ::  ' .. tn
			col = p:Team() == S.TEAM2 and Color(236, 96, 72) or BLUE
		end
	elseif st == S.END then
		text = 'КОНЕЦ РАУНДА'
	end
	if not text then return end
	draw.SimpleText(text, 'hla_st_mono', ScrW() / 2, math.floor(26 * s), col or BLUE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

---------------------------------------------------------------------------------------------------
-- spectator: who is watched and the keys
hook.Add('HUDPaint', 'HLASpectator', function()
	local p = LocalPlayer()
	if not IsValid(p) or p:Alive() or hiddenUI() or not S.InRound() then return end
	fonts()
	local s = sc()
	local t = p:GetObserverTarget()
	local mode = p:GetObserverMode()
	local who = IsValid(t) and t:IsPlayer() and string.upper(t:GetNWString('hla_name', t:Nick())) or 'СВОБОДНАЯ КАМЕРА'
	local y = ScrH() - math.floor(150 * s)
	draw.SimpleText('НАБЛЮДЕНИЕ', 'hla_st_small', ScrW() / 2, y, BLUE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(who, 'hla_st_mid', ScrW() / 2, y + 34 * s, WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	local how = mode == OBS_MODE_IN_EYE and 'ОТ ПЕРВОГО ЛИЦА' or mode == OBS_MODE_CHASE and 'ОТ ТРЕТЬЕГО ЛИЦА' or 'СВОБОДНО'
	draw.SimpleText('ЛКМ / ПКМ — другой игрок     ПРОБЕЛ — ' .. how, 'hla_st_mono', ScrW() / 2, y + 68 * s, GREY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	local st = S.State()
	local tip = st == S.STORY and 'вы вернётесь в начале следующей главы' or 'вы вернётесь в следующем раунде'
	draw.SimpleText(tip, 'hla_st_mono', ScrW() / 2, y + 94 * s, Color(GREY.r, GREY.g, GREY.b, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- the HUD hides while spectating (it would show the dead player's own numbers)
hook.Add('HUDShouldDraw', 'HLASpectator', function(name)
	local p = LocalPlayer()
	if IsValid(p) and not p:Alive() and S.InRound() and (name == 'CHudHealth' or name == 'CHudDamageIndicator') then return false end
end)
