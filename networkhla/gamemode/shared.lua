--[[
	Network - HL:A RP
	Ядро фреймворка: метаданные гейммода и загрузчик файлов.
]]

GM.Name    = "Network - HL:A RP"
GM.Author  = "Network"
GM.Website = ""
GM.TeamBased = false

DeriveGamemode("base")

HLARP = HLARP or {}
HLARP.Version = "0.1.0"
HLARP.Folder  = GM.FolderName .. "/gamemode"

-- Подключает файл с учётом реалма.
-- Реалм берётся из аргумента или из префикса имени: sv_, cl_, sh_ (по умолчанию shared).
function HLARP.Include(path, realm)
	realm = realm or string.match(string.GetFileFromFilename(path), "^(%a%a)_") or "sh"

	if realm == "sv" then
		if SERVER then include(path) end
	elseif realm == "cl" then
		if SERVER then AddCSLuaFile(path) else include(path) end
	else
		if SERVER then AddCSLuaFile(path) end
		return include(path)
	end
end

-- Подключает все .lua файлы папки (в алфавитном порядке), затем подпапки.
function HLARP.IncludeDir(dir, recursive)
	local full = HLARP.Folder .. "/" .. dir
	local files, folders = file.Find(full .. "/*", "LUA")

	table.sort(files)
	for _, name in ipairs(files) do
		if string.EndsWith(name, ".lua") then
			HLARP.Include(full .. "/" .. name)
		end
	end

	if recursive then
		table.sort(folders)
		for _, folder in ipairs(folders) do
			HLARP.IncludeDir(dir .. "/" .. folder, true)
		end
	end
end

HLARP.IncludeDir("config")
HLARP.IncludeDir("core")
HLARP.IncludeDir("modules", true)

MsgC(HLARP.Config.Colors.Primary, "[Network HL:A RP] ", color_white, "Framework v" .. HLARP.Version .. " loaded (" .. (SERVER and "server" or "client") .. ")\n")
