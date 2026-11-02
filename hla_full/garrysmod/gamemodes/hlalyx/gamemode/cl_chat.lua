local CH = HLA.Chat
local C = {lines = {}, open = false, bubbles = {}}
HLA.ChatBox = C

local BLUE = HLA.Hud.AMBER_C
local WHITE = Color(226, 236, 244)
local GREY = Color(122, 150, 170)
local ENV = Color(150, 192, 214)
local ACT = Color(176, 214, 236)
local LIFE, FADE, MAXLINES = 14, 2, 60
local SPEED = 110

local bg, inputBg, mark = Material('hla/chat/bg'), Material('hla/chat/input'), Material('hla/chat/mark')

local function S() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local size = math.max(13, math.floor(21 * S()))
	surface.CreateFont('hla_chat', {font = 'IBM Plex Mono', size = size, weight = 400, extended = true})
	surface.CreateFont('hla_chat_b', {font = 'IBM Plex Mono', size = size, weight = 600, extended = true})
	surface.CreateFont('hla_chat_i', {font = 'IBM Plex Mono', size = size, weight = 400, italic = true, extended = true})
	surface.CreateFont('hla_chat_s', {font = 'IBM Plex Mono', size = math.max(11, math.floor(15 * S())), weight = 400, extended = true})
end
surface.CreateFont('hla_chat_head', {font = 'IBM Plex Mono', size = 44, weight = 600, extended = true})
surface.CreateFont('hla_chat_head_i', {font = 'IBM Plex Mono', size = 40, weight = 400, italic = true, extended = true})

local function ulen(s) return utf8.len(s) or #s end
local function usub(s, n)
	if n <= 0 then return '' end
	local o = utf8.offset(s, n + 1)
	return o and string.sub(s, 1, o - 1) or s
end

function C.Add(segs, opts)
	local line = {segs = segs, t = RealTime(), total = 0}
	for _, sg in ipairs(segs) do line.total = line.total + ulen(sg[1]) end
	if opts and opts.instant then line.t = RealTime() - 60 end
	table.insert(C.lines, line)
	while #C.lines > MAXLINES do table.remove(C.lines, 1) end
end

local function layout(line, w)
	if line.cacheW == w then return line.rows end
	local rows, row, x = {}, {}, 0
	local spaceW = {}
	for _, sg in ipairs(line.segs) do
		local font = sg[3] or 'hla_chat'
		surface.SetFont(font)
		spaceW[font] = spaceW[font] or surface.GetTextSize(' ')
		local first = true
		for word, sp in string.gmatch(sg[1], '(%S*)(%s*)') do
			if word == '' and sp == '' then break end
			local ww = surface.GetTextSize(word)
			if x > 0 and x + ww > w and word ~= '' then
				rows[#rows + 1] = row row, x = {}, 0
			end
			if word ~= '' then row[#row + 1] = {word, sg[2], font, x} x = x + ww end
			if sp ~= '' then x = x + spaceW[font] * ulen(sp) end
			first = false
		end
	end
	if #row > 0 then rows[#rows + 1] = row end
	line.rows, line.cacheW = rows, w
	return rows
end

local function soft(path)
	if file.Exists('sound/' .. path, 'GAME') then LocalPlayer():EmitSound(path, 0, 100, 0.25, CHAN_STATIC) end
end

net.Receive('hla_chat', function()
	local id = net.ReadUInt(4)
	local who = net.ReadEntity()
	local name = net.ReadString()
	local muffled = net.ReadBool()
	local text = muffled and '' or net.ReadString()
	local mode = CH.ByID[id]
	local radioSounds = (mode and mode.radio) and net.ReadString() or ''
	if id == CH.DISPATCH then
		local snd = net.ReadString()
		local who = name ~= '' and name or 'ДИСПЕТЧЕР'
		C.Add({{'// ' .. who .. ' — ', Color(236, 64, 52), 'hla_chat_b'}, {text, Color(255, 120, 108), 'hla_chat'}})
		if snd == '' then soft('hla/ui/textline_7.wav') return end
		local me = LocalPlayer()
		local at = 0
		for part in string.gmatch(snd, '[^;]+') do
			local path, dur = string.match(part, '^(.-)|([%d%.]+)$')
			path = path or part
			dur = tonumber(dur) or 0
			if dur <= 0 then dur = SoundDuration(path) end
			if not dur or dur <= 0 then dur = 1.2 end
			timer.Simple(at, function() surface.PlaySound(path) end)
			at = at + math.max(0.06, dur - 0.03)
		end
		return
	end
	if id == 0 then
		C.Add({{'// ', BLUE, 'hla_chat_b'}, {text, ENV, 'hla_chat_i'}})
		soft('hla/ui/textline_7.wav')
		return
	end
	local m = CH.ByID[id]
	if not m then return end
	name = string.upper(name ~= '' and name or '???')
	local segs
	if muffled then
		segs = {{name, BLUE, 'hla_chat_b'}, {m.key == 'y' and ' что-то кричит вдалеке.' or ' говорит что-то неразборчиво.', GREY, 'hla_chat_i'}}
	elseif m.radio then
		local c = m.radio == 'tac' and Color(110, 200, 255) or Color(110, 232, 128)
		local cd = m.radio == 'tac' and Color(170, 222, 255) or Color(178, 244, 186)
		segs = {{'[' .. m.label .. '] ', c, 'hla_chat_b'}, {name, c, 'hla_chat_b'}, {' ' .. m.verb .. ': ', c, 'hla_chat'}, {'"' .. text .. '"', cd, 'hla_chat'}}
		C.Add(segs)
		local me = LocalPlayer()
		me:EmitSound('npc/combine_soldier/vo/on' .. math.random(1, 2) .. '.wav', 0, 100, 0.3, CHAN_STATIC)
		local at = 0.15
		if radioSounds ~= '' and who ~= me then
			for part in string.gmatch(radioSounds, '[^;]+') do
				timer.Simple(at, function() if IsValid(me) then me:EmitSound(part, 0, 100, 0.55, CHAN_STATIC) end end)
				at = at + math.Clamp(SoundDuration(part), 0.3, 12) + 0.15
			end
		end
		timer.Simple(math.max(0.35, at), function() if IsValid(me) then me:EmitSound('npc/combine_soldier/vo/off' .. math.random(1, 3) .. '.wav', 0, 100, 0.25, CHAN_STATIC) end end)
		if IsValid(who) and who:IsPlayer() then
			C.bubbles[who] = {inner = text, t = RealTime(), life = math.Clamp(4 + ulen(text) / 14, 5, 12)}
		end
		return
	elseif m.action then
		segs = {{'* ' .. name .. ' ', BLUE, 'hla_chat_b'}, {text, ACT, 'hla_chat_i'}}
	elseif m.env then
		segs = {{'* ', BLUE, 'hla_chat_b'}, {text, ENV, 'hla_chat_i'}, {'  (' .. name .. ')', GREY, 'hla_chat_s'}}
	else
		local body = m.key == 'w' and 'hla_chat_i' or 'hla_chat'
		segs = {{name, BLUE, 'hla_chat_b'}, {' ' .. m.verb .. ': ', GREY, 'hla_chat'}, {'<:: ', BLUE, 'hla_chat_b'},
			{text, m.key == 'w' and ACT or WHITE, body}, {' ::>', BLUE, 'hla_chat_b'}}
	end
	C.Add(segs)
	soft(m.key == 'w' and 'hla/ui/textline_8.wav' or 'hla/ui/textline_6.wav')
	if IsValid(who) and not muffled and not m.env then
		C.bubbles[who] = {text = m.action and ('* ' .. text) or nil, inner = (not m.action) and text or nil, t = RealTime(),
			italic = m.action or m.key == 'w', yell = m.key == 'y', life = math.Clamp(4 + ulen(text) / 14, 5, 12)}
	end
end)

local origAddText = chat.AddText
function chat.AddText(...)
	local segs, col = {}, WHITE
	for _, v in ipairs({...}) do
		if istable(v) and v.r then col = Color(v.r, v.g, v.b)
		elseif isentity(v) and IsValid(v) and v:IsPlayer() then segs[#segs + 1] = {string.upper(v:GetNWString('hla_name', v:Nick())), BLUE, 'hla_chat_b'}
		elseif v ~= nil then segs[#segs + 1] = {tostring(v), col, 'hla_chat'} end
	end
	if #segs > 0 then C.Add(segs) end
	return origAddText(...)
end

hook.Add('ChatText', 'HLAChat', function(_, _, text, kind)
	if kind == 'joinleave' or kind == 'namechange' or kind == 'teamchange' then return true end
	if text and text ~= '' then C.Add({{text, GREY, 'hla_chat'}}) end
	return true
end)
hook.Add('HUDShouldDraw', 'HLAChatHideDefault', function(name) if name == 'CHudChat' then return false end end)
function GM:OnPlayerChat() return true end

local posX = CreateClientConVar('hla_chat_x', '-1', true, false, 'Chat position: left edge, 0..1 of the screen width (-1 = default)')
local posY = CreateClientConVar('hla_chat_y', '-1', true, false, 'Chat position: bottom line, 0..1 of the screen height (-1 = default)')
local function geometry()
	local s = S()
	local hs = s * math.Clamp(HLA.HudScale and HLA.HudScale:GetFloat() or 0.66, 0.4, 1.2)
	local w = math.floor(700 * s)
	local x = math.floor(40 * s)
	local bottom = ScrH() - math.floor(54 * hs + 236 * hs + 40 * s)
	if posX:GetFloat() >= 0 then x = math.Clamp(math.floor(posX:GetFloat() * ScrW()), 0, ScrW() - w) end
	if posY:GetFloat() >= 0 then bottom = math.Clamp(math.floor(posY:GetFloat() * ScrH()), math.floor(120 * s), ScrH() - math.floor(80 * s)) end
	return x, bottom, w, s
end
concommand.Add('hla_chat_reset', function() RunConsoleCommand('hla_chat_x', '-1') RunConsoleCommand('hla_chat_y', '-1') end)

function C.Close()
	C.open = false
	if IsValid(C.frame) then C.frame:Remove() end
	if IsValid(C.suggPanel) then C.suggPanel:Remove() end
	C.frame, C.suggPanel, C.sugg = nil, nil, nil
end

local V = HLA.Voice
local function splitInput(v)
	local cmd, rest = '', v
	if CH.Parse(v) ~= 'say' then
		local c, r = string.match(v, '^(%S+%s+)(.*)$')
		if c then cmd, rest = c, r end
	end
	local before, last = '', rest
	local pos = string.find(rest, ',[^,]*$')
	if pos then before, last = string.sub(rest, 1, pos), string.sub(rest, pos + 1) end
	return cmd .. before, last
end

local function updateSugg(v)
	C.sugg, C.ghost, C.sel = nil, nil, 1
	if not V then return end
	local _, last = splitInput(v)
	local typed = string.gsub(last, '^%s+', '')
	local list = V.Suggest(typed, 5)
	if #list == 0 then return end
	C.sugg = list
	local n = ulen(typed)
	local head = usub(list[1].text, n)
	if V.Norm(head) == V.Norm(typed) and string.sub(v, -1) ~= ' ' then
		C.ghost = string.sub(list[1].text, #head + 1)
	end
end

local function takeSugg(e)
	local l = C.sugg and C.sugg[C.sel or 1]
	if not l then return false end
	local before = splitInput(e:GetValue())
	local v = before .. ((before ~= '' and string.sub(before, -1) == ',') and ' ' or '') .. l.text
	e:SetText(v)
	e:SetCaretPos(ulen(v))
	updateSugg(v)
	C.sugg, C.ghost = nil, nil
	return true
end

function C.Open()
	if C.open then return end
	local p = LocalPlayer()
	if not IsValid(p) or p:GetNWBool('hla_in_menu') then return end
	fonts()
	C.open = true
	local x, bottom, w, s = geometry()
	local hintH, entryH = math.floor(26 * s), math.floor(46 * s)
	local f = vgui.Create('EditablePanel')
	C.frame = f
	f:SetPos(x, bottom + math.floor(6 * s))
	f:SetSize(w, hintH + entryH)
	f:MakePopup()
	f:SetMouseInputEnabled(true)
	f:SetCursor('sizeall')
	f.OnMousePressed = function(self, code)
		if code ~= MOUSE_LEFT then return end
		local mx, my = gui.MousePos()
		local fx, fy = self:GetPos()
		self.drag = {mx - fx, my - fy}
		self:MouseCapture(true)
	end
	f.OnMouseReleased = function(self)
		if not self.drag then return end
		self.drag = nil
		self:MouseCapture(false)
		local fx, fy = self:GetPos()
		RunConsoleCommand('hla_chat_x', string.format('%.4f', fx / ScrW()))
		RunConsoleCommand('hla_chat_y', string.format('%.4f', (fy - math.floor(6 * s)) / ScrH()))
		if IsValid(C.entry) then C.entry:RequestFocus() end
	end
	f.Think = function(self)
		if not self.drag then return end
		local mx, my = gui.MousePos()
		local nx = math.Clamp(mx - self.drag[1], 0, ScrW() - self:GetWide())
		local ny = math.Clamp(my - self.drag[2], math.floor(120 * s), ScrH() - self:GetTall())
		self:SetPos(nx, ny)
		posX:SetFloat(nx / ScrW()) posY:SetFloat((ny - math.floor(6 * s)) / ScrH())
	end
	f.Paint = function(self, pw, ph)
		local key = CH.Parse(IsValid(C.entry) and C.entry:GetValue() or '')
		local hx = math.floor(4 * s)
		for _, h in ipairs({{'/w', 'шёпот', 'w'}, {'/y', 'крик', 'y'}, {'/me', 'действие', 'me'}, {'/it', 'окружение', 'it'}, {'/t', 'так-рация', 't'}, {'/r', 'рация', 'r'}}) do
			local on = key == h[3]
			surface.SetFont('hla_chat_s')
			local c1 = on and WHITE or BLUE
			draw.SimpleText(h[1], 'hla_chat_s', hx, hintH / 2, Color(c1.r, c1.g, c1.b, on and 255 or 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			hx = hx + surface.GetTextSize(h[1] .. ' ')
			draw.SimpleText(h[2], 'hla_chat_s', hx, hintH / 2, Color(GREY.r, GREY.g, GREY.b, on and 255 or 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			hx = hx + surface.GetTextSize(h[2]) + math.floor(22 * s)
		end
	end
	local e = vgui.Create('DTextEntry', f)
	e:SetPos(0, hintH)
	e:SetSize(w, entryH)
	e:SetFont('hla_chat')
	e:SetAllowNonAsciiCharacters(true)
	e:SetDrawLanguageID(false)
	e:SetUpdateOnType(true)
	e:SetTextInset(math.floor(14 * s), 0)
	e.AllowInput = function(self) return ulen(self:GetValue()) >= CH.MaxLen end
	e.Paint = function(self, pw, ph)
		surface.SetDrawColor(4, 12, 20, 225)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 200)
		surface.DrawRect(0, ph - 2, pw, 2)
		surface.DrawRect(0, 0, 3, ph - 2)
		local m = CH.Modes[CH.Parse(self:GetValue())]
		draw.SimpleText(m.label .. ' · ' .. CH.RangeText(m), 'hla_chat_s', pw - 12, ph / 2, Color(BLUE.r, BLUE.g, BLUE.b, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		if self:GetValue() == '' then
			draw.SimpleText('Сообщение — слышат только те, кто рядом', 'hla_chat_i', math.floor(14 * s), ph / 2, Color(GREY.r, GREY.g, GREY.b, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		self:DrawTextEntryText(WHITE, Color(BLUE.r, BLUE.g, BLUE.b, 120), WHITE)
		if C.ghost and self:GetCaretPos() >= ulen(self:GetValue()) then
			surface.SetFont('hla_chat')
			local tw = surface.GetTextSize(self:GetValue())
			if tw + math.floor(14 * s) < pw - math.floor(160 * s) then
				draw.SimpleText(C.ghost, 'hla_chat', math.floor(14 * s) + tw, ph / 2, Color(GREY.r, GREY.g, GREY.b, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
	end
	e.OnValueChange = function(self, v) updateSugg(v or self:GetValue()) end
	e.OnKeyCodeTyped = function(self, code)
		if code == KEY_TAB then takeSugg(self) return true end
		if C.sugg and (code == KEY_UP or code == KEY_DOWN) then
			C.sel = (C.sel - 1 + (code == KEY_DOWN and 1 or -1)) % #C.sugg + 1
			return true
		end
		return DTextEntry.OnKeyCodeTyped(self, code)
	end
	e.OnEnter = function(self)
		local t = string.Trim(self:GetValue())
		C.Close()
		if t == '' then return end
		if string.sub(t, 1, 1) == '!' then
			RunConsoleCommand('say', (string.gsub(t, '"', "'")))
		else
			net.Start('hla_say') net.WriteString(usub(t, CH.MaxLen + 40)) net.SendToServer()
		end
	end
	local sp = vgui.Create('DPanel')
	C.suggPanel = sp
	local rowH = math.floor(26 * s)
	sp:SetSize(w, rowH * 5 + math.floor(26 * s))
	sp:SetPos(x, bottom + math.floor(6 * s) - sp:GetTall() - math.floor(4 * s))
	sp:SetMouseInputEnabled(false)
	sp:SetKeyboardInputEnabled(false)
	sp.Think = function(self)
		if IsValid(f) then
			local fx, fy = f:GetPos()
			self:SetPos(fx, fy - self:GetTall() - math.floor(4 * s))
		end
	end
	sp.Paint = function(self, pw, ph)
		local list = C.sugg
		if not list then return end
		local y0 = ph - #list * rowH - math.floor(22 * s)
		surface.SetDrawColor(4, 12, 20, 225)
		surface.DrawRect(0, y0, pw, ph - y0)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 200)
		surface.DrawRect(0, y0, 3, ph - y0)
		for i, l in ipairs(list) do
			local yy = y0 + (i - 1) * rowH
			if i == C.sel then
				surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 50)
				surface.DrawRect(3, yy, pw - 3, rowH)
			end
			draw.SimpleText(l.text, 'hla_chat', math.floor(14 * s), yy + rowH / 2, i == C.sel and WHITE or BLUE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		draw.SimpleText('ВОЙСЛАЙН   Tab — дополнить   ↑↓ — выбрать   несколько — через запятую', 'hla_chat_s', math.floor(14 * s), ph - math.floor(11 * s), Color(GREY.r, GREY.g, GREY.b, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	e.OnLoseFocus = function(self)
		timer.Simple(0, function() if IsValid(self) and C.open then self:RequestFocus() end end)
	end
	e:RequestFocus()
	C.entry = e
	soft('hla/ui/textline_5.wav')
end

hook.Add('PlayerBindPress', 'HLAChat', function(_, bind, pressed)
	if not pressed then return end
	if string.find(bind, 'messagemode', 1, true) then C.Open() return true end
end)
hook.Add('OnPauseMenuShow', 'HLAChat', function()
	if C.open then C.Close() return false end
end)

hook.Add('HUDPaint', 'HLAChat', function()
	local p = LocalPlayer()
	if not IsValid(p) or p:GetNWBool('hla_in_menu') then return end
	if #C.lines == 0 and not C.open then return end
	fonts()
	local x, bottom, w, s = geometry()
	local pad = math.floor(10 * s)
	surface.SetFont('hla_chat')
	local _, lh = surface.GetTextSize('Ay')
	lh = lh + math.floor(4 * s)
	local y = bottom
	local now = RealTime()
	local shown = 0
	for i = #C.lines, 1, -1 do
		local line = C.lines[i]
		local age = now - line.t
		local a = C.open and 1 or math.Clamp(1 - (age - LIFE) / FADE, 0, 1)
		if a <= 0 and not C.open then break end
		local rows = layout(line, w - pad * 3)
		local hgt = #rows * lh + math.floor(6 * s)
		y = y - hgt
		if y < ScrH() * 0.3 then break end
		surface.SetMaterial(bg)
		surface.SetDrawColor(255, 255, 255, 230 * a)
		surface.DrawTexturedRect(x, y, w, hgt - math.floor(2 * s))
		surface.SetMaterial(mark)
		surface.SetDrawColor(255, 255, 255, 220 * a)
		surface.DrawTexturedRect(x - math.floor(6 * s), y + math.floor(3 * s), math.floor(12 * s), hgt - math.floor(8 * s))
		local left = math.floor(age * SPEED)
		local blink = left < line.total and (math.floor(now * 8) % 2 == 0)
		local lastX, lastY
		for r, row in ipairs(rows) do
			local ry = y + math.floor(3 * s) + (r - 1) * lh
			for _, wd in ipairs(row) do
				if left <= 0 then break end
				local n = ulen(wd[1])
				local txt = n <= left and wd[1] or usub(wd[1], left)
				left = left - n - 1
				local c = wd[2]
				draw.SimpleText(txt, wd[3], x + pad + 2 + wd[4], ry, Color(c.r, c.g, c.b, 255 * a))
				surface.SetFont(wd[3])
				lastX, lastY = x + pad + 2 + wd[4] + surface.GetTextSize(txt), ry
			end
		end
		if blink and lastX then
			surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 230 * a)
			surface.DrawRect(lastX + 2, lastY + 2, math.max(2, math.floor(9 * s)), lh - math.floor(8 * s))
		end
		y = y - math.floor(3 * s)
		shown = shown + 1
		if shown >= (C.open and 16 or 8) then break end
	end
end)

local function wrapWords(text, maxLetters)
	local rows, cur, cut = {}, '', false
	for word in string.gmatch(text, '%S+') do
		if #rows >= 3 then cut = true break end
		local cand = cur == '' and word or (cur .. ' ' .. word)
		if ulen(cand) > maxLetters and cur ~= '' then rows[#rows + 1] = cur cur = word else cur = cand end
	end
	if cur ~= '' then
		if #rows < 3 then rows[#rows + 1] = cur else cut = true end
	end
	if cut and #rows > 0 then rows[#rows] = rows[#rows] .. ' …' end
	return rows
end

local function bubbleRows(b)
	if b.rows then return b.rows end
	local rows = wrapWords(b.inner or b.text, 32)
	if b.inner and #rows > 0 then
		rows[1] = '<:: ' .. rows[1]
		rows[#rows] = rows[#rows] .. ' ::>'
	end
	b.rows = rows
	return rows
end

local function headPos(ent)
	local pos
	if ent:IsPlayer() then
		pos = ent:EyePos() + Vector(0, 0, ent:Crouching() and 9 or 11)
	else
		local bone = ent:LookupBone('ValveBiped.Bip01_Head1')
		if bone then ent:SetupBones() pos = ent:GetBonePosition(bone) end
		pos = (pos or ent:WorldSpaceCenter() + Vector(0, 0, 30)) + Vector(0, 0, 10)
	end
	return pos
end
C.HeadPos = headPos

hook.Add('PostDrawTranslucentRenderables', 'HLAChatBubbles', function(_, sky)
	if sky then return end
	local now = RealTime()
	local me = LocalPlayer()
	for ent, b in pairs(C.bubbles) do
		local age = now - b.t
		local life = b.life or 7
		if not IsValid(ent) or age > life or (ent:IsPlayer() and not ent:Alive()) then
			C.bubbles[ent] = nil
		elseif ent ~= me or me:ShouldDrawLocalPlayer() then
			local a = math.Clamp(math.min(age * 4, (life - age) / 1.2), 0, 1)
			local target = headPos(ent) + Vector(0, 0, 22)
			b.pos = b.pos and LerpVector(math.min(1, FrameTime() * 14), b.pos, target) or target
			local pos = b.pos
			if pos:DistToSqr(EyePos()) < 900 * 900 then
				local font = b.italic and 'hla_chat_head_i' or 'hla_chat_head'
				local col = b.italic and ACT or WHITE
				cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), b.yell and 0.075 or 0.06)
					local rows = bubbleRows(b)
					for i, r in ipairs(rows) do
						local yy = (i - #rows) * 46
						draw.SimpleTextOutlined(r, font, 0, yy, Color(col.r, col.g, col.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, Color(0, 6, 12, 170 * a))
					end
				cam.End3D2D()
			end
		end
	end
end)

concommand.Add('hla_dispatch_test', function()
	local city = 'npc/overwatch/cityvoice/f_innactionisconspiracy_spkr.wav'
	local radio = 'hla/radiovoice/attention.wav'
	chat.AddText(Color(236, 64, 52), '// ТЕСТ — ', color_white, city .. (file.Exists('sound/' .. city, 'GAME') and ' (найден)' or ' (НЕ НАЙДЕН)'))
	surface.PlaySound(city)
	timer.Simple(6, function()
		chat.AddText(Color(236, 64, 52), '// ТЕСТ — ', color_white, radio .. (file.Exists('sound/' .. radio, 'GAME') and ' (найден)' or ' (НЕ НАЙДЕН)'))
		surface.PlaySound(radio)
	end)
end)
