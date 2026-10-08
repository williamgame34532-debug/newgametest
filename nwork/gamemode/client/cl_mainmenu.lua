--[[-------------------------------------------------------------------------
	N-work — главное меню.

	Логотип N-WORK с линиями и косыми засечками, кнопка PLAY.
	PLAY: есть персонажи -> выбор персонажа, нет -> создание.
	Команда nwork_menu открывает меню снова.
---------------------------------------------------------------------------]]

local T = NWORK.Theme

NWORK.Chars = NWORK.Chars or {}

local MENU

------------------------------------------------- текст с разрядкой (логотип)

local function Chars( text )
	local out = {}
	for _, code in utf8.codes( text ) do
		out[ #out + 1 ] = utf8.char( code )
	end
	return out
end

local function SpacedSize( font, text, spacing )
	surface.SetFont( font )
	local chars = Chars( text )
	local w, h = 0, 0
	for i, ch in ipairs( chars ) do
		local cw, chh = surface.GetTextSize( ch )
		w = w + cw + ( i < #chars and spacing or 0 )
		h = math.max( h, chh )
	end
	return w, h
end

local function DrawSpaced( font, text, x, y, col, spacing )
	surface.SetFont( font )
	surface.SetTextColor( col )
	for _, ch in ipairs( Chars( text ) ) do
		surface.SetTextPos( x, y )
		surface.DrawText( ch )
		x = x + select( 1, surface.GetTextSize( ch ) ) + spacing
	end
end

--------------------------------------------------------------------- панель

local PANEL = {}

function PANEL:Init()
	self.BaseClass.Init( self )

	local k = ScrH() / 1080

	local bw, bh = math.floor( 280 * k ), math.floor( 36 * k )
	local btn = NWORK.UI.Button( self, "PLAY" )
	btn:SetSize( bw, bh )
	btn:SetPos( ( ScrW() - bw ) / 2, math.floor( ScrH() * 0.545 ) )
	btn.DoClick = function()
		surface.PlaySound( "buttons/lightswitch2.wav" )
		self:Close( function()
			if #NWORK.Chars > 0 then
				NWORK.OpenCharSelect()
			else
				NWORK.OpenCharCreate()
			end
		end )
	end
end

function PANEL:Paint( w, h )
	self.BaseClass.Paint( self, w, h )

	local k  = h / 1080
	local cx = w / 2

	local spacing = math.floor( 10 * k )
	local tw, th  = SpacedSize( "Nwork.Logo", T.Menu.Title, spacing )
	local ty      = math.floor( h * 0.44 - th / 2 )

	DrawSpaced( "Nwork.Logo", T.Menu.Title, cx - tw / 2, ty, T.Colors.Text, spacing )

	local ly    = ty + th - math.floor( 6 * k )
	local lth   = math.max( 2, math.floor( 3 * k ) )
	local reach = math.floor( 250 * k )
	local gap   = math.floor( 18 * k )
	local tip   = math.floor( 26 * k )

	local lx0 = cx - tw / 2 - gap - reach
	local rx1 = cx + tw / 2 + gap + reach

	surface.SetDrawColor( T.Colors.Line )
	surface.DrawRect( lx0, ly, reach, lth )
	surface.DrawRect( cx + tw / 2 + gap, ly, reach, lth )

	draw.NoTexture()
	surface.DrawPoly( {
		{ x = lx0,             y = ly + lth },
		{ x = lx0 - tip,       y = ly + lth + tip * 0.55 },
		{ x = lx0 - tip + lth, y = ly + lth + tip * 0.55 },
		{ x = lx0 + lth,       y = ly + lth },
	} )
	surface.DrawPoly( {
		{ x = rx1 - lth,       y = ly },
		{ x = rx1 + tip - lth, y = ly - tip * 0.55 },
		{ x = rx1 + tip,       y = ly - tip * 0.55 },
		{ x = rx1,             y = ly },
	} )
end

vgui.Register( "NworkMainMenu", PANEL, "NworkScreen" )

------------------------------------------------------------ открытие/закрытие

function NWORK.OpenMainMenu()
	if IsValid( MENU ) then MENU:Remove() end
	MENU = vgui.Create( "NworkMainMenu" )
	return MENU
end

hook.Add( "InitPostEntity", "Nwork.MainMenu", function()
	net.Start( "nwork_ready" )
	net.SendToServer()

	timer.Simple( 0.5, NWORK.OpenMainMenu )
end )

concommand.Add( "nwork_menu", function()
	NWORK.OpenMainMenu()
end )

--------------------------------------------------------------- приём данных

net.Receive( "nwork_chars", function()
	local n = net.ReadUInt( 8 )
	NWORK.Chars = {}

	for i = 1, n do
		NWORK.Chars[ i ] = {
			id      = net.ReadUInt( 32 ),
			name    = net.ReadString(),
			descr   = net.ReadString(),
			model   = net.ReadString(),
			skin    = net.ReadUInt( 8 ),
			faction = net.ReadString(),
		}
	end

	hook.Run( "NworkCharsUpdated" )
end )

net.Receive( "nwork_fail", function()
	local why = net.ReadString()
	notification.AddLegacy( why, NOTIFY_ERROR, 4 )
	surface.PlaySound( "buttons/button10.wav" )
end )

-- персонаж загружен: закрываем все экраны N-work
net.Receive( "nwork_loaded", function()
	for pnl in pairs( NWORK.UI.Open ) do
		if IsValid( pnl ) and pnl.Close then pnl:Close() end
	end
end )
