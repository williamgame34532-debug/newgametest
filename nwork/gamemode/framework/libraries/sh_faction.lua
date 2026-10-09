--[[-------------------------------------------------------------------------
	N-work — фракции.

	NWORK.Faction.Register( "id", {
		Name        = "Название",
		Initials    = "ИН",            -- без иконки в неймплейте рисуются инициалы
		Icon        = "nwork/x.png",   -- материал иконки (необязательно)
		Color       = Color( ... ),
		Description = "Текст для вкладки «Фракция»",
		Models      = { male = { ... }, female = { ... } },
		Radio       = true,            -- может пользоваться /r
		Combine     = true,            -- видит оверлей Альянса
	} )
---------------------------------------------------------------------------]]

NWORK.Factions = NWORK.Factions or {}
NWORK.Faction  = NWORK.Faction or {}

local F = NWORK.Faction

function F.Register( id, t )
	t.id          = id
	t.Name        = t.Name or id
	t.Initials    = t.Initials or string.upper( string.sub( id, 1, 2 ) )
	t.Color       = t.Color or Color( 200, 204, 210 )
	t.Description = t.Description or ""
	t.Models      = t.Models or { male = { "models/player/group01/male_01.mdl" } }

	NWORK.Factions[ id ] = t
	return t
end

function F.Get( id )
	return NWORK.Factions[ id ]
end

function F.HasModel( id, mdl )
	local f = NWORK.Factions[ id ]
	if not f then return false end

	for _, list in pairs( f.Models ) do
		for _, m in ipairs( list ) do
			if m == mdl then return true end
		end
	end

	return false
end

-- случайная модель фракции (для ботов и смены фракции)
function F.RandomModel( id )
	local f = NWORK.Factions[ id ]
	if not f then return end

	local pools = {}
	for _, list in pairs( f.Models ) do
		if #list > 0 then pools[ #pools + 1 ] = list end
	end
	if #pools == 0 then return end

	local pool = pools[ math.random( #pools ) ]
	return pool[ math.random( #pool ) ]
end

-- игроки онлайн во фракции
function F.Members( id )
	local out = {}
	for _, ply in ipairs( player.GetAll() ) do
		if ply:HasCharacter() and ply:GetFaction() == id then
			out[ #out + 1 ] = ply
		end
	end
	return out
end

-- совместимость с 0.x
NWORK.FactionHasModel = F.HasModel
