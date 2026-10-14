-- Combat for the music (cl_music.lua): a player is "in combat" when hurt by someone, when he
-- hurts someone, or when bullets fly within 1200 units of him. The client gets nwCombat (at most
-- once a second) and keeps the combat music for a while after the last one.

util.AddNetworkString("nwCombat")

local RANGE = 1200

local function Mark(client)
	if (!IsValid(client) or !client:IsPlayer() or client:IsBot() or (client.nwCombatSent or 0) > CurTime()) then
		return
	end

	client.nwCombatSent = CurTime() + 1

	net.Start("nwCombat")
	net.Send(client)
end

hook.Add("EntityTakeDamage", "nwCombatMusic", function(target, damage)
	local attacker = damage:GetAttacker()

	if (!IsValid(attacker) or attacker == target or attacker:IsWorld()) then
		return
	end

	if (target:IsPlayer() and (attacker:IsPlayer() or attacker:IsNPC() or attacker:IsNextBot())) then
		Mark(target)
	end

	if (attacker:IsPlayer() and (target:IsPlayer() or target:IsNPC() or target:IsNextBot())) then
		Mark(attacker)
	end
end)

hook.Add("EntityFireBullets", "nwCombatMusic", function(shooter)
	if (!IsValid(shooter)) then
		return
	end

	local pos = shooter:GetPos()

	for _, client in ipairs(player.GetAll()) do
		if (client:GetPos():DistToSqr(pos) < RANGE * RANGE) then
			Mark(client)
		end
	end
end)
