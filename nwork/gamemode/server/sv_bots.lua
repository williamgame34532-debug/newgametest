--[[-------------------------------------------------------------------------
	N-work — боты (сервер).

	Бот при заходе получает случайное имя с пометкой (BOT), случайную
	фракцию и случайную модель этой фракции. Все видят его имя сразу,
	без знакомства.
---------------------------------------------------------------------------]]

local FIRST = {
	"Ray", "Viktor", "Pavel", "John", "Boris", "Anton",
	"Marek", "Igor", "Sergei", "Dmitri", "Karl", "Milos",
}

local LAST = {
	"Mogbert", "Volkov", "Miller", "Sokolov", "Krause", "Novak",
	"Petrov", "Weber", "Orlov", "Kovacs", "Bauer", "Smirnov",
}

hook.Add( "PlayerInitialSpawn", "Nwork.BotSetup", function( ply )
	if not ply:IsBot() then return end

	local keys = table.GetKeys( NWORK.Factions )
	local fkey = keys[ math.random( #keys ) ]
	local fac  = NWORK.Factions[ fkey ]

	-- случайный пол из доступных у фракции, случайная модель
	local genders = table.GetKeys( fac.Models )
	local pool    = fac.Models[ genders[ math.random( #genders ) ] ]
	local mdl     = pool[ math.random( #pool ) ]

	local name = FIRST[ math.random( #FIRST ) ] .. " " .. LAST[ math.random( #LAST ) ] .. " (BOT)"

	ply.NworkChar = { id = 0, name = name, model = mdl, skin = 0, faction = fkey }

	ply:SetNWString( "nwork_name", name )
	ply:SetNWString( "nwork_faction", fkey )
	ply:SetNWInt( "nwork_charid", 0 )
end )
