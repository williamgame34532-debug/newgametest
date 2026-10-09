--[[-------------------------------------------------------------------------
	N-work — вкладки меню персонажа.

	Сверху: Инвентарь, Фракция, Помощь, Игроки.
	Снизу: Администрирование (админы), Правила, Настройки.
	Модули добавляют свои через NWORK.UI.AddPage (см. cl_tabmenu.lua).
---------------------------------------------------------------------------]]

local T  = NWORK.Theme
local UI = NWORK.UI
local O  = NWORK.Option
local TC = T.Colors
local U  = NWORK.Util

local WHITE = Color( 240, 243, 247 )
local DIM   = Color( 196, 202, 210 )
local RED   = Color( 186, 70, 62 )
local BLUE  = Color( 80, 120, 190 )
local GREY  = Color( 130, 134, 140 )

-- разбить текст на строки по ширине (для расчёта высоты при сборке)
local function Lines( text, font, w )
	surface.SetFont( font )
	local out, line = {}, ""
	for word in string.gmatch( text, "%S+" ) do
		local try = line == "" and word or ( line .. " " .. word )
		if surface.GetTextSize( try ) > w and line ~= "" then
			out[ #out + 1 ] = line
			line = word
		else
			line = try
		end
	end
	if line ~= "" then out[ #out + 1 ] = line end
	return out
end

local function LineH( font )
	surface.SetFont( font )
	local _, h = surface.GetTextSize( "Ау" )
	return h + 2
end

-- колонка справа (как у Monarch на вкладке фракций)
local function Column( c )
	local x0 = math.floor( c:GetWide() * 0.33 )
	return x0, c:GetWide() - x0
end

-- прокручиваемый список строк-действий в колонке
local function RowList( c, x, y, w, h )
	local sc = vgui.Create( "DScrollPanel", c )
	sc:SetPos( x, y )
	sc:SetSize( w, h )
	local bar = sc:GetVBar()
	bar:SetWide( 4 )
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function( _, ww, hh )
		surface.SetDrawColor( 255, 255, 255, 40 )
		surface.DrawRect( 0, 0, ww, hh )
	end
	return sc
end

local function AddRow( list, title, desc, color, fn )
	local S = ScrH() / 1125
	local row = UI.ActionRow( list, 0, 0, list:GetWide() - 8, title, desc, color, fn )
	row:Dock( TOP )
	row:DockMargin( 0, 0, 8, math.floor( 6.5 * S ) )
	return row
end

------------------------------------------------------------------ инвентарь

UI.AddPage( "inv", {
	Title = "ИНВЕНТАРЬ", Tip = "Инвентарь", Glyph = "backpack", Order = 10,

	Build = function( c, menu )
		local S   = c.S
		local inv = NWORK.LocalInv or {}
		local C   = NWORK.Config

		local cols = 5
		local rows = math.ceil( C.InvSlots / cols )
		local cell = math.floor( 118 * S )
		local step = math.floor( 124 * S )
		local gw   = cols * step - ( step - cell )
		local gx   = c:GetWide() - gw - math.floor( 26 * S )
		local gy   = math.floor( 79 * S )

		local selIdx = menu.SelIdx
		if selIdx and not inv[ selIdx ] then selIdx = nil menu.SelIdx = nil end
		local sel    = selIdx and inv[ selIdx ]
		local def    = sel and NWORK.Items[ sel.id ]

		local dx = math.floor( 9 * S )
		local dw = gx - dx - math.floor( 120 * S )
		local descLines = def and Lines( def.Desc or "", "Nwork.TabSub", dw - math.floor( 50 * S ) ) or {}

		c.Paint = function( _, w, h )
			UI.PageHeader( "ИНВЕНТАРЬ", "backpack", gx + gw / 2, math.floor( 20 * S ) )

			-- пустые ячейки сетки
			for i = 0, cols * rows - 1 do
				if not inv[ i + 1 ] then
					local x = gx + ( i % cols ) * step
					local y = gy + math.floor( i / cols ) * step
					surface.SetDrawColor( TC.Cell )
					surface.DrawRect( x, y, cell, cell )
					UI.Corner( x, y, cell, cell, Color( 255, 255, 255, 22 ) )
				end
			end

			draw.SimpleText( ( "Занято ячеек: %d / %d" ):format( #inv, C.InvSlots ), "Nwork.Status",
				gx, gy + rows * step + math.floor( 6 * S ), WHITE )

			-- карточка выбранного предмета
			if not def then
				draw.SimpleText( "Выберите предмет, чтобы увидеть описание и действия.", "Nwork.TabSub",
					dx, math.floor( 60 * S ), Color( 170, 176, 184 ) )
				return
			end

			local gs = math.floor( 34 * S )
			NWORK.Glyph( "box", dx, math.floor( 30 * S ), gs, WHITE, Color( 18, 20, 23 ) )
			draw.SimpleText( U.Upper( def.Name ), "Nwork.ItemTitle", dx + gs + math.floor( 14 * S ),
				math.floor( 30 * S ), WHITE )

			local ly = math.floor( 64 * S )
			for _, l in ipairs( descLines ) do
				draw.SimpleText( l, "Nwork.TabSub", dx + gs + math.floor( 14 * S ), ly, DIM )
				ly = ly + LineH( "Nwork.TabSub" )
			end

			local iy = math.max( ly + math.floor( 14 * S ), math.floor( 112 * S ) )
			surface.SetDrawColor( TC.Cell )
			surface.DrawRect( dx, iy, cell, cell )
			UI.Corner( dx, iy, cell, cell, NWORK.Item.Color( def ) )

			local tx = dx + cell + math.floor( 18 * S )
			draw.SimpleText( "Категория: " .. def.Category, "Nwork.TabText", tx, iy + math.floor( 8 * S ), DIM )
			draw.SimpleText( ( "В ячейке: %d / %d" ):format( sel.n, def.Stack ), "Nwork.TabText", tx,
				iy + math.floor( 32 * S ), DIM )
			draw.SimpleText( ( "Всего: %d" ):format( NWORK.Inventory.Count( inv, def.id ) ), "Nwork.TabText", tx,
				iy + math.floor( 56 * S ), DIM )

			surface.SetDrawColor( 255, 255, 255, 40 )
			surface.DrawRect( dx, iy + cell + math.floor( 12 * S ), dw, 1 )
		end

		-- ячейки с предметами
		for idx, e in ipairs( inv ) do
			if idx > cols * rows then break end
			local d = NWORK.Items[ e.id ]

			local b = vgui.Create( "DButton", c )
			b:SetText( "" )
			b:SetPos( gx + ( idx - 1 ) % cols * step, gy + math.floor( ( idx - 1 ) / cols ) * step )
			b:SetSize( cell, cell )
			b.Paint = function( s, ww, hh )
				surface.SetDrawColor( s:IsHovered() and TC.CellHover or TC.Cell )
				surface.DrawRect( 0, 0, ww, hh )
				if selIdx == idx then
					surface.SetDrawColor( 255, 255, 255, 120 )
					surface.DrawOutlinedRect( 0, 0, ww, hh, 1 )
				end
			end
			b.PaintOver = function( _, ww, hh )
				if e.n > 1 then
					draw.SimpleText( e.n, "Nwork.Cell", math.floor( 6 * S ), math.floor( 4 * S ), WHITE )
				end
				UI.Corner( 0, 0, ww, hh, d and NWORK.Item.Color( d ) or GREY )
			end
			b.DoClick = function()
				surface.PlaySound( "ui/buttonclick.wav" )
				menu.SelIdx = idx
				menu:SetPage( "inv" )
			end
			b.DoRightClick = function()
				-- ПКМ — первое действие предмета (съесть, выпить...)
				local list = d and NWORK.Item.ActionList( d ) or {}
				if list[ 1 ] then NWORK.Inventory.Action( idx, list[ 1 ].key ) end
			end

			if d then
				local ic = vgui.Create( "ModelImage", b )
				local pad = math.floor( 14 * S )
				ic:SetPos( pad, pad )
				ic:SetSize( cell - pad * 2, cell - pad * 2 )
				ic:SetModel( d.Model )
				ic:SetMouseInputEnabled( false )
				b:SetTooltip( d.Name )
			end
		end

		-- иконка выбранного предмета и действия
		if def then
			local gs = math.floor( 34 * S )
			local ly = math.floor( 64 * S ) + #descLines * LineH( "Nwork.TabSub" )
			local iy = math.max( ly + math.floor( 14 * S ), math.floor( 112 * S ) )

			local ic = vgui.Create( "ModelImage", c )
			local pad = math.floor( 14 * S )
			ic:SetPos( dx + pad, iy + pad )
			ic:SetSize( cell - pad * 2, cell - pad * 2 )
			ic:SetModel( def.Model )
			ic:SetMouseInputEnabled( false )

			local ay = iy + cell + math.floor( 26 * S )
			for _, a in ipairs( NWORK.Item.ActionList( def ) ) do
				UI.ActionRow( c, dx, ay, dw, a.Name, "Действие с предметом.", BLUE, function()
					NWORK.Inventory.Action( selIdx, a.key )
				end )
				ay = ay + math.floor( 62 * S )
			end

			UI.ActionRow( c, dx, ay, dw, "Выбросить", "Положить один предмет на землю перед собой.", RED, function()
				NWORK.Inventory.Action( selIdx, "drop" )
			end )
		end
	end,
} )

-------------------------------------------------------------------- фракция

UI.AddPage( "faction", {
	Title = "ФРАКЦИЯ", Tip = "Фракция", Glyph = "lambda", Order = 20,

	Build = function( c, menu )
		local S  = c.S
		local lp = LocalPlayer()
		local f  = lp:GetFactionTable() or {}
		local x0, cw = Column( c )

		local members = NWORK.Faction.Members( f.id or "" )
		local desc = Lines( f.Description or "", "Nwork.TabText", cw - math.floor( 20 * S ) )
		local lh   = LineH( "Nwork.TabText" )

		local infoY = math.floor( 190 * S )
		local textY = infoY + math.floor( 38 * S )
		local actY  = textY + ( #desc + 2 ) * lh + math.floor( 30 * S )

		c.Paint = function( _, w, h )
			UI.PageHeader( "ФРАКЦИЯ", "lambda", x0 + cw / 2, math.floor( 12 * S ),
				"Ваша фракция, её состав и действия персонажа.", x0 )

			-- карточка фракции
			local cy, ch = math.floor( 85 * S ), math.floor( 75 * S )
			surface.SetDrawColor( TC.Row )
			surface.DrawRect( x0, cy, cw, ch )

			local is = math.floor( 50 * S )
			local icon = f.id and NWORK.GetFactionIcon( f.id )
			if icon then
				surface.SetMaterial( icon )
				surface.SetDrawColor( 255, 255, 255 )
				surface.DrawTexturedRect( x0 + math.floor( 12 * S ), cy + ( ch - is ) / 2, is, is )
			else
				draw.RoundedBox( is / 2, x0 + math.floor( 12 * S ), cy + ( ch - is ) / 2, is, is, f.Color or GREY )
				draw.SimpleText( f.Initials or "?", "Nwork.RowTitle", x0 + math.floor( 12 * S ) + is / 2, cy + ch / 2,
					Color( 20, 22, 25 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			end

			draw.SimpleText( f.Name or "—", "Nwork.CardTitle", x0 + math.floor( 75 * S ), cy + math.floor( 10 * S ), WHITE )
			draw.SimpleText( ( "В сети: %d" ):format( #members ), "Nwork.RowDesc", x0 + math.floor( 75 * S ),
				cy + math.floor( 44 * S ), DIM )

			-- информация
			UI.SectionHead( "ИНФОРМАЦИЯ", x0, infoY )
			local y = textY
			for _, l in ipairs( desc ) do
				draw.SimpleText( l, "Nwork.TabText", x0, y, WHITE )
				y = y + lh
			end
			draw.SimpleText( "Ваш персонаж: " .. lp:GetCharName() .. ".", "Nwork.TabText", x0, y + lh * 0.4,
				f.Color or WHITE )

			UI.SectionHead( "ДЕЙСТВИЯ", x0, actY )
			draw.SimpleText( "Действия вашего персонажа.", "Nwork.TabSub", x0, actY + math.floor( 30 * S ),
				Color( 200, 204, 210 ) )
		end

		local list = RowList( c, x0, actY + math.floor( 52 * S ), cw, c:GetTall() - actY - math.floor( 60 * S ) )

		AddRow( list, "Представиться", "Назвать своё имя всем, кто стоит рядом (F3).", f.Color or BLUE, function()
			RunConsoleCommand( "nwork_introduce" )
		end )

		AddRow( list, "Изменить описание", "Внешность и приметы, которые видят другие при осмотре.", BLUE, function()
			UI.TextPrompt( "Описание персонажа", lp:GetCharDesc(), true, function( v )
				net.Start( "nwork_setdesc" )
					net.WriteString( v )
				net.SendToServer()
			end )
		end )

		local names = {}
		for _, p in ipairs( members ) do names[ #names + 1 ] = NWORK.CharName( p ) end
		AddRow( list, "Состав в сети", #names > 0 and U.Sub( table.concat( names, ", " ), 120 ) or "Никого.", GREY )

		AddRow( list, "Сменить персонажа", "Сохранить игру и вернуться к выбору персонажа.", RED, function()
			menu:Close()
			NWORK.UnloadCharacter()
		end )
	end,
} )

--------------------------------------------------------------------- помощь

UI.AddPage( "help", {
	Title = "ПОМОЩЬ", Tip = "Помощь", Glyph = "question", Order = 30,

	Build = function( c )
		local S = c.S
		local x0, cw = Column( c )

		c.Paint = function()
			UI.PageHeader( "ПОМОЩЬ", "question", x0 + cw / 2, math.floor( 12 * S ),
				"Клавиши и команды чата.", x0 )
		end

		local list = RowList( c, x0, math.floor( 85 * S ), cw, c:GetTall() - math.floor( 95 * S ) )

		local keys = {
			{ "Tab", "Меню персонажа: инвентарь, фракция, настройки." },
			{ "E", "Взаимодействие: поднять предмет, действия с игроком." },
			{ "F1", "Эта вкладка." },
			{ "F2", "Колесо анимаций." },
			{ "F3", "Представиться окружающим." },
		}
		for _, kv in ipairs( keys ) do AddRow( list, kv[ 1 ], kv[ 2 ], WHITE ) end

		for _, cmd in ipairs( NWORK.Command.Help( LocalPlayer() ) ) do
			AddRow( list, cmd.cmd .. " " .. cmd.args, cmd.desc .. "  ·  " .. cmd.cat,
				cmd.cat == "АДМИН" and RED or BLUE, function()
					SetClipboardText( cmd.cmd .. " " )
					NWORK.Notify( "Скопировано: " .. cmd.cmd, "ok", 3 )
				end )
		end
	end,
} )

--------------------------------------------------------------------- игроки

UI.AddPage( "players", {
	Title = "ИГРОКИ", Tip = "Игроки", Glyph = "stats", Order = 40,

	Build = function( c )
		local S = c.S
		local x0, cw = Column( c )
		local all = player.GetAll()

		c.Paint = function()
			UI.PageHeader( "ИГРОКИ", "people", x0 + cw / 2, math.floor( 12 * S ),
				( "На сервере: %d / %d" ):format( #all, game.MaxPlayers() ), x0 )
		end

		table.sort( all, function( a, b ) return a:GetFaction() < b:GetFaction() end )

		local list = RowList( c, x0, math.floor( 85 * S ), cw, c:GetTall() - math.floor( 95 * S ) )
		for _, ply in ipairs( all ) do
			local f = ply:GetFactionTable()
			AddRow( list, NWORK.CharName( ply ),
				( "%s  ·  %s  ·  %d мс" ):format( ply:HasCharacter() and f and f.Name or "в меню", ply:Nick(), ply:Ping() ),
				f and f.Color or GREY )
		end
	end,
} )

---------------------------------------------------------------- администрирование

UI.AddPage( "admin", {
	Title = "АДМИН", Tip = "Администрирование", Glyph = "shield", Order = 10, Group = "bottom", Admin = true,

	Build = function( c )
		local S = c.S
		local x0, cw = Column( c )

		c.Paint = function()
			UI.PageHeader( "АДМИН", "shield", x0 + cw / 2, math.floor( 12 * S ),
				"Инструменты администрации.", x0 )
		end

		local list = RowList( c, x0, math.floor( 85 * S ), cw, c:GetTall() - math.floor( 95 * S ) )

		AddRow( list, "Задание для всех", "Изменить строку «? Задание» слева сверху у всех игроков.", BLUE, function()
			UI.TextPrompt( "Заголовок задания", "", false, function( title )
				UI.TextPrompt( "Подзадача (можно пусто)", "", false, function( desc )
					RunConsoleCommand( "say", "/objective " .. title .. " | " .. desc )
				end )
			end )
		end )

		local cam = {
			{ "Добавить точку камеры", "Камера меню на этой карте: точка там, где вы стоите.", "nwork_cam_add" },
			{ "Убрать последнюю точку", "Удалить последнюю точку пути камеры.", "nwork_cam_undo" },
			{ "Очистить путь камеры", "Удалить все точки на этой карте.", "nwork_cam_clear" },
			{ "Список точек", "Вывести точки в консоль.", "nwork_cam_list" },
		}
		for _, e in ipairs( cam ) do
			AddRow( list, e[ 1 ], e[ 2 ], GREY, function() RunConsoleCommand( e[ 3 ] ) end )
		end

		for _, cmd in ipairs( NWORK.Command.Help( LocalPlayer() ) ) do
			if cmd.cat == "АДМИН" then
				AddRow( list, cmd.cmd .. " " .. cmd.args, cmd.desc, RED, function()
					SetClipboardText( cmd.cmd .. " " )
					NWORK.Notify( "Скопировано: " .. cmd.cmd, "ok", 3 )
				end )
			end
		end
	end,
} )

-------------------------------------------------------------------- правила

UI.AddPage( "rules", {
	Title = "ПРАВИЛА", Tip = "Правила", Glyph = "exclaim", Order = 20, Group = "bottom",

	Build = function( c )
		local S = c.S
		local x0, cw = Column( c )
		local rules = NWORK.Schema and NWORK.Schema.Rules or {}

		c.Paint = function()
			UI.PageHeader( "ПРАВИЛА", "exclaim", x0 + cw / 2, math.floor( 12 * S ),
				"Незнание правил не освобождает от ответственности.", x0 )
		end

		local list = RowList( c, x0, math.floor( 85 * S ), cw, c:GetTall() - math.floor( 95 * S ) )
		for i, r in ipairs( rules ) do
			AddRow( list, "Правило " .. i, r, i % 2 == 0 and GREY or RED )
		end
	end,
} )

------------------------------------------------------------------- настройки

local function Toggle( parent, def, S )
	local row = UI.ActionRow( parent, 0, 0, parent:GetWide() - 8, def.Name, def.Desc, BLUE, function()
		O.Set( def.id, not O.Get( def.id ) )
	end )
	row.PaintOver = function( _, w, h )
		local pw, ph = math.floor( 46 * S ), math.floor( 22 * S )
		local px, py = w - pw - math.floor( 16 * S ), ( h - ph ) / 2
		local on = O.Get( def.id )
		draw.RoundedBox( ph / 2, px, py, pw, ph, on and Color( 186, 74, 64, 235 ) or Color( 96, 101, 107, 180 ) )
		local kn = ph - 6
		draw.RoundedBox( kn / 2, on and ( px + pw - kn - 3 ) or ( px + 3 ), py + 3, kn, kn, WHITE )
	end
	return row
end

local function Slider( parent, def, S )
	local row = UI.ActionRow( parent, 0, 0, parent:GetWide() - 8, def.Name, def.Desc, BLUE )
	local trackW = math.floor( 180 * S )

	row.PaintOver = function( s, w, h )
		local v    = O.Get( def.id )
		local frac = math.Clamp( ( v - def.Min ) / ( def.Max - def.Min ), 0, 1 )
		local tx   = w - trackW - math.floor( 16 * S )

		draw.SimpleText( math.Round( v, def.Decimals or 0 ), "Nwork.TabText", tx - math.floor( 12 * S ), h / 2,
			DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		surface.SetDrawColor( 120, 125, 131, 200 )
		surface.DrawRect( tx, h / 2 - 1, trackW, 2 )
		draw.RoundedBox( 6, tx + frac * ( trackW - 12 ), h / 2 - 6, 12, 12, WHITE )

		if s.Drag then
			if not input.IsMouseDown( MOUSE_LEFT ) then s.Drag = false return end
			local mx = s:CursorPos()
			local f  = math.Clamp( ( mx - tx ) / trackW, 0, 1 )
			O.Set( def.id, math.Round( def.Min + f * ( def.Max - def.Min ), def.Decimals or 0 ) )
		end
	end
	row.OnMousePressed = function( s ) s.Drag = true end
	return row
end

UI.AddPage( "settings", {
	Title = "НАСТРОЙКИ", Tip = "Настройки", Glyph = "gear", Order = 30, Group = "bottom",

	Build = function( c )
		local S = c.S
		local x0, cw = Column( c )

		c.Paint = function()
			UI.PageHeader( "НАСТРОЙКИ", "gear", x0 + cw / 2, math.floor( 12 * S ),
				"Сохраняются на вашем компьютере.", x0 )
		end

		local list = RowList( c, x0, math.floor( 85 * S ), cw, c:GetTall() - math.floor( 95 * S ) )
		local order, cats = O.ByCategory()

		for _, cat in ipairs( order ) do
			local head = vgui.Create( "DPanel", list )
			head:SetTall( math.floor( 40 * S ) )
			head:Dock( TOP )
			head.Paint = function( _, w, h )
				draw.SimpleText( U.Upper( cat ), "Nwork.TabHead", 0, h - 4, WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM )
			end

			for _, def in ipairs( cats[ cat ] ) do
				local row = def.Type == "bool" and Toggle( list, def, S ) or Slider( list, def, S )
				row:Dock( TOP )
				row:DockMargin( 0, 0, 8, math.floor( 6.5 * S ) )
			end
		end

		local reset = UI.ActionRow( list, 0, 0, list:GetWide() - 8, "Сбросить положение чата",
			"Вернуть чат-бокс на место по умолчанию.", GREY, function()
				for _, k in ipairs( { "x", "y", "w", "h" } ) do cookie.Delete( "nwork_chat_" .. k ) end
				NWORK.Notify( "Чат сброшен — применится после перезахода.", "ok" )
			end )
		reset:Dock( TOP )
		reset:DockMargin( 0, math.floor( 12 * S ), 8, 0 )
	end,
} )
