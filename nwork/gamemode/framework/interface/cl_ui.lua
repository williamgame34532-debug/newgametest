--[[-------------------------------------------------------------------------
	N-work — база экранов.

	Общее для всех полноэкранных меню: учёт открытых экранов, размытие и
	приглушение цвета мира, эхо на фоновых звуках, полёт камеры по пути,
	стилизованные кнопки и панель-подложка NworkScreen.

	Помощники отрисовки для всего интерфейса:
		UI.Wordmark( x, y, w, alpha, alignX )   логотип-материал
		UI.Corner( x, y, w, h, color )          уголок-треугольник ячейки
		UI.ShadowText( text, font, x, y, color, ax, ay )
---------------------------------------------------------------------------]]

local T = NWORK.Theme
local O = NWORK.Option

NWORK.UI = NWORK.UI or {}
local UI = NWORK.UI

UI.Open = UI.Open or {}

local matBlur = Material( "pp/blurscreen" )
local matGrad = Material( "vgui/gradient-u" )

local matIcon
local function GetIcon()
	if matIcon == nil then
		local m = Material( T.Menu.IconMat, "smooth" )
		matIcon = ( m and not m:IsError() ) and m or false
	end
	return matIcon
end

------------------------------------------------------------- учёт и эффекты

function UI.Active()
	for pnl in pairs( UI.Open ) do
		if IsValid( pnl ) then return true end
	end
	return false
end

local function UpdateDSP()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end
	lp:SetDSP( ( UI.Active() and O.Get( "menu_echo" ) ) and T.Menu.EchoDSP or 0, false )
end

function UI.Track( pnl )
	UI.Open[ pnl ] = true
	UpdateDSP()

	local oldRemove = pnl.OnRemove
	pnl.OnRemove = function( s, ... )
		UI.Open[ s ] = nil
		timer.Simple( 0, UpdateDSP )
		if oldRemove then oldRemove( s, ... ) end
	end
end

-- приглушение цвета мира за меню
local colorMod = {
	[ "$pp_colour_addr" ]       = 0,
	[ "$pp_colour_addg" ]       = 0,
	[ "$pp_colour_addb" ]       = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ]   = 1,
	[ "$pp_colour_colour" ]     = 1,
	[ "$pp_colour_mulr" ]       = 0,
	[ "$pp_colour_mulg" ]       = 0,
	[ "$pp_colour_mulb" ]       = 0,
}

hook.Add( "RenderScreenspaceEffects", "Nwork.MenuGray", function()
	if not UI.Active() then return end

	colorMod[ "$pp_colour_colour" ] = O.Get( "menu_gray" )
	DrawColorModify( colorMod )
end )

-- прячем HUD, пока открыт любой экран
hook.Add( "HUDShouldDraw", "Nwork.MenuHideHUD", function( name )
	if not UI.Active() then return end
	if name ~= "CHudGMod" then return false end
end )

--------------------------------------------------------------------- размытие

function UI.DrawBlur( panel, density )
	local x, y = panel:LocalToScreen( 0, 0 )
	local frac = panel:GetAlpha() / 255

	surface.SetMaterial( matBlur )
	surface.SetDrawColor( 255, 255, 255 )

	for i = 1, 3 do
		matBlur:SetFloat( "$blur", ( i / 3 ) * density * frac )
		matBlur:Recompute()

		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect( -x, -y, ScrW(), ScrH() )
	end
end

------------------------------------------------------------------ путь камеры

-- Катмулл-Ром: непрерывная кривая через все точки, без остановок на них
local function CR( p0, p1, p2, p3, t )
	local t2, t3 = t * t, t * t * t
	return ( p1 * 2 + ( p2 - p0 ) * t
		+ ( p0 * 2 - p1 * 5 + p2 * 4 - p3 ) * t2
		+ ( p1 * 3 - p0 - p2 * 3 + p3 ) * t3 ) * 0.5
end

local function PathView()
	local path = NWORK.CamPath or T.CameraPaths[ game.GetMap() ]
	if not path or #path == 0 then return end

	local n   = #path
	local seg = O.Get( "menu_cam" )

	if n == 1 then
		return path[ 1 ].pos, path[ 1 ].ang
	end

	-- две точки: мягкое косинусное качание туда-обратно
	if n == 2 then
		local f = 0.5 - 0.5 * math.cos( CurTime() / seg * math.pi )
		return LerpVector( f, path[ 1 ].pos, path[ 2 ].pos ),
			LerpAngle( f, path[ 1 ].ang, path[ 2 ].ang )
	end

	-- 3+ точек: замкнутая петля по сплайну, скорость не падает в узлах
	local tt = ( CurTime() / seg ) % n
	local i  = math.floor( tt )
	local f  = tt - i

	local function P( j ) return path[ ( j % n ) + 1 ] end
	local a, b, c, d = P( i - 1 ), P( i ), P( i + 1 ), P( i + 2 )

	local pos = CR( a.pos, b.pos, c.pos, d.pos, f )

	-- углы через направляющие векторы — без скачков на 360°
	local fwd = CR( a.ang:Forward(), b.ang:Forward(), c.ang:Forward(), d.ang:Forward(), f )
	return pos, fwd:Angle()
end

hook.Add( "CalcView", "Nwork.MenuCamera", function( ply, origin, angles, fov )
	if not UI.Active() then return end

	local pos, ang = PathView()
	if not pos then return end

	return {
		origin     = pos,
		angles     = ang,
		fov        = fov,
		drawviewer = true,
	}
end )

---------------------------------------------------------------------- кнопки

-- Кнопка в стиле референса: тёмная плашка, блик, тонкий контур при
-- наводке и яркий тонкий контур в момент нажатия.
function UI.Button( parent, label )
	local btn = vgui.Create( "DButton", parent )
	btn:SetText( "" )
	btn.Label = label

	btn.Paint = function( s, w, h )
		local hov  = s:IsHovered()
		local down = s:IsDown()

		surface.SetDrawColor( T.Colors.BtnBase )
		surface.DrawRect( 0, 0, w, h )

		surface.SetMaterial( matGrad )
		surface.SetDrawColor( hov and T.Colors.BtnSheenHov or T.Colors.BtnSheen )
		surface.DrawTexturedRect( 0, 0, w, math.floor( h * 0.55 ) )

		if down then
			surface.SetDrawColor( T.Colors.BtnOutlineDn )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
		elseif hov then
			surface.SetDrawColor( T.Colors.BtnOutline )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
		end

		draw.SimpleText( s.Label, "Nwork.Button", w / 2, h / 2,
			hov and T.Colors.Text or Color( 222, 226, 230 ),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	return btn
end

------------------------------------------------------- подложка всех экранов

local PANEL = {}

function PANEL:Init()
	self:SetSize( ScrW(), ScrH() )
	self:SetPos( 0, 0 )
	self:MakePopup()
	self:SetKeyboardInputEnabled( false )

	self:SetAlpha( 0 )
	self:AlphaTo( 255, T.Menu.FadeIn, 0 )

	UI.Track( self )
end

function PANEL:Close( callback )
	if self.Closing then return end
	self.Closing = true

	self:AlphaTo( 0, T.Menu.FadeOut, 0, function()
		if IsValid( self ) then self:Remove() end
		if callback then callback() end
	end )
end

-- иконку можно приглушить на конкретном экране
function PANEL:SetIconAlphaMul( m ) self.IconMul = m end

function PANEL:Paint( w, h )
	UI.DrawBlur( self, O.Get( "menu_blur" ) )

	surface.SetDrawColor( T.Colors.Overlay )
	surface.DrawRect( 0, 0, w, h )

	local icon = GetIcon()
	if icon then
		local size = math.floor( h * T.Menu.IconScale )
		surface.SetMaterial( icon )
		surface.SetDrawColor( 255, 255, 255, T.Menu.IconAlpha * ( self.IconMul or 1 ) )
		surface.DrawTexturedRect( ( w - size ) / 2, h * 0.5 - size / 2, size, size )
	end
end

vgui.Register( "NworkScreen", PANEL, "EditablePanel" )

---------------------------------------------------------- помощники отрисовки

local matWordmark

function UI.WordmarkMat()
	if matWordmark == nil then
		local m = Material( T.Watermark.Mat or "", "smooth mips" )
		matWordmark = ( m and not m:IsError() ) and m or false
	end
	return matWordmark or nil
end

-- Логотип-надпись. alignX: 0 — левый край, 0.5 — центр, 1 — правый край.
-- Возвращает высоту (0, если материала нет).
function UI.Wordmark( x, y, w, alpha, alignX )
	local m = UI.WordmarkMat()
	if not m then return 0 end

	local h = math.floor( w * m:Height() / math.max( 1, m:Width() ) )
	surface.SetMaterial( m )
	surface.SetDrawColor( 255, 255, 255, alpha or 255 )
	surface.DrawTexturedRect( x - w * ( alignX or 0 ), y, w, h )
	return h
end

-- уголок-треугольник в правом нижнем углу ячейки (как в Monarch)
function UI.Corner( x, y, w, h, col, size )
	size = size or math.max( 6, math.floor( math.min( w, h ) * 0.11 ) )
	draw.NoTexture()
	surface.SetDrawColor( col )
	surface.DrawPoly( {
		{ x = x + w - size, y = y + h },
		{ x = x + w,        y = y + h - size },
		{ x = x + w,        y = y + h },
	} )
end

-- текст с мягкой тенью (HUD поверх мира)
function UI.ShadowText( text, font, x, y, col, ax, ay, salpha )
	local a = col.a or 255
	draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, ( salpha or 170 ) * a / 255 ), ax, ay )
	return draw.SimpleText( text, font, x, y, col, ax, ay )
end

-- закрыть все экраны N-work
function UI.CloseAll()
	for pnl in pairs( UI.Open ) do
		if IsValid( pnl ) and pnl.Close then pnl:Close() end
	end
end
