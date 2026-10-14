-- Music. Three moods with smooth crossfades between them:
--   menu     the main menu and the character screens - a1_intro_strider2, looped, quiet;
--   passive  in the world - the passive tracks, shuffled, one after another;
--   combat   when a fight starts (sv_music.lua) - the combat tracks; about 20 seconds after the
--            last shot or hit it fades back into the passive music.
-- Files: sound/network2/music/{menu,passive,combat}/. Settings (Q menu → Настройки):
-- nw_music (on / off), nw_music_volume (0..1).

NW.music = NW.music or {}

local MU = NW.music
local enabled = CreateClientConVar("nw_music", "1", true, false, "Музыка")
local volume = CreateClientConVar("nw_music_volume", "0.5", true, false, "Громкость музыки", 0, 1)

local TRACKS = {
	menu = {"sound/network2/music/menu/a1_intro_strider2.mp3"},
	passive = {},
	combat = {}
}

for i = 1, 10 do
	TRACKS.passive[i] = string.format("sound/network2/music/passive/passivemusic_%02d.mp3", i)
end

for i = 1, 5 do
	TRACKS.combat[i] = "sound/network2/music/combat/combinemusic_" .. i .. ".mp3"
end

-- how loud each mood is (times nw_music_volume) and how fast it comes in / goes out
local LEVEL = {menu = 0.35, passive = 0.55, combat = 0.8}
local FADE_IN = {menu = 3, passive = 6, combat = 1.5}
local FADE_OUT = {menu = 2.5, passive = 2, combat = 6}
local COMBAT_HOLD = 20

MU.channels = MU.channels or {}
MU.combatUntil = 0
MU.lastTrack = MU.lastTrack or {}

net.Receive("nwCombat", function()
	MU.combatUntil = CurTime() + COMBAT_HOLD
end)

local function Mood()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	if ((NW.menu and NW.menu.active) or client:GetNW2Bool("nwInMenu", false)) then
		return "menu"
	end

	if (client:GetCharacterID() == 0) then
		return
	end

	if (MU.combatUntil > CurTime() and client:Alive()) then
		return "combat"
	end

	return "passive"
end

-- a track of the mood, not the same as the last one when there is a choice
local function Pick(mood)
	local list = TRACKS[mood]

	if (#list == 1) then
		return list[1]
	end

	local track

	repeat
		track = list[math.random(#list)]
	until (track != MU.lastTrack[mood])

	MU.lastTrack[mood] = track

	return track
end

local function Start(mood)
	local entry = {mood = mood, volume = 0, loading = true}

	MU.channels[#MU.channels + 1] = entry

	sound.PlayFile(Pick(mood), "noplay noblock", function(channel)
		if (!IsValid(channel)) then
			entry.dead = true

			return
		end

		if (entry.dead) then
			channel:Stop()

			return
		end

		entry.channel = channel
		entry.loading = false
		channel:SetVolume(0)
		channel:EnableLooping(mood == "menu")
		channel:Play()
	end)

	return entry
end

hook.Add("Think", "nwMusic", function()
	local mood = enabled:GetBool() and Mood() or nil
	local master = volume:GetFloat()
	local dt = FrameTime()
	local current

	for _, entry in ipairs(MU.channels) do
		if (entry.mood == mood and !entry.leaving) then
			current = entry
		end
	end

	-- the wanted mood has no channel yet: start one
	if (mood and !current) then
		current = Start(mood)
	end

	for index = #MU.channels, 1, -1 do
		local entry = MU.channels[index]

		if (entry != current) then
			entry.leaving = true
		end

		local target = entry.leaving and 0 or LEVEL[entry.mood] * master
		local speed = entry.leaving and FADE_OUT[entry.mood] or FADE_IN[entry.mood]

		entry.volume = math.Approach(entry.volume, target, dt * (LEVEL[entry.mood] / speed))

		local channel = entry.channel

		if (IsValid(channel)) then
			channel:SetVolume(entry.volume)

			-- a track that ended: the next one of the same mood
			if (!entry.leaving and channel:GetState() == GMOD_CHANNEL_STOPPED) then
				entry.leaving = true
				entry.volume = 0
			end
		end

		if (entry.leaving and entry.volume <= 0 and !entry.loading) then
			if (IsValid(channel)) then
				channel:Stop()
			end

			entry.dead = true
			table.remove(MU.channels, index)
		end
	end
end)

concommand.Add("nw_music_next", function()
	for _, entry in ipairs(MU.channels) do
		entry.leaving = true
	end
end)
