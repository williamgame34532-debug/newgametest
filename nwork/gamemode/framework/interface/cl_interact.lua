--[[-------------------------------------------------------------------------
	N-work — взаимодействие.

	Подсказка снизу по центру, как в Monarch: клавиша в квадратике и
	действие крупным текстом («E  Взять «Аптечка»»).

	E на предмете или игроке открывает список действий у прицела:
	колесо мыши — выбрать, ЛКМ — выполнить, E/ПКМ — закрыть.

	Свои действия добавляются так:
		NWORK.Interact.AddOption( "inspect", {
			Name   = "Осмотреть",
			Glyph  = "question",
			Order  = 10,
			Filter = function( ent ) return ent:IsPlayer() end,
			Run    = function( ent ) ... end,      -- клиент
		} )
---------------------------------------------------------------------------]]

local UI = NWORK.UI

NWORK.Interact = NWORK.Interact or {}
local IA = NWORK.Interact
IA.Options = IA.Options or {}

local DOORS = {
	prop_door_rotating = true,
	func_door          = true,
	func_door_rotating = true,
}

function IA.AddOption( id, def )
	def.id    = id
	def.Order = def.Order or 50
	IA.Options[ id ] = def
end

function IA.OptionsFor( ent )
	local out = {}
	for _, def in pairs( IA.Options ) do
		if not def.Filter or def.Filter( ent ) then out[ #out + 1 ] = def end
	end
	table.sort( out, function( a, b ) return a.Order < b.Order end )
	return out
end

local function Target()
	local lp = LocalPlayer()
	if not IsValid( lp ) or not lp:Alive() then return end

	local tr = util.TraceLine( {
		start  = lp:EyePos(),
		endpos = lp:EyePos() + lp:GetAimVector() * 110,
		filter = lp,
	} )

	local ent = tr.Entity
	if not IsValid( ent ) then return end
	if ent:IsPlayer() and not ent:Alive() then return end
	return ent
end

local function LabelFor( ent )
	local class = ent:GetClass()

	if class == "nwork_item" then
		local def = NWORK.Items[ ent:GetItemID() ]
		local n   = ent:GetAmount()
		return "Взять «" .. ( def and def.Name or "Предмет" ) .. "»" .. ( n > 1 and ( " x" .. n ) or "" )
	end

	if ent:IsPlayer() then
		return #IA.OptionsFor( ent ) > 0 and "Взаимодействовать" or nil
	end

	if DOORS[ class ] then return "Взаимодействовать с дверью" end
	if class == "func_button" or class == "gmod_button" then return "Нажать" end

	-- свои энтити задают подпись полем ENT.NworkUseText
	return ent.NworkUseText
end

------------------------------------------------------------ список действий

local MENU -- { ent, options, sel, expire }

local function OpenMenu( ent )
	local opts = IA.OptionsFor( ent )
	if #opts == 0 then return false end

	MENU = { ent = ent, options = opts, sel = 1, expire = CurTime() + 10 }
	surface.PlaySound( "ui/buttonrollover.wav" )
	return true
end

local function CloseMenu() MENU = nil end

function IA.IsMenuOpen() return MENU ~= nil end

hook.Add( "Think", "Nwork.InteractMenu", function()
	if not MENU then return end

	local lp = LocalPlayer()
	if not IsValid( MENU.ent ) or not lp:Alive() or CurTime() > MENU.expire
		or lp:GetPos():DistToSqr( MENU.ent:GetPos() ) > 160 * 160
		or UI.Active() then
		CloseMenu()
	end
end )

---------------------------------------------------------------- подсказка

local hintAlpha, hintText, hintKey = 0, "", "E"

local function DrawPrompt( w, h, k, key, text, a )
	surface.SetFont( "Nwork.Prompt" )
	local tw = surface.GetTextSize( text )

	surface.SetFont( "Nwork.PromptKey" )
	local kw = surface.GetTextSize( key )

	local box = math.max( math.floor( 40 * k ), kw + math.floor( 18 * k ) )
	local gap = math.floor( 20 * k )
	local x   = math.floor( ( w - box - gap - tw ) / 2 )
	local cy  = math.floor( h * 0.918 )

	surface.SetDrawColor( 18, 20, 23, 150 * a )
	surface.DrawRect( x, cy - box / 2, box, box )
	surface.SetDrawColor( 255, 255, 255, 40 * a )
	surface.DrawOutlinedRect( x, cy - box / 2, box, box, 1 )

	draw.SimpleText( key, "Nwork.PromptKey", x + box / 2, cy,
		Color( 230, 234, 238, 240 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	UI.ShadowText( text, "Nwork.Prompt", x + box + gap, cy,
		Color( 222, 226, 230, 245 * a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
end

hook.Add( "HUDPaint", "Nwork.Interact", function()
	if UI.Active() or ( NWORK.TabOpen and NWORK.TabOpen() ) then return end

	local w, h = ScrW(), ScrH()
	local k = h / 1080

	-- открытый список действий
	if MENU then
		local n   = #MENU.options
		local row = math.floor( 64 * k )
		local x   = w / 2 - math.floor( 98 * k )
		local y0  = h / 2 - ( MENU.sel - 1 ) * row - row / 2   -- выбранный — на уровне прицела

		for i, o in ipairs( MENU.options ) do
			local y   = y0 + ( i - 1 ) * row
			local sel = i == MENU.sel
			local a   = sel and 255 or 150

			NWORK.Glyph( o.Glyph or "arrow", x, y + row / 2 - math.floor( 10 * k ), math.floor( 20 * k ),
				Color( 240, 243, 247, a ) )
			UI.ShadowText( o.Name, "Nwork.Option", x + math.floor( 30 * k ), y + row / 2,
				Color( 240, 243, 247, a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end

		DrawPrompt( w, h, k, "ЛКМ", "Выбрать действие", 1 )
		return
	end

	local ent = Target()
	local label = ent and LabelFor( ent )

	if label then hintText = label end
	hintAlpha = Lerp( FrameTime() * 10, hintAlpha, label and 1 or 0 )

	if hintAlpha < 0.03 or hintText == "" then return end
	DrawPrompt( w, h, k, hintKey, hintText, hintAlpha )
end )

-------------------------------------------------------------------- ввод

hook.Add( "PlayerBindPress", "Nwork.Interact", function( _, bind, pressed )
	if not pressed or UI.Active() then return end

	if MENU then
		if bind == "+attack" then
			local o = MENU.options[ MENU.sel ]
			local ent = MENU.ent
			CloseMenu()
			if o and IsValid( ent ) then
				surface.PlaySound( "ui/buttonclick.wav" )
				o.Run( ent )
			end
			return true
		end
		if bind == "invnext" then MENU.sel = MENU.sel % #MENU.options + 1 return true end
		if bind == "invprev" then MENU.sel = ( MENU.sel - 2 ) % #MENU.options + 1 return true end
		if bind == "+use" or bind == "+attack2" then CloseMenu() return true end
		return
	end

	if bind ~= "+use" then return end

	local ent = Target()
	if not IsValid( ent ) then return end

	if ( ent:GetClass() == "nwork_item" or ent:IsPlayer() ) and OpenMenu( ent ) then
		return true
	end
end )

----------------------------------------------------------- базовые действия

IA.AddOption( "take", {
	Name   = "Взять",
	Glyph  = "backpack",
	Order  = 1,
	Filter = function( ent ) return ent:GetClass() == "nwork_item" end,
	Run    = function( ent )
		net.Start( "nwork_item_take" )
			net.WriteEntity( ent )
		net.SendToServer()
	end,
} )

IA.AddOption( "inspect", {
	Name   = "Осмотреть",
	Glyph  = "question",
	Order  = 30,
	Filter = function( ent ) return ent:IsPlayer() and ent:HasCharacter() end,
	Run    = function( ent )
		local d = ent:GetCharDesc()
		NWORK.Notify( d ~= "" and d or "Ничего примечательного.", "info", 10 )
	end,
} )

IA.AddOption( "showid", {
	Name   = "Показать документы",
	Glyph  = "box",
	Order  = 20,
	Filter = function( ent )
		return ent:IsPlayer() and NWORK.Inventory.Count( NWORK.LocalInv, "cid" ) > 0
	end,
	Run    = function()
		for idx, e in ipairs( NWORK.LocalInv ) do
			if e.id == "cid" then return NWORK.Inventory.Action( idx, "show" ) end
		end
	end,
} )
