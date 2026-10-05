hook.Add("Initialize", "nwMovementConVars", function()

	game.ConsoleCommand("sv_airaccelerate 10\n")
	game.ConsoleCommand("sv_accelerate 10\n")
	game.ConsoleCommand("sv_friction 4\n")
	game.ConsoleCommand("sv_stopspeed 75\n")
	game.ConsoleCommand("sv_gravity 600\n")
end)

hook.Add("PlayerSpawn", "nwMovementApply", function(client)
	timer.Simple(0, function()
		if (IsValid(client)) then
			NETWORK.movement.Apply(client)
		end
	end)
end)

concommand.Add("network_movement", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	local config = NETWORK.movement

	NETWORK.util.Print(string.format("шаг %d | бег %d | прыжок %d | кулдаун %.2f | воздух %d",
		config.walkSpeed, config.runSpeed, config.jumpPower, config.jumpCooldown,
		config.airSpeedCap))
end)
