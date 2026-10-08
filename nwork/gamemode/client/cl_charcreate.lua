--[[-------------------------------------------------------------------------
	N-work — создание персонажа.

	Слева — превью модели (бюст), справа — имя, правила, пол, ряд моделей
	фракции («Внешность»), ряд скинов («Вариации лица»), описание и кнопка
	создания. Создание идёт во фракции NWORK.Config.CreateFaction.
---------------------------------------------------------------------------]]

local T = NWORK.Theme
local C = NWORK.Config

--------------------------------------------------------- кэш количества скинов

local skinCount = {}

local function GetSkinCount( mdl )
	if skinCount[ mdl ] then return skinCount[ mdl ] end

	local ent = ClientsideModel( mdl, RENDERGROUP_OTHER )
	local n = 1
	if IsValid( ent ) then
		n = math.max( ent:SkinCount() or 1, 1 )
		ent:Remove()
	end

	skinCount[ mdl ] = n
	return n
end

------------------------------------------------------------------- помощники

local function Label( parent, text, font, col )
	local l = vgui.Create( "DLabel", parent )
	l:SetFont( font or "Nwork.Label" )
	l:SetTextColor( col or T.Colors.Text )
	l:SetText( text )
	l:SizeToContents()
	return l
end

local function DarkEntry( parent, multiline )
	local e = vgui.Create( "DTextEntry", parent )
	e:SetFont( "Nwork.Input" )
	e:SetMultiline( multiline or false )
	e:SetUpdateOnType( true )
	e:SetDrawLanguageID( false )
	e.Paint = function( s, w, h )
		surface.SetDrawColor( T.Colors.Panel )
		surface.DrawRect( 0, 0, w, h )

		surface.SetDrawColor( 255, 255, 255, s:HasFocus() and 40 or 16 )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )

		s:DrawTextEntryText( T.Colors.Text, T.Colors.TextDim, T.Colors.Text )
	end
	return e
end

--------------------------------------------------------------------- панель

local PANEL = {}

function PANEL:Init()
	self.BaseClass.Init( self )
	self:SetKeyboardInputEnabled( true ) -- нужен ввод текста
	self:SetIconAlphaMul( 0.6 )

	local w, h = ScrW(), ScrH()
	local k    = h / 1080

	self.Gender = "male"
	self.Model  = nil
	self.Skin   = 0

	local rx = math.floor( w * 0.40 )     -- левый край правой колонки
	local rw = math.floor( w * 0.55 )
	local y  = math.floor( h * 0.185 )

	----------------------------------------------------------------- превью

	local preview = vgui.Create( "DModelPanel", self )
	preview:SetPos( math.floor( w * 0.02 ), 0 )
	preview:SetSize( math.floor( w * 0.34 ), h )
	preview:SetFOV( 28 )
	preview.LayoutEntity = function( s, ent )
		ent:SetAngles( Angle( 0, 35, 0 ) )
		s:RunAnimation()
	end
	self.Preview = preview

	------------------------------------------------------------------- имя

	Label( self, "ПОЛНОЕ ИМЯ" ):SetPos( rx, y )
	y = y + math.floor( 36 * k )

	local name = DarkEntry( self )
	name:SetParent( self )
	name:SetPos( rx, y )
	name:SetSize( rw, math.floor( 42 * k ) )
	name:SetPlaceholderText( "Имя Фамилия" )
	self.NameEntry = name
	y = y + math.floor( 52 * k )

	local rules = {
		"Это ваш ЕДИНСТВЕННЫЙ персонаж. Придерживайтесь правил ниже:",
		"  •  Имя должно быть реалистичным и соответствовать сеттингу Half-Life.",
		"  •  Имя не должно быть шуточным или отсылать к известным личностям.",
		"  •  Если используете голосовой чат — внешность должна соответствовать голосу.",
	}
	for i, line in ipairs( rules ) do
		local l = Label( self, line, "Nwork.Rules", i == 1 and T.Colors.Text or T.Colors.TextDim )
		l:SetPos( rx, y )
		y = y + math.floor( 19 * k )
	end
	y = y + math.floor( 22 * k )

	------------------------------------------------------------------- пол

	Label( self, "ПОЛ" ):SetPos( rx, y )
	y = y + math.floor( 40 * k )

	local gsize = math.floor( 46 * k )
	self.GenderBtns = {}

	local function GenderBtn( sym, gender, x )
		local b = vgui.Create( "DButton", self )
		b:SetPos( x, y )
		b:SetSize( gsize, gsize )
		b:SetText( "" )
		b.Paint = function( s, bw, bh )
			local active = self.Gender == gender
			draw.SimpleText( sym, "Nwork.Gender", bw / 2, bh / 2,
				active and T.Colors.Text or T.Colors.TextDim,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			if s:IsDown() then
				surface.SetDrawColor( T.Colors.BtnOutlineDn )
				surface.DrawOutlinedRect( 0, 0, bw, bh, 1 )
			end
		end
		b.DoClick = function()
			if self.Gender == gender then return end
			self.Gender = gender
			surface.PlaySound( "ui/buttonclick.wav" )
			self:RebuildAppearance()
		end
		self.GenderBtns[ gender ] = b
	end

	GenderBtn( "♂", "male",   rx )
	GenderBtn( "♀", "female", rx + gsize + math.floor( 14 * k ) )
	y = y + gsize + math.floor( 28 * k )

	------------------------------------------------------------- внешность

	Label( self, "ВНЕШНОСТЬ" ):SetPos( rx, y )
	y = y + math.floor( 38 * k )

	self.AppearY = y
	self.Thumb   = math.floor( 86 * k )
	self.ThumbGap= math.floor( 8 * k )
	y = y + self.Thumb + math.floor( 30 * k )

	------------------------------------------------------- вариации (скины)

	Label( self, "ВАРИАЦИИ ЛИЦА" ):SetPos( rx, y )
	y = y + math.floor( 38 * k )

	self.SkinsY = y
	y = y + self.Thumb + math.floor( 30 * k )

	-------------------------------------------------------------- описание

	Label( self, "ОПИСАНИЕ" ):SetPos( rx, y )
	y = y + math.floor( 36 * k )

	local desc = DarkEntry( self, true )
	desc:SetPos( rx, y )
	desc:SetSize( rw, math.floor( 96 * k ) )
	desc:SetPlaceholderText( "Кем был ваш персонаж до этого дня..." )
	self.DescEntry = desc
	y = y + math.floor( 96 * k ) + math.floor( 26 * k )

	--------------------------------------------------------------- создать

	local bw, bh = math.floor( 240 * k ), math.floor( 36 * k )
	local create = NWORK.UI.Button( self, "СОЗДАТЬ ПЕРСОНАЖА" )
	create:SetPos( rx, y )
	create:SetSize( bw, bh )
	create.DoClick = function() self:TryCreate() end

	self.RowX, self.RowW = rx, rw
	self.AppearIcons = {}
	self.SkinIcons   = {}

	self:RebuildAppearance()
end

--------------------------------------------------------------- ряды миниатюр

local function ThumbPaintOver( s, w, h )
	if s.Selected then
		surface.SetDrawColor( T.Colors.Select )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
	elseif s:IsHovered() then
		surface.SetDrawColor( T.Colors.BtnOutline )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
	end
end

function PANEL:RebuildAppearance()
	for _, p in ipairs( self.AppearIcons ) do p:Remove() end
	self.AppearIcons = {}

	local models = NWORK.Factions[ C.CreateFaction ].Models[ self.Gender ] or {}
	local x = self.RowX

	for i, mdl in ipairs( models ) do
		local ic = vgui.Create( "ModelImage", self )
		ic:SetPos( x, self.AppearY )
		ic:SetSize( self.Thumb, self.Thumb )
		ic:SetModel( mdl )
		ic:SetMouseInputEnabled( true )
		ic:SetCursor( "hand" )
		ic.PaintOver = ThumbPaintOver
		ic.OnMousePressed = function()
			surface.PlaySound( "ui/buttonclick.wav" )
			self:SelectModel( mdl )
		end

		self.AppearIcons[ i ] = ic
		ic.NworkModel = mdl

		x = x + self.Thumb + self.ThumbGap
	end

	self:SelectModel( models[ 1 ] )
end

function PANEL:SelectModel( mdl )
	if not mdl then return end
	self.Model = mdl
	self.Skin  = 0

	for _, ic in ipairs( self.AppearIcons ) do
		ic.Selected = ic.NworkModel == mdl
	end

	self:RebuildSkins()
	self:UpdatePreview()
end

function PANEL:RebuildSkins()
	for _, p in ipairs( self.SkinIcons ) do p:Remove() end
	self.SkinIcons = {}

	local n = GetSkinCount( self.Model )
	local x = self.RowX

	for skin = 0, n - 1 do
		local ic = vgui.Create( "ModelImage", self )
		ic:SetPos( x, self.SkinsY )
		ic:SetSize( self.Thumb, self.Thumb )
		ic:SetModel( self.Model, skin )
		ic:SetMouseInputEnabled( true )
		ic:SetCursor( "hand" )
		ic.Selected = skin == self.Skin
		ic.PaintOver = ThumbPaintOver
		ic.OnMousePressed = function()
			surface.PlaySound( "ui/buttonclick.wav" )
			self.Skin = skin
			for _, o in ipairs( self.SkinIcons ) do o.Selected = o.NworkSkin == skin end
			self:UpdatePreview()
		end

		ic.NworkSkin = skin
		table.insert( self.SkinIcons, ic )

		x = x + self.Thumb + self.ThumbGap
	end
end

--------------------------------------------------------------------- превью

function PANEL:UpdatePreview()
	local pv = self.Preview
	pv:SetModel( self.Model )

	local ent = pv:GetEntity()
	if not IsValid( ent ) then return end

	ent:SetSkin( self.Skin )

	-- бюст: целимся в голову
	local head = ent:LookupBone( "ValveBiped.Bip01_Head1" )
	local pos  = head and ent:GetBonePosition( head ) or ( ent:GetPos() + ent:OBBCenter() )

	pv:SetCamPos( pos + Vector( 52, 14, -4 ) )
	pv:SetLookAt( pos + Vector( 0, 0, -12 ) )
end

-------------------------------------------------------------------- создание

function PANEL:TryCreate()
	local name  = string.Trim( self.NameEntry:GetValue() or "" )
	local descr = string.Trim( self.DescEntry:GetValue() or "" )

	local nlen = utf8.len( name ) or #name
	if nlen < C.MinName then
		notification.AddLegacy( ( "Имя слишком короткое (минимум %d)." ):format( C.MinName ), NOTIFY_ERROR, 4 )
		return
	end

	local dlen = utf8.len( descr ) or #descr
	if dlen < C.MinDesc then
		notification.AddLegacy( ( "Описание слишком короткое (минимум %d)." ):format( C.MinDesc ), NOTIFY_ERROR, 4 )
		return
	end

	if not self.Model then return end

	surface.PlaySound( "buttons/lightswitch2.wav" )

	net.Start( "nwork_create" )
		net.WriteString( name )
		net.WriteString( descr )
		net.WriteString( self.Model )
		net.WriteUInt( self.Skin, 8 )
	net.SendToServer()
end

--------------------------------------------------------------- фон и заголовок

function PANEL:Paint( w, h )
	self.BaseClass.Paint( self, w, h )

	draw.SimpleText( "СОЗДАНИЕ ПЕРСОНАЖА", "Nwork.Ghost",
		math.floor( w * 0.04 ), math.floor( h * 0.06 ),
		T.Colors.TextFaded, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
end

vgui.Register( "NworkCharCreate", PANEL, "NworkScreen" )

function NWORK.OpenCharCreate()
	return vgui.Create( "NworkCharCreate" )
end
