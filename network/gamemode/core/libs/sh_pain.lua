NETWORK.wound = NETWORK.wound or {}

NETWORK.wound.painTime = 45
NETWORK.wound.painkillerTime = 150
NETWORK.wound.painSpeed = 0.7

function NETWORK.wound.GetPain(client)
	return math.max(client:GetNWFloat("nwPain", 0) - CurTime(), 0)
end

function NETWORK.wound.IsNumb(client)
	return client:GetNWFloat("nwPainkiller", 0) > CurTime()
end

if (SERVER) then

	function NETWORK.wound.Pain(client, duration)
		if (NETWORK.wound.IsNumb(client)) then
			return false
		end

		duration = duration or NETWORK.wound.painTime

		if (NETWORK.toughness) then
			duration = duration * (NETWORK.toughness.Get(client, "pain") or 1)

			if (duration <= 0) then
				return false
			end
		end

		client:SetNWFloat("nwPain", CurTime() + duration)

		return true
	end

	function NETWORK.wound.Numb(client, duration)
		client:SetNWFloat("nwPainkiller", CurTime() +
			(duration or NETWORK.wound.painkillerTime))
		client:SetNWFloat("nwPain", 0)
	end

	hook.Add("PlayerSpawn", "nwPain", function(client)
		client:SetNWFloat("nwPain", 0)
		client:SetNWFloat("nwPainkiller", 0)
	end)

	hook.Add("NetworkMovementSpeed", "nwPain", function(client, walk, run)
		if (NETWORK.wound.GetPain(client) <= 0) then
			return
		end

		return walk * NETWORK.wound.painSpeed, run * NETWORK.wound.painSpeed
	end)
else
	local BLUR = Material("pp/blurscreen")

	hook.Add("RenderScreenspaceEffects", "nwPain", function()
		local client = LocalPlayer()

		if (!IsValid(client) or !client:Alive()) then
			return
		end

		local left = NETWORK.wound.GetPain(client)

		if (left <= 0) then
			return
		end

		local strength = math.Clamp(left / NETWORK.wound.painTime, 0.25, 1)
		local pulse = 0.55 + math.abs(math.sin(CurTime() * 1.6)) * 0.45
		local amount = strength * pulse

		DrawColorModify({
			["$pp_colour_addr"] = 0.02 * amount,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.04 * amount,
			["$pp_colour_contrast"] = 1 + 0.12 * amount,
			["$pp_colour_colour"] = 1 - 0.45 * amount,
			["$pp_colour_mulr"] = 0.1 * amount,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})

		render.UpdateScreenEffectTexture()

		surface.SetMaterial(BLUR)
		surface.SetDrawColor(255, 255, 255, 255)

		for pass = 1, 3 do
			BLUR:SetFloat("$blur", amount * 1.4 * (pass / 3))
			BLUR:Recompute()

			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		end
	end)

	hook.Add("NetworkDrawHUD", "nwPain", function()
		local client = LocalPlayer()

		if (!IsValid(client) or NETWORK.wound.GetPain(client) <= 0) then
			return
		end

		local Sc = NETWORK.util.Scale
		local pulse = 0.4 + math.abs(math.sin(CurTime() * 1.6)) * 0.6

		NETWORK.util.DrawSimpleTextShadow(L("painHurts"), "nwHudSmall",
			math.Round(ScrW() * 0.5), math.Round(ScrH() * 0.5) + Sc(150),
			ColorAlpha(NETWORK.theme.danger, 220 * pulse * NETWORK.hud.GetFade()),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, math.max(Sc(2), 1))
	end)
end
