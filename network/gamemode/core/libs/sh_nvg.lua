NETWORK.nvg = NETWORK.nvg or {}

NETWORK.nvg.duration = 150
NETWORK.nvg.recharge = 60
NETWORK.nvg.minStart = 0.15

NETWORK.nvg.factions = {
	cp = true,
	cmb = true,
	worker = true,
	disinfector = true
}

NETWORK.nvg.flashlightClasses = {
	administration = true,
	cwuhead = true,
	council = true
}

function NETWORK.nvg.HasFlashlight(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	return NETWORK.nvg.flashlightClasses[client:GetNWString("nwClass", "")] == true
end

function NETWORK.nvg.CanUse(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	if (NETWORK.nvg.HasFlashlight(client)) then
		return false
	end

	if (NETWORK.classes and NETWORK.classes.HasCivilianHud(client)) then
		return false
	end

	local faction = client:GetCharacterFaction()

	if (faction and NETWORK.nvg.factions[faction]) then
		return true
	end

	return client:IsCombine() or (client.IsCWUMember and client:IsCWUMember())
end

function NETWORK.nvg.IsActive(client)
	return IsValid(client) and client:GetNWBool("nwNVG", false)
end

function NETWORK.nvg.GetCharge(client)
	return IsValid(client) and math.Clamp(client:GetNWFloat("nwNVGCharge", 1), 0, 1) or 0
end

function NETWORK.nvg.GetTimeLeft(client)
	return NETWORK.nvg.GetCharge(client) * NETWORK.nvg.duration
end

function NETWORK.nvg.FormatTime(seconds)
	seconds = math.max(math.floor(seconds + 0.5), 0)

	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
