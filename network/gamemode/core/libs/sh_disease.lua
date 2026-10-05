NETWORK.disease = NETWORK.disease or {}

local D = NETWORK.disease

D.interval = 6

D.list = {
	poisoning = {
		name = "diseasePoisoning",
		desc = "diseasePoisoningDesc",
		duration = 600,
		icon = "sick",
		color = Color(150, 200, 90),
		severity = 1,
		escalateTo = "infection",
		escalateAfter = 480,
		escalateChance = 0.3,
		screen = 1,
		Tick = function(client, state)
			NETWORK.needs.Add(client, "nwHunger", -1.5)
			NETWORK.needs.Add(client, "nwThirst", -2)

			if (NETWORK.needs.GetExact and NETWORK.needs.PushStamina) then
				NETWORK.needs.PushStamina(client, NETWORK.needs.GetExact(client) - 12)
				client.nwStaminaDelay = math.max(client.nwStaminaDelay or 0,
					CurTime() + 2)
			end

			if ((state.nextVomit or 0) <= CurTime()) then
				state.nextVomit = CurTime() + math.Rand(40, 70)

				client:EmitSound("ambient/voices/cough1.wav", 65, math.random(90, 100))

				if (client:GetHunger() < 30) then
					client:TakeDamage(1, client, client)
				end
			end
		end
	},
	infection = {
		name = "diseaseInfection",
		desc = "diseaseInfectionDesc",
		duration = 900,
		icon = "pharmacy",
		color = Color(226, 120, 96),
		severity = 2,
		speedScale = 0.9,
		screen = 0.6,
		Tick = function(client, state)
			if ((state.nextHit or 0) > CurTime()) then
				return
			end

			state.nextHit = CurTime() + 30

			local hit = math.min(2, client:Health() - 20)

			if (hit > 0) then
				client:TakeDamage(hit, client, client)
			end
		end
	}
}

function D.Get(id)
	return D.list[id or ""]
end

function D.Has(client)
	return IsValid(client) and client:GetNWString("nwDisease", "") != ""
end

function D.GetID(client)
	local id = IsValid(client) and client:GetNWString("nwDisease", "") or ""

	return id != "" and id or nil
end

function D.GetData(client)
	return D.Get(D.GetID(client))
end

function D.TimeLeft(client)
	if (!D.Has(client)) then
		return 0
	end

	return math.max(client:GetNWFloat("nwDiseaseEnd", 0) - CurTime(), 0)
end

hook.Add("NetworkMovementSpeed", "nwDisease", function(client, walk, run)
	local data = D.GetData(client)

	if (!data or !data.speedScale) then
		return
	end

	return walk * data.speedScale, run * data.speedScale
end)
