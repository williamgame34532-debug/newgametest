--[[-------------------------------------------------------------------------
	N-work — тема интерфейса.

	Палитра, шрифты, параметры меню и вотермарка. Визуальный стиль —
	Monarch / Project Synapse: шрифт Roboto (встроен в GMod), белый текст
	с мягкой тенью, тёмные полупрозрачные плашки, тонкие контуры.
---------------------------------------------------------------------------]]

NWORK.Theme = NWORK.Theme or {}
local T = NWORK.Theme

--------------------------------------------------------------------- палитра

T.Colors = {
	Overlay     = Color( 16, 19, 23, 218 ),   -- пелена поверх размытия в меню
	Text        = Color( 240, 243, 247 ),
	TextDim     = Color( 148, 156, 166 ),
	TextFaded   = Color( 255, 255, 255, 26 ),
	Line        = Color( 235, 238, 242 ),

	Panel       = Color( 12, 13, 15, 235 ),
	PanelLight  = Color( 22, 24, 27, 235 ),

	BtnBase     = Color( 14, 14, 15, 240 ),
	BtnSheen    = Color( 255, 255, 255, 10 ),
	BtnSheenHov = Color( 255, 255, 255, 24 ),
	BtnOutline  = Color( 255, 255, 255, 60 ),
	BtnOutlineDn= Color( 255, 255, 255, 235 ),

	Select      = Color( 255, 255, 255, 200 ),

	-- меню персонажа (Tab)
	Cell        = Color( 30, 32, 36, 170 ),   -- ячейки инвентаря и слоты
	CellHover   = Color( 52, 56, 61, 200 ),
	Row         = Color( 34, 36, 40, 190 ),   -- строки действий
	RowHover    = Color( 46, 49, 54, 210 ),
	Faction     = Color( 123, 167, 201 ),     -- подпись фракции
	Danger      = Color( 125, 48, 52, 235 ),  -- красная плашка-предупреждение
	Accent      = Color( 205, 72, 62 ),
}

---------------------------------------------------------------- конфиг меню

T.Menu = {
	-- иконка-фон: content/materials/nwork/menu_icon.png
	IconMat     = "nwork/menu_icon.png",
	IconAlpha   = 22,
	IconScale   = 0.85,

	FadeIn      = 0.45,
	FadeOut     = 0.35,
	BlurDensity = 6,      -- сила размытия мира
	GraySat     = 0.35,   -- насыщенность мира за меню (1 — обычная, 0 — ч/б)
	EchoDSP     = 12,     -- DSP-пресет эха фоновых звуков
	CamSegment  = 20,     -- секунд на перелёт между точками пути камеры
}

T.Intro = {
	Flash    = 0.7,
	FadeIn   = 0.8,
	Hold     = 4.0,
	FadeOut  = 1.2,
}

-- резервные пути камеры для фона меню (основные задаются в игре, модуль campath)
T.CameraPaths = {
	-- [ "gm_construct" ] = {
	-- 	{ pos = Vector( -1024, 512, 128 ), ang = Angle( 4, 45, 0 ) },
	-- 	{ pos = Vector( -512, 1024, 160 ), ang = Angle( 6, 90, 0 ) },
	-- },
}

------------------------------------------------------------------- вотермарк

T.Watermark = {
	-- логотип-материал (белый на прозрачном), 1024x200
	Mat      = "nwork/watermark.png",
	MatAlpha = 150,
	MatWidth = 300,   -- ширина в пикселях при 1080p

	-- запасной текстовый вариант, если материала нет
	Title    = "PRIVATE ALPHA",
	Sub      = "WORK IN PROGRESS",
	Color    = Color( 158, 48, 44 ),
}

---------------------------------------------------------------------- шрифты

-- Основной шрифт — Roboto, как в Monarch. Можно заменить своим TTF из
-- content/resource/fonts/ — GMod подхватит его по внутреннему имени.
T.FontMain = "Roboto"

local function F( name, font, size, weight, extra )
	local data = { font = font, size = size, weight = weight, antialias = true, extended = true }
	if extra then table.Merge( data, extra ) end
	surface.CreateFont( name, data )
end

local IT = { italic = true }

local function Rebuild()
	local k  = ScrH() / 1080
	local R  = T.FontMain
	local px = function( n, min ) return math.max( min or 10, math.floor( n * k ) ) end

	-- меню и экраны
	F( "Nwork.Ghost",    R, px( 64 ), 900 )
	F( "Nwork.Label",    R, px( 22 ), 700 )
	F( "Nwork.Button",   R, px( 19, 15 ), 700, IT )
	F( "Nwork.Input",    R, px( 24 ), 500 )
	F( "Nwork.Small",    R, px( 16, 12 ), 500 )
	F( "Nwork.Tiny",     R, px( 14, 11 ), 500 )
	F( "Nwork.Gender",   R, px( 40 ), 500 )
	F( "Nwork.CardName", R, px( 24 ), 700 )
	F( "Nwork.InvName",  R, px( 28 ), 700, IT )
	F( "Nwork.Intro",    R, px( 86 ), 900, IT )
	F( "Nwork.IntroSub", R, px( 26 ), 500 )
	F( "Nwork.Rules",    R, px( 15, 11 ), 500 )

	-- чат
	F( "Nwork.Chat",        R, px( 19 ), 400 )
	F( "Nwork.ChatBold",    R, px( 19 ), 700 )
	F( "Nwork.ChatItalic",  R, px( 19 ), 400, IT )
	F( "Nwork.ChatRadio",   R, px( 19 ), 500 )
	F( "Nwork.ChatWhisper", R, px( 16, 12 ), 400, IT )
	F( "Nwork.ChatYell",    R, px( 23 ), 700 )
	F( "Nwork.ChatEntry",   R, px( 19 ), 400 )
	F( "Nwork.ChatHint",    R, px( 14 ), 500 )
	F( "Nwork.CmdName",     R, px( 19 ), 700 )
	F( "Nwork.CmdArgs",     R, px( 17 ), 400 )
	F( "Nwork.CmdDesc",     R, px( 14 ), 400 )
	F( "Nwork.CmdTag",      R, px( 12 ), 700 )

	-- HUD
	F( "Nwork.ObjMark",    R, px( 32 ), 700 )
	F( "Nwork.ObjTitle",   R, px( 31 ), 500 )
	F( "Nwork.ObjSub",     R, px( 18 ), 500 )
	F( "Nwork.Notice",     R, px( 18 ), 500 )
	F( "Nwork.PlateName",  R, px( 38 ), 900 )
	F( "Nwork.PlateSub",   R, px( 21 ), 700 )
	F( "Nwork.PlateMark",  R, px( 64 ), 900 )
	F( "Nwork.PlateInit",  R, px( 34 ), 900 )
	F( "Nwork.PlateSmall", R, px( 18 ), 500 )
	F( "Nwork.PlateTiny",  R, px( 11 ), 700 )
	F( "Nwork.Prompt",     R, px( 24 ), 500 )
	F( "Nwork.PromptKey",  R, px( 15 ), 700 )
	F( "Nwork.Voice",      R, px( 17 ), 700 )
	F( "Nwork.Overhead",   R, px( 20 ), 500 )
	F( "Nwork.OverheadIt", R, px( 18 ), 500, IT )
	F( "Nwork.Option",     R, px( 18 ), 500 )
	F( "Nwork.Radial",     R, px( 17 ), 700 )
	F( "Nwork.WepSlot",    R, px( 19 ), 700 )
	F( "Nwork.WepName",    R, px( 20 ), 600 )
	F( "Nwork.WepAmmo",    R, px( 14 ), 500 )
	F( "Nwork.Watermark",    R, px( 22 ), 800 )
	F( "Nwork.WatermarkSub", R, px( 14 ), 500 )
	F( "Nwork.WatermarkLambda", R, px( 30 ), 500 )
	F( "Nwork.Combine",    "Courier New", px( 20 ), 800 )
	F( "Nwork.CombineBig", "Courier New", px( 26 ), 800 )

	-- меню персонажа (Tab)
	F( "Nwork.TabName",    R, px( 25 ), 500 )
	F( "Nwork.TabFaction", R, px( 20 ), 500 )
	F( "Nwork.TabTitle",   R, px( 25 ), 700 )
	F( "Nwork.TabSub",     R, px( 13 ), 400 )
	F( "Nwork.TabHead",    R, px( 26 ), 700 )
	F( "Nwork.TabText",    R, px( 15 ), 400 )
	F( "Nwork.RowTitle",   R, px( 14 ), 500 )
	F( "Nwork.RowDesc",    R, px( 12, 11 ), 400 )
	F( "Nwork.CardTitle",  R, px( 24 ), 500 )
	F( "Nwork.Cell",       R, px( 12, 11 ), 700 )
	F( "Nwork.BarLabel",   R, px( 12, 11 ), 500 )
	F( "Nwork.Status",     R, px( 16 ), 500 )
	F( "Nwork.CloseSmall", R, px( 12, 11 ), 500 )
	F( "Nwork.CloseX",     R, px( 22 ), 700 )
	F( "Nwork.NavTip",     R, px( 15 ), 500 )
	F( "Nwork.ItemTitle",  R, px( 25 ), 700 )
end

Rebuild()
hook.Add( "OnScreenSizeChanged", "Nwork.RebuildFonts", Rebuild )

------------------------------------------------------------------ настройки

local O = NWORK.Option

O.Register( "watermark", { Name = "Вотермарк", Default = true, Category = "Интерфейс" } )
O.Register( "overhead",  { Name = "Реплики над головами", Default = true, Category = "Интерфейс" } )
O.Register( "crosshair", { Name = "Точка прицела", Default = true, Category = "Интерфейс" } )
O.Register( "objective", { Name = "Текущее задание", Default = true, Category = "Интерфейс" } )

O.Register( "menu_echo", { Name = "Эхо звуков в меню", Default = true, Category = "Главное меню" } )
O.Register( "menu_blur", { Name = "Размытие мира в меню", Type = "number", Default = T.Menu.BlurDensity,
	Min = 0, Max = 10, Decimals = 0, Category = "Главное меню" } )
O.Register( "menu_gray", { Name = "Насыщенность мира в меню", Type = "number", Default = T.Menu.GraySat,
	Min = 0, Max = 1, Decimals = 2, Category = "Главное меню" } )
O.Register( "menu_cam",  { Name = "Секунд на перелёт камеры", Type = "number", Default = T.Menu.CamSegment,
	Min = 8, Max = 40, Decimals = 0, Category = "Главное меню" } )
