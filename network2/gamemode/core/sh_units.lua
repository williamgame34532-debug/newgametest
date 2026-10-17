-- Units of the Alliance: the name of the unit and the callsign.
--   A character who joins a faction with FACTION.unitPrefix gets a unit name instead of the
--   civil one: "C24.MPD.RCT:443" (Civil Protection), "C24.OTA.ECHO:443" (the Combine); the number
--   000..999 is random and kept with the character. Leaving the faction gives the civil name back.
--   A callsign is chosen at an NPC with the answer "Выдать позывной" (sh_npc.lua): a word of the
--   side and a number 1..9, unique among the units in the game. It is added to the name:
--   "C24.MPD.RCT:443 (Виктор-4)". The dispatcher says it (NW.units.Voice).
-- Members of the Alliance know each other's unit names (NWRecognizes).

NW.units = NW.units or {}

local UN = NW.units

-- the words, by side ("cp" - Civil Protection, "ota" - the Combine); voice - the Overwatch / the
-- soldiers' radio saying it (nil - the dispatcher says the number only)
UN.callsigns = {
	cp = {
		{id = "victor", name = "Виктор", voice = "npc/overwatch/radiovoice/victor.wav"},
		{id = "jury", name = "Судья", voice = "npc/overwatch/radiovoice/jury.wav"},
		{id = "protector", name = "Защитник", voice = "npc/overwatch/radiovoice/defender.wav"},
		{id = "lock", name = "Лок", voice = "npc/metropolice/vo/line.wav"},
		{id = "vice", name = "Порок", voice = "npc/overwatch/radiovoice/vice.wav"},
		{id = "union", name = "Союз", voice = "npc/overwatch/radiovoice/union.wav"},
		{id = "quick", name = "Быстрый", voice = "npc/overwatch/radiovoice/quick.wav"},
		{id = "stick", name = "Жезл", voice = "npc/overwatch/radiovoice/stick.wav"},
		{id = "yellow", name = "Жёлтый", voice = "npc/overwatch/radiovoice/yellow.wav"},
		{id = "xray", name = "Рентген", voice = "npc/overwatch/radiovoice/xray.wav"},
		{id = "hero", name = "Герой", voice = "npc/overwatch/radiovoice/hero.wav"},
		{id = "king", name = "Король", voice = "npc/overwatch/radiovoice/king.wav"},
		{id = "fenix", name = "Феникс"}
	},
	ota = {
		{id = "dagger", name = "Кинжал", voice = "npc/combine_soldier/vo/dagger.wav"},
		{id = "hammer", name = "Молот", voice = "npc/combine_soldier/vo/hammer.wav"},
		{id = "razor", name = "Бритва", voice = "npc/combine_soldier/vo/razor.wav"},
		{id = "blade", name = "Клинок", voice = "npc/combine_soldier/vo/blade.wav"},
		{id = "sweeper", name = "Дворник", voice = "npc/combine_soldier/vo/sweeper.wav"},
		{id = "savage", name = "Дикарь", voice = "npc/combine_soldier/vo/savage.wav"},
		{id = "flash", name = "Вспышка", voice = "npc/combine_soldier/vo/flash.wav"},
		{id = "hunter", name = "Охотник", voice = "npc/combine_soldier/vo/hunter.wav"},
		{id = "swift", name = "Быстрый", voice = "npc/combine_soldier/vo/swift.wav"},
		{id = "leader", name = "Лидер", voice = "npc/combine_soldier/vo/leader.wav"}
	}
}

-- the numbers as the side's voice says them
UN.numbers = {
	cp = "npc/overwatch/radiovoice/%s.wav",
	ota = "npc/combine_soldier/vo/%s.wav"
}

UN.numberWords = {"one", "two", "three", "four", "five", "six", "seven", "eight", "nine"}

UN.byID = {}

for side, list in pairs(UN.callsigns) do
	UN.byID[side] = {}

	for _, entry in ipairs(list) do
		UN.byID[side][entry.id] = entry
	end
end

-- the side of a faction: "ota" for the Combine, "cp" for the rest of the Alliance
function UN.Side(faction)
	return faction == "combine" and "ota" or "cp"
end

-- "Виктор-4" for {id = "victor", num = 4}
function UN.CallsignText(side, callsign)
	local entry = istable(callsign) and UN.byID[side] and UN.byID[side][callsign.id]

	if (!entry or !tonumber(callsign.num)) then
		return
	end

	return entry.name .. "-" .. callsign.num
end

-- the sound files the dispatcher says for a callsign (the word and the number)
function UN.VoiceFor(side, callsign)
	local out = {}
	local entry = istable(callsign) and UN.byID[side] and UN.byID[side][callsign.id]

	if (entry and entry.voice) then
		out[#out + 1] = entry.voice
	end

	local word = UN.numberWords[tonumber(callsign and callsign.num) or 0]

	if (word) then
		out[#out + 1] = string.format(UN.numbers[side] or UN.numbers.cp, word)
	end

	return out
end

-- the Alliance knows its own
hook.Add("NWRecognizes", "nwUnits", function(client, target)
	if (NW.zones and NW.zones.IsAlliance(client) and NW.zones.IsAlliance(target)) then
		return true
	end
end)

if (SERVER) then
	return
end

-- the dispatcher speaks: the sounds one after another, over the radio (only for the one who hears)
net.Receive("nwDispatchVoice", function()
	local count = net.ReadUInt(4)
	local list = {}

	for i = 1, count do
		list[i] = net.ReadString()
	end

	local delay = 0

	for _, path in ipairs(list) do
		timer.Simple(delay, function()
			surface.PlaySound(path)
		end)

		local length = SoundDuration(path)

		delay = delay + ((length and length > 0.05 and length < 5) and length + 0.05 or 0.6)
	end
end)
