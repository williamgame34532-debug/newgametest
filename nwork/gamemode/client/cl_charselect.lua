--[[-------------------------------------------------------------------------
	N-work — выбор персонажа, стиль референса.

	Тёмный фон, крупный бюст персонажа по центру, снизу чёрная плашка:
	ИМЯ курсивным капсом, фракция под ним, слева «НАЗАД», справа
	«НАЧАТЬ». Если персонажей несколько — стрелки ‹ › листают.
	«Удалить персонажа» — ссылка в углу плашки, с подтверждением.
---------------------------------------------------------------------------]]

local T = NWORK.Theme

local PANEL = {}

function PANEL:Init()
	self.BaseClass.Init( self )
	self:SetIconAlphaMul( 0.35 )

	self.Idx = 1
	self:Build()
end

function PANEL:Build()
	if self.Kids then
		for _, p in ipairs( self.Kids ) do if IsValid( p ) then p:Remove() end end
	end
	self.Kids = {}

	local w, h = ScrW(), ScrH()
	local k    = h / 1080

	local list = NWORK.Chars
	self.Idx = math.Clamp( self.Idx, 1, math.max( #list, 1 ) )
	local char = list[ self.Idx ]

	if not char then
		self:Close( function() NWORK.OpenCharCreate() end )
		return
	end

	-- бюст по центру
	local mdl = vgui.Create( "DModelPanel", self )
	mdl:SetSize( math.floor( w * 0.5 ), math.floor( h * 0.72 ) )
	mdl:SetPos( math.floor( w * 0.25 ), math.floor( h * 0.02 ) )
	mdl:SetFOV( 24 )
	mdl:SetModel( char.model )
	mdl.LayoutEntity = function( s, ent )
		ent:SetAngles( Angle( 0, 8, 0 ) )
		s:RunAnimation()
	end

	local ent = mdl:GetEntity()
	if IsValid( ent ) then
		ent:SetSkin( char.skin or 0 )
		local head = ent:LookupBone( "ValveBiped.Bip01_Head1" )
		local pos  = head and ent:GetBonePosition( head ) or ( ent:GetPos() + ent:OBBCenter() )
		mdl:SetCamPos( pos + Vector( 66, 0, -12 ) )
		mdl:SetLookAt( pos + Vector( 0, 0, -18 ) )
	end
	table.insert( self.Kids, mdl )

	-- нижняя плашка
	local pw, ph = math.floor( w * 0.42 ), math.floor( h * 0.22 )
	local px, py = math.floor( ( w - pw ) / 2 ), math.floor( h * 0.70 )

	local plate = vgui.Create( "DPanel", self )
	plate:SetPos( px, py )
	plate:SetSize( pw, ph )
	plate.Paint = function( _, ww, hh )
		draw.RoundedBox( 4, 0, 0, ww, hh, Color( 11, 11, 13, 242 ) )
		surface.SetDrawColor( 255, 255, 255, 16 )
		surface.DrawOutlinedRect( 0, 0, ww, hh, 1 )

		local fac = NWORK.Factions[ char.faction ]

		draw.SimpleText( string.upper( char.name ), "Nwork.InvName", ww / 2, math.floor( 22 * k ),
			Color( 240, 243, 247 ), TEXT_ALIGN_CENTER )
		draw.SimpleText( string.upper( fac and fac.Name or char.faction ), "Nwork.Small",
			ww / 2, math.floor( 64 * k ), Color( 196, 202, 210 ), TEXT_ALIGN_CENTER )

		if #list > 1 then
			draw.SimpleText( ( "%d / %d" ):format( self.Idx, #list ), "Nwork.Tiny",
				ww / 2, hh - math.floor( 14 * k ), Color( 150, 156, 164 ),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
		end
	end
	table.insert( self.Kids, plate )

	-- НАЗАД / НАЧАТЬ
	local bw, bh = math.floor( 240 * k ), math.floor( 40 * k )

	local back = NWORK.UI.Button( plate, "НАЗАД" )
	back:SetSize( bw, bh )
	back:SetPos( math.floor( 12 * k ), ph - bh - math.floor( 12 * k ) )
	back.DoClick = function()
		surface.PlaySound( "ui/buttonclick.wav" )
		self:Close( function() NWORK.OpenMainMenu() end )
	end

	local begin = NWORK.UI.Button( plate, "НАЧАТЬ" )
	begin:SetSize( bw, bh )
	begin:SetPos( pw - bw - math.floor( 12 * k ), ph - bh - math.floor( 12 * k ) )
	begin.DoClick = function()
		surface.PlaySound( "buttons/lightswitch2.wav" )
		net.Start( "nwork_select" )
			net.WriteUInt( char.id, 32 )
		net.SendToServer()
	end

	-- удалить (ссылка с подтверждением)
	local del = vgui.Create( "DButton", plate )
	del:SetText( "" )
	del:SetSize( math.floor( 200 * k ), math.floor( 22 * k ) )
	del:SetPos( pw - del:GetWide() - math.floor( 12 * k ), math.floor( 8 * k ) )
	del.Label = "Удалить персонажа"
	del.Paint = function( s, ww, hh )
		draw.SimpleText( s.Label, "Nwork.Tiny", ww, hh / 2,
			s:IsHovered() and Color( 214, 120, 110 ) or Color( 160, 166, 174, 170 ),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end
	del.DoClick = function( s )
		if not s.Armed then
			s.Armed = true
			s.Label = "Точно удалить?"
			timer.Simple( 3, function()
				if IsValid( s ) then s.Armed = nil s.Label = "Удалить персонажа" end
			end )
			return
		end

		surface.PlaySound( "buttons/button10.wav" )
		net.Start( "nwork_delete" )
			net.WriteUInt( char.id, 32 )
		net.SendToServer()
	end

	-- стрелки листания
	if #list > 1 then
		local function Arrow( sym, x, dir )
			local a = vgui.Create( "DButton", self )
			a:SetText( "" )
			a:SetSize( math.floor( 60 * k ), math.floor( 90 * k ) )
			a:SetPos( x, math.floor( h * 0.42 ) )
			a.Paint = function( s, ww, hh )
				draw.SimpleText( sym, "Nwork.Ghost", ww / 2, hh / 2,
					Color( 235, 238, 242, s:IsHovered() and 235 or 110 ),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			end
			a.DoClick = function()
				surface.PlaySound( "ui/buttonclick.wav" )
				self.Idx = ( ( self.Idx - 1 + dir ) % #list ) + 1
				self:Build()
			end
			table.insert( self.Kids, a )
		end

		Arrow( "‹", math.floor( w * 0.16 ), -1 )
		Arrow( "›", math.floor( w * 0.80 ), 1 )
	end
end

vgui.Register( "NworkCharSelect", PANEL, "NworkScreen" )

local SELECT

function NWORK.OpenCharSelect()
	if IsValid( SELECT ) then SELECT:Remove() end
	SELECT = vgui.Create( "NworkCharSelect" )
	return SELECT
end

hook.Add( "NworkCharsUpdated", "Nwork.RefreshSelect", function()
	if IsValid( SELECT ) and not SELECT.Closing then
		SELECT:Build()
	end
end )
