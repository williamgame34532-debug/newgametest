local function Sound(name)
	if (file.Exists("sound/items/nvg_" .. name .. ".wav", "GAME")) then
		return "items/nvg_" .. name .. ".wav", 100
	end

	return "items/flashlight1.wav", name == "on" and 80 or 65
end

function NETWORK.nvg.Set(client, bState)
	if (!NETWORK.nvg.CanUse(client)) then
		bState = false
	end

	bState = tobool(bState)

	if (client:GetNWBool("nwNVG", false) == bState) then
		return false
	end

	if (bState and NETWORK.nvg.GetCharge(client) < NETWORK.nvg.minStart) then
		client:EmitSound("buttons/combine_button_locked.wav", 55, 80)
		NETWORK.chat.Notice(client, "nvgEmpty")

		return false
	end

	client:SetNWBool("nwNVG", bState)

	local path, pitch = Sound(bState and "on" or "off")

	client:EmitSound(path, 60, pitch)

	hook.Run("NetworkNVGToggled", client, bState)

	return true
end

function NETWORK.nvg.Toggle(client)
	return NETWORK.nvg.Set(client, !client:GetNWBool("nwNVG", false))
end

concommand.Add("nw_nvg", function(client)
	if (!IsValid(client) or !client:Alive()) then
		return
	end

	if ((client.nwNextNVG or 0) > CurTime()) then
		return
	end

	client.nwNextNVG = CurTime() + 0.4

	NETWORK.nvg.Toggle(client)
end)

hook.Add("Think", "nwNVGCharge", function()
	if ((NETWORK.nvg.nextTick or 0) > CurTime()) then
		return
	end

	local step = 0.5

	NETWORK.nvg.nextTick = CurTime() + step

	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter()) then
			continue
		end

		local charge = NETWORK.nvg.GetCharge(client)
		local bActive = client:GetNWBool("nwNVG", false)

		if (bActive) then
			if (!client:Alive() or !NETWORK.nvg.CanUse(client)) then
				NETWORK.nvg.Set(client, false)

				continue
			end

			charge = charge - step / NETWORK.nvg.duration

			if (charge <= 0) then
				charge = 0

				NETWORK.nvg.Set(client, false)
			end
		elseif (charge < 1) then
			charge = math.min(charge + step / NETWORK.nvg.recharge, 1)
		end

		if (math.abs(charge - client:GetNWFloat("nwNVGCharge", 1)) > 0.001) then
			client:SetNWFloat("nwNVGCharge", charge)
		end
	end
end)

hook.Add("PlayerSwitchFlashlight", "nwNVG", function(client, bState)
	if (!NETWORK.nvg.CanUse(client)) then
		return
	end

	if (bState and (client.nwNextNVG or 0) <= CurTime()) then
		client.nwNextNVG = CurTime() + 0.4

		NETWORK.nvg.Toggle(client)
	end

	return false
end)

hook.Add("PlayerDeath", "nwNVG", function(client)
	NETWORK.nvg.Set(client, false)
end)

hook.Add("NetworkCharacterLoaded", "nwNVG", function(client)
	client:SetNWBool("nwNVG", false)
	client:SetNWFloat("nwNVGCharge", 1)
end)
