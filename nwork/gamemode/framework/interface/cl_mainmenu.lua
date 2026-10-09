--[[-------------------------------------------------------------------------
	N-work — главное меню.

	Логотип-надпись (materials/nwork/watermark.png) в стиле
	PROJECT SYNAPSE, под ним кнопка ИГРАТЬ. Если материала нет —
	текстовый заголовок с линиями и засечками.
	PLAY: есть персонажи -> выбор персонажа, нет -> создание.
	Команда nwork_menu открывает меню снова.
---------------------------------------------------------------------------]]

local T = NWORK.Theme

NWORK.Chars = NWORK.Chars or {}

local MENU

------------------------------------------------- текст с разрядкой (логотип)

local Chars = NWORK.Util.Chars

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
	local btn = NWORK.UI.Button( self, "ИГРАТЬ" )
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

	-- логотип-материал
	local lw = math.floor( 620 * k )
	if NWORK.UI.Wordmark( cx, math.floor( h * 0.30 ), lw, 245, 0.5 ) > 0 then return end

	local spacing = math.floor( 10 * k )
	local title   = NWORK.Schema and NWORK.Schema.Name or "N-WORK"
	local tw, th  = SpacedSize( "Nwork.Ghost", title, spacing )
	local ty      = math.floor( h * 0.44 - th / 2 )

	DrawSpaced( "Nwork.Ghost", title, cx - tw / 2, ty, T.Colors.Text, spacing )

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

-- персонаж загружен: закрываем все экраны N-work
net.Receive( "nwork_loaded", function()
	NWORK.UI.CloseAll()
	hook.Run( "NworkCharacterLoaded", LocalPlayer() )
end )

-- вернуться к выбору персонажа (меню персонажа -> «Сменить персонажа»)
function NWORK.UnloadCharacter()
	net.Start( "nwork_unload" )
	net.SendToServer()
	timer.Simple( 0.3, NWORK.OpenMainMenu )
end
