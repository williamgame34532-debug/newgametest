--[[-------------------------------------------------------------------------
	N-work — меню персонажа (Tab), стиль референса.

	Слева: белая иконка одежды + имя курсивом + фракция голубым;
	колонки слотов экипировки с белыми глифами; крупная модель;
	снизу — полосы состояний (Здоровье/Голод/Жажда/Бодрость).
	Справа сверху: глиф + заголовок вкладки. По правому краю —
	квадратные иконки-кнопки навигации. Действия предмета — текстовые
	ссылки, как в референсе. Tab открывает, ✕/ESC закрывают.
---------------------------------------------------------------------------]]

local T = NWORK.Theme

local matGradL = Material( "vgui/gradient-l" )
local matGradD = Material( "vgui/gradient-d" )
local matGradU = Material( "vgui/gradient-u" )

local C_SUB   = Color( 123, 167, 201 )         -- голубая подпись фракции
local C_SLOT  = Color( 40, 43, 47, 140 )
local C_WHITE = Color( 235, 238, 242 )

local INV

local function SlotBox( x, y, s, glyph, accent )
	draw.RoundedBox( 4, x, y, s, s, C_SLOT )

	surface.SetMaterial( matGradU )
	surface.SetDrawColor( 255, 255, 255, 8 )
	surface.DrawTexturedRect( x, y, s, math.floor( s * 0.6 ) )

	if glyph then
		NWORK.Glyph( glyph, x + s * 0.18, y + s * 0.18, s * 0.64, Color( 225, 229, 234, 200 ) )
	end

	draw.NoTexture()
	surface.SetDrawColor( accent and Color( 190, 84, 74, 210 ) or Color( 255, 255, 255, 40 ) )
	surface.DrawPoly( {
		{ x = x + s - 11, y = y + s - 2 },
		{ x = x + s - 2,  y = y + s - 11 },
		{ x = x + s - 2,  y = y + s - 2 },
	} )
end

--------------------------------------------------------------------- панель

local PANEL = {}

function PANEL:Init()
	self:SetSize( ScrW(), ScrH() )
	self:MakePopup()
	self:SetKeyboardInputEnabled( false )

	self:SetAlpha( 0 )
	self:AlphaTo( 255, 0.18, 0 )

	local w, h = ScrW(), ScrH()
	local k    = h / 1080
	self.K = k

	self.Tab = "inv"

	-- модель персонажа (крупно, как в референсе)
	local mdl = vgui.Create( "DModelPanel", self )
	mdl:SetPos( math.floor( w * 0.03 ), 0 )
	mdl:SetSize( math.floor( w * 0.34 ), h )
	mdl:SetFOV( 26 )
	mdl:SetModel( LocalPlayer():GetModel() )
	mdl.LayoutEntity = function( s, ent )
		ent:SetAngles( Angle( 0, 24, 0 ) )
		s:RunAnimation()
	end

	local ent = mdl:GetEntity()
	if IsValid( ent ) then
		ent:SetSkin( LocalPlayer():GetSkin() or 0 )
		local head = ent:LookupBone( "ValveBiped.Bip01_Head1" )
		local pos  = head and ent:GetBonePosition( head ) or ( ent:GetPos() + ent:OBBCenter() )
		mdl:SetCamPos( pos + Vector( 62, 12, -14 ) )
		mdl:SetLookAt( pos + Vector( 0, 0, -20 ) )
	end
	self.Model = mdl

	-- ЗАКРЫТЬ ✕
	local close = vgui.Create( "DButton", self )
	close:SetText( "" )
	close:SetSize( math.floor( 130 * k ), math.floor( 30 * k ) )
	close:SetPos( w - close:GetWide() - math.floor( 24 * k ), math.floor( 14 * k ) )
	close.Paint = function( s, bw, bh )
		draw.SimpleText( "ЗАКРЫТЬ  ✕", "Nwork.NavBtn", bw, bh / 2,
			Color( 220, 226, 232, s:IsHovered() and 255 or 160 ),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end
	close.DoClick = function() self:Close() end

	self:BuildNav()
	self:BuildTab()
end

function PANEL:Close()
	if self.Closing then return end
	self.Closing = true
	self:AlphaTo( 0, 0.14, 0, function()
		if IsValid( self ) then self:Remove() end
	end )
end

function PANEL:Think()
	if input.IsKeyDown( KEY_ESCAPE ) then self:Close() end
end

-------------------------------------------------------------------- навигация

local NAV = {
	{ id = "inv",      label = "Инвентарь",       glyph = "backpack", title = "ИНВЕНТАРЬ" },
	{ id = "players",  label = "Список игроков",  glyph = "people",   title = "СПИСОК ИГРОКОВ" },
	{ id = "settings", label = "Настройки",       glyph = "gear",     title = "НАСТРОЙКИ" },
	{ id = "config",   label = "Конфигурация",    glyph = "shield",   title = "КОНФИГУРАЦИЯ", admin = true },
}

function PANEL:BuildNav()
	local k = self.K
	local s = math.floor( 54 * k )
	local x = ScrW() - s - math.floor( 24 * k )
	local y = math.floor( ScrH() * 0.10 )

	for _, tab in ipairs( NAV ) do
		if not tab.admin or LocalPlayer():IsAdmin() then
			local b = vgui.Create( "DButton", self )
			b:SetText( "" )
			b:SetPos( x, y )
			b:SetSize( s, s )
			b.Paint = function( bs, ww, hh )
				local active = self.Tab == tab.id

				draw.RoundedBox( 6, 0, 0, ww, hh, Color( 24, 27, 31, active and 235 or 170 ) )

				if active then
					surface.SetDrawColor( 150, 178, 205, 200 )
					surface.DrawRect( 0, 4, 2, hh - 8 )
				elseif bs:IsHovered() then
					surface.SetDrawColor( 255, 255, 255, 40 )
					surface.DrawOutlinedRect( 0, 0, ww, hh, 1 )
				end

				NWORK.Glyph( tab.glyph, ww * 0.18, hh * 0.18, ww * 0.64,
					Color( 235, 238, 242, active and 255 or 185 ), Color( 24, 27, 31 ) )

				if bs:IsHovered() then
					draw.SimpleText( tab.label, "Nwork.NavBtn", -math.floor( 10 * k ), hh / 2,
						Color( 226, 231, 237, 220 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
				end
			end
			b.DoClick = function()
				surface.PlaySound( "ui/buttonclick.wav" )
				self.Tab = tab.id
				self:BuildTab()
			end

			y = y + s + math.floor( 10 * k )
		end
	end
end

--------------------------------------------------------------------- вкладки

local function TabInfo( id )
	for _, t in ipairs( NAV ) do
		if t.id == id then return t end
	end
end

function PANEL:BuildTab()
	if IsValid( self.Content ) then self.Content:Remove() end

	local w, h = ScrW(), ScrH()

	local content = vgui.Create( "DPanel", self )
	content:SetPos( math.floor( w * 0.345 ), math.floor( h * 0.095 ) )
	content:SetSize( math.floor( w * 0.60 ), math.floor( h * 0.82 ) )
	content:SetPaintBackground( false )
	self.Content = content

	if self.Tab == "inv" then
		self:TabInventory( content )
	elseif self.Tab == "players" then
		self:TabPlayers( content )
	elseif self.Tab == "settings" then
		self:TabSettings( content )
	elseif self.Tab == "config" then
		self:TabConfig( content )
	end
end

-- заголовок вкладки: глиф + текст по центру-справа, как в референсе
function PANEL:PaintHeader( c, w )
	local k    = self.K
	local info = TabInfo( self.Tab )
	local s    = math.floor( 46 * k )
	local hx   = math.floor( w * 0.44 )

	NWORK.Glyph( info.glyph, hx, 0, s, C_WHITE, Color( 12, 14, 16 ) )
	draw.SimpleText( info.title, "Nwork.InvHeader", hx + s + math.floor( 16 * k ),
		math.floor( 2 * k ), C_WHITE )
end

------------------------------------------------------------------- инвентарь

function PANEL:TabInventory( c )
	local k   = self.K
	local inv = NWORK.LocalInv or {}

	local cols, rows = 5, 4
	local slot, gap  = math.floor( 82 * k ), math.floor( 8 * k )
	local gridW = cols * slot + ( cols - 1 ) * gap
	local gx    = c:GetWide() - gridW
	local gy    = math.floor( 78 * k )

	local detailW = gx - math.floor( 60 * k )
	local sel     = self.SelIdx and inv[ self.SelIdx ]
	local selDef  = sel and NWORK.Items[ sel.id ]

	c.Paint = function( _, w, h )
		self:PaintHeader( c, w )

		for i = 0, cols * rows - 1 do
			local col, row = i % cols, math.floor( i / cols )
			SlotBox( gx + col * ( slot + gap ), gy + row * ( slot + gap ), slot )
		end

		if selDef then
			local y0 = gy

			draw.SimpleText( string.upper( selDef.Name ), "Nwork.InvHeader", 0, y0, C_WHITE )

			surface.SetDrawColor( 255, 255, 255, 70 )
			surface.DrawRect( 0, y0 + math.floor( 168 * k ), detailW, 1 )

			draw.SimpleText( "СТАТЫ", "Nwork.Label", 0, y0 + math.floor( 192 * k ), C_WHITE )
			draw.SimpleText( "Выпадает при смерти", "Nwork.Small", 0, y0 + math.floor( 230 * k ),
				Color( 200, 206, 214 ) )
			draw.SimpleText( "В стопке: " .. sel.n, "Nwork.Small", 0, y0 + math.floor( 256 * k ),
				Color( 200, 206, 214 ) )

			draw.SimpleText( "ДЕЙСТВИЯ", "Nwork.Label", math.floor( detailW * 0.52 ),
				y0 + math.floor( 192 * k ), C_WHITE, TEXT_ALIGN_CENTER )
		end
	end

	if selDef then
		local y0 = gy

		local desc = vgui.Create( "DLabel", c )
		desc:SetFont( "Nwork.Small" )
		desc:SetTextColor( Color( 210, 215, 222 ) )
		desc:SetWrap( true )
		desc:SetContentAlignment( 7 )
		desc:SetText( selDef.Desc or "" )
		desc:SetPos( 0, y0 + math.floor( 50 * k ) )
		desc:SetSize( detailW - math.floor( 165 * k ), math.floor( 110 * k ) )

		local icon = vgui.Create( "ModelImage", c )
		icon:SetPos( detailW - math.floor( 145 * k ), y0 )
		icon:SetSize( math.floor( 145 * k ), math.floor( 145 * k ) )
		icon:SetModel( selDef.Model )

		-- действия — текстовые ссылки, как в референсе (Wear / Drop)
		local ay = y0 + math.floor( 228 * k )

		local function Action( label, fn )
			local b = vgui.Create( "DButton", c )
			b:SetText( "" )
			b:SetSize( math.floor( 200 * k ), math.floor( 26 * k ) )
			b:SetPos( math.floor( detailW * 0.52 - b:GetWide() / 2 ), ay )
			b.Paint = function( s, ww, hh )
				draw.SimpleText( label, "Nwork.InvSub", ww / 2, hh / 2,
					s:IsHovered() and C_WHITE or Color( 196, 202, 210 ),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			end
			b.DoClick = fn
			ay = ay + math.floor( 30 * k )
		end

		if selDef.UseName then
			Action( selDef.UseName, function()
				net.Start( "nwork_item_use" )
					net.WriteUInt( self.SelIdx, 8 )
				net.SendToServer()
			end )
		end

		Action( "Выбросить", function()
			net.Start( "nwork_item_drop" )
				net.WriteUInt( self.SelIdx, 8 )
			net.SendToServer()
		end )
	end

	for idx, entry in ipairs( inv ) do
		if idx > cols * rows then break end

		local def = NWORK.Items[ entry.id ]
		local col, row = ( idx - 1 ) % cols, math.floor( ( idx - 1 ) / cols )

		local b = vgui.Create( "DButton", c )
		b:SetText( "" )
		b:SetPos( gx + col * ( slot + gap ), gy + row * ( slot + gap ) )
		b:SetSize( slot, slot )
		b.Paint = function( s, ww, hh )
			if self.SelIdx == idx then
				draw.RoundedBox( 4, 0, 0, ww, hh, Color( 118, 122, 128, 235 ) )
			elseif s:IsHovered() then
				draw.RoundedBox( 4, 0, 0, ww, hh, Color( 58, 62, 67, 235 ) )
			end
		end
		b.DoClick = function()
			surface.PlaySound( "ui/buttonclick.wav" )
			self.SelIdx = idx
			self:BuildTab()
		end

		if def then
			local ic = vgui.Create( "ModelImage", b )
			ic:SetPos( math.floor( 5 * k ), math.floor( 5 * k ) )
			ic:SetSize( slot - math.floor( 10 * k ), slot - math.floor( 10 * k ) )
			ic:SetModel( def.Model )
			ic:SetMouseInputEnabled( false )
		end

		if entry.n > 1 then
			local cnt = vgui.Create( "DLabel", b )
			cnt:SetFont( "Nwork.Small" )
			cnt:SetTextColor( C_WHITE )
			cnt:SetText( tostring( entry.n ) )
			cnt:SizeToContents()
			cnt:SetPos( slot - cnt:GetWide() - math.floor( 7 * k ), math.floor( 3 * k ) )
			cnt:SetMouseInputEnabled( false )
		end
	end
end

--------------------------------------------------------------------- игроки

function PANEL:TabPlayers( c )
	local k = self.K

	c.Paint = function( _, w ) self:PaintHeader( c, w ) end

	local scroll = vgui.Create( "DScrollPanel", c )
	scroll:SetPos( 0, math.floor( 78 * k ) )
	scroll:SetSize( c:GetWide(), c:GetTall() - math.floor( 78 * k ) )

	for _, ply in ipairs( player.GetAll() ) do
		local fac = NWORK.Factions[ ply:GetNWString( "nwork_faction", "citizen" ) ]

		local row = vgui.Create( "DPanel", scroll )
		row:SetTall( math.floor( 44 * k ) )
		row:Dock( TOP )
		row:DockMargin( 0, 0, math.floor( 8 * k ), math.floor( 6 * k ) )
		row.Paint = function( _, w, h )
			draw.RoundedBox( 4, 0, 0, w, h, Color( 24, 27, 31, 170 ) )
			draw.SimpleText( NWORK.CharName( ply ), "Nwork.InvSub",
				math.floor( 12 * k ), h / 2, C_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			draw.SimpleText( fac and fac.Name or "", "Nwork.Tiny",
				w * 0.55, h / 2, C_SUB, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			draw.SimpleText( ply:Ping() .. " ms", "Nwork.Tiny",
				w - math.floor( 12 * k ), h / 2, Color( 168, 174, 182, 180 ),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
	end
end

------------------------------------------------------------------- настройки

-- тумблер в стиле референса (пилюля, красный во включённом состоянии)
local function ToggleRow( parent, y, k, label, get, set )
	local row = vgui.Create( "DButton", parent )
	row:SetText( "" )
	row:SetPos( 0, y )
	row:SetSize( math.floor( parent:GetWide() * 0.48 ), math.floor( 36 * k ) )
	row.Paint = function( s, w, h )
		draw.SimpleText( label, "Nwork.InvSub", 0, h / 2,
			Color( 222, 227, 233 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

		local pw, ph = math.floor( 46 * k ), math.floor( 22 * k )
		local px, py = w - pw, ( h - ph ) / 2
		local on = get()

		draw.RoundedBox( ph / 2, px, py, pw, ph,
			on and Color( 186, 74, 64, 235 ) or Color( 96, 101, 107, 180 ) )

		local kn = ph - 6
		draw.RoundedBox( kn / 2, on and ( px + pw - kn - 3 ) or ( px + 3 ), py + 3, kn, kn,
			Color( 235, 238, 242 ) )
	end
	row.DoClick = function()
		set( not get() )
		surface.PlaySound( "ui/buttonclick.wav" )
	end
end

-- слайдер: подпись слева, значение и тонкая дорожка справа
local function SliderRow( parent, y, k, label, min, max, dec, get, set )
	local row = vgui.Create( "DPanel", parent )
	row:SetPos( 0, y )
	row:SetSize( math.floor( parent:GetWide() * 0.48 ), math.floor( 36 * k ) )
	row:SetPaintBackground( false )
	row:SetMouseInputEnabled( true )
	row:SetCursor( "hand" )

	local trackW = math.floor( 120 * k )

	row.Paint = function( s, w, h )
		draw.SimpleText( label, "Nwork.InvSub", 0, h / 2,
			Color( 222, 227, 233 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

		local v    = get()
		local frac = math.Clamp( ( v - min ) / ( max - min ), 0, 1 )
		local tx   = w - trackW

		draw.SimpleText( math.Round( v, dec ), "Nwork.Small", tx - math.floor( 12 * k ), h / 2,
			Color( 200, 206, 214 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

		surface.SetDrawColor( 120, 125, 131, 200 )
		surface.DrawRect( tx, h / 2 - 1, trackW, 2 )

		draw.RoundedBox( 6, tx + frac * ( trackW - 12 ), h / 2 - 6, 12, 12,
			Color( 235, 238, 242 ) )

		if s.Drag then
			local mx = s:CursorPos()
			local f = math.Clamp( ( mx - tx ) / trackW, 0, 1 )
			set( math.Round( min + f * ( max - min ), dec ) )
			if not input.IsMouseDown( MOUSE_LEFT ) then s.Drag = false end
		end
	end
	row.OnMousePressed  = function( s ) s.Drag = true end
	row.OnMouseReleased = function( s ) s.Drag = false end
end

function PANEL:TabSettings( c )
	local k = self.K

	c.Paint = function( _, w )
		self:PaintHeader( c, w )

		draw.SimpleText( "Интерфейс", "Nwork.Label", 0, math.floor( 78 * k ), C_WHITE )
		draw.SimpleText( "Меню", "Nwork.Label", 0, math.floor( 262 * k ), C_WHITE )
	end

	local y = math.floor( 118 * k )

	ToggleRow( c, y, k, "Вотермарк", function() return T.Watermark.Enabled end,
		function( v ) T.Watermark.Enabled = v cookie.Set( "nwork_wm", v and 1 or 0 ) end )
	y = y + math.floor( 40 * k )

	ToggleRow( c, y, k, "Эхо звуков в меню", function() return T.Menu.EchoDSP ~= 0 end,
		function( v ) T.Menu.EchoDSP = v and 12 or 0 cookie.Set( "nwork_echo", v and 1 or 0 ) end )
	y = y + math.floor( 40 * k )

	local row = vgui.Create( "DButton", c )
	row:SetText( "" )
	row:SetPos( 0, y )
	row:SetSize( math.floor( c:GetWide() * 0.48 ), math.floor( 36 * k ) )
	row.Paint = function( s, w, h )
		draw.SimpleText( "Сбросить положение и размер чата", "Nwork.InvSub", 0, h / 2,
			s:IsHovered() and C_WHITE or Color( 200, 206, 214 ),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end
	row.DoClick = function()
		cookie.Delete( "nwork_chat_x" ) cookie.Delete( "nwork_chat_y" )
		cookie.Delete( "nwork_chat_w" ) cookie.Delete( "nwork_chat_h" )
		notification.AddLegacy( "Чат сброшен — применится после перезахода.", NOTIFY_GENERIC, 3 )
	end

	y = math.floor( 302 * k )

	SliderRow( c, y, k, "Размытие мира в меню", 0, 10, 0,
		function() return T.Menu.BlurDensity end,
		function( v ) T.Menu.BlurDensity = v cookie.Set( "nwork_blur", v ) end )
	y = y + math.floor( 40 * k )

	SliderRow( c, y, k, "Насыщенность мира в меню", 0, 1, 2,
		function() return T.Menu.GraySat end,
		function( v ) T.Menu.GraySat = v cookie.Set( "nwork_gray", v ) end )
	y = y + math.floor( 40 * k )

	SliderRow( c, y, k, "Секунд на перелёт камеры", 8, 40, 0,
		function() return T.Menu.CamSegment end,
		function( v ) T.Menu.CamSegment = v cookie.Set( "nwork_camseg", v ) end )
end

---------------------------------------------------------------- конфигурация

function PANEL:TabConfig( c )
	local k = self.K

	c.Paint = function( _, w )
		self:PaintHeader( c, w )
		draw.SimpleText( "Путь камеры меню на этой карте", "Nwork.Label", 0,
			math.floor( 78 * k ), C_WHITE )
	end

	local cmds = {
		{ "Добавить точку камеры (где стою)", "nwork_cam_add" },
		{ "Убрать последнюю точку",           "nwork_cam_undo" },
		{ "Очистить путь карты",              "nwork_cam_clear" },
		{ "Список точек в консоль",           "nwork_cam_list" },
	}

	for i, cmd in ipairs( cmds ) do
		local b = vgui.Create( "DButton", c )
		b:SetText( "" )
		b:SetPos( 0, math.floor( ( 118 + ( i - 1 ) * 36 ) * k ) )
		b:SetSize( math.floor( c:GetWide() * 0.48 ), math.floor( 30 * k ) )
		b.Paint = function( s, ww, hh )
			draw.SimpleText( cmd[ 1 ], "Nwork.InvSub", 0, hh / 2,
				s:IsHovered() and C_WHITE or Color( 200, 206, 214 ),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end
		b.DoClick = function()
			LocalPlayer():ConCommand( cmd[ 2 ] )
			surface.PlaySound( "ui/buttonclick.wav" )
		end
	end
end

--------------------------------------------------------------------- фон

local EQUIP_A = { "helmet", "glasses", "gasmask", "shirt", "gloves", "pants", "boots" }
local EQUIP_B = { [4] = "shield", [5] = "knife", [6] = "pistol", [7] = "rifle" }

function PANEL:Paint( w, h )
	local k = self.K

	NWORK.UI.DrawBlur( self, 2 )

	surface.SetDrawColor( 10, 12, 14, 140 )
	surface.DrawRect( 0, 0, w, h )

	surface.SetMaterial( matGradL )
	surface.SetDrawColor( 8, 10, 12, 160 )
	surface.DrawTexturedRect( 0, 0, math.floor( w * 0.5 ), h )

	surface.SetMaterial( matGradD )
	surface.SetDrawColor( 8, 10, 12, 130 )
	surface.DrawTexturedRect( 0, math.floor( h * 0.6 ), w, math.floor( h * 0.4 ) )

	-- шапка: белая иконка одежды, имя курсивом, фракция голубым
	local lp   = LocalPlayer()
	local fkey = lp:GetNWString( "nwork_faction", "citizen" )
	local fac  = NWORK.Factions[ fkey ]

	local bx, by = math.floor( 26 * k ), math.floor( 20 * k )

	NWORK.Glyph( "shirt", bx, by, math.floor( 58 * k ), C_WHITE )

	draw.SimpleText( lp:GetNWString( "nwork_name", "—" ), "Nwork.InvName",
		bx + math.floor( 76 * k ), by, C_WHITE )
	draw.SimpleText( fac and fac.Name or "", "Nwork.InvSub",
		bx + math.floor( 76 * k ), by + math.floor( 38 * k ), C_SUB )

	-- колонки слотов экипировки
	local slot = math.floor( 70 * k )
	local gap  = math.floor( 8 * k )
	local ax   = math.floor( 8 * k )
	local sy   = math.floor( h * 0.30 )

	for i, glyph in ipairs( EQUIP_A ) do
		local y = sy + ( i - 1 ) * ( slot + gap )
		SlotBox( ax, y, slot, glyph, i == #EQUIP_A )
		if EQUIP_B[ i ] then
			SlotBox( ax + slot + gap, y, slot, EQUIP_B[ i ], EQUIP_B[ i ] == "rifle" )
		end
	end

	-- полосы состояний
	local bwX = math.floor( w * 0.105 )
	local bwW = math.floor( w * 0.235 )
	local byY = math.floor( h * 0.755 )

	local stats = {
		{ "Здоровье", math.Clamp( lp:Health() / math.max( lp:GetMaxHealth(), 1 ), 0, 1 ), Color( 184, 106, 104 ) },
		{ "Голод",    0.92, Color( 181, 170, 111 ) },
		{ "Жажда",    0.95, Color( 116, 148, 186 ) },
		{ "Бодрость", 0.97, Color( 116, 132, 199 ) },
	}

	for i, st in ipairs( stats ) do
		local y = byY + ( i - 1 ) * math.floor( 42 * k )

		draw.SimpleText( st[ 1 ], "Nwork.Small", bwX, y, Color( 224, 228, 234 ) )

		surface.SetDrawColor( 60, 64, 69, 200 )
		surface.DrawRect( bwX, y + math.floor( 22 * k ), bwW, math.floor( 4 * k ) )

		surface.SetDrawColor( st[ 3 ] )
		surface.DrawRect( bwX, y + math.floor( 22 * k ),
			math.floor( bwW * st[ 2 ] ), math.floor( 4 * k ) )
	end
end

vgui.Register( "NworkInventory", PANEL, "EditablePanel" )

--------------------------------------------------------------------- Tab

NWORK.LocalInv = NWORK.LocalInv or {}

net.Receive( "nwork_inv", function()
	local n = net.ReadUInt( 8 )
	local t = {}

	for i = 1, n do
		t[ i ] = { id = net.ReadString(), n = net.ReadUInt( 16 ) }
	end

	NWORK.LocalInv = t

	if IsValid( INV ) and not INV.Closing then
		if INV.SelIdx and not t[ INV.SelIdx ] then INV.SelIdx = nil end
		if INV.Tab == "inv" then INV:BuildTab() end
	end
end )

hook.Add( "ScoreboardShow", "Nwork.Inventory", function()
	if NWORK.UI.Active() then return true end

	if IsValid( INV ) then
		INV:Close()
	else
		INV = vgui.Create( "NworkInventory" )
	end

	return true
end )

hook.Add( "ScoreboardHide", "Nwork.InventoryHide", function()
	return true
end )
