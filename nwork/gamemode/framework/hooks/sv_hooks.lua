--[[-------------------------------------------------------------------------
	N-work — серверные переопределения геймода.

	* без персонажа игрок заморожен и бессмертен (сидит в меню);
	* лоадаут: руки, у админов — физган и тулган;
	* песочница (пропы, энтити, NPC, машины) — только админам,
	  если не включено C.PlayerSandbox;
	* ноуклип — только админам;
	* задержка возрождения C.RespawnTime;
	* голосовой чат слышно в радиусе C.VoiceRange, со звуком в 3D.
---------------------------------------------------------------------------]]

local C = NWORK.Config

function GM:PlayerSpawn( ply )
	self.BaseClass.PlayerSpawn( self, ply )

	local c = ply.NworkChar

	if c then
		ply:SetModel( c.model )
		ply:SetSkin( c.skin or 0 )
		ply:SetupHands()
		ply:GodDisable()
		ply:Freeze( false )
	else
		ply:GodEnable()
		ply:Freeze( true )
	end

	hook.Run( "NworkPlayerSpawn", ply, c )
end

function GM:PlayerLoadout( ply )
	if not ply.NworkChar then return true end

	ply:Give( C.HandsWeapon )

	if ply:IsAdmin() then
		for _, wep in ipairs( C.AdminLoadout ) do ply:Give( wep ) end
	end

	hook.Run( "NworkLoadout", ply )
	ply:SelectWeapon( C.HandsWeapon )
	return true
end

------------------------------------------------------------------- песочница

local SANDBOX = {
	"PlayerSpawnObject", "PlayerSpawnProp", "PlayerSpawnRagdoll", "PlayerSpawnEffect",
	"PlayerSpawnSENT", "PlayerSpawnSWEP", "PlayerGiveSWEP", "PlayerSpawnNPC", "PlayerSpawnVehicle",
}

for _, name in ipairs( SANDBOX ) do
	GM[ name ] = function( self, ply, ... )
		if not C.PlayerSandbox and not ply:IsAdmin() then return false end
		return self.BaseClass[ name ]( self, ply, ... )
	end
end

function GM:PlayerNoClip( ply, desired )
	return ply:IsAdmin() or not desired
end

--------------------------------------------------------------------- смерть

function GM:PlayerDeath( ply, inflictor, attacker )
	self.BaseClass.PlayerDeath( self, ply, inflictor, attacker )
	ply.NworkRespawnAt = CurTime() + C.RespawnTime
end

function GM:PlayerDeathThink( ply )
	if ( ply.NworkRespawnAt or 0 ) > CurTime() then return false end
	return self.BaseClass.PlayerDeathThink( self, ply )
end

-- реалистичный урон от падения вместо фиксированных 10
function GM:GetFallDamage( ply, speed )
	return math.max( 0, ( speed - 526.5 ) * 0.225 )
end

----------------------------------------------------------------------- голос

function GM:PlayerCanHearPlayersVoice( listener, talker )
	if not talker:HasCharacter() then return false, false end
	return listener:GetPos():DistToSqr( talker:GetPos() ) <= C.VoiceRange * C.VoiceRange, true
end
