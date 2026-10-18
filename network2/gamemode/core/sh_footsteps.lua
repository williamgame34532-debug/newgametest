-- The steps of the Overwatch soldiers (the faction combine): heavy boots on metal grating
-- (sound/network2/combine/step1-4.wav) instead of the usual footsteps; running - louder, walking - softer,
-- crouching - quiet. Shared: the walker hears his own at once (prediction), the others from the server.

local STEPS = {}

for index = 1, 4 do
	STEPS[index] = "network2/combine/step" .. index .. ".wav"
end

hook.Add("PlayerFootstep", "nwCombineSteps", function(client, _, _, _, volume)
	if (client:GetFaction() != "combine") then
		return
	end

	local speed = client:GetVelocity():Length2D()
	local running = speed > client:GetWalkSpeed() * 1.2
	local level = client:Crouching() and 60 or (running and 76 or 68)
	local loud = client:Crouching() and 0.35 or (running and 0.9 or 0.6)

	client.nwStep = (client.nwStep or 0) % #STEPS + 1
	client:EmitSound(STEPS[client.nwStep], level, math.random(95, 105), loud * math.max(volume or 1, 0.5))

	return true
end)
