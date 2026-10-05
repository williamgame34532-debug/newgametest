DeriveGamemode("sandbox")

include("shared.lua")

local hidden = {
	CHudHealth = true,
	CHudBattery = true,
	CHudAmmo = true,
	CHudSecondaryAmmo = true,
	CHudCrosshair = true,
	CHudDamageIndicator = true,
	CHudSuitPower = true,
	CHudChat = true,
	CHudDeathNotice = true,
	CHudVoiceStatus = true,
	CHudVoiceSelfStatus = true
}

hook.Add("HUDShouldDraw", "nwHideDefaultHUD", function(element)
	if (hidden[element]) then
		return false
	end
end)

function GM:HUDShouldDraw(element)
	if (IsValid(NETWORK.gui.menu)) then
		return false
	end

	if (hidden[element]) then
		return false
	end

	return true
end

function GM:HUDDrawTargetID()
	return false
end

hook.Add("InitPostEntity", "nwKillfeed", function()
	RunConsoleCommand("hud_deathnotice_time", "0")
	RunConsoleCommand("cl_showhelp", "0")
end)

timer.Create("nwKillfeed", 30, 0, function()
	local convar = GetConVar("hud_deathnotice_time")

	if (convar and convar:GetFloat() > 0) then
		RunConsoleCommand("hud_deathnotice_time", "0")
	end
end)

function GM:InitPostEntity()
	NETWORK.character.Request()

	timer.Simple(0.5, function()
		NETWORK.gui.OpenMainMenu()
	end)
end

function GM:ScoreboardShow()

	if (IsValid(NETWORK.gui.chat) and NETWORK.gui.chat.bActive) then
		return true
	end

	NETWORK.gui.ToggleTabMenu()

	return true
end

function GM:ScoreboardHide()
	return true
end

function GM:OnReloaded()
	NETWORK.gui.CloseAll()
	NETWORK.gui.CloseTabMenu()

	NETWORK.character.Request()
end

net.Receive("nwOpenMenu", function()
	NETWORK.gui.OpenMainMenu()
end)

concommand.Add("network_menu", function()
	NETWORK.gui.OpenMainMenu()
end)
