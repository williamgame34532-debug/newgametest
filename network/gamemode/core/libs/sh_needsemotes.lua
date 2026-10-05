NETWORK.needs.emotes = NETWORK.needs.emotes or {}

NETWORK.needs.emotes.thresholds = {
	{need = "nwThirst", value = 35, keys = {"emoteThirst1", "emoteThirst2"}},
	{need = "nwThirst", value = 15, keys = {"emoteThirst3", "emoteThirst4"}},
	{need = "nwHunger", value = 35, keys = {"emoteHunger1", "emoteHunger2"}},
	{need = "nwHunger", value = 15, keys = {"emoteHunger3", "emoteHunger4"}}
}

NETWORK.needs.emotes.minDelay = 70
NETWORK.needs.emotes.maxDelay = 130

NETWORK.config.Register("needsEmotes", {
	name = "cfgNeedsEmotes",
	description = "cfgNeedsEmotesDesc",
	category = "needs",
	type = "bool",
	default = true
})

NETWORK.config.Register("weatherEmotes", {
	name = "cfgWeatherEmotes",
	description = "cfgWeatherEmotesDesc",
	category = "needs",
	type = "bool",
	default = true
})

NETWORK.config.Register("needsEmoteDelay", {
	name = "cfgEmoteDelay",
	description = "cfgEmoteDelayDesc",
	category = "needs",
	type = "number",
	min = 20,
	max = 600,
	default = 100
})

function NETWORK.needs.emotes.GetDelay()
	local base = math.Clamp(NETWORK.config.Get("needsEmoteDelay") or 100,
		20, 600)

	return math.Round(base * 0.7), math.Round(base * 1.3)
end

NETWORK.needs.emoteMark = "\1"

function NETWORK.needs.IsEmote(text)
	return isstring(text) and string.sub(text, 1, 1) == NETWORK.needs.emoteMark
end

function NETWORK.needs.StripMark(text)
	if (!NETWORK.needs.IsEmote(text)) then
		return text
	end

	return string.sub(text, 2)
end

if (SERVER) then
	local function Emote(client, key)

		NETWORK.chat.Send(client, "me",
			NETWORK.needs.emoteMark .. L(key, client))
	end

	timer.Create("nwNeedsEmotes", 10, 0, function()
		for _, client in ipairs(player.GetAll()) do
			if (!client:Alive() or !client:HasCharacter()) then
				continue
			end

			if ((client.nwNextEmote or 0) > CurTime()) then
				continue
			end

			if (NETWORK.config.Get("needsEmotes") == false) then
				continue
			end

			local chosen

			for _, entry in ipairs(NETWORK.needs.emotes.thresholds) do
				if (client:GetNWFloat(entry.need, 100) <= entry.value) then
					if (!chosen or entry.value < chosen.value) then
						chosen = entry
					end
				end
			end

			if (!chosen) then
				continue
			end

			client.nwNextEmote = CurTime() +
				math.random(NETWORK.needs.emotes.GetDelay())

			Emote(client, chosen.keys[math.random(#chosen.keys)])
		end
	end)

	timer.Create("nwWeatherEmotes", 20, 0, function()

		if (NETWORK.config.Get("weatherEmotes") == false) then
			return
		end

		if (!NETWORK.time or !NETWORK.time.IsNight or !NETWORK.time.IsNight()) then
			return
		end

		for _, client in ipairs(player.GetAll()) do
			if (!client:Alive() or !client:HasCharacter()) then
				continue
			end

			if ((client.nwNextWeatherEmote or 0) > CurTime()) then
				continue
			end

			local trace = util.TraceLine({
				start = client:EyePos(),
				endpos = client:EyePos() + Vector(0, 0, 4096),
				filter = client,
				mask = MASK_SOLID_BRUSHONLY
			})

			if (trace.Hit and !trace.HitSky) then
				continue
			end

			client.nwNextWeatherEmote = CurTime() + math.random(90, 180)

			Emote(client, ({"emoteCold1", "emoteCold2", "emoteCold3"})
				[math.random(3)])
		end
	end)
end
