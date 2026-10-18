-- The voice of the body: pain when hurt, a last sound at death - by the faction and the gender.
--   citizens, the CWU, the Resistance, the refugees   male01 / female01 (sound/network2/voices): pain,
--                      "ow", and by the place of the hit "my arm", "my leg", "my gut" (male); dying - the
--                      moans (male), the hardest cries of pain (female)
--   Civil Protection   npc/metropolice pain1-4, dying die1-4
--   the Overwatch      npc/combine_soldier pain1-3, dying die1-3
-- The beep of Garry's Mod at death is gone (PlayerDeathSound). Not more often than every 0.7 s; a hurt
-- that is too small (under 3) stays silent.

local V = "network2/voices/"

local function List(prefix, from, to)
	local out = {}

	for index = from, to do
		out[#out + 1] = string.format(prefix, index)
	end

	return out
end

local SETS = {
	male = {
		pain = List(V .. "male01/pain%02d.wav", 1, 9),
		ow = List(V .. "male01/ow%02d.wav", 1, 2),
		arm = List(V .. "male01/myarm%02d.wav", 1, 2),
		leg = List(V .. "male01/myleg%02d.wav", 1, 2),
		gut = {V .. "male01/mygut02.wav", V .. "male01/hitingut01.wav", V .. "male01/hitingut02.wav"},
		death = List(V .. "male01/moan%02d.wav", 1, 5)
	},
	female = {
		pain = List(V .. "female01/pain%02d.wav", 1, 9),
		ow = List(V .. "female01/ow%02d.wav", 1, 2),
		death = List(V .. "female01/pain%02d.wav", 5, 9)
	},
	cp = {
		pain = List("npc/metropolice/pain%d.wav", 1, 4),
		death = List("npc/metropolice/die%d.wav", 1, 4)
	},
	ota = {
		pain = List("npc/combine_soldier/pain%d.wav", 1, 3),
		death = List("npc/combine_soldier/die%d.wav", 1, 3)
	}
}

local function Set(client)
	local faction = client:GetFaction()

	if (faction == "cp") then
		return SETS.cp
	elseif (faction == "combine") then
		return SETS.ota
	end

	return client:GetNW2String("nwCharGender", "male") == "female" and SETS.female or SETS.male
end

local function Pick(list)
	return list and list[math.random(#list)]
end

hook.Add("PlayerHurt", "nwPain", function(client, _, health, damage)
	if (!IsValid(client) or health <= 0 or damage < 3 or client:GetCharacterID() == 0 or
		(client.nwPainNext or 0) > CurTime()) then
		return
	end

	client.nwPainNext = CurTime() + 0.7

	local set = Set(client)
	local group = client.nwLastHitgroup
	local sound

	-- the place of the hit, now and then (citizens)
	if (math.random() < 0.45) then
		if ((group == HITGROUP_LEFTARM or group == HITGROUP_RIGHTARM) and set.arm) then
			sound = Pick(set.arm)
		elseif ((group == HITGROUP_LEFTLEG or group == HITGROUP_RIGHTLEG) and set.leg) then
			sound = Pick(set.leg)
		elseif (group == HITGROUP_STOMACH and set.gut) then
			sound = Pick(set.gut)
		end
	end

	-- a small hurt: "ow"
	if (!sound and damage < 12 and set.ow and math.random() < 0.5) then
		sound = Pick(set.ow)
	end

	client.nwLastHitgroup = nil
	client:EmitSound(sound or Pick(set.pain), 75, math.random(97, 103))
end)

hook.Add("PlayerDeath", "nwPain", function(client)
	if (!IsValid(client) or client:GetCharacterID() == 0) then
		return
	end

	client:EmitSound(Pick(Set(client).death), 78, math.random(97, 103))
end)

-- no beep of Garry's Mod at death
hook.Add("PlayerDeathSound", "nwPain", function()
	return true
end)
