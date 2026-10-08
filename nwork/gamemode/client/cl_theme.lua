--[[-------------------------------------------------------------------------
	N-work — тема.
	Палитра, шрифты, конфиг экранов и пути камеры для фонов меню.
---------------------------------------------------------------------------]]

NWORK.Theme = NWORK.Theme or {}
local T = NWORK.Theme

--------------------------------------------------------------------- палитра

T.Colors = {
	Overlay     = Color( 16, 19, 23, 218 ),   -- пелена поверх размытия
	Text        = Color( 240, 243, 247 ),
	TextDim     = Color( 148, 156, 166 ),
	TextFaded   = Color( 255, 255, 255, 26 ), -- большой заголовок-фантом
	Line        = Color( 235, 238, 242 ),

	Panel       = Color( 12, 13, 15, 235 ),   -- поля ввода, карточки
	PanelLight  = Color( 22, 24, 27, 235 ),

	BtnBase     = Color( 14, 14, 15, 240 ),
	BtnSheen    = Color( 255, 255, 255, 10 ),
	BtnSheenHov = Color( 255, 255, 255, 24 ),
	BtnOutline  = Color( 255, 255, 255, 60 ),  -- тонкий контур при наводке
	BtnOutlineDn= Color( 255, 255, 255, 235 ), -- тонкий контур при нажатии

	Select      = Color( 255, 255, 255, 200 ), -- рамка выбранной миниатюры
}

---------------------------------------------------------------- конфиг меню

T.Menu = {
	Title       = "N-WORK",

	-- Иконка-вотермарк: content/materials/nwork/menu_icon.png
	IconMat     = "nwork/menu_icon.png",
	IconAlpha   = 22,     -- прозрачность 0..255
	IconScale   = 0.85,   -- в долях высоты экрана

	FadeIn      = 0.45,
	FadeOut     = 0.35,
	BlurDensity = 6,      -- сила размытия мира
	GraySat     = 0.35,   -- насыщенность мира за меню (1 = обычная, 0 = ч/б)

	EchoDSP     = 12,     -- DSP-пресет эха для фоновых звуков в меню
	                      -- (подбери на слух: 12, 15, 104 звучат по-разному)

	CamSegment  = 20,     -- секунд на перелёт между точками пути камеры
}

------------------------------------------------------------------ интро-титр

T.Intro = {
	Flash    = 0.7,  -- длительность вспышки
	FadeIn   = 0.8,
	Hold     = 4.0,
	FadeOut  = 1.2,
}

------------------------------------------------------------------ пути камеры

--[[
	Камера на фоне главного меню и создания персонажа медленно летит по
	точкам пути своей карты (плавный пинг-понг). Точки удобно снимать
	командой nwork_campos — она печатает готовую строку для вставки.

	Если для карты пути нет — остаётся обычный вид от игрока.
]]
T.CameraPaths = {
	-- ["gm_construct"] = {
	-- 	{ pos = Vector( -1024, 512, 128 ), ang = Angle( 4, 45, 0 ) },
	-- 	{ pos = Vector( -512, 1024, 160 ), ang = Angle( 6, 90, 0 ) },
	-- },
}

------------------------------------------------------------------- вотермарк

T.Watermark = {
	Enabled  = true,

	-- Логотип-материал справа снизу (стиль PROJECT SYNAPSE).
	-- Файл: content/materials/nwork/watermark.png (1024x200, белый на прозрачном).
	-- Если материала нет — рисуется старый текстовый λ-вотермарк ниже.
	Mat      = "nwork/watermark.png",
	MatAlpha = 170,   -- прозрачность 0..255
	MatWidth = 300,   -- ширина в пикселях при 1080p

	Title    = "PRIVATE ALPHA",
	Sub      = "WORK IN PROGRESS",
	Color    = Color( 158, 48, 44 ),   -- красный, как в референсе
	Location = nil,  -- подпись локации слева (nil = имя карты)
}

---------------------------------------------------------------------- шрифты

-- Главный дисплейный шрифт. Положи TTF в content/resource/fonts/ — GMod
-- подхватит его по внутреннему имени. Если файла нет, будет системный фолбэк.
T.FontMain = "Boxed Round"

local function F( name, data )
	data.antialias = true
	data.extended  = true
	surface.CreateFont( name, data )
end

local function Rebuild()
	local k = ScrH() / 1080

	F( "Nwork.Logo",     { font = "Roboto", size = math.max( 48, math.floor( 96 * k ) ), weight = 900 } )
	F( "Nwork.Ghost",    { font = T.FontMain, size = math.floor( 64 * k ), weight = 900 } )
	F( "Nwork.Label",    { font = T.FontMain, size = math.floor( 22 * k ), weight = 800 } )
	F( "Nwork.Button",   { font = "Roboto", size = math.max( 15, math.floor( 19 * k ) ), weight = 700, italic = true } )
	F( "Nwork.Input",    { font = "Roboto", size = math.floor( 24 * k ), weight = 500 } )
	F( "Nwork.Small",    { font = "Roboto", size = math.max( 12, math.floor( 16 * k ) ), weight = 500 } )
	F( "Nwork.Tiny",     { font = "Roboto", size = math.max( 11, math.floor( 14 * k ) ), weight = 500 } )
	F( "Nwork.Gender",   { font = "Roboto", size = math.floor( 40 * k ), weight = 500 } )
	F( "Nwork.CardName", { font = T.FontMain, size = math.floor( 24 * k ), weight = 800 } )
	F( "Nwork.Intro",    { font = T.FontMain, size = math.floor( 86 * k ), weight = 900, italic = true } )
	F( "Nwork.IntroSub", { font = "Roboto", size = math.floor( 26 * k ), weight = 500 } )

	F( "Nwork.Rules",    { font = "Roboto", size = math.max( 11, math.floor( 14 * k ) ), weight = 500 } )

	-- чат как в Monarch: Roboto (встроен в GMod), обычный + жирный глагол
	F( "Nwork.Chat",       { font = "Roboto", size = math.floor( 19 * k ), weight = 400 } )
	F( "Nwork.ChatBold",   { font = "Roboto", size = math.floor( 19 * k ), weight = 700 } )
	F( "Nwork.ChatItalic", { font = "Roboto", size = math.floor( 19 * k ), weight = 400, italic = true } )
	F( "Nwork.ChatRadio",  { font = "Roboto", size = math.floor( 19 * k ), weight = 500 } )
	F( "Nwork.ChatEntry", { font = "Roboto", size = math.floor( 20 * k ), weight = 500 } )
	F( "Nwork.ChatHint",  { font = "Roboto", size = math.floor( 14 * k ), weight = 500 } )
	F( "Nwork.CmdName",   { font = "Roboto", size = math.floor( 21 * k ), weight = 800 } )
	F( "Nwork.CmdArgs",   { font = "Roboto", size = math.floor( 19 * k ), weight = 400 } )
	F( "Nwork.CmdDesc",   { font = "Roboto", size = math.floor( 15 * k ), weight = 500 } )
	F( "Nwork.CmdTag",    { font = "Roboto", size = math.floor( 13 * k ), weight = 700 } )
	F( "Nwork.ChatWhisper", { font = "Roboto", size = math.max( 12, math.floor( 15 * k ) ), weight = 500, italic = true } )
	F( "Nwork.ChatYell",    { font = "Roboto", size = math.floor( 24 * k ), weight = 800 } )

	F( "Nwork.PlateName", { font = T.FontMain, size = math.floor( 38 * k ), weight = 800 } )
	F( "Nwork.PlateSub",  { font = "Roboto", size = math.floor( 21 * k ), weight = 500 } )
	F( "Nwork.PlateInit", { font = T.FontMain, size = math.floor( 30 * k ), weight = 900 } )

	F( "Nwork.WepSlot", { font = "Roboto", size = math.floor( 19 * k ), weight = 700 } )
	F( "Nwork.WepName", { font = "Roboto", size = math.floor( 20 * k ), weight = 600 } )
	F( "Nwork.WepAmmo", { font = "Roboto", size = math.floor( 14 * k ), weight = 500 } )

	F( "Nwork.InvHeader", { font = T.FontMain, size = math.floor( 34 * k ), weight = 900 } )
	F( "Nwork.InvName",   { font = T.FontMain, size = math.floor( 28 * k ), weight = 800, italic = true } )
	F( "Nwork.InvSub",    { font = "Roboto", size = math.floor( 19 * k ), weight = 500 } )
	F( "Nwork.NavBtn",    { font = "Roboto", size = math.floor( 18 * k ), weight = 700 } )

	F( "Nwork.TargetName",     { font = "Roboto", size = math.floor( 28 * k ), weight = 800 } )
	F( "Nwork.TargetSub",      { font = "Roboto", size = math.floor( 19 * k ), weight = 500 } )
	F( "Nwork.Location",       { font = "Roboto", size = math.floor( 24 * k ), weight = 700, italic = true } )
	F( "Nwork.LocationSub",    { font = "Roboto", size = math.floor( 19 * k ), weight = 500, italic = true } )
	F( "Nwork.Watermark",      { font = "Roboto", size = math.floor( 22 * k ), weight = 800 } )
	F( "Nwork.WatermarkSub",   { font = "Roboto", size = math.floor( 14 * k ), weight = 500 } )
	F( "Nwork.WatermarkLambda",{ font = "Roboto", size = math.floor( 30 * k ), weight = 500 } )
end

Rebuild()
hook.Add( "OnScreenSizeChanged", "Nwork.RebuildFonts", Rebuild )

------------------------------------------------------- сохранённые настройки

T.Watermark.Enabled = cookie.GetNumber( "nwork_wm", 1 ) == 1
T.Menu.EchoDSP      = cookie.GetNumber( "nwork_echo", 1 ) == 1 and T.Menu.EchoDSP or 0
T.Menu.BlurDensity  = cookie.GetNumber( "nwork_blur", T.Menu.BlurDensity )
T.Menu.GraySat      = cookie.GetNumber( "nwork_gray", T.Menu.GraySat )
T.Menu.CamSegment   = cookie.GetNumber( "nwork_camseg", T.Menu.CamSegment )
