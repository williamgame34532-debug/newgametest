--[[-------------------------------------------------------------------------
	N-work — радиальное меню (как колесо анимаций в Monarch).

	NWORK.UI.Radial( {
		{ Name = "Помахать", Run = function() ... end },
		...
	} )

	Тёмное полупрозрачное кольцо, подписи по кругу, тонкая линия от
	центра к курсору. Клик — выбрать, ПКМ/ESC — закрыть.
---------------------------------------------------------------------------]]

local UI = NWORK.UI

local RADIAL

local PANEL = {}

function PANEL:Init()
	self:SetSize( ScrW(), ScrH() )
	self:MakePopup()
	self:SetKeyboardInputEnabled( false )
	self:SetAlpha( 0 )
	self:AlphaTo( 255, 0.12, 0 )
	input.SetCursorPos( ScrW() / 2, ScrH() / 2 )
end

function PANEL:SetOptions( opts )
	self.Options = opts
end

local function Ring( cx, cy, r1, r2, col, seg )
	seg = seg or 64
	draw.NoTexture()
	surface.SetDrawColor( col )
	for i = 0, seg - 1 do
		local a1 = math.rad( i / seg * 360 )
		local a2 = math.rad( ( i + 1 ) / seg * 360 )
		surface.DrawPoly( {
			{ x = cx + math.cos( a1 ) * r2, y = cy + math.sin( a1 ) * r2 },
			{ x = cx + math.cos( a2 ) * r2, y = cy + math.sin( a2 ) * r2 },
			{ x = cx + math.cos( a2 ) * r1, y = cy + math.sin( a2 ) * r1 },
			{ x = cx + math.cos( a1 ) * r1, y = cy + math.sin( a1 ) * r1 },
		} )
	end
end

-- индекс опции под курсором (0 — в центре)
function PANEL:Hovered()
	local opts = self.Options or {}
	if #opts == 0 then return 0 end

	local mx, my = self:CursorPos()
	local dx, dy = mx - ScrW() / 2, my - ScrH() / 2
	if dx * dx + dy * dy < ( 40 * ScrH() / 1080 ) ^ 2 then return 0 end

	-- 0° — вверх, по часовой
	local ang = ( math.deg( math.atan2( dx, -dy ) ) + 360 ) % 360
	local step = 360 / #opts
	return math.floor( ( ang + step / 2 ) % 360 / step ) + 1
end

function PANEL:Paint( w, h )
	local k  = h / 1080
	local cx, cy = w / 2, h / 2
	local r2 = math.floor( 235 * k )
	local r1 = math.floor( 150 * k )

	Ring( cx, cy, r1, r2, Color( 30, 32, 36, 120 ) )

	local opts = self.Options or {}
	local hov  = self:Hovered()
	local step = 360 / math.max( #opts, 1 )

	for i, o in ipairs( opts ) do
		local a  = math.rad( ( i - 1 ) * step - 90 )
		local lr = math.floor( 200 * k )
		local x, y = cx + math.cos( a ) * lr, cy + math.sin( a ) * lr

		UI.ShadowText( o.Name, "Nwork.Radial", x, y,
			Color( 240, 243, 247, i == hov and 255 or 200 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	-- линия к курсору
	if hov > 0 then
		local mx, my = self:CursorPos()
		local dx, dy = mx - cx, my - cy
		local len = math.sqrt( dx * dx + dy * dy )
		local cl  = math.min( len, r2 - math.floor( 20 * k ) )

		surface.SetDrawColor( 240, 243, 247, 220 )
		surface.DrawLine( cx, cy, cx + dx / len * cl, cy + dy / len * cl )
	end
end

function PANEL:Think()
	if input.IsKeyDown( KEY_ESCAPE ) then self:Close() end
end

function PANEL:OnMousePressed( code )
	if code == MOUSE_LEFT then
		local o = self.Options and self.Options[ self:Hovered() ]
		if o and o.Run then
			surface.PlaySound( "ui/buttonclick.wav" )
			o.Run()
		end
	end
	self:Close()
end

function PANEL:Close()
	if self.Closing then return end
	self.Closing = true
	self:AlphaTo( 0, 0.1, 0, function()
		if IsValid( self ) then self:Remove() end
	end )
end

vgui.Register( "NworkRadial", PANEL, "EditablePanel" )

function UI.Radial( opts )
	if IsValid( RADIAL ) then RADIAL:Remove() end
	RADIAL = vgui.Create( "NworkRadial" )
	RADIAL:SetOptions( opts )
	return RADIAL
end
