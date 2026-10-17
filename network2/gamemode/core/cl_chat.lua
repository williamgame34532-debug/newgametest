-- Chat: a dark rounded plate (9-slice material) with the messages, a separate plate of the same
-- look under it to type in, and the "Чат" tab above (drag it to move the chat; the lower right
-- corner resizes it). Closed, only the latest lines stay for a while and fade out; open (Y / U,
-- or the usual chat keys) the whole history scrolls with the wheel. ENTER sends, ESC closes,
-- Up / Down go through what you sent. Message kinds and their look: sh_chat.lua; chat.AddText
-- still works for everything (it is mirrored here). Every message plays the chat sound of the
-- game (chat.PlaySound, as the Helix chatbox does). The character names are a soft green. Open,
-- the history can be selected with the mouse (drag over the text, double click a message for
-- the whole of it): the selection is copied right away and Ctrl+C copies it again.
-- Typing: over the input the kind of message being written (Сказать, Шёпот, Крик, ...); "/"
-- opens the list of commands with their arguments (Tab completes the first one); Up / Down put
-- the messages you sent earlier into the input (Up - the last one).

NW.chat = NW.chat or {}

local CH = NW.chat
local U = NW.ui

CH.lines = CH.lines or {}
CH.sent = CH.sent or {}
CH.maxLines = 200
CH.fadeAfter = 12

local function Fonts()
	local h = ScrH()

	for name, size in pairs({nwChat = 0.02, nwChatSmall = 0.0165, nwChatBig = 0.0245}) do
		surface.CreateFont(name, {font = "Exo 2", size = math.max(13, math.Round(h * size)), weight = 500,
			extended = true, antialias = true})
		surface.CreateFont(name .. "Shadow", {font = "Exo 2", size = math.max(13, math.Round(h * size)), weight = 500,
			extended = true, antialias = true, blursize = 2})
	end

	-- /me: the same size in italics (Exo 2 Italic, resource/fonts/Exo2-Italic.ttf)
	local size = math.max(13, math.Round(h * 0.02))

	surface.CreateFont("nwChatMe", {font = "Exo 2 Italic", size = size, weight = 500, extended = true,
		antialias = true})
	surface.CreateFont("nwChatMeShadow", {font = "Exo 2 Italic", size = size, weight = 500, extended = true,
		antialias = true, blursize = 2})
end

local function HintFonts()
	local h = ScrH()

	surface.CreateFont("nwChatHint", {font = "Exo 2", size = math.max(14, math.Round(h * 0.0178)), weight = 500,
		extended = true, antialias = true})
	surface.CreateFont("nwChatHintBold", {font = "Exo 2", size = math.max(14, math.Round(h * 0.0178)), weight = 700,
		extended = true, antialias = true})
	surface.CreateFont("nwChatMode", {font = "Montserrat Medium", size = math.max(12, math.Round(h * 0.0145)),
		weight = 500, extended = true, antialias = true})
end

Fonts()
HintFonts()
hook.Add("OnScreenSizeChanged", "nwChatFonts", function()
	Fonts()
	HintFonts()
end)

-- position and size of the message panel, kept between sessions (fractions of the screen)
local saved = {
	x = CreateClientConVar("nw_chat_x", "0.02", true, false),
	y = CreateClientConVar("nw_chat_y", "0.47", true, false),
	w = CreateClientConVar("nw_chat_w", "0.34", true, false),
	h = CreateClientConVar("nw_chat_h", "0.3", true, false)
}

local function Layout()
	local sw, sh = ScrW(), ScrH()
	local L = {}

	L.pad = math.Round(sh * 0.016)
	L.inputH = math.Round(sh * 0.05)
	L.gap = math.Round(sh * 0.01)
	L.tabH = math.Round(sh * 0.034)
	L.tabW = math.Round(sh * 0.12)
	L.minW, L.minH = math.Round(sw * 0.18), math.Round(sh * 0.14)

	L.w = math.Clamp(math.Round(saved.w:GetFloat() * sw), L.minW, sw - 20)
	L.h = math.Clamp(math.Round(saved.h:GetFloat() * sh), L.minH, sh - L.inputH - L.tabH - 40)
	-- the whole block (tab, messages, input) stays on the screen
	L.x = math.Clamp(math.Round(saved.x:GetFloat() * sw), 4, sw - L.w - 4)
	L.y = math.Clamp(math.Round(saved.y:GetFloat() * sh), L.tabH + 8, sh - L.h - L.gap - L.inputH - 4)
	L.inputY = L.y + L.h + L.gap
	L.tabX, L.tabY = L.x, L.y - L.tabH - 6

	return L
end

local function SaveLayout(L)
	local sw, sh = ScrW(), ScrH()

	RunConsoleCommand("nw_chat_x", tostring(L.x / sw))
	RunConsoleCommand("nw_chat_y", tostring(L.y / sh))
	RunConsoleCommand("nw_chat_w", tostring(L.w / sw))
	RunConsoleCommand("nw_chat_h", tostring(L.h / sh))
end

-- ---------------------------------------------------------------- messages --
local function Parts(...)
	local parts = {}
	local color = U.color.text

	for _, value in ipairs({...}) do
		if (IsColor(value) or (istable(value) and value.r and value.g and value.b)) then
			color = Color(value.r, value.g, value.b)
		elseif (isentity(value) and IsValid(value) and value:IsPlayer()) then
			parts[#parts + 1] = {color = team.GetColor(value:Team()), text = value:Nick()}
		elseif (value != nil) then
			parts[#parts + 1] = {color = color, text = tostring(value)}
		end
	end

	return parts
end

-- word wrap of coloured parts into lines no wider than width
local function Wrap(parts, width, font)
	surface.SetFont(font or "nwChat")

	local lines = {{}}
	local x = 0

	local function Push(color, text)
		local line = lines[#lines]
		local last = line[#line]

		if (last and last.color == color) then
			last.text = last.text .. text
		else
			line[#line + 1] = {color = color, text = text}
		end
	end

	for _, part in ipairs(parts) do
		for word, space in string.gmatch(part.text, "(%S*)(%s*)") do
			if (word == "" and space == "") then
				break
			end

			local chunk = word .. space
			local cw = surface.GetTextSize(chunk)

			if (x + surface.GetTextSize(word) > width and x > 0) then
				lines[#lines + 1] = {}
				x = 0
				chunk = word .. space
				cw = surface.GetTextSize(chunk)
			end

			-- a word longer than the line: cut it by characters
			if (cw > width) then
				for _, code in utf8.codes(chunk) do
					local char = utf8.char(code)
					local charW = surface.GetTextSize(char)

					if (x + charW > width) then
						lines[#lines + 1] = {}
						x = 0
					end

					Push(part.color, char)
					x = x + charW
				end
			else
				Push(part.color, chunk)
				x = x + cw
			end
		end
	end

	return lines
end

function CH.AddStyled(font, ...)
	local message = {time = RealTime(), parts = Parts(...), font = font or "nwChat"}

	if (#message.parts == 0) then
		return
	end

	chat.PlaySound()

	table.insert(CH.lines, message)

	if (#CH.lines > CH.maxLines) then
		table.remove(CH.lines, 1)
	end

	CH.scroll = 0
end

function CH.Add(...)
	local message = {time = RealTime(), parts = Parts(...)}

	if (#message.parts == 0) then
		return
	end

	chat.PlaySound()

	table.insert(CH.lines, message)

	if (#CH.lines > CH.maxLines) then
		table.remove(CH.lines, 1)
	end

	CH.scroll = 0
end

-- every chat.AddText ends up here too (the stock chat box is hidden)
CH.stockAddText = CH.stockAddText or chat.AddText

function chat.AddText(...)
	CH.Add(...)
	CH.stockAddText(...)
end

-- the kinds of messages (sh_chat.lua) and how they look
local K = NW.chatKinds
-- the character's name: a soft green
local NAME = Color(176, 222, 160)
local RADIO_BLUE = Color(96, 200, 255)
local RADIO_RED = Color(240, 92, 80)
local VERB = Color(170, 176, 184)
local STYLE = {
	[K.IC] = {color = Color(232, 214, 176), font = "nwChat"},
	[K.WHISPER] = {color = Color(160, 164, 170), font = "nwChatSmall"},
	[K.YELL] = {color = Color(236, 96, 84), font = "nwChatBig"},
	[K.OOC] = {color = Color(255, 255, 255), font = "nwChat"},
	[K.LOOC] = {color = Color(255, 255, 255), font = "nwChat"},
	[K.PM] = {color = Color(186, 132, 255), font = "nwChat"},
	[K.ROLL] = {color = Color(186, 132, 255), font = "nwChat"},
	[K.ME] = {color = Color(150, 214, 138), font = "nwChatMe"},
	[K.IT] = {color = Color(150, 186, 214), font = "nwChat"},
	[K.ADMIN] = {color = Color(240, 150, 60), font = "nwChat"},
	[K.RADIO] = {color = Color(96, 200, 255), font = "nwChat"},
	[K.RADIO_ALL] = {color = Color(96, 200, 255), font = "nwChat"},
	[K.SQUAD] = {color = Color(96, 200, 255), font = "nwChat"}
}

net.Receive("nwChatTyped", function()
	local kind = net.ReadUInt(4)
	local speaker = net.ReadEntity()
	local text = net.ReadString()
	local extra = net.ReadString()

	if (!IsValid(speaker)) then
		return
	end

	local style = STYLE[kind] or STYLE[K.IC]
	local c = style.color
	local name = speaker:Nick()

	-- the name in the colour of the side: Civil Protection blue, the Combine red, the rest as usual
	local NAME = NAME

	if (NW.zones and NW.zones.IsAlliance(speaker)) then
		NAME = K.RadioSide(speaker) == "ota" and RADIO_RED or RADIO_BLUE
	end

	-- in character a stranger has no name (NW.char.Knows, "Познакомиться")
	if ((kind == K.IC or kind == K.WHISPER or kind == K.YELL or kind == K.ME or kind == K.ROLL) and
		!NW.char.Knows(LocalPlayer(), speaker)) then
		name = "Неизвестный"
	end
	local steam = speaker:SteamName()

	if (kind == K.IC) then
		CH.AddStyled(style.font, NAME, name, VERB, " сказал: ", c, "\"" .. text .. "\"")
	elseif (kind == K.WHISPER) then
		CH.AddStyled(style.font, NAME, name, VERB, " шепнул: ", c, "\"" .. text .. "\"")
	elseif (kind == K.YELL) then
		CH.AddStyled(style.font, NAME, name, VERB, " крикнул: ", c, "\"" .. text .. "\"")
	elseif (kind == K.OOC) then
		CH.AddStyled(style.font, c, "|OOC| ", NAME, name, c, " (" .. steam .. "): " .. text)
	elseif (kind == K.LOOC) then
		CH.AddStyled(style.font, c, "|LOOC| ", NAME, name, c, " (" .. steam .. "): " .. text)
	elseif (kind == K.PM) then
		if (speaker == LocalPlayer()) then
			CH.AddStyled(style.font, c, "|PM| *" .. steam .. "* → *" .. extra .. "*: \"" .. text .. "\"")
		else
			CH.AddStyled(style.font, c, "|PM| *" .. steam .. "*: \"" .. text .. "\"")
		end
	elseif (kind == K.ROLL) then
		CH.AddStyled(style.font, NAME, name, c, " roll " .. text .. " (0-" .. extra .. ")")
	elseif (kind == K.ME) then
		CH.AddStyled(style.font, c, "*", NAME, name, c, " " .. text .. "*")
	elseif (kind == K.IT) then
		CH.AddStyled(style.font, c, "** " .. text)
	elseif (kind == K.ADMIN) then
		CH.AddStyled(style.font, c, "|A| ", NAME, steam, c, ": " .. text)
	elseif (kind == K.RADIO or kind == K.RADIO_ALL or kind == K.SQUAD) then
		-- like the visor log: <name> по рации: "<:: text ::>" - blue for Civil Protection, red for the Combine
		local radio = extra == "ota" and RADIO_RED or RADIO_BLUE
		local channel = kind == K.RADIO_ALL and "[ОБЩ] " or ""

		CH.AddStyled(style.font, radio, channel, NAME, name, radio, " по рации: \"<:: " .. text .. " ::>\"")
		c = radio

		-- the set: the one who said it hears the key go up; everyone in the Alliance who gets the
		-- message hears the channel open and close
		if (speaker == LocalPlayer()) then
			CH.RadioSound("off")
		else
			CH.RadioSound("on")

			timer.Simple(math.Clamp(0.3 + (utf8.len(text) or #text) * 0.012, 0.3, 1), function()
				CH.RadioSound("off")
			end)
		end
	end

	MsgN(name .. ": " .. text)

	-- the words over the head (cl_speech.lua)
	hook.Run("NWChatMessage", kind, speaker, text, c)
end)

-- server notices go to the notifications at the top (sh_notify.lua)
net.Receive("nwChatNotice", function()
	NW.notify.Add(net.ReadString())
end)

hook.Add("ChatText", "nwChat", function(index, name, text, kind)
	if (kind == "joinleave" or kind == "none" or kind == "servermsg" or kind == "namechange" or kind == "teamchange") then
		CH.Add(U.color.dim, text)
	end
end)

-- the dispatcher (sv_chat.lua NW.Dispatch): red-orange, with the alarm of the city
local DISPATCH = Color(236, 98, 74)

net.Receive("nwDispatch", function()
	local text = net.ReadString()
	local alarm = net.ReadBool()

	CH.AddStyled("nwChat", DISPATCH, "Диспетчер: ", Color(236, 226, 220), text)
	MsgN("Диспетчер: " .. text)

	if (alarm) then
		surface.PlaySound("network2/dispatch/alarm.mp3")
	end
end)

-- the radio of the Alliance (sound/network2/radio, combine_tech): the key goes down when a radio
-- command is typed, up when it is sent; the others hear the channel open and close
local RADIO_SOUNDS = {on = 5, off = 6}

function CH.RadioSound(kind)
	surface.PlaySound(string.format("network2/radio/combine_radio_%s_%02d.wav", kind, math.random(RADIO_SOUNDS[kind])))
end

local function RadioTyping(text)
	local typing = NW.zones and NW.zones.IsAlliance(LocalPlayer()) and
		(string.find(text, "^/[tT][rR]?%s") or string.find(text, "^/[rR]%s")) != nil

	if (typing and !CH.radioKeyed) then
		CH.RadioSound("on")
	end

	CH.radioKeyed = typing
end

-- ------------------------------------------------------------------ panels --
local function Close()
	if (!IsValid(CH.frame)) then
		return
	end

	CH.open = false
	CH.radioKeyed = nil
	CH.drag = nil
	CH.sel = nil
	CH.entry:SetText("")
	CH.entry:KillFocus()
	CH.entry:SetVisible(false)
	CH.frame:SetMouseInputEnabled(false)
	CH.frame:SetKeyboardInputEnabled(false)

	hook.Run("FinishChat")
end

local function Send()
	local text = string.Trim(CH.entry:GetValue() or "")

	if (text != "") then
		table.insert(CH.sent, 1, text)

		if (#CH.sent > 30) then
			table.remove(CH.sent)
		end

		net.Start("nwChatSay")
			net.WriteString(text)
			net.WriteBool(CH.team == true)
		net.SendToServer()
	end

	Close()
end

local function Build()
	if (IsValid(CH.frame)) then
		CH.frame:Remove()
	end

	local L = Layout()
	CH.layout = L

	local frame = vgui.Create("EditablePanel")
	frame:SetPos(0, 0)
	frame:SetSize(ScrW(), ScrH())
	frame:SetMouseInputEnabled(false)
	frame:SetKeyboardInputEnabled(false)
	frame:SetPaintedManually(false)
	frame.Paint = function(self, w, h)
		CH.Paint(self)
	end
	frame.OnMouseWheeled = function(self, delta)
		if (CH.open) then
			CH.scroll = math.max(0, (CH.scroll or 0) + delta * 2)
		end
	end
	-- only the chat block takes the mouse, and only while open
	frame.TestHover = function(self, x, y)
		local L = CH.layout

		return CH.open and x >= L.x and x <= L.x + L.w and y >= L.tabY and y <= L.inputY + L.inputH
	end
	-- the tab moves the chat, the lower right corner resizes it
	frame.OnMousePressed = function(self, code)
		if (code != MOUSE_LEFT or !CH.open) then
			return
		end

		local L = CH.layout
		local mx, my = input.GetCursorPos()
		local grip = L.pad * 1.6

		if (mx >= L.tabX and mx <= L.tabX + L.tabW and my >= L.tabY and my <= L.tabY + L.tabH) then
			CH.drag = {mode = "move", ox = mx - L.x, oy = my - L.y}
			NW.ui.Tick()
		elseif (mx >= L.x + L.w - grip and my >= L.y + L.h - grip and mx <= L.x + L.w and my <= L.y + L.h) then
			CH.drag = {mode = "size", ox = L.x + L.w - mx, oy = L.y + L.h - my}
			NW.ui.Tick()
		end

		-- in the history: select text
		if (!CH.drag and mx >= L.x and mx <= L.x + L.w and my >= L.y and my <= L.y + L.h) then
			local hit = CH.HitTest(mx, my)

			if (hit) then
				if (CH.lastClick and RealTime() - CH.lastClick < 0.35 and CH.sel and CH.sel.a.message == hit.message) then
					-- double click: the whole message
					local message = CH.lines[hit.message]

					CH.sel = {a = {message = hit.message, line = 1, char = 0},
						b = {message = hit.message, line = #message.wrapped, char = math.huge}}
					CH.CopySelection()
					CH.lastClick = nil

					return
				end

				CH.lastClick = RealTime()
				CH.sel = {a = hit, b = hit, active = true}
				CH.drag = {mode = "select"}
			else
				CH.sel = nil
			end
		end

		if (CH.drag) then
			self:MouseCapture(true)
		else
			CH.entry:RequestFocus()
		end
	end
	frame.OnMouseReleased = function(self)
		if (CH.drag) then
			local mode = CH.drag.mode

			CH.drag = nil
			self:MouseCapture(false)

			if (mode == "select") then
				CH.sel.active = false

				if (CH.SelectionText() != "") then
					CH.CopySelection()
				else
					CH.sel = nil
				end

				CH.entry:RequestFocus()
			else
				SaveLayout(CH.layout)
			end
		end
	end
	frame.Think = function(self)
		local drag = CH.drag

		if (!drag) then
			return
		end

		if (drag.mode == "select") then
			if (!input.IsMouseDown(MOUSE_LEFT)) then
				self:OnMouseReleased(MOUSE_LEFT)

				return
			end

			local mx, my = input.GetCursorPos()
			local hit = CH.HitTest(mx, my, true)

			if (hit) then
				CH.sel.b = hit
			end

			-- scroll while dragging past the edges
			local L = CH.layout

			if (my < L.y + 6) then
				CH.scroll = (CH.scroll or 0) + 1
			elseif (my > L.y + L.h - 6 and (CH.scroll or 0) > 0) then
				CH.scroll = CH.scroll - 1
			end

			return
		end

		if (!input.IsMouseDown(MOUSE_LEFT)) then
			self:OnMouseReleased(MOUSE_LEFT)

			return
		end

		local sw, sh = ScrW(), ScrH()
		local mx, my = input.GetCursorPos()
		local L = CH.layout

		if (drag.mode == "move") then
			L.x = math.Clamp(mx - drag.ox, 4, sw - L.w - 4)
			L.y = math.Clamp(my - drag.oy, L.tabH + 8, sh - L.h - L.gap - L.inputH - 4)
		else
			L.w = math.Clamp(mx + drag.ox - L.x, L.minW, sw - L.x - 4)
			L.h = math.Clamp(my + drag.oy - L.y, L.minH, sh - L.y - L.gap - L.inputH - 4)
		end

		L.inputY = L.y + L.h + L.gap
		L.tabX, L.tabY = L.x, L.y - L.tabH - 6

		CH.entry:SetPos(L.x + L.pad, L.inputY + 2)
		CH.entry:SetSize(L.w - L.pad * 2, L.inputH - 4)
	end

	local entry = frame:Add("DTextEntry")
	entry:SetPos(L.x + L.pad, L.inputY + 2)
	entry:SetSize(L.w - L.pad * 2, L.inputH - 4)
	entry:SetFont("nwChat")
	entry:SetPaintBackground(false)
	entry:SetTextColor(U.color.text)
	entry:SetCursorColor(U.color.text)
	entry:SetDrawLanguageID(false)
	entry:SetVisible(false)
	entry:SetMaximumCharCount(1000)
	entry:SetTabbingDisabled(true)
	entry:SetMouseInputEnabled(true)
	entry:SetKeyboardInputEnabled(true)
	entry.Paint = function(self, w, h)
		if (self:GetValue() == "") then
			draw.SimpleText(CH.team and "Сообщение команде..." or "Сообщение...", "nwChat", 2, h / 2,
				ColorAlpha(U.color.dim, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		self:DrawTextEntryText(U.color.text, Color(64, 190, 240, 90), U.color.text)
	end
	entry.OnKeyCodeTyped = function(self, code)
		if (code == KEY_C and (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)) and CH.sel and
			self:GetSelectedText() == "") then
			CH.CopySelection()

			return true
		end

		if (code == KEY_ENTER or code == KEY_PAD_ENTER) then
			Send()

			return true
		elseif (code == KEY_ESCAPE) then
			Close()
			gui.HideGameUI()

			return true
		elseif (code == KEY_UP or code == KEY_DOWN) then
			-- handled in Think (the arrows do not always reach here)
			return true
		elseif (code == KEY_TAB) then
			-- complete the first suggested command
			local first = CH.hints and CH.hints[1]

			if (first and !CH.hintsExact) then
				local text = first.command .. " "

				self:SetText(text)
				self:SetCaretPos(utf8.len(text) or #text)
				self:OnChange()
			end

			self:RequestFocus()

			return true
		end
	end
	entry.OnChange = function(self)
		RadioTyping(self:GetValue())
		hook.Run("ChatTextChanged", self:GetValue())
	end
	-- Up / Down: what you sent before (Up first gives the last message)
	entry.Think = function(self)
		if (!self:HasFocus()) then
			return
		end

		for _, code in ipairs({KEY_UP, KEY_DOWN}) do
			local down = input.IsKeyDown(code)

			if (down and !self["held" .. code]) then
				CH.recall = math.Clamp((CH.recall or 0) + (code == KEY_UP and 1 or -1), 0, #CH.sent)
				self:SetText(CH.sent[CH.recall] or "")
				self:SetCaretPos(utf8.len(self:GetValue()) or #self:GetValue())
				self:OnChange()
			end

			self["held" .. code] = down
		end
	end

	CH.frame = frame
	CH.entry = entry
end

function CH.Open(bTeam)
	-- dead or unconscious: no chat (sh_incapable.lua)
	if (NW.Incapable and NW.Incapable(LocalPlayer())) then
		return
	end

	if (!IsValid(CH.frame)) then
		Build()
	end

	CH.open = true
	CH.team = bTeam
	CH.recall = 0
	CH.openTime = RealTime()
	CH.scroll = 0

	CH.entry:SetVisible(true)
	CH.frame:MakePopup()
	CH.frame:SetKeyboardInputEnabled(true)
	CH.frame:SetMouseInputEnabled(true)
	CH.entry:RequestFocus()

	hook.Run("StartChat", bTeam)
end

-- --------------------------------------------------------------- selection --
-- A point in the history: message index, wrapped line, characters before the point.
local function Before(p, q)
	if (p.message != q.message) then
		return p.message < q.message
	end

	if (p.line != q.line) then
		return p.line < q.line
	end

	return p.char < q.char
end

local function Ordered()
	local sel = CH.sel

	if (!sel) then
		return
	end

	if (Before(sel.b, sel.a)) then
		return sel.b, sel.a
	end

	return sel.a, sel.b
end

local function LineText(line)
	local parts = {}

	for _, segment in ipairs(line) do
		parts[#parts + 1] = segment.text
	end

	return table.concat(parts)
end

local function Sub(text, first, last)
	local length = utf8.len(text) or #text

	first = math.Clamp(first, 0, length)
	last = math.Clamp(last, 0, length)

	if (last <= first) then
		return ""
	end

	local from = utf8.offset(text, first + 1) or (#text + 1)
	local to = utf8.offset(text, last + 1) or (#text + 1)

	return string.sub(text, from, to - 1)
end

-- the characters of a line before x (pixels from the line start), by the nearest edge
local function CharAt(text, font, x)
	surface.SetFont(font)

	local width = 0
	local index = 0

	for _, code in utf8.codes(text) do
		local w = surface.GetTextSize(utf8.char(code))

		if (x < width + w / 2) then
			return index
		end

		width = width + w
		index = index + 1
	end

	return index
end

-- which drawn line / character is under the cursor (bClamp: the nearest line when outside)
function CH.HitTest(mx, my, bClamp)
	local drawn = CH.drawn

	if (!drawn or #drawn == 0) then
		return
	end

	local best, bestDistance

	for _, entry in ipairs(drawn) do
		local distance = 0

		if (my < entry.y) then
			distance = entry.y - my
		elseif (my > entry.y + entry.h) then
			distance = my - entry.y - entry.h
		end

		if (distance == 0) then
			best = entry
			break
		end

		if (bClamp and (!bestDistance or distance < bestDistance)) then
			best, bestDistance = entry, distance
		end
	end

	if (!best) then
		return
	end

	local text = LineText(best.line)

	return {message = best.message, line = best.index, char = CharAt(text, best.font, mx - best.x)}
end

function CH.SelectionText()
	local first, last = Ordered()

	if (!first) then
		return ""
	end

	local out = {}

	for index = first.message, last.message do
		local message = CH.lines[index]

		if (message and message.wrapped) then
			local pieces = {}

			for k, line in ipairs(message.wrapped) do
				local text = LineText(line)
				local length = utf8.len(text) or #text
				local from, to = 0, length

				if (index == first.message and k < first.line) or (index == last.message and k > last.line) then
					from, to = 0, 0
				else
					if (index == first.message and k == first.line) then
						from = first.char
					end

					if (index == last.message and k == last.line) then
						to = math.min(last.char, length)
					end
				end

				pieces[#pieces + 1] = Sub(text, from, to)
			end

			local text = table.concat(pieces)

			if (text != "") then
				out[#out + 1] = text
			end
		end
	end

	return string.Trim(table.concat(out, "\n"))
end

function CH.CopySelection()
	local text = CH.SelectionText()

	if (text == "") then
		return
	end

	SetClipboardText(text)
	CH.copiedAt = RealTime()
	NW.ui.Tick()
end

-- the part of a drawn line that is selected: characters from, to (or nil)
local function SelectedRange(index, k, length)
	local first, last = Ordered()

	if (!first or (first.message == last.message and first.line == last.line and first.char == last.char)) then
		return
	end

	local here = {message = index, line = k, char = 0}
	local hereEnd = {message = index, line = k, char = math.huge}

	if (Before(hereEnd, first) or Before(last, here)) then
		return
	end

	local from = (first.message == index and first.line == k) and first.char or 0
	local to = (last.message == index and last.line == k) and math.min(last.char, length) or length

	if (to <= from) then
		return
	end

	return from, to
end

-- ------------------------------------------------------------------- paint --
local function DrawSelection(line, x, y, h, font, from, to)
	surface.SetFont(font)

	local text = LineText(line)
	local x1 = x + surface.GetTextSize(Sub(text, 0, from))
	local x2 = x + surface.GetTextSize(Sub(text, 0, to))

	surface.SetDrawColor(176, 222, 160, 60)
	surface.DrawRect(x1, y, x2 - x1, h)
end

local function DrawLine(line, x, y, alpha, bShadow, font)
	font = font or "nwChat"
	surface.SetFont(font)

	for _, segment in ipairs(line) do
		if (bShadow) then
			draw.SimpleText(segment.text, font .. "Shadow", x + 1, y + 1, Color(0, 0, 0, 200 * alpha))
		end

		draw.SimpleText(segment.text, font, x, y, ColorAlpha(segment.color, 255 * alpha))
		x = x + surface.GetTextSize(segment.text)
	end
end

function CH.Paint(panel)
	local L = CH.layout

	if (NW.menu and NW.menu.active) then
		return
	end

	local open = CH.open
	CH.openAlpha = Lerp(math.Clamp(FrameTime() * 10, 0, 1), CH.openAlpha or 0, open and 1 or 0)

	local a = CH.openAlpha

	if (a > 0.02) then
		-- clean dark plates (no blur: sharp, even edges)
		U.Slice(U.Material("network2/ui/chat_panel.png"), L.x, L.y, L.w, L.h, 20, 255, 255, 255, 255 * a)
		U.Slice(U.Material("network2/ui/chat_panel.png"), L.x, L.inputY, L.w, L.inputH, 16, 255, 255, 255, 255 * a)

		-- the tab: "Чат" (drag it to move the chat)
		local hover = CH.drag and CH.drag.mode == "move" and 1 or 0
		U.Slice(U.Material("network2/ui/chat_tab.png"), L.tabX, L.tabY, L.tabW, L.tabH, 12, 255, 255, 255, 255 * a)

		local size = L.tabH * 0.52
		U.DrawIcon("chat", L.tabX + L.tabH * 0.32, L.tabY + (L.tabH - size) / 2, size, U.color.accent, a)
		draw.SimpleText("Чат", "nwButton", L.tabX + L.tabH * 0.32 + size + L.tabH * 0.25, L.tabY + L.tabH / 2,
			ColorAlpha(U.color.text, 255 * a * (0.85 + hover * 0.15)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (CH.team) then
			draw.SimpleText("команда", "nwSmall", L.tabX + L.tabW + 10, L.tabY + L.tabH / 2,
				ColorAlpha(Color(120, 200, 140), 220 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		-- the resize grip, lower right corner
		local grip = L.pad * 1.1
		U.DrawIcon("resize", L.x + L.w - grip - 6, L.y + L.h - grip - 6, grip, U.color.dim, a * 0.6)

		-- a faint line between the history and the bottom
		surface.SetDrawColor(255, 255, 255, 10 * a)
		surface.DrawRect(L.x + L.pad, L.y + L.h - 2, L.w - L.pad * 2, 1)
	end

	-- the entry follows the panel (leaving room on the right for the kind of message)
	if (IsValid(CH.entry)) then
		local ex, ey = L.x + L.pad, L.inputY + 2
		local ew = L.w - L.pad * 2 - (CH.modeW or 0)

		if (CH.entry.x != ex or CH.entry.y != ey or CH.entry:GetWide() != ew) then
			CH.entry:SetPos(ex, ey)
			CH.entry:SetSize(ew, L.inputH - 4)
		end
	end

	-- the lines, newest at the bottom; closed: only the recent ones, fading
	local width = L.w - L.pad * 2
	local y = L.y + L.h - L.pad
	local skip = open and (CH.scroll or 0) or 0
	local now = RealTime()

	render.SetScissorRect(L.x, L.y + 4, L.x + L.w, L.y + L.h - 4, true)

	local drawn = {}

	for index = #CH.lines, 1, -1 do
		local message = CH.lines[index]
		local age = now - message.time
		local alpha = open and 1 or math.Clamp(CH.fadeAfter - age, 0, 1)

		if (alpha <= 0 and !open) then
			break
		end

		local font = message.font or "nwChat"

		if (message.width != width) then
			message.wrapped = Wrap(message.parts, width, font)
			message.width = width
		end

		surface.SetFont(font)

		local lineH = select(2, surface.GetTextSize("Ag")) + 2

		for k = #message.wrapped, 1, -1 do
			if (skip > 0) then
				skip = skip - 1
			else
				y = y - lineH

				if (y < L.y) then
					break
				end

				local line = message.wrapped[k]

				if (open) then
					drawn[#drawn + 1] = {message = index, index = k, line = line, x = L.x + L.pad, y = y, h = lineH,
						font = font}

					local from, to = SelectedRange(index, k, utf8.len(LineText(line)) or 0)

					if (from) then
						DrawSelection(line, L.x + L.pad, y, lineH, font, from, to)
					end
				end

				DrawLine(line, L.x + L.pad, y, math.max(alpha, a), a < 0.5, font)
			end
		end

		if (y < L.y) then
			break
		end
	end

	render.SetScissorRect(0, 0, 0, 0, false)

	CH.drawn = drawn

	if (open and IsValid(CH.entry)) then
		CH.PaintTyping(L, a)
	end

	-- "copied" next to the tab for a moment
	if (CH.copiedAt and open) then
		local t = RealTime() - CH.copiedAt

		if (t < 1.4) then
			draw.SimpleText("Скопировано", "nwSmall", L.tabX + L.tabW + 10, L.tabY + L.tabH / 2,
				Color(176, 222, 160, 230 * math.Clamp((1.4 - t) * 3, 0, 1)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
end

-- ------------------------------------------------------------------ typing --
-- the kind of message over the input, the command list over that
local function Matches(text)
	local word, space = string.match(text, "^[/!](%S*)(%s?)")

	if (!word or string.sub(text, 1, 2) == "//" or string.sub(text, 1, 3) == ".//") then
		return nil
	end

	word = string.lower(word)

	local out, exact = {}, false

	for _, entry in ipairs(K.help) do
		if (!K.Allowed(entry, LocalPlayer())) then
			continue
		end

		local names = {string.sub(entry.command, 2)}

		for _, alias in ipairs(entry.also or {}) do
			names[#names + 1] = alias
		end

		for _, name in ipairs(names) do
			if (space != "" and name == word) or (space == "" and string.sub(name, 1, #word) == word) then
				out[#out + 1] = entry
				exact = exact or (space != "")
				break
			end
		end
	end

	return out, exact, word
end

function CH.PaintTyping(L, a)
	local sh = ScrH()
	local text = CH.entry:GetValue() or ""
	local kind, word = K.Parse(text)
	local pad = math.Round(sh * 0.008)

	-- staff kinds are unknown to everyone else
	if (kind == K.ADMIN and !LocalPlayer():IsAdmin()) then
		kind = nil
	end

	-- the kind of message: inside the input, on the right (a staff command: "Команда")
	local command = !kind and K.Find(word, LocalPlayer())
	local label = kind and K.names[kind] or (command and "Команда" or "Неизвестная команда")
	local color = kind and (STYLE[kind] or STYLE[K.IC]).color or (command and U.color.hint or U.color.error)

	if (CH.team and kind == K.IC) then
		label = "Сказать команде"
	end

	surface.SetFont("nwChatMode")

	local lw = surface.GetTextSize(label)
	local right = L.x + L.w - L.pad

	CH.modeW = lw + pad * 3 + 6

	draw.RoundedBox(3, right - lw - pad - 6, L.inputY + L.inputH / 2 - 3, 6, 6, ColorAlpha(color, 255 * a))
	draw.SimpleText(label, "nwChatMode", right, L.inputY + L.inputH / 2, ColorAlpha(color, 230 * a), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	-- the command is typed (a space after it): the list goes away, only the label above stays
	if (string.match(text, "^%s*[/!][^%s]+%s")) then
		CH.hints, CH.hintsExact = nil, nil

		return
	end

	-- commands: a solid box at the bottom of the history (nothing shows through it)
	local list, exact, word = Matches(text)

	CH.hints = list
	CH.hintsExact = exact

	if (!list) then
		return
	end

	surface.SetFont("nwChatHint")

	local rowH = select(2, surface.GetTextSize("Ag")) + math.Round(sh * 0.009)
	local maxRows = math.max(1, math.floor((L.h - pad * 4) / rowH))
	local rows = math.Clamp(#list, 1, maxRows)
	local boxX, boxW = L.x + pad, L.w - pad * 2
	local boxH = rows * rowH + pad * 2
	local boxY = L.y + L.h - boxH - pad

	draw.RoundedBox(10, boxX, boxY, boxW, boxH, Color(12, 14, 17, 252 * a))
	surface.SetDrawColor(255, 255, 255, 18 * a)
	surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 1)

	if (#list == 0) then
		draw.SimpleText("Нет команды «/" .. word .. "»", "nwChatHint", boxX + pad * 1.5, boxY + pad + rowH / 2,
			ColorAlpha(U.color.error, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	render.SetScissorRect(boxX, boxY, boxX + boxW, boxY + boxH, true)

	for index = 1, rows do
		local entry = list[index]
		local y = boxY + pad + (index - 1) * rowH
		local x = boxX + pad * 1.5
		local entryColor = (STYLE[entry.kind] or STYLE[K.IC]).color

		if (index == 1) then
			draw.RoundedBox(6, boxX + pad * 0.5, y + 1, boxW - pad, rowH - 2, Color(255, 255, 255, 14 * a))

			if (!exact) then
				draw.SimpleText("Tab", "nwChatMode", boxX + boxW - pad * 1.5, y + rowH / 2,
					ColorAlpha(U.color.dim, 220 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetFont("nwChatHintBold")

		local cw = surface.GetTextSize(entry.command .. " ")

		draw.SimpleText(entry.command, "nwChatHintBold", x, y + rowH / 2, ColorAlpha(entryColor, 255 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetFont("nwChatHint")

		local aw = surface.GetTextSize(entry.args .. "  ")

		draw.SimpleText(entry.args, "nwChatHint", x + cw, y + rowH / 2, ColorAlpha(U.color.text, 235 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("— " .. entry.text, "nwChatHint", x + cw + aw, y + rowH / 2, ColorAlpha(U.color.dim, 255 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	render.SetScissorRect(0, 0, 0, 0, false)
end

-- ------------------------------------------------------------------- hooks --
hook.Add("PlayerBindPress", "nwChat", function(client, bind, bPressed)
	if (!bPressed) then
		return
	end

	bind = string.lower(bind)

	if (string.find(bind, "messagemode", 1, true)) then
		if (NW.menu and NW.menu.active) then
			return true
		end

		CH.Open(string.find(bind, "messagemode2", 1, true) != nil)

		return true
	end
end)

-- the stock chat box never opens
hook.Add("StartChat", "nwChatStock", function()
	return true
end)

hook.Add("InitPostEntity", "nwChat", Build)

hook.Add("OnScreenSizeChanged", "nwChatLayout", function()
	if (IsValid(CH.frame)) then
		Build()
	end
end)

-- ESC while typing closes the chat (cl_pausemenu.lua asks this first)
CH.Close = Close
