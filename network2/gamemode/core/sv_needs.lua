-- Needs, server. Hunger empties in about 90 minutes, thirst in about 60. At zero hunger the
-- character loses 1-2 health every 5 seconds; at zero thirst running costs over twice as much and
-- stamina comes back slowly. After death the character comes back with hunger 55 and thirst 50. Both are kept in the character's data and saved with it. Stamina: running
-- (Shift, moving faster than a walk) spends about 9 per second, a jump 7; it comes back after a
-- second of rest (faster standing still). The Endurance skill makes running cheaper. At zero the
-- character is exhausted and walks until stamina is back to 30.
-- Convars: nw_hunger_minutes, nw_thirst_minutes, nw_stamina_drain.

local N = NW.needs

local hungerMinutes = CreateConVar("nw_hunger_minutes", "90", FCVAR_ARCHIVE, "За сколько минут голод падает до нуля")
local thirstMinutes = CreateConVar("nw_thirst_minutes", "60", FCVAR_ARCHIVE, "За сколько минут жажда падает до нуля")
local drain = CreateConVar("nw_stamina_drain", "9", FCVAR_ARCHIVE, "Расход стамины в секунду при беге")

local TICK = 5

local function InWorld(client)
	return client:Alive() and client:GetCharacterID() != 0 and !client:GetNW2Bool("nwInMenu", false)
end

function N.Set(client, kind, value)
	value = math.Clamp(value, 0, 100)

	if (kind == "hunger") then
		client:SetNW2Float("nwHunger", value)
	elseif (kind == "thirst") then
		client:SetNW2Float("nwThirst", value)
	end

	local character = client.nwCharacter

	if (character) then
		character.data = character.data or {}
		character.data.needs = {hunger = client:GetHunger(), thirst = client:GetThirst()}
	end
end

function N.Add(client, kind, amount)
	N.Set(client, kind, (kind == "hunger" and client:GetHunger() or client:GetThirst()) + amount)
end

hook.Add("NWCharacterLoaded", "nwNeeds", function(client, character)
	local needs = character.data and character.data.needs or {}

	N.Set(client, "hunger", tonumber(needs.hunger) or 100)
	N.Set(client, "thirst", tonumber(needs.thirst) or 100)
	client:SetNW2Float("nwStamina", 100)
	client:SetNW2Bool("nwExhausted", false)
end)

hook.Add("PlayerDeath", "nwNeeds", function(client)
	client.nwDied = true
end)

hook.Add("PlayerSpawn", "nwNeeds", function(client)
	client:SetNW2Float("nwStamina", 100)
	client:SetNW2Bool("nwExhausted", false)

	-- back from death: hungry and thirsty (55 / 50)
	if (client.nwDied and client:GetCharacterID() != 0) then
		N.Set(client, "hunger", 55)
		N.Set(client, "thirst", 50)
	end

	client.nwDied = nil
end)

-- starving: 1-2 health every tick (parched: no damage, but stamina goes fast - see below)
timer.Create("nwNeeds", TICK, 0, function()
	local hungerStep = 100 / math.max(1, hungerMinutes:GetFloat() * 60 / TICK)
	local thirstStep = 100 / math.max(1, thirstMinutes:GetFloat() * 60 / TICK)

	for _, client in ipairs(player.GetAll()) do
		if (InWorld(client)) then
			N.Add(client, "hunger", -hungerStep)
			N.Add(client, "thirst", -thirstStep)

			if (client:GetHunger() <= 0) then
				local damage = DamageInfo()
				damage:SetDamage(math.random(1, 2))
				damage:SetDamageType(DMG_GENERIC)
				damage:SetAttacker(game.GetWorld())
				client:TakeDamageInfo(damage)
			end
		end
	end
end)

-- ---------------------------------------------------------------- stamina --
local function RunSpeed(client)
	local convar = GetConVar("nw_runspeed")

	return client and client.nwRunSpeed or (convar and convar:GetFloat() or 200)
end

hook.Add("KeyPress", "nwStamina", function(client, key)
	if (key == IN_JUMP and client:OnGround() and InWorld(client) and client:GetMoveType() == MOVETYPE_WALK) then
		client:SetNW2Float("nwStamina", math.max(0, client:GetStamina() - 7))
		client.nwStaminaUsed = CurTime()
	end
end)

local nextThink = 0

hook.Add("Think", "nwStamina", function()
	if (nextThink > CurTime()) then
		return
	end

	local step = 0.1
	nextThink = CurTime() + step

	for _, client in ipairs(player.GetAll()) do
		if (!InWorld(client)) then
			continue
		end

		local stamina = client:GetStamina()
		local parched = client:GetThirst() <= 0
		local speed = client:GetVelocity():Length2D()
		local running = client:KeyDown(IN_SPEED) and client:OnGround() and client:GetMoveType() == MOVETYPE_WALK and
			speed > client:GetWalkSpeed() + 15

		if (running) then
			-- Выносливость: -5% a level (sh_skills.lua)
			stamina = stamina - drain:GetFloat() * NW.skills.Factor(client, "endurance", -0.05) * (parched and 2.2 or 1) *
				step
			client.nwStaminaUsed = CurTime()
		elseif (CurTime() - (client.nwStaminaUsed or 0) > (parched and 2 or 1)) then
			stamina = stamina + (speed < 10 and 9 or 5) * (parched and 0.4 or 1) * step
		end

		stamina = math.Clamp(stamina, 0, 100)

		if (math.abs(stamina - client:GetStamina()) > 0.01) then
			client:SetNW2Float("nwStamina", stamina)
		end

		-- exhausted: no running until 30
		local exhausted = client:IsExhausted()

		if (!exhausted and stamina <= 0) then
			client:SetNW2Bool("nwExhausted", true)
			client:SetRunSpeed(client:GetWalkSpeed())
		elseif (exhausted and stamina >= 30) then
			client:SetNW2Bool("nwExhausted", false)
			client:SetRunSpeed(RunSpeed(client))
		end
	end
end)
