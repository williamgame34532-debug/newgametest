--[[-------------------------------------------------------------------------
	N-work — общая точка входа.

	Здесь только метаданные геймода и загрузчик файлов. Всё остальное
	подключает framework/boot.lua в строгом порядке:

		framework/libraries   ядро: конфиг, фракции, предметы, персонажи,
		                      инвентарь, команды, чат-классы, уведомления
		framework/hooks       переопределения GM (спавн, лоадаут, HUD)
		schema/               контент сервера: фракции, предметы, чат
		framework/interface   клиентский интерфейс
		modules/              отключаемые модули (знакомства, нужды и т.д.)

	Реалм файла определяется префиксом: sv_ — сервер, cl_ — клиент,
	sh_ (или без префикса) — обе стороны.
---------------------------------------------------------------------------]]

DeriveGamemode( "sandbox" )

NWORK = NWORK or {}
NWORK.Version = "1.0.0"
NWORK.Folder  = GM.FolderName .. "/gamemode"

GM.Name    = "N-work"
GM.Author  = "N-work"
GM.Email   = ""
GM.Website = ""

-- Подключить файл с учётом реалма (по префиксу имени или явно).
function NWORK.Include( path, realm )
	local fname = string.GetFileFromFilename( path )
	realm = realm or string.match( fname, "^(%a%a)_" ) or "sh"

	if realm == "sv" then
		if SERVER then return include( path ) end
	elseif realm == "cl" then
		if SERVER then AddCSLuaFile( path ) else return include( path ) end
	else
		if SERVER then AddCSLuaFile( path ) end
		return include( path )
	end
end

-- порядок внутри папки: сначала общие (sh_), потом серверные, потом клиентские
local RANK = { sh = 1, sv = 2, cl = 3 }

local function Rank( f )
	return RANK[ string.match( f, "^(%a%a)_" ) or "sh" ] or 1
end

-- Подключить все .lua папки (путь от gamemode/): sh_ -> sv_ -> cl_, внутри —
-- по алфавиту; затем, если recursive, — подпапки.
function NWORK.IncludeDir( dir, recursive )
	local base = NWORK.Folder .. "/" .. dir
	local files, folders = file.Find( base .. "/*", "LUA" )

	table.sort( files, function( a, b )
		local ra, rb = Rank( a ), Rank( b )
		if ra ~= rb then return ra < rb end
		return a < b
	end )
	for _, f in ipairs( files ) do
		if string.EndsWith( f, ".lua" ) then
			NWORK.Include( base .. "/" .. f )
		end
	end

	if recursive then
		table.sort( folders )
		for _, d in ipairs( folders ) do
			NWORK.IncludeDir( dir .. "/" .. d, true )
		end
	end
end

NWORK.Include( NWORK.Folder .. "/framework/boot.lua", "sh" )
