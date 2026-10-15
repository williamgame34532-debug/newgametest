-- Combat for the music (cl_music.lua): a player is "in combat" when hurt by someone, when they
-- hurt someone, or when bullets fly past them (within NEAR units of the line of fire, or where the
-- bullets land). Shooting into the air or at a wall does not start the music for anyone, the
-- shooter included. The client gets nwCombat (at most once a second) and keeps the combat music for
-- a while after the last one.

util.AddNetworkString("nwCombat")

local NEAR = 180
local REACH = 4000

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

-- the bullets: only the ones they fly past (or land next to) hear them
hook.Add("EntityFireBullets", "nwCombatMusic", function(shooter, data)
	if (!IsValid(shooter) or !data or !data.Src or !data.Dir) then
		return
	end

	local from = data.Src
	local direction = data.Dir:GetNormalized()
	local length = math.min(data.Distance or REACH, REACH)
	local trace = util.TraceLine({start = from, endpos = from + direction * length, filter = shooter,
		mask = MASK_SHOT})
	local land = trace.HitPos
	local reach = from:Distance(land)
	local target = trace.Entity
	local aimed = IsValid(target) and (target:IsPlayer() or target:IsNPC() or target:IsNextBot())

	for _, client in ipairs(player.GetAll()) do
		if (client != shooter and client:Alive()) then
			local center = client:WorldSpaceCenter()
			local along = math.Clamp((center - from):Dot(direction), 0, reach)
			local closest = from + direction * along

			if (center:DistToSqr(closest) < NEAR * NEAR or center:DistToSqr(land) < NEAR * NEAR) then
				Mark(client)
				aimed = true
			end
		end
	end

	-- the shooter is in the fight only when someone is shot at
	if (aimed and shooter:IsPlayer()) then
		Mark(shooter)
	end
end)
