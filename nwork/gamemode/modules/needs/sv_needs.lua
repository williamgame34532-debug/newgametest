--[[-------------------------------------------------------------------------
	Нужды (сервер).
---------------------------------------------------------------------------]]

local N   = NWORK.Needs
local CH  = NWORK.Character
local TICK = 10

local function Set( ply, id, v )
	ply:SetNW2Float( "nwork_need_" .. id, math.Clamp( v, 0, 100 ) )
end

function N.Add( ply, id, amount )
	if not N.ById[ id ] then return end
	Set( ply, id, N.Get( ply, id ) + amount )
end

hook.Add( "NworkCharacterLoaded", "Nwork.Needs", function( ply, char, fresh )
	local saved = ( char.data or {} ).needs or {}
	for _, n in ipairs( N.List ) do
		Set( ply, n.id, fresh and 100 or ( saved[ n.id ] or 100 ) )
	end
end )

hook.Add( "NworkCharacterSave", "Nwork.Needs", function( ply, char )
	local t = {}
	for _, n in ipairs( N.List ) do t[ n.id ] = math.Round( N.Get( ply, n.id ), 1 ) end
	char.data = char.data or {}
	char.data.needs = t
end )

timer.Create( "Nwork.Needs", TICK, 0, function()
	for _, ply in ipairs( player.GetAll() ) do
		if ply:GetCharID() ~= 0 and ply:Alive() then
			for _, n in ipairs( N.List ) do
				N.Add( ply, n.id, -100 * TICK / n.Time )
			end

			-- отдых: сидит на корточках и не двигается
			if ply:Crouching() and ply:GetVelocity():Length2DSqr() < 25 then
				N.Add( ply, "rest", 100 * TICK / 600 )
			end

			if ( N.Get( ply, "hunger" ) <= 0 or N.Get( ply, "thirst" ) <= 0 ) and ply:Health() > 10 then
				ply:SetHealth( ply:Health() - 1 )
			end
		end
	end
end )

-- усталость замедляет бег
hook.Add( "NworkPlayerSpawn", "Nwork.Needs", function( ply )
	ply.NworkBaseRun = ply:GetRunSpeed()
end )

timer.Create( "Nwork.NeedsSpeed", 2, 0, function()
	for _, ply in ipairs( player.GetAll() ) do
		if ply.NworkBaseRun and ply:Alive() then
			local tired = N.Get( ply, "rest" ) < 20
			ply:SetRunSpeed( tired and ply.NworkBaseRun * 0.7 or ply.NworkBaseRun )
		end
	end
end )
