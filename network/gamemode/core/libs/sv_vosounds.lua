NETWORK.vo = NETWORK.vo or {}

NETWORK.vo.sets = {
	citizen = {
		male = {
			pain = {
				"framework/vo/cit/pain01.wav",
				"framework/vo/cit/pain02.wav",
				"framework/vo/cit/pain03.wav",
				"framework/vo/cit/pain04.wav"
			}
		},
		female = {
			pain = {
				"framework/vo/citfemale/pain01.wav",
				"framework/vo/citfemale/pain02.wav",
				"framework/vo/citfemale/pain03.wav",
				"framework/vo/citfemale/pain04.wav"
			}
		}
	},
	combine = {
		pain = {
			"framework/vo/metropolice/pain01.wav",
			"framework/vo/metropolice/pain02.wav",
			"framework/vo/metropolice/pain03.wav"
		},
		death = {
			"framework/vo/metropolice/die1.wav",
			"framework/vo/metropolice/die2.wav"
		},
		foley = {
			"framework/vo/metropolice/foley/s1.wav",
			"framework/vo/metropolice/foley/s2.wav",
			"framework/vo/metropolice/foley/s3.wav",
			"framework/vo/metropolice/foley/s4.wav",
			"framework/vo/metropolice/foley/s5.wav",
			"framework/vo/metropolice/foley/s6.wav"
		}
	}
}

NETWORK.vo.painDelay = 1.2

NETWORK.vo.foleyLevel = 75

function NETWORK.vo.GetSet(client)
	if (client:IsCombine()) then
		return NETWORK.vo.sets.combine
	end

	local bFemale = string.find(string.lower(client:GetModel() or ""), "female") != nil

	return NETWORK.vo.sets.citizen[bFemale and "female" or "male"]
end

function NETWORK.vo.Play(client, kind, volume, pitch)
	local set = NETWORK.vo.GetSet(client)
	local list = set and set[kind]

	if (!list and kind == "death") then
		list = set and set.pain
	end

	if (!list or #list == 0) then
		return
	end

	client:EmitSound(list[math.random(#list)], volume or 75, pitch or 100)
end

hook.Add("PlayerHurt", "nwVoicePain", function(client, attacker, remaining)
	if (!client:HasCharacter() or remaining <= 0) then
		return
	end

	if ((client.nwNextPain or 0) > CurTime()) then
		return
	end

	client.nwNextPain = CurTime() + NETWORK.vo.painDelay

	NETWORK.vo.Play(client, "pain", 75, math.random(97, 103))
end)

hook.Add("PlayerDeath", "nwVoiceDeath", function(client)
	if (!client:HasCharacter()) then
		return
	end

	client.nwNextPain = 0

	NETWORK.vo.Play(client, "death", 95, math.random(96, 102))
end)

hook.Add("Think", "nwVoiceFoley", function()
	if (!NETWORK.util.Throttle("vo.foley", 0.15)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:HasCharacter() or !client:IsCombine()) then
			continue
		end

		local set = NETWORK.vo.GetSet(client)

		if (!set or !set.foley) then
			continue
		end

		local speed = client:GetVelocity():Length2D()

		if (!client:IsOnGround() or speed < 120) then
			continue
		end

		if ((client.nwNextFoley or 0) > CurTime()) then
			continue
		end

		local index = (client.nwFoleyIndex or 0) % #set.foley + 1

		client.nwFoleyIndex = index

		client:EmitSound(set.foley[index], NETWORK.vo.foleyLevel, 100, 0.85,
			CHAN_BODY)

		local rate = math.Clamp(320 / math.max(speed, 1), 0.3, 0.55)

		client.nwNextFoley = CurTime() + rate
	end
end)
