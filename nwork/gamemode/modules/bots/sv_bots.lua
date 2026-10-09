--[[-------------------------------------------------------------------------
	Боты (сервер): случайное имя с пометкой (BOT), фракция и модель.
	Их имена видны без знакомства.
---------------------------------------------------------------------------]]

local FIRST = { "Ray", "Viktor", "Pavel", "John", "Boris", "Anton", "Marek", "Igor", "Sergei", "Dmitri", "Karl", "Milos" }
local LAST  = { "Mogbert", "Volkov", "Miller", "Sokolov", "Krause", "Novak", "Petrov", "Weber", "Orlov", "Kovacs", "Bauer", "Smirnov" }

hook.Add( "PlayerInitialSpawn", "Nwork.BotSetup", function( ply )
	if not ply:IsBot() then return end

	local keys = table.GetKeys( NWORK.Factions )
	local fkey = keys[ math.random( #keys ) ]
	local name = FIRST[ math.random( #FIRST ) ] .. " " .. LAST[ math.random( #LAST ) ] .. " (BOT)"

	ply.NworkChar = {
		id = 0, name = name, descr = "Бот.", faction = fkey, skin = 0, data = {},
		model = NWORK.Faction.RandomModel( fkey ) or "models/player/group01/male_01.mdl",
	}

	ply:SetNWString( "nwork_name", name )
	ply:SetNWString( "nwork_faction", fkey )
	ply:SetNWString( "nwork_desc", "Бот." )
	ply:SetNWInt( "nwork_charid", 0 )
end )
