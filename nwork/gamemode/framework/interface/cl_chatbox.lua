--[[-------------------------------------------------------------------------
	N-work — чат-бокс.

	Только отображение: форматы строк задают чат-классы (sh_chat.lua),
	сервер рассылает готовые сообщения. Вид — как в Monarch: закрытый
	чат — строки без подложки с мягкой тенью, гаснут через ~10 секунд;
	открытый — плоская тёмная панель и тонкая строка ввода.

	Панель перетаскивается за верхнюю кромку и растягивается за правый
	нижний угол (геометрия запоминается). При вводе «/» справа
	открывается список команд: Tab — дополнить, стрелки — выбрать.

	API:
		NWORK.ChatPush( font, цвет, "текст", NWORK.Chat.Font( "..." ), ... )
		chat.AddText( ... )   — как обычно, шрифт Nwork.Chat
---------------------------------------------------------------------------]]

local CC      = NWORK.Chat.Colors
local C_PANEL = Color( 14, 15, 17, 175 )   -- открытый чат: плоская тёмная подложка
local C_ENTRY = Color( 8, 9, 10, 200 )
local C_NAME  = CC.Name
local C_TEXT  = CC.Text
local C_SYS   = CC.System
local C_EVENT = CC.Event
local C_DIM   = Color( 158, 164, 172 )

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
		math.Clamp( cookie.GetNumber( "nwork_chat_y", math.floor( h * 0.77 ) - defH ), 0, h - 160 ) )

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
		surface.SetDrawColor( C_ENTRY )
		surface.DrawRect( 0, 0, ww, hh )
		surface.SetDrawColor( 255, 255, 255, s:HasFocus() and 34 or 16 )
		surface.DrawOutlinedRect( 0, 0, ww, hh, 1 )
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
	local rows, cur, curw, curh = {}, {}, 0, 0
	local function push()
		if #cur > 0 then
			rows[ #rows + 1 ] = { font = line.font, h = curh, parts = cur }
			cur, curw, curh = {}, 0, 0
		end
	end

	for _, seg in ipairs( line.segs ) do
		local font = seg.f or line.font
		for token in string.gmatch( seg.t, "%S+%s*" ) do
			surface.SetFont( font )
			local tw = surface.GetTextSize( token )

			if curw + tw > maxw and curw > 0 then push() end

			cur[ #cur + 1 ] = { c = seg.c, t = token, f = font }
			curw = curw + tw
			curh = math.max( curh, FontH( font ) )
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
	local curF = nil

	for _, v in ipairs( { ... } ) do
		if IsColor( v ) then
			cur = v
		elseif istable( v ) and v.nworkFont then
			curF = v.nworkFont
		elseif istable( v ) and v.r and v.g and v.b then
			cur = Color( v.r, v.g, v.b, v.a )
		elseif isentity( v ) and IsValid( v ) and v:IsPlayer() then
			segs[ #segs + 1 ] = { c = C_NAME, t = NWORK.CharName( v ), f = curF }
		else
			segs[ #segs + 1 ] = { c = cur, t = tostring( v ), f = curF }
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
		surface.SetDrawColor( C_PANEL )
		surface.DrawRect( 0, 0, w, h )

		-- кромка для перетаскивания и подсказка
		if self:IsHovered() or self.Dragging then
			surface.SetDrawColor( 255, 255, 255, 10 )
			surface.DrawRect( 0, 0, w, self.HeadH )
		end
		draw.SimpleText( self.CmdOpen and "Tab — дополнить · ↑↓ — выбрать" or os.date( "%H:%M" ),
			"Nwork.ChatHint", w - math.floor( 10 * k ), math.floor( 5 * k ),
			Color( 255, 255, 255, 70 ), TEXT_ALIGN_RIGHT )

		-- уголок-грип для растягивания
		surface.SetDrawColor( 255, 255, 255, 60 )
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

		-- части строки выравниваются по низу (разные шрифты), с мягкой тенью
		local x = self.Pad
		for _, part in ipairs( row.parts ) do
			surface.SetFont( part.f or row.font )
			local tw, th = surface.GetTextSize( part.t )
			local ty = y + row.h - th

			surface.SetTextColor( 0, 0, 0, 170 )
			surface.SetTextPos( x + 1, ty + 1 )
			surface.DrawText( part.t )

			surface.SetTextColor( part.c )
			surface.SetTextPos( x, ty )
			surface.DrawText( part.t )
			x = x + tw
		end
	end
end

function PANEL:Think()
	-- в меню N-work и в меню персонажа чата не видно
	if NWORK.UI.Active() or ( NWORK.TabOpen and NWORK.TabOpen() ) then
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
		for _, c in ipairs( NWORK.Command.Help( LocalPlayer() ) ) do
			if c.cmd == arg then
				chat.AddText( C_EVENT, c.cmd .. " " .. c.args, C_SYS, " — " .. c.desc )
				return
			end
		end
		chat.AddText( C_SYS, "Команда " .. arg .. " не найдена." )
		return
	end

	chat.AddText( C_EVENT, "Команды:" )
	for _, c in ipairs( NWORK.Command.Help( LocalPlayer() ) ) do
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

	for _, c in ipairs( NWORK.Command.Help( LocalPlayer() ) ) do
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
	local maxRows = math.max( 3, math.floor( ( ScrH() * 0.6 - self.HeadH ) / self.RowH ) )
	self.Shown = math.min( #list, maxRows )
	self.First = math.Clamp( sel - self.Shown, 0, math.max( 0, #list - self.Shown ) )
	local h = self.HeadH + self.Shown * self.RowH + math.floor( 8 * k )

	local cx, cy = chatPnl:GetPos()
	local x = math.min( cx + chatPnl:GetWide() + math.floor( 10 * k ), ScrW() - w )

	self:SetSize( w, h )
	self:SetPos( x, math.max( 0, cy + chatPnl:GetTall() - h ) )
	self:SetVisible( true )
	self:SetMouseInputEnabled( true )
end

function CMDS:Paint( w, h )
	local k = ScrH() / 1080

	surface.SetDrawColor( C_PANEL )
	surface.DrawRect( 0, 0, w, h )

	draw.SimpleText( ( "%d команд" ):format( #self.List ), "Nwork.ChatHint",
		math.floor( 12 * k ), math.floor( 6 * k ), Color( 210, 216, 224, 150 ) )
	draw.SimpleText( "Tab — дополнить · ↑↓ — выбрать", "Nwork.ChatHint",
		w - math.floor( 12 * k ), math.floor( 6 * k ), Color( 210, 216, 224, 110 ), TEXT_ALIGN_RIGHT )

	for i = self.First + 1, self.First + self.Shown do
		local c = self.List[ i ]
		local y = self.HeadH + ( i - self.First - 1 ) * self.RowH + math.floor( 4 * k )

		if i == self.Sel then
			surface.SetDrawColor( 255, 255, 255, 14 )
			surface.DrawRect( 2, y, w - 4, self.RowH )
			surface.SetDrawColor( 205, 72, 62, 230 )
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
	local i = math.floor( ( my - self.HeadH ) / self.RowH ) + 1 + ( self.First or 0 )

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
		elseif istable( v ) and v.nworkFont then
			-- маркер шрифта, в консоль не печатается
		elseif istable( v ) and v.nworkFont then
			-- маркер шрифта, в консоль не печатается
		elseif isentity( v ) and IsValid( v ) and v:IsPlayer() then
			MsgC( cur, NWORK.CharName( v ) )
		else
			MsgC( cur, tostring( v ) )
		end
	end
	MsgN( "" )
end

function NWORK.ChatPush( font, ... )
	GetChat():AddLine( font or "Nwork.Chat", ... )
	Mirror( ... )
	chat.PlaySound()
end

local Push = NWORK.ChatPush

function chat.AddText( ... )
	Push( "Nwork.Chat", ... )
end

hook.Add( "PlayerBindPress", "Nwork.ChatOpen", function( _, bind, pressed )
	if not pressed then return end
	if bind == "messagemode" or bind == "messagemode2" then
		if NWORK.UI.Active() then return true end
		GetChat():Open()
		return true
	end
end )

-- системные сообщения движка (вход/выход игроков и т.п.)
hook.Add( "ChatText", "Nwork.ChatText", function( _, _, text, kind )
	if kind ~= "chat" then
		Push( "Nwork.ChatItalic", C_SYS, text )
		return true
	end
end )

-- сообщения мимо PlayerSay (консольный say и т.п.) — как OOC
hook.Add( "OnPlayerChat", "Nwork.Chat", function( ply, text )
	Push( "Nwork.Chat", CC.OOC, "(OOC) ", CC.OOCText, ( IsValid( ply ) and ply:Nick() or "Консоль" ) .. ": " .. text )
	return true
end )
