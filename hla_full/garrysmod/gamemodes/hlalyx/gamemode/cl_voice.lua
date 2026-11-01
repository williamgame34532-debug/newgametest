-- Voice chat as the units' radio: instead of the standard voice panel, a list on the right of the visor
-- («ЭФИР», the unit, the channel, a level meter), a radio click when someone keys in, and over a talking
-- player a small radio icon with waves that follow the voice level (the engine icon is off: sv_story.lua).
local BLUE = HLA.Hud.AMBER_C
local WHITE = Color(226, 236, 244)
local GREY = Color(122, 150, 170)

local talking = {} -- player -> {t = start time, level = smoothed}

local function click(on)
	local snd = on and ('npc/combine_soldier/vo/on' .. math.random(1, 2) .. '.wav') or ('npc/combine_soldier/vo/off' .. math.random(1, 3) .. '.wav')
	if IsValid(LocalPlayer()) then LocalPlayer():EmitSound(snd, 0, 100, 0.22, CHAN_STATIC) end
end

function GM:PlayerStartVoice(p)
	if not IsValid(p) then return end
	if not talking[p] then click(true) end
	talking[p] = {t = RealTime(), level = 0}
end

function GM:PlayerEndVoice(p)
	if talking[p] then click(false) end
	talking[p] = nil
end

-- the standard panel list of the base gamemode stays hidden
hook.Add('InitPostEntity', 'HLAVoicePanel', function()
	if IsValid(g_VoicePanelList) then g_VoicePanelList:SetVisible(false) end
end)

local function sc() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local s = sc()
	surface.CreateFont('hla_vc_name', {font = 'Play', size = math.max(13, math.floor(22 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_vc_small', {font = 'IBM Plex Mono', size = math.max(10, math.floor(15 * s)), weight = 500, extended = true})
end

local function channel(p)
	if p:GetNW2Bool('hla_radio') then return 'РАЦИЯ ОТРЯДА', true, true end
	local SQ = HLA.Squads
	local mine, theirs = SQ and SQ.Of(LocalPlayer()), SQ and SQ.Of(p)
	if mine and theirs and mine == theirs then return 'КАНАЛ ОТРЯДА', true end
	if HLA.Story and HLA.Story.State() == HLA.Story.PVP and HLA.Story.Mode() == 'teams' and p:Team() == LocalPlayer():Team() then
		return 'КАНАЛ КОМАНДЫ', true
	end
	return 'ОБЩИЙ КАНАЛ', false
end

hook.Add('HUDPaint', 'HLAVoicePanel', function()
	if IsValid(g_VoicePanelList) and g_VoicePanelList:IsVisible() then g_VoicePanelList:SetVisible(false) end
	if next(talking) == nil then return end
	local me = LocalPlayer()
	if not IsValid(me) or me:GetNWBool('hla_in_menu') then return end
	fonts()
	local s = sc()
	local w, h = math.floor(300 * s), math.floor(52 * s)
	local x = ScrW() - w - math.floor(40 * s)
	local y = math.floor(ScrH() * 0.30)
	draw.SimpleText('ЭФИР', 'hla_vc_small', x + w, y - 6 * s, Color(BLUE.r, BLUE.g, BLUE.b, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	local list = {}
	for p, v in pairs(talking) do
		if IsValid(p) then list[#list + 1] = {p, v} else talking[p] = nil end
	end
	table.sort(list, function(a, b) return a[2].t < b[2].t end)
	for _, it in ipairs(list) do
		local p, v = it[1], it[2]
		v.level = Lerp(math.min(1, FrameTime() * 12), v.level, p:VoiceVolume() or 0)
		local age = RealTime() - v.t
		local a = math.Clamp(age * 6, 0, 1)
		local ch, close, radio = channel(p)
		surface.SetDrawColor(4, 12, 20, 150 * a)
		surface.DrawRect(x, y, w, h)
		local acc = radio and Color(110, 232, 128) or BLUE
		surface.SetDrawColor(acc.r, acc.g, acc.b, 230 * a)
		surface.DrawRect(x, y, math.max(2, math.floor(3 * s)), h)
		local name = p == me and 'ВЫ В ЭФИРЕ' or string.upper(p:GetNWString('hla_name', p:Nick()))
		draw.SimpleText(name, 'hla_vc_name', x + 14 * s, y + 6 * s, Color(WHITE.r, WHITE.g, WHITE.b, 255 * a))
		draw.SimpleText(ch, 'hla_vc_small', x + 14 * s, y + h - 6 * s, close and Color(acc.r, acc.g, acc.b, 220 * a) or Color(GREY.r, GREY.g, GREY.b, 220 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		-- level meter: 10 bars
		local bars, bw, gap = 10, math.max(2, math.floor(5 * s)), math.max(1, math.floor(3 * s))
		local bx = x + w - 12 * s - bars * (bw + gap)
		local lit = math.floor(math.Clamp(v.level * 1.6, 0, 1) * bars + 0.5)
		for i = 1, bars do
			local bh = math.floor((8 + i * 2.2) * s)
			surface.SetDrawColor(acc.r, acc.g, acc.b, (i <= lit and 230 or 40) * a)
			surface.DrawRect(bx + (i - 1) * (bw + gap), y + h / 2 + 10 * s - bh, bw, bh)
		end
		y = y + h + math.floor(6 * s)
	end
end)

-- over the head of a talking player: a radio mark with waves
local function arc(cx, cy, r, th, a0, a1, col)
	local seg = 10
	for i = 0, seg - 1 do
		local t0 = math.rad(a0 + (a1 - a0) * i / seg)
		local t1 = math.rad(a0 + (a1 - a0) * (i + 1) / seg)
		surface.SetDrawColor(col)
		surface.DrawPoly({
			{x = cx + math.cos(t0) * r, y = cy + math.sin(t0) * r},
			{x = cx + math.cos(t1) * r, y = cy + math.sin(t1) * r},
			{x = cx + math.cos(t1) * (r - th), y = cy + math.sin(t1) * (r - th)},
			{x = cx + math.cos(t0) * (r - th), y = cy + math.sin(t0) * (r - th)},
		})
	end
end

hook.Add('PostDrawTranslucentRenderables', 'HLAVoiceIcons', function(_, sky)
	if sky then return end
	local me = LocalPlayer()
	for p, v in pairs(talking) do
		if IsValid(p) and p ~= me and p:Alive() and not p:GetNoDraw() and p:GetPos():DistToSqr(EyePos()) < 1500 * 1500 then
			local head = (HLA.ChatBox and HLA.ChatBox.HeadPos) and HLA.ChatBox.HeadPos(p) or p:EyePos()
			local pos = head + Vector(0, 0, 26)
			local lvl = math.Clamp((v.level or 0) * 1.6, 0, 1)
			cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), 0.08)
				draw.NoTexture()
				local col = Color(BLUE.r, BLUE.g, BLUE.b, 235)
				-- the body of the radio
				surface.SetDrawColor(4, 12, 20, 200)
				surface.DrawRect(-14, -22, 28, 44)
				surface.SetDrawColor(col)
				surface.DrawOutlinedRect(-14, -22, 28, 44, 3)
				surface.DrawRect(6, -40, 4, 20) -- the antenna
				surface.DrawRect(-8, -12, 16, 4)
				surface.DrawRect(-8, -4, 16, 4)
				-- waves on both sides, louder voice — more of them
				for i = 1, 3 do
					local on = lvl >= (i - 1) / 3
					local c = Color(BLUE.r, BLUE.g, BLUE.b, on and 235 or 50)
					arc(0, 0, 26 + i * 12, 5, -40, 40, c)
					arc(0, 0, 26 + i * 12, 5, 140, 220, c)
				end
			cam.End3D2D()
		end
	end
end)

---------------------------------------------------------------------------------------------------
-- H held: talk over the squad radio (voice to the whole squad, wherever they are). The microphone is
-- opened with permissions.EnableVoiceChat — the allowed way (RunConsoleCommand('+voicerecord') is blocked
-- for Lua). Released — the microphone closes. The normal voice key keeps working as usual (near only).
local radioOn = false
local function setRadio(on)
	if radioOn == on then return end
	radioOn = on
	net.Start('hla_radio') net.WriteBool(on) net.SendToServer()
	if permissions and permissions.EnableVoiceChat then
		permissions.EnableVoiceChat(on)
	else
		RunConsoleCommand(on and '+voicerecord' or '-voicerecord')
	end
end
hook.Add('Think', 'HLARadioKey', function()
	local p = LocalPlayer()
	if not IsValid(p) then return end
	local typing = vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or gui.IsConsoleVisible()
	local can = p:Alive() and not p:GetNWBool('hla_in_menu') and HLA.Squads and HLA.Squads.Of(p) ~= nil
	local down = input.IsKeyDown(KEY_H) and not typing
	if down and not radioOn and not can and not p.HLARadioWarned then
		p.HLARadioWarned = true
		chat.AddText(Color(110, 232, 128), '[РАЦИЯ] ', Color(226, 236, 244), 'вы не в отряде — вступите в отряд у терминала')
		timer.Simple(5, function() if IsValid(p) then p.HLARadioWarned = nil end end)
	end
	setRadio(down and can)
end)
