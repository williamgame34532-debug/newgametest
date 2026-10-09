--[[-------------------------------------------------------------------------
	N-work — меню персонажа (Tab) в стиле Monarch / Project Suppressed.

	Слева: иконка одежды, имя и фракция; крупная модель; слоты
	экипировки; «Состояние» — значки эффектов и полосы здоровья, сытости,
	жажды и бодрости; снизу — хотбар с оружием. Справа — колонка
	квадратных кнопок-вкладок и «ЗАКРЫТЬ X». Снизу по центру — логотип.

	Вкладки — реестр, модули добавляют свои:
		NWORK.UI.AddPage( "id", {
			Title = "ИНВЕНТАРЬ", Sub = "Подзаголовок", Glyph = "backpack",
			Order = 10, Group = "top" | "bottom", Admin = false,
			Build = function( page, menu ) ... end,   -- page — DPanel области
		} )

	Tab — открыть/закрыть, F1 — сразу «Помощь».
---------------------------------------------------------------------------]]

local T  = NWORK.Theme
local UI = NWORK.UI
local O  = NWORK.Option
local TC = T.Colors

local WHITE = Color( 240, 243, 247 )
local DIM   = Color( 196, 202, 210 )

UI.Pages = UI.Pages or {}

function UI.AddPage( id, def )
	def.id    = id
	def.Order = def.Order or 50
	def.Group = def.Group or "top"
	UI.Pages[ id ] = def
end

local TAB

function NWORK.TabOpen()
	return IsValid( TAB ) and not TAB.Closing
end

-------------------------------------------------------------- виджеты страниц

-- масштаб: размеры из референса 2000x1125
local function Sc() return ScrH() / 1125 end

-- заголовок вкладки: глиф + КАПС, центр по cx; подзаголовок под ним слева от x0
function UI.PageHeader( title, glyph, cx, y, sub, subX )
	local S = Sc()
	surface.SetFont( "Nwork.TabTitle" )
	local tw = surface.GetTextSize( title )
	local gs = math.floor( 36 * S )
	local x  = math.floor( cx - ( gs + 10 * S + tw ) / 2 )

	NWORK.Glyph( glyph, x, y, gs, WHITE, Color( 18, 20, 23 ) )
	draw.SimpleText( title, "Nwork.TabTitle", x + gs + math.floor( 10 * S ), y + gs / 2, WHITE,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

	if sub then
		draw.SimpleText( sub, "Nwork.TabSub", subX or x, y + gs + math.floor( 14 * S ),
			Color( 200, 204, 210 ) )
	end
end

-- строка-действие: тёмная плашка, цветная полоска слева, КАПС + описание
function UI.ActionRow( parent, x, y, w, title, desc, color, onClick )
	local S = Sc()
	local b = vgui.Create( "DButton", parent )
	b:SetText( "" )
	b:SetPos( x, y )
	b:SetSize( w, math.floor( 56 * S ) )
	b.Paint = function( s, ww, hh )
		surface.SetDrawColor( s:IsHovered() and onClick and TC.RowHover or TC.Row )
		surface.DrawRect( 0, 0, ww, hh )
		surface.SetDrawColor( color or Color( 120, 124, 130 ) )
		surface.DrawRect( 0, 0, math.max( 2, math.floor( 3 * S ) ), hh )

		draw.SimpleText( NWORK.Util.Upper( title ), "Nwork.RowTitle",
			math.floor( 12 * S ), math.floor( 9 * S ), WHITE )
		if desc then
			draw.SimpleText( desc, "Nwork.RowDesc", math.floor( 12 * S ), math.floor( 33 * S ), DIM )
		end
	end
	b.DoClick = function()
		if not onClick then return end
		surface.PlaySound( "ui/buttonclick.wav" )
		onClick( b )
	end
	if not onClick then b:SetCursor( "arrow" ) end
	return b
end

function UI.SectionHead( text, x, y )
	draw.SimpleText( text, "Nwork.TabHead", x, y, WHITE )
end

-- текст с переносом строк в заданную ширину, возвращает высоту
function UI.WrapText( text, font, x, y, w, col, lineH )
	surface.SetFont( font )
	local _, fh = surface.GetTextSize( "Ау" )
	lineH = lineH or fh + 2

	local line, yy = "", y
	for word in string.gmatch( text, "%S+" ) do
		local try = line == "" and word or ( line .. " " .. word )
		if surface.GetTextSize( try ) > w and line ~= "" then
			draw.SimpleText( line, font, x, yy, col )
			yy, line = yy + lineH, word
		else
			line = try
		end
	end
	if line ~= "" then
		draw.SimpleText( line, font, x, yy, col )
		yy = yy + lineH
	end
	return yy - y
end

-- модальный ввод текста в стиле меню
function UI.TextPrompt( title, default, multiline, callback )
	local S = Sc()
	local bg = vgui.Create( "EditablePanel" )
	bg:SetSize( ScrW(), ScrH() )
	bg:MakePopup()
	bg.Paint = function( _, w, h )
		surface.SetDrawColor( 0, 0, 0, 170 )
		surface.DrawRect( 0, 0, w, h )
	end

	local pw, ph = math.floor( 640 * S ), math.floor( ( multiline and 300 or 170 ) * S )
	local box = vgui.Create( "DPanel", bg )
	box:SetSize( pw, ph )
	box:Center()
	box.Paint = function( _, w, h )
		surface.SetDrawColor( 22, 24, 27, 245 )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( 255, 255, 255, 20 )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
		draw.SimpleText( title, "Nwork.RowTitle", math.floor( 16 * S ), math.floor( 14 * S ), WHITE )
	end

	local e = vgui.Create( "DTextEntry", box )
	e:SetPos( math.floor( 16 * S ), math.floor( 42 * S ) )
	e:SetSize( pw - math.floor( 32 * S ), ph - math.floor( 108 * S ) )
	e:SetMultiline( multiline or false )
	e:SetFont( "Nwork.TabText" )
	e:SetText( default or "" )
	e:SetDrawLanguageID( false )
	e.Paint = function( s, w, h )
		surface.SetDrawColor( 10, 11, 12, 240 )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( 255, 255, 255, s:HasFocus() and 34 or 16 )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
		s:DrawTextEntryText( WHITE, Color( 120, 126, 132 ), WHITE )
	end
	e:RequestFocus()

	local function Btn( label, x, fn )
		local b = UI.Button( box, label )
		b:SetSize( math.floor( 180 * S ), math.floor( 36 * S ) )
		b:SetPos( x, ph - math.floor( 52 * S ) )
		b.DoClick = fn
	end

	Btn( "ОТМЕНА", math.floor( 16 * S ), function() bg:Remove() end )
	Btn( "СОХРАНИТЬ", pw - math.floor( 196 * S ), function()
		local v = e:GetValue()
		bg:Remove()
		callback( v )
	end )

	bg.Think = function()
		if input.IsKeyDown( KEY_ESCAPE ) then bg:Remove() end
	end
end

------------------------------------------------------------------- панель

local PANEL = {}

function PANEL:Init()
	local w, h = ScrW(), ScrH()
	local S = Sc()
	self.S = S

	self:SetSize( w, h )
	self:MakePopup()
	self:SetKeyboardInputEnabled( false )
	self:SetAlpha( 0 )
	self:AlphaTo( 255, 0.16, 0 )

	-- модель персонажа крупно
	local lp  = LocalPlayer()
	local mdl = vgui.Create( "DModelPanel", self )
	mdl:SetPos( 0, 0 )
	mdl:SetSize( math.floor( 680 * S ), h )
	mdl:SetFOV( 30 )
	mdl:SetModel( lp:GetModel() )
	mdl:SetMouseInputEnabled( false )
	mdl.LayoutEntity = function( s, ent )
		ent:SetAngles( Angle( 0, 28, 0 ) )
		s:RunAnimation()
	end

	local ent = mdl:GetEntity()
	if IsValid( ent ) then
		ent:SetSkin( lp:GetSkin() or 0 )
		for i = 0, lp:GetNumBodyGroups() - 1 do ent:SetBodygroup( i, lp:GetBodygroup( i ) ) end
		local head = ent:LookupBone( "ValveBiped.Bip01_Head1" )
		local pos  = head and ent:GetBonePosition( head ) or ( ent:GetPos() + ent:OBBCenter() )
		mdl:SetCamPos( pos + Vector( 56, 10, -14 ) )
		mdl:SetLookAt( pos + Vector( 0, 0, -22 ) )
	end
	self.Model = mdl

	self:BuildHotbar()
	self:BuildNav()

	-- ЗАКРЫТЬ X
	local close = vgui.Create( "DButton", self )
	close:SetText( "" )
	close:SetSize( math.floor( 90 * S ), math.floor( 34 * S ) )
	close:SetPos( w - close:GetWide() - math.floor( 18 * S ), math.floor( 16 * S ) )
	close.Paint = function( s, bw, bh )
		local a = s:IsHovered() and 255 or 200
		draw.SimpleText( "X", "Nwork.CloseX", bw, bh / 2, Color( 240, 243, 247, a ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		draw.SimpleText( "ЗАКРЫТЬ", "Nwork.CloseSmall", bw - math.floor( 24 * S ), bh / 2 + 1,
			Color( 220, 224, 230, a ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end
	close.DoClick = function() self:Close() end

	self.Page = "inv"
end

function PANEL:Close()
	if self.Closing then return end
	self.Closing = true
	self:AlphaTo( 0, 0.12, 0, function()
		if IsValid( self ) then self:Remove() end
	end )
end

function PANEL:Think()
	if input.IsKeyDown( KEY_ESCAPE ) then
		self:Close()
		gui.HideGameUI()
	end
end

------------------------------------------------------------------- хотбар

function PANEL:BuildHotbar()
	local S    = self.S
	local cell = math.floor( 85 * S )
	local step = math.floor( 91 * S )
	local x0   = math.floor( 22 * S )
	local y    = ScrH() - cell - math.floor( 16 * S )

	local weps = LocalPlayer():GetWeapons()
	table.sort( weps, function( a, b )
		if a:GetSlot() ~= b:GetSlot() then return a:GetSlot() < b:GetSlot() end
		return a:GetSlotPos() < b:GetSlotPos()
	end )

	for i = 1, 7 do
		local wep = weps[ i ]
		local b = vgui.Create( "DButton", self )
		b:SetText( "" )
		b:SetPos( x0 + ( i - 1 ) * step, y )
		b:SetSize( cell, cell )
		b.Paint = function( s, ww, hh )
			surface.SetDrawColor( s:IsHovered() and IsValid( wep ) and TC.CellHover or TC.Cell )
			surface.DrawRect( 0, 0, ww, hh )

			if IsValid( wep ) then
				local name = language.GetPhrase( wep:GetPrintName() or wep:GetClass() )
				local active = LocalPlayer():GetActiveWeapon() == wep
				draw.SimpleText( i, "Nwork.Cell", math.floor( 6 * S ), math.floor( 4 * S ), Color( 220, 224, 230 ) )
				UI.WrapText( name, "Nwork.RowDesc", math.floor( 6 * S ), hh * 0.45, ww - math.floor( 10 * S ),
					Color( 230, 234, 238, active and 255 or 180 ) )
				UI.Corner( 0, 0, ww, hh, active and TC.Accent or Color( 255, 255, 255, 50 ) )
			else
				UI.Corner( 0, 0, ww, hh, Color( 255, 255, 255, 30 ) )
			end
		end
		b.DoClick = function()
			if not IsValid( wep ) then return end
			input.SelectWeapon( wep )
			surface.PlaySound( "common/wpn_select.wav" )
			self:Close()
		end
	end
end

---------------------------------------------------------------- навигация

local function SortedPages( group )
	local out = {}
	for _, p in pairs( UI.Pages ) do
		if p.Group == group and ( not p.Admin or LocalPlayer():IsAdmin() ) then out[ #out + 1 ] = p end
	end
	table.sort( out, function( a, b ) return a.Order < b.Order end )
	return out
end

function PANEL:NavButton( p, x, y, s )
	local S = self.S
	local b = vgui.Create( "DButton", self )
	b:SetText( "" )
	b:SetPos( x, y )
	b:SetSize( s, s )
	b.Paint = function( bs, ww, hh )
		local active = self.Page == p.id

		surface.SetDrawColor( 22, 24, 27, active and 235 or 190 )
		surface.DrawRect( 0, 0, ww, hh )
		surface.SetDrawColor( 255, 255, 255, active and 70 or ( bs:IsHovered() and 45 or 16 ) )
		surface.DrawOutlinedRect( 0, 0, ww, hh, 1 )

		NWORK.Glyph( p.Glyph, ww * 0.16, hh * 0.16, ww * 0.68,
			Color( 240, 243, 247, active and 255 or 215 ), Color( 22, 24, 27 ) )
		UI.Corner( 0, 0, ww, hh, Color( 255, 255, 255, active and 200 or 70 ), math.floor( 9 * S ) )

		if bs:IsHovered() then
			draw.SimpleText( p.Tip or p.Title, "Nwork.NavTip", -math.floor( 10 * S ), hh / 2,
				Color( 226, 231, 237, 230 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
	end
	b.DoClick = function()
		surface.PlaySound( "ui/buttonclick.wav" )
		self:SetPage( p.id )
	end
end

function PANEL:BuildNav()
	local S    = self.S
	local s    = math.floor( 72 * S )
	local step = math.floor( 79 * S )
	local x    = ScrW() - s - math.floor( 16 * S )

	local y = math.floor( 82 * S )
	for _, p in ipairs( SortedPages( "top" ) ) do
		self:NavButton( p, x, y, s )
		y = y + step
	end

	local bottom = SortedPages( "bottom" )
	y = ScrH() - math.floor( 20 * S ) - s - ( #bottom - 1 ) * step
	for _, p in ipairs( bottom ) do
		self:NavButton( p, x, y, s )
		y = y + step
	end
end

function PANEL:SetPage( id )
	if not UI.Pages[ id ] then id = "inv" end
	self.Page = id

	if IsValid( self.Content ) then self.Content:Remove() end

	local S = self.S
	local x = math.floor( ScrW() * 0.305 )
	local r = ScrW() - math.floor( 128 * S )

	local c = vgui.Create( "DPanel", self )
	c:SetPos( x, 0 )
	c:SetSize( r - x, ScrH() - math.floor( 150 * S ) )
	c:SetPaintBackground( false )
	c.S = S
	self.Content = c

	local p = UI.Pages[ id ]
	if p.Build then p.Build( c, self ) end
end

----------------------------------------------------------------- левая часть

local EQUIP_A = { "helmet", "gasmask", "shirt", "gloves", "pants", "boots" }
local EQUIP_B = { [ 2 ] = "glasses", [ 3 ] = "shield", [ 4 ] = "knife", [ 5 ] = "pistol", [ 6 ] = "rifle" }

-- полосы состояния: модули могут дополнить список хуком NworkTabStats
local function Stats()
	local lp = LocalPlayer()
	local hp = math.Clamp( lp:Health() / math.max( lp:GetMaxHealth(), 1 ), 0, 1 )

	local list = {
		{ label = hp > 0.75 and "Здоров" or ( hp > 0.35 and "Ранен" or "Тяжело ранен" ),
		  frac = hp, color = Color( 168, 72, 70 ) },
	}
	hook.Run( "NworkTabStats", list )
	return list
end

function PANEL:Paint( w, h )
	local S = self.S

	UI.DrawBlur( self, 3 )
	surface.SetDrawColor( 12, 14, 17, 205 )
	surface.DrawRect( 0, 0, w, h )

	-- шапка: иконка одежды, имя, фракция
	local lp  = LocalPlayer()
	local fac = lp:GetFactionTable()

	NWORK.Glyph( "jacket", math.floor( 24 * S ), math.floor( 10 * S ), math.floor( 44 * S ), WHITE )
	draw.SimpleText( lp:GetCharName(), "Nwork.TabName", math.floor( 81 * S ), math.floor( 6 * S ), WHITE )
	draw.SimpleText( fac and fac.Name or "", "Nwork.TabFaction", math.floor( 81 * S ), math.floor( 38 * S ),
		TC.Faction )

	-- логотип снизу по центру
	UI.Wordmark( w / 2, h - math.floor( 100 * S ), math.floor( 350 * S ), 210, 0.5 )
end

function PANEL:PaintOver( w, h )
	local S = self.S

	-- слоты экипировки (две колонки слева)
	local cell, step = math.floor( 85 * S ), math.floor( 90 * S )
	local ax, bx = math.floor( 22 * S ), math.floor( 113 * S )
	local y0 = math.floor( 484 * S )

	for i, g in ipairs( EQUIP_A ) do
		local y = y0 + ( i - 1 ) * step
		surface.SetDrawColor( TC.Cell )
		surface.DrawRect( ax, y, cell, cell )
		NWORK.Glyph( g, ax + cell * 0.22, y + cell * 0.22, cell * 0.56, Color( 220, 224, 230, 40 ) )
		UI.Corner( ax, y, cell, cell, Color( 255, 255, 255, 30 ) )

		if EQUIP_B[ i ] then
			surface.SetDrawColor( TC.Cell )
			surface.DrawRect( bx, y, cell, cell )
			NWORK.Glyph( EQUIP_B[ i ], bx + cell * 0.22, y + cell * 0.22, cell * 0.56, Color( 220, 224, 230, 40 ) )
			UI.Corner( bx, y, cell, cell, Color( 255, 255, 255, 30 ) )
		end
	end

	-- состояние: значки эффектов и полосы
	local sx = math.floor( 211 * S )
	local bw = math.floor( 440 * S )
	local stats = Stats()
	local by = h - math.floor( 140 * S ) - #stats * math.floor( 46 * S )

	local effects = {}
	hook.Run( "NworkTabEffects", effects )   -- { glyph = "food", tip = "Голод" }

	if #effects > 0 then
		draw.SimpleText( "Эффекты", "Nwork.Status", sx, by - math.floor( 72 * S ), WHITE )
		local es = math.floor( 28 * S )
		for i, e in ipairs( effects ) do
			local ex, ey = sx + ( i - 1 ) * ( es + math.floor( 8 * S ) ), by - math.floor( 46 * S )
			surface.SetDrawColor( 40, 43, 47, 200 )
			surface.DrawRect( ex, ey, es, es )
			surface.SetDrawColor( 255, 255, 255, 40 )
			surface.DrawOutlinedRect( ex, ey, es, es, 1 )
			NWORK.Glyph( e.glyph, ex + es * 0.15, ey + es * 0.15, es * 0.7, e.color or WHITE )
		end
	end

	for i, st in ipairs( stats ) do
		local y = by + ( i - 1 ) * math.floor( 46 * S )
		draw.SimpleText( st.label, "Nwork.BarLabel", sx, y, Color( 228, 232, 236 ) )

		local bh = math.max( 3, math.floor( 6 * S ) )
		surface.SetDrawColor( 70, 74, 79, 200 )
		surface.DrawRect( sx, y + math.floor( 21 * S ), bw, bh )
		surface.SetDrawColor( st.color )
		surface.DrawRect( sx, y + math.floor( 21 * S ), math.floor( bw * math.Clamp( st.frac, 0, 1 ) ), bh )
	end
end

vgui.Register( "NworkTabMenu", PANEL, "EditablePanel" )

------------------------------------------------------------------ открытие

function NWORK.OpenTab( page )
	if UI.Active() or not LocalPlayer():HasCharacter() then return end

	if not IsValid( TAB ) or TAB.Closing then
		TAB = vgui.Create( "NworkTabMenu" )
	end
	TAB:SetPage( page or TAB.Page or "inv" )
	return TAB
end

hook.Add( "ScoreboardShow", "Nwork.TabMenu", function()
	if UI.Active() then return true end

	if NWORK.TabOpen() then
		TAB:Close()
	else
		NWORK.OpenTab( "inv" )
	end
	return true
end )

hook.Add( "ScoreboardHide", "Nwork.TabMenu", function() return true end )

hook.Add( "PlayerBindPress", "Nwork.TabHelp", function( _, bind, pressed )
	if pressed and bind == "gm_showhelp" then
		NWORK.OpenTab( "help" )
		return true
	end
end )

-- обновить открытую вкладку при изменении данных
local function Refresh( page )
	if NWORK.TabOpen() and ( not page or TAB.Page == page ) then
		TAB:SetPage( TAB.Page )
	end
end
UI.RefreshTab = Refresh

hook.Add( "NworkInventoryUpdated", "Nwork.TabMenu", function() Refresh( "inv" ) end )
