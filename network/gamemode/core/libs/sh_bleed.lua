NETWORK.bleed = NETWORK.bleed or {}

NETWORK.bleed.max = 6

local PLAYER = FindMetaTable("Player")

function PLAYER:GetBleeding()
	return self:GetNWFloat("nwBleed", 0)
end

function PLAYER:IsBleeding()
	return self:GetBleeding() > 0.05
end

if (CLIENT) then
	local shown = 0

	hook.Add("HUDPaintBackground", "nwBleed", function()
		local client = LocalPlayer()

		if (!IsValid(client) or !client:HasCharacter()) then
			shown = 0

			return
		end

		local amount = math.Clamp(client:GetBleeding() / NETWORK.bleed.max, 0, 1)

		shown = math.Approach(shown, amount, FrameTime() * 0.8)

		if (shown < 0.01) then
			return
		end

		local pulse = 0.75 + math.abs(math.sin(CurTime() * 1.7)) * 0.25

		NETWORK.util.DrawVignette(0, 0, ScrW(), ScrH(),
			math.Round(math.min(ScrW(), ScrH()) * 0.55),
			120 * shown * pulse, Color(120, 12, 14))
	end)

	return
end

function NETWORK.bleed.Set(client, amount)
	client:SetNWFloat("nwBleed",
		math.Clamp(amount or 0, 0, NETWORK.bleed.max))
end

function NETWORK.bleed.Add(client, amount)
	if (!NETWORK.medical or !NETWORK.medical.AddBleed) then
		return
	end

	amount = amount or 0

	if (amount > 0) then
		NETWORK.medical.AddBleed(client, "stomach", amount >= 2 and "major" or "minor")
	elseif (amount < 0) then
		NETWORK.medical.StopAllBleeding(client)
	end
end

function NETWORK.bleed.Clear(client)
	if (NETWORK.medical and NETWORK.medical.StopAllBleeding) then
		NETWORK.medical.StopAllBleeding(client, true)
	else
		NETWORK.bleed.Set(client, 0)
	end
end

function NETWORK.bleed.Splatter(client)
	local source = client

	if (IsValid(client.nwRagdollEntity)) then
		source = client.nwRagdollEntity
	end

	local start = source:WorldSpaceCenter() + Vector(0, 0, 12)
	local trace = util.TraceLine({
		start = start,
		endpos = start - Vector(0, 0, 120),
		filter = {client, source},
		mask = MASK_SOLID_BRUSHONLY
	})

	if (!trace.Hit) then
		return
	end

	util.Decal("Blood", start, trace.HitPos - Vector(0, 0, 8), {client, source})

	local effect = EffectData()

	effect:SetOrigin(trace.HitPos)
	effect:SetNormal(trace.HitNormal)
	effect:SetMagnitude(2)

	util.Effect("BloodImpact", effect)
end

hook.Add("NetworkPlayerHealed", "nwBleed", function(client)
	NETWORK.bleed.Add(client, -1)
end)
