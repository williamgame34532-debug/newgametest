--[[-------------------------------------------------------------------------
	N-work — чат.

	Свой чат-бокс: мягкий градиентный фон без резких переходов,
	скруглённые углы, тонкая строка ввода. Панель можно перетаскивать
	за шапку и растягивать за правый нижний угол — геометрия
	запоминается (cookie). Когда чат закрыт, виден только текст,
	который гаснет через ~10 секунд. В меню чат не показывается.

	Типы речи (у каждого свой размер шрифта и дистанция на сервере):
		обычное        Имя говорит "текст"
		/w, /whisp     Имя шепчет "текст"        (мелко, ~120 юнитов)
		/y, /yell      Имя кричит "текст"        (крупно, ~640 юнитов)
		/me, /it       ** эмоуты
		/r             Имя передаёт по рации "<:: текст. ::>"
		//             [OOC] Имя: текст
		/event         СОБЫТИЕ: текст            (только админ)
		/help          список команд

	Незнакомые персонажи пишут как «Неизвестный» — см. систему
	знакомств (F3, cl_hud.lua / sv_recognize.lua).
---------------------------------------------------------------------------]]

local T = NWORK.Theme

--------------------------------------------------------------------- палитра

local C_BASE   = Color( 104, 108, 113, 165 )  -- тело панели (серый, как в референсе)
local C_ENTRY  = Color( 24, 25, 27, 240 )
local C_NAME   = Color( 176, 200, 224 )
local C_TEXT   = Color( 240, 243, 247 )
local C_EMOTE  = Color( 210, 214, 220 )
local C_WHIS   = Color( 196, 200, 206 )
local C_RADIO  = Color( 130, 200, 140 )
local C_OOC    = Color( 224, 170, 104 )
local C_EVENT  = Color( 236, 200, 120 )
local C_SYS    = Color( 168, 172, 178 )
local C_DIM    = Color( 158, 164, 172 )

local matGradU = Material( "vgui/gradient-u" )
local matGradD = Material( "vgui/gradient-d" )

------------------------------------------------------------------- команды

NWORK.Commands = {
	{ cmd = "//",     args = "<сообщение>", cat = "ЧАТ",   desc = "Сказать вне персонажа (OOC), видно всем." },
	{ cmd = "/me",    args = "<действие>",  cat = "ЧАТ",   desc = "Действие от лица персонажа." },
	{ cmd = "/it",    args = "<описание>",  cat = "ЧАТ",   desc = "Описать сцену без имени персонажа." },
	{ cmd = "/w",     args = "<сообщение>", cat = "ЧАТ",   desc = "Шёпот — слышно только вплотную." },
	{ cmd = "/y",     args = "<сообщение>", cat = "ЧАТ",   desc = "Крик — слышно издалека." },
	{ cmd = "/r",     args = "<сообщение>", cat = "ЧАТ",   desc = "Передать сообщение по рации." },
	{ cmd = "/event", args = "<текст>",     cat = "АДМИН", desc = "Объявить событие для всех (только админ)." },
	{ cmd = "/help",  args = "[команда]",   cat = "ОБЩЕЕ", desc = "Список команд или помощь по одной." },
}

--------------------------------------------------------- имя с учётом знакомств

NWORK.Recognized = NWORK.Recognized or {}

function NWORK.CharName( ply )
	if not IsValid( ply ) then return "Console" end

	local n = ply:GetNWString( "nwork_name", "" )
	if n == "" then return ply:Nick() end

	if ply == LocalPlayer() or ply:IsBot() then return n end

	local id = ply:GetNWInt( "nwork_charid", 0 )
	if id ~= 0 and NWORK.Recognized[ id ] then return n end

	return "Неизвестный"
end

--------------------------------------------------------------------- чат-бокс

local CHAT

local function FontH( font )
	surface.SetFont( font )
	local _, h = surface.GetTextSize( "Аy" )
	return h
end

local PANEL = {}

function PANEL:Init()
	local w, h = ScrW(), ScrH()
	local k    = h / 1080
	self.K = k

	local defW = math.floor( w * 0.42 )
	local defH = math.floor( h * 0.34 )

	self:SetSize(
		math.Clamp( cookie.GetNumber( "nwork_chat_w", defW ), 260, w - 40 ),
		math.Clamp( cookie.GetNumber( "nwork_chat_h", defH ), 160, h - 40 ) )
	self:SetPos(
		math.Clamp( cookie.GetNumber( "nwork_chat_x", math.floor( 16 * k ) ), 0, w - 260 ),
		math.Clamp( cookie.GetNumber( "nwork_chat_y", h - defH - math.floor( 16 * k ) ), 0, h - 160 ) )

	self.LastMsg = -1e5
	self.IsOpen  = false
	self.Lines   = {}   -- исходные строки: { font, segs = { {c, t}, ... } }
	self.Rows    = {}   -- перенесённые: { font, h, parts }
	self.Scroll  = 0

	self.Pad   = math.floor( 10 * k )
	self.HeadH = math.floor( 26 * k )
	self.EntryH= math.floor( 34 * k )
	self.Grip  = math.floor( 18 * k )

	local entry = vgui.Create( "DTextEntry", self )
	entry:SetFont( "Nwork.ChatEntry" )
	entry:SetUpdateOnType( true )
	entry:SetDrawLanguageID( false )
	entry:SetTabbingDisabled( true )
	entry:SetVisible( false )
	entry.Paint = function( s, ww, hh )
		draw.RoundedBox( 4, 0, 0, ww, hh, C_ENTRY )
		surface.SetDrawColor( 255, 255, 255, s:HasFocus() and 40 or 16 )
		surface.DrawOutlinedRect( 0, 0, ww, hh, 1 )
		-- белый маркер-каретка справа, как в референсе
		surface.SetDrawColor( 235, 238, 242, 220 )
		surface.DrawRect( ww - math.floor( 8 * self.K ) - 3, 4, 6, hh - 8 )
		s:DrawTextEntryText( C_TEXT, C_DIM, C_TEXT )
	end
	entry.OnValueChange  = function() self:UpdateCommands() end
	entry.OnKeyCodeTyped = function( _, key ) return self:HandleKey( key ) end
	self.Entry = entry

	self:Relayout()
	self:SetVisible( true )
	self:SetAlpha( 0 )
end

function PANEL:Relayout()
	local w, h = self:GetSize()
	self.Entry:SetPos( self.Pad, h - self.EntryH - self.Pad )
	self.Entry:SetSize( w - self.Pad * 2, self.EntryH )
	self:Rewrap()
end

---------------------------------------------------------------- перенос строк

function PANEL:TextWidth()
	return self:GetWide() - self.Pad * 2
end

local function WrapLine( line, maxw )
	surface.SetFont( line.font )

	local rows, cur, curw = {}, {}, 0
	local function push()
		if #cur > 0 then
			rows[ #rows + 1 ] = { font = line.font, h = FontH( line.font ), parts = cur }
			cur, curw = {}, 0
		end
	end

	for _, seg in ipairs( line.segs ) do
		for token in string.gmatch( seg.t, "%S+%s*" ) do
			surface.SetFont( line.font )
			local tw = surface.GetTextSize( token )

			if curw + tw > maxw and curw > 0 then push() end

			cur[ #cur + 1 ] = { c = seg.c, t = token }
			curw = curw + tw
		end
	end

	push()
	return rows
end

function PANEL:Rewrap()
	self.Rows = {}
	local maxw = self:TextWidth()

	for _, line in ipairs( self.Lines ) do
		for _, row in ipairs( WrapLine( line, maxw ) ) do
			self.Rows[ #self.Rows + 1 ] = row
		end
	end
end

function PANEL:AddLine( font, ... )
	local segs = {}
	local cur  = C_TEXT

	for _, v in ipairs( { ... } ) do
		if IsColor( v ) then
			cur = v
		elseif isentity( v ) and IsValid( v ) and v:IsPlayer() then
			segs[ #segs + 1 ] = { c = C_NAME, t = NWORK.CharName( v ) }
		else
			segs[ #segs + 1 ] = { c = cur, t = tostring( v ) }
		end
	end

	local line = { font = font or "Nwork.Chat", segs = segs }
	self.Lines[ #self.Lines + 1 ] = line

	if #self.Lines > 150 then
		table.remove( self.Lines, 1 )
		self:Rewrap()
	else
		for _, row in ipairs( WrapLine( line, self:TextWidth() ) ) do
			self.Rows[ #self.Rows + 1 ] = row
		end
	end

	self.Scroll  = 0
	self.LastMsg = CurTime()
end

--------------------------------------------------------------------- отрисовка

function PANEL:Paint( w, h )
	local k = self.K

	if self.IsOpen then
		-- мягкий фон: база + плавные градиенты сверху/снизу, без резких стыков
		draw.RoundedBox( 8, 0, 0, w, h, C_BASE )

		surface.SetMaterial( matGradU )
		surface.SetDrawColor( 255, 255, 255, 22 )
		surface.DrawTexturedRect( 0, 0, w, h )

		surface.SetMaterial( matGradD )
		surface.SetDrawColor( 12, 13, 15, 110 )
		surface.DrawTexturedRect( 0, math.floor( h * 0.35 ), w, math.floor( h * 0.65 ) )

		-- шапка
		draw.SimpleText( "N-WORK", "Nwork.ChatHint", math.floor( 12 * k ), math.floor( 7 * k ),
			Color( 255, 255, 255, 110 ) )
		draw.SimpleText( self.CmdOpen and "Tab — дополнить · ↑↓ — выбрать" or os.date( "%H:%M" ),
			"Nwork.ChatHint", w - math.floor( 26 * k ), math.floor( 7 * k ),
			Color( 255, 255, 255, 100 ), TEXT_ALIGN_RIGHT )

		-- уголок-грип для растягивания
		surface.SetDrawColor( 255, 255, 255, 90 )
		for i = 1, 3 do
			local o = i * 5
			surface.DrawLine( w - o, h - 3, w - 3, h - o )
		end
	end

	-- строки: снизу вверх от строки ввода
	local bottom = self.IsOpen and ( h - self.EntryH - self.Pad * 2 ) or ( h - self.Pad )
	local y      = bottom
	local top    = self.IsOpen and self.HeadH or 0

	local start = #self.Rows - self.Scroll

	for i = start, 1, -1 do
		local row = self.Rows[ i ]
		if not row then break end

		y = y - row.h
		if y < top then break end

		local x = self.Pad
		surface.SetFont( row.font )
		for _, part in ipairs( row.parts ) do
			surface.SetTextColor( part.c )
			surface.SetTextPos( x, y )
			surface.DrawText( part.t )
			x = x + select( 1, surface.GetTextSize( part.t ) )
		end
	end
end

function PANEL:Think()
	-- в меню N-work чата не видно
	if NWORK.UI.Active() then
		if self.IsOpen then self:Close() end
		self:SetAlpha( 0 )
		return
	end

	if self.IsOpen then
		self:SetAlpha( 255 )
		if input.IsKeyDown( KEY_ESCAPE ) then self:Close() end
		self:DragThink()
		return
	end

	local dt = CurTime() - self.LastMsg
	local a  = dt < 10 and 235 or math.max( 0, 235 - ( dt - 10 ) * 235 / 1.5 )
	self:SetAlpha( a )
end

------------------------------------------------------- перетаскивание/резайз

function PANEL:OnMousePressed( code )
	if not self.IsOpen or code ~= MOUSE_LEFT then return end

	local mx, my = self:CursorPos()
	local w, h   = self:GetSize()

	if mx > w - self.Grip and my > h - self.Grip then
		self.Resizing = true
	elseif my < self.HeadH then
		self.Dragging = { mx, my }
	end

	self:MouseCapture( true )
end

function PANEL:OnMouseReleased()
	if self.Dragging or self.Resizing then
		local x, y = self:GetPos()
		cookie.Set( "nwork_chat_x", x )
		cookie.Set( "nwork_chat_y", y )
		cookie.Set( "nwork_chat_w", self:GetWide() )
		cookie.Set( "nwork_chat_h", self:GetTall() )
	end

	self.Dragging, self.Resizing = nil, nil
	self:MouseCapture( false )
end

function PANEL:DragThink()
	if self.Dragging then
		local mx, my = gui.MousePos()
		local x = math.Clamp( mx - self.Dragging[ 1 ], 0, ScrW() - self:GetWide() )
		local y = math.Clamp( my - self.Dragging[ 2 ], 0, ScrH() - self:GetTall() )
		self:SetPos( x, y )
	elseif self.Resizing then
		local x, y = self:GetPos()
		local mx, my = gui.MousePos()
		self:SetSize(
			math.Clamp( mx - x, 260, ScrW() - x ),
			math.Clamp( my - y, 160, ScrH() - y ) )
		self:Relayout()
	end
end

function PANEL:OnMouseWheeled( delta )
	if not self.IsOpen then return end
	self.Scroll = math.Clamp( self.Scroll + delta * 2, 0, math.max( 0, #self.Rows - 4 ) )
	return true
end

------------------------------------------------------------ открытие/закрытие

function PANEL:Open()
	self.IsOpen = true
	self:MakePopup()
	self.Entry:SetVisible( true )
	self.Entry:RequestFocus()
	self:UpdateCommands()
end

function PANEL:Close()
	self.IsOpen = false
	self.Entry:SetText( "" )
	self.Entry:SetVisible( false )
	self:SetMouseInputEnabled( false )
	self:SetKeyboardInputEnabled( false )
	self:HideCommands()
	self.Scroll  = 0
	self.LastMsg = CurTime() - 6
end

--------------------------------------------------------------------- ввод

function PANEL:HandleKey( key )
	if key == KEY_ENTER or key == KEY_PAD_ENTER then
		self:Send()
		return true
	end

	if key == KEY_ESCAPE then
		self:Close()
		return true
	end

	if self.CmdOpen then
		if key == KEY_TAB then self:CompleteCommand() return true end
		if key == KEY_UP then self:MoveSel( -1 ) return true end
		if key == KEY_DOWN then self:MoveSel( 1 ) return true end
	end

	return false
end

function PANEL:Send()
	local text = string.Trim( self.Entry:GetValue() or "" )
	self:Close()

	if text == "" then return end

	if string.match( text, "^/help" ) then
		self:PrintHelp( string.match( text, "^/help%s+(%S+)" ) )
		return
	end

	RunConsoleCommand( "say", text )
end

function PANEL:PrintHelp( arg )
	if arg and arg ~= "" then
		if not string.StartsWith( arg, "/" ) then arg = "/" .. arg end
		for _, c in ipairs( NWORK.Commands ) do
			if c.cmd == arg then
				chat.AddText( C_EVENT, c.cmd .. " " .. c.args, C_SYS, " — " .. c.desc )
				return
			end
		end
		chat.AddText( C_SYS, "Команда " .. arg .. " не найдена." )
		return
	end

	chat.AddText( C_EVENT, "Команды N-work:" )
	for _, c in ipairs( NWORK.Commands ) do
		chat.AddText( C_TEXT, "  " .. c.cmd .. " ", C_DIM, c.args, C_SYS, " — " .. c.desc )
	end
end

--------------------------------------------------------------- панель команд

function PANEL:UpdateCommands()
	local text = self.Entry:GetValue() or ""

	if not string.StartsWith( text, "/" ) then
		self:HideCommands()
		return
	end

	local token = string.match( text, "^(%S+)" ) or "/"
	local list = {}

	for _, c in ipairs( NWORK.Commands ) do
		if token == "/" or string.StartsWith( c.cmd, token ) then
			list[ #list + 1 ] = c
		end
	end

	if #list == 0 then
		self:HideCommands()
		return
	end

	self.Matches = list
	self.Sel     = math.Clamp( self.Sel or 1, 1, #list )

	if not IsValid( self.Cmds ) then
		self.Cmds = vgui.Create( "NworkCmdList" )
		self.Cmds.Chat = self
	end

	self.Cmds:Update( list, self.Sel, self )
	self.CmdOpen = true
end

function PANEL:HideCommands()
	self.CmdOpen = false
	self.Sel = 1
	if IsValid( self.Cmds ) then self.Cmds:SetVisible( false ) end
end

function PANEL:MoveSel( dir )
	if not self.Matches then return end
	self.Sel = ( ( self.Sel - 1 + dir ) % #self.Matches ) + 1
	self.Cmds:Update( self.Matches, self.Sel, self )
end

function PANEL:CompleteCommand()
	local c = self.Matches and self.Matches[ self.Sel ]
	if not c then return end

	local filled = c.cmd .. " "
	self.Entry:SetText( filled )
	self.Entry:SetCaretPos( #filled )
	self:UpdateCommands()
end

vgui.Register( "NworkChat", PANEL, "EditablePanel" )

------------------------------------------------------- панель списка команд

local CMDS = {}

function CMDS:Init()
	self:SetVisible( false )
end

function CMDS:Update( list, sel, chatPnl )
	self.List, self.Sel = list, sel

	local k = ScrH() / 1080
	self.RowH  = math.floor( 48 * k )
	self.HeadH = math.floor( 26 * k )

	local w = math.floor( ScrW() * 0.26 )
	local h = self.HeadH + #list * self.RowH + math.floor( 8 * k )

	local cx, cy = chatPnl:GetPos()
	local x = math.min( cx + chatPnl:GetWide() + math.floor( 10 * k ), ScrW() - w )

	self:SetSize( w, h )
	self:SetPos( x, math.max( 0, cy + chatPnl:GetTall() - h ) )
	self:SetVisible( true )
	self:SetMouseInputEnabled( true )
end

function CMDS:Paint( w, h )
	local k = ScrH() / 1080

	draw.RoundedBox( 8, 0, 0, w, h, Color( 40, 43, 47, 215 ) )
	surface.SetMaterial( Material( "vgui/gradient-u" ) )
	surface.SetDrawColor( 255, 255, 255, 16 )
	surface.DrawTexturedRect( 0, 0, w, h )

	draw.SimpleText( ( "%d команд" ):format( #self.List ), "Nwork.ChatHint",
		math.floor( 12 * k ), math.floor( 6 * k ), Color( 210, 216, 224, 150 ) )
	draw.SimpleText( "Tab — дополнить · ↑↓ — выбрать", "Nwork.ChatHint",
		w - math.floor( 12 * k ), math.floor( 6 * k ), Color( 210, 216, 224, 110 ), TEXT_ALIGN_RIGHT )

	for i, c in ipairs( self.List ) do
		local y = self.HeadH + ( i - 1 ) * self.RowH + math.floor( 4 * k )

		if i == self.Sel then
			surface.SetDrawColor( 255, 255, 255, 14 )
			surface.DrawRect( 2, y, w - 4, self.RowH )
			surface.SetDrawColor( 150, 178, 205, 220 )
			surface.DrawRect( 2, y, 2, self.RowH )
		end

		local x = math.floor( 14 * k )

		draw.SimpleText( c.cmd, "Nwork.CmdName", x, y + math.floor( 4 * k ), C_TEXT )
		surface.SetFont( "Nwork.CmdName" )
		local cw = surface.GetTextSize( c.cmd )
		draw.SimpleText( c.args, "Nwork.CmdArgs", x + cw + math.floor( 8 * k ),
			y + math.floor( 6 * k ), C_DIM )

		draw.SimpleText( c.desc, "Nwork.CmdDesc", x, y + math.floor( 26 * k ),
			Color( 195, 200, 207, 220 ) )

		draw.SimpleText( c.cat, "Nwork.CmdTag", w - math.floor( 12 * k ),
			y + math.floor( 6 * k ), Color( 185, 191, 199, 160 ), TEXT_ALIGN_RIGHT )
	end
end

function CMDS:OnMousePressed()
	local _, my = self:CursorPos()
	local i = math.floor( ( my - self.HeadH ) / self.RowH ) + 1

	if self.List and self.List[ i ] and IsValid( self.Chat ) then
		self.Chat.Sel = i
		self.Chat.Matches = self.List
		self.Chat:CompleteCommand()
		self.Chat.Entry:RequestFocus()
	end
end

vgui.Register( "NworkCmdList", CMDS, "EditablePanel" )

--------------------------------------------------------------- интеграция

local function GetChat()
	if not IsValid( CHAT ) then
		CHAT = vgui.Create( "NworkChat" )
	end
	return CHAT
end

local function Mirror( ... )
	local cur = Color( 255, 255, 255 )
	for _, v in ipairs( { ... } ) do
		if IsColor( v ) then
			cur = v
		elseif isentity( v ) and IsValid( v ) and v:IsPlayer() then
			MsgC( cur, NWORK.CharName( v ) )
		else
			MsgC( cur, tostring( v ) )
		end
	end
	MsgN( "" )
end

local function Push( font, ... )
	GetChat():AddLine( font, ... )
	Mirror( ... )
	chat.PlaySound()
end

function chat.AddText( ... )
	Push( "Nwork.Chat", ... )
end

hook.Add( "HUDShouldDraw", "Nwork.HideChat", function( name )
	if name == "CHudChat" then return false end
end )

hook.Add( "PlayerBindPress", "Nwork.ChatOpen", function( _, bind, pressed )
	if not pressed then return end
	if bind == "messagemode" or bind == "messagemode2" then
		if NWORK.UI.Active() then return true end
		GetChat():Open()
		return true
	end
end )

hook.Add( "ChatText", "Nwork.ChatText", function( _, _, text, kind )
	if kind ~= "chat" then
		chat.AddText( C_SYS, text )
		return true
	end
end )

--------------------------------------------------------------- форматы речи

hook.Add( "OnPlayerChat", "Nwork.Chat", function( ply, text )
	local name = NWORK.CharName( ply )

	local ooc = string.match( text, "^//%s*(.+)" )
	if ooc then
		Push( "Nwork.Chat", C_OOC, "[OOC] ", C_NAME, name, C_TEXT, ": " .. ooc )
		return true
	end

	local event = string.match( text, "^/event%s+(.+)" )
	if event then
		if IsValid( ply ) and ply:IsAdmin() then
			Push( "Nwork.ChatYell", C_EVENT, "СОБЫТИЕ: " .. event )
		end
		return true
	end

	local whisper = string.match( text, "^/w%S*%s+(.+)" )
	if whisper then
		Push( "Nwork.ChatWhisper", C_NAME, name, C_WHIS, " шепчет \"" .. whisper .. "\"" )
		return true
	end

	local yell = string.match( text, "^/y%S*%s+(.+)" )
	if yell then
		Push( "Nwork.ChatYell", C_NAME, name, C_TEXT, " кричит \"" .. yell .. "\"" )
		return true
	end

	local it = string.match( text, "^/it%s+(.+)" )
	if it then
		Push( "Nwork.Chat", C_EMOTE, "** " .. it .. "." )
		return true
	end

	local me = string.match( text, "^/me%s+(.+)" )
	if me then
		Push( "Nwork.Chat", C_EMOTE, "** " .. name .. " " .. me .. "." )
		return true
	end

	local radio = string.match( text, "^/r%s+(.+)" )
	if radio then
		Push( "Nwork.Chat", C_NAME, name, C_RADIO, " передаёт по рации \"<:: " .. radio .. ". ::>\"" )
		return true
	end

	Push( "Nwork.Chat", C_NAME, name, C_TEXT, " говорит \"" .. text .. "\"" )
	return true
end )

--------------------------------------------------------------- знакомства (сеть)

net.Receive( "nwork_recog", function()
	local intro = net.ReadBool()

	if not intro then
		local n = net.ReadUInt( 16 )
		for _ = 1, n do
			NWORK.Recognized[ net.ReadUInt( 32 ) ] = true
		end
		return
	end

	local self_ = net.ReadBool()
	local id    = net.ReadUInt( 32 )
	local name  = net.ReadString()

	if self_ then
		Push( "Nwork.Chat", C_EMOTE, "** Вы представляетесь окружающим как " .. name .. "." )
	else
		NWORK.Recognized[ id ] = true
		Push( "Nwork.Chat", C_EMOTE, "** " .. name .. " представляется." )
	end
end )
