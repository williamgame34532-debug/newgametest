local SOUNDS = {
	"framework/ambient/str.mp3",
	"framework/ambient/str2.mp3",
	"framework/ambient/str3.mp3",
	"framework/ambient/str4.mp3"
}

local function PlayNear(client)
	local offset = VectorRand()

	offset.z = math.Rand(0.1, 0.6)
	offset:Normalize()

	local position = client:GetPos() + offset * math.Rand(280, 620)

	sound.Play(SOUNDS[math.random(#SOUNDS)], position,
		62, math.random(92, 104), 0.8)
end

timer.Create("nwAmbientFX", 12, 0, function()
	if (math.random() > 0.28) then
		return
	end

	local players = {}

	for _, client in ipairs(player.GetAll()) do
		if (client:Alive() and client:HasCharacter()) then
			players[#players + 1] = client
		end
	end

	if (#players == 0) then
		return
	end

	local client = players[math.random(#players)]

	if ((client.nwNextAmbient or 0) > CurTime()) then
		return
	end

	client.nwNextAmbient = CurTime() + math.Rand(40, 90)

	PlayNear(client)
end)
