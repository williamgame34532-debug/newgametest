local C = NETWORK.climate

C.tick = 6

local function IsOutside(client)
	if (client:WaterLevel() >= 2) then
		return true, true
	end

	local trace = util.TraceLine({
		start = client:EyePos(),
		endpos = client:EyePos() + Vector(0, 0, 4096),
		mask = MASK_SOLID_BRUSHONLY
	})

	return !trace.Hit or trace.HitSky, false
end

local function Push(client, key, value)
	value = math.Clamp(value, 0, 100)

	if (math.abs(client:GetNWFloat(key, 0) - value) >= 0.5 or value == 0) then
		client:SetNWFloat(key, value)
	end

	return value
end

local function Notice(client, key, tone)
	client.nwClimateNotice = client.nwClimateNotice or {}

	if ((client.nwClimateNotice[key] or 0) > CurTime()) then
		return
	end

	client.nwClimateNotice[key] = CurTime() + 60

	NETWORK.notice.Send(client, key, tone)
end

function C.Reset(client)
	client:SetNWFloat("nwCold", 0)
	client:SetNWFloat("nwWet", 0)
end

function C.Update(client)
	if (!client:Alive() or !client:HasCharacter()) then
		return
	end

	if (C.IsExempt(client) or NETWORK.config.Get("climate") == false) then
		if (client:GetCold() > 0 or client:GetWet() > 0) then
			C.Reset(client)
		end

		return
	end

	local state = NETWORK.inventory.GetState(client)
	local equipped = state and state.equipped or {}
	local warmth = C.GetWarmth(equipped)
	local bOutside, bWater = IsOutside(client)
	local rain = NETWORK.weather.GetValue and NETWORK.weather.GetValue("rain") or 0
	local wet = client:GetWet()
	local cold = client:GetCold()
	local rate = NETWORK.config.Get("climateColdRate") or 1.5

	if (bWater) then
		wet = 100
	elseif (bOutside and rain > 0.15) then
		wet = wet + rain * (C.HasCoat(equipped) and 3 or 6)
	else
		wet = wet - 3
	end

	wet = Push(client, "nwWet", wet)

	local demand = C.GetDemand() + (wet >= 50 and 1 or 0)
	local deficit = demand - warmth

	if (bOutside and deficit > 0) then
		cold = cold + deficit * rate
	else
		cold = cold - (bOutside and 2 or 4)
	end

	local previous = client:GetCold()

	cold = Push(client, "nwCold", cold)

	if (cold >= C.coldFreeze) then
		Notice(client, "climateFreezing", "warn")

		if (NETWORK.config.Get("climateDamage") != false) then
			client:TakeDamage(1, client, client)
		end
	elseif (cold >= C.coldWarn) then
		if (previous < C.coldWarn) then
			client.nwClimateNotice = client.nwClimateNotice or {}
			client.nwClimateNotice.climateCold = 0
		end

		Notice(client, "climateCold", "warn")
	elseif (previous >= C.coldWarn and cold < C.coldWarn) then
		Notice(client, "climateWarm", "good")
	end

	if (wet >= C.wetWarn and client:GetNWFloat("nwWetWas", 0) < C.wetWarn) then
		Notice(client, "climateWet", "warn")
	end

	client:SetNWFloat("nwWetWas", wet)
end

timer.Create("nwClimate", C.tick, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (client:IsBot()) then
			continue
		end

		local bOk, err = pcall(C.Update, client)

		if (!bOk) then
			NETWORK.util.PrintWarning("[climate] " .. tostring(err))
		end
	end
end)

hook.Add("PlayerSpawn", "nwClimateReset", function(client)
	C.Reset(client)
	client.nwClimateNotice = nil
end)

NETWORK.command.Register("climate", {
	description = "cmdClimate",
	usage = "/climate",
	adminOnly = true,
	OnRun = function(command, client)
		local state = NETWORK.inventory.GetState(client)
		local bOutside = IsOutside(client)

		NETWORK.chat.Notice(client, L("climateInfo", math.Round(client:GetCold()),
			math.Round(client:GetWet()), C.GetWarmth(state and state.equipped),
			C.GetDemand(), bOutside and L("climateOutside") or L("climateInside"),
			C.IsExempt(client) and L("climateExempt") or "—"))
	end
})
