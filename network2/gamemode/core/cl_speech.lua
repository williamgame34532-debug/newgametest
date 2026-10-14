-- Talking, seen in the world (no plates, just text over the head, facing the camera):
--   voice    an animated microphone (cl_voice.lua) while the player talks in voice chat;
--   typing   "Говорит..." / "Шепчет..." / "Кричит..." / "Пишет..." (for anything else) while the
--            player types; it rises in and sinks out;
--   words    every IC message (say, whisper, yell) shows over the speaker's head as "Text" in the
--            colour of that message, for 9-10 seconds (longer text - longer); at most 4 at once,
--            the oldest goes first; new ones push the older ones up;
--   gesture  sometimes a talking gesture (one of ten) plays with an IC message (sv_chat.lua).

local K = NW.chatKinds
local typingText = K.typing

local function Fonts()
	surface.CreateFont("nwSpeech", {font = "Exo 2", size = 54, weight = 600, extended = true, antialias = true})
	surface.CreateFont("nwSpeechTyping", {font = "Montserrat Medium", size = 46, weight = 500, extended = true,
		antialias = true})
end

Fonts()

-- ------------------------------------------------------------------ typing --
-- the state the others should see; sent when it changes (the latest one always gets through),
-- and dropped after 3 seconds without typing (it comes back with the next key)
local IDLE = 3
local typing = {want = 0, sent = 0, changed = 0, text = ""}

local function Wanted(text)
	if (string.Trim(text or "") == "") then
		return 0
	end

	local kind = K.Parse(text)

	return kind == K.IC and 1 or kind == K.WHISPER and 2 or kind == K.YELL and 3 or 4
end

hook.Add("ChatTextChanged", "nwSpeech", function(text)
	if (!IsValid(LocalPlayer()) or LocalPlayer():GetCharacterID() == 0) then
		return
	end

	typing.text = text or ""
	typing.want = Wanted(typing.text)
	typing.changed = RealTime()
end)

hook.Add("FinishChat", "nwSpeech", function()
	typing.text = ""
	typing.want = 0
end)

hook.Add("Think", "nwSpeechTyping", function()
	local state = typing.want

	-- stopped typing for a while: hide it until the next key
	if (state != 0 and RealTime() - typing.changed > IDLE) then
		state = 0
	end

	if (state != typing.sent and RealTime() > (typing.next or 0)) then
		typing.sent = state
		typing.next = RealTime() + 0.15

		net.Start("nwTyping")
			net.WriteUInt(state, 3)
		net.SendToServer()
	end
end)

net.Receive("nwTyping", function()
	local client = net.ReadEntity()
	local state = net.ReadUInt(3)

	if (IsValid(client)) then
		if (state > 0) then
			client.nwTyping = state
		end

		client.nwTypingOn = state > 0
	end
end)

-- ------------------------------------------------------------------- words --
local MAX = 4

hook.Add("NWChatMessage", "nwSpeech", function(kind, speaker, text, color)
	if (kind != K.IC and kind != K.WHISPER and kind != K.YELL) or !IsValid(speaker) then
		return
	end

	speaker.nwWords = speaker.nwWords or {}

	table.insert(speaker.nwWords, {
		text = "\"" .. text .. "\"",
		color = color or color_white,
		born = RealTime(),
		life = math.Clamp(9 + utf8.len(text) / 120, 9, 10)
	})

	while (#speaker.nwWords > MAX) do
		table.remove(speaker.nwWords, 1)
	end

	-- the one typing just said it
	speaker.nwTypingOn = false
end)

-- ---------------------------------------------------------------- gestures --
net.Receive("nwGesture", function()
	local client = net.ReadEntity()
	local index = net.ReadUInt(5)

	if (!IsValid(client) or (client.GetAct and client:GetAct())) then
		return
	end

	-- the chosen one, or the next this model has
	for offset = 0, #K.gestures - 1 do
		local name = K.gestures[(index - 1 + offset) % #K.gestures + 1]
		local sequence = client:LookupSequence(name)

		if (sequence and sequence > 0) then
			client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, sequence, 0, true)

			return
		end
	end
end)

-- ----------------------------------------------------------------- drawing --
local SCALE = 0.05
local RANGE = 900
local WRAP = 1100

local function Lines(entry)
	if (!entry.lines) then
		entry.lines = NW.inventory.WrapText(entry.text, "nwSpeech", WRAP)

		if (#entry.lines > 3) then
			entry.lines = {entry.lines[1], entry.lines[2], entry.lines[3] .. "…"}
		end
	end

	return entry.lines
end

local function Outlined(text, font, x, y, color, alpha)
	draw.SimpleTextOutlined(text, font, x, y, ColorAlpha(color, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2,
		Color(0, 0, 0, alpha * 0.75))
end

hook.Add("PostDrawTranslucentRenderables", "nwSpeech", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	local me = LocalPlayer()
	local eye = EyePos()
	local angle = Angle(0, EyeAngles().y - 90, 90)
	local now = RealTime()
	local dt = FrameTime()

	for _, client in ipairs(player.GetAll()) do
		-- the typing fade
		client.nwTypingFade = math.Approach(client.nwTypingFade or 0, client.nwTypingOn and 1 or 0, dt * 4)

		local words = client.nwWords

		if (words) then
			for index = #words, 1, -1 do
				if (now - words[index].born > words[index].life) then
					table.remove(words, index)
				end
			end
		end

		local typing = client.nwTypingFade > 0.01
		local hasWords = words and #words > 0
		local level, speaking = NW.voice.Level(client)

		speaking = speaking > 0.01 and speaking or nil

		if (!(typing or hasWords or speaking) or !client:Alive() or (client == me and !client:ShouldDrawLocalPlayer())) then
			continue
		end

		local distance = client:GetPos():Distance(eye)

		if (distance > RANGE) then
			continue
		end

		local fade = math.Clamp((RANGE - distance) / 200, 0, 1)
		local head = client:LookupBone("ValveBiped.Bip01_Head1")
		local pos = (head and client:GetBonePosition(head) or client:EyePos()) + Vector(0, 0, 12)

		cam.Start3D2D(pos, angle, SCALE)
			local y = 0

			-- talking in voice: the microphone at the very bottom
			if (speaking) then
				local size = 64

				NW.voice.DrawMic(-size / 2, y - size + (1 - speaking) * 10, size, level, speaking * fade)
				y = y - size - 6
			end

			-- typing
			if (typing) then
				local t = client.nwTypingFade
				local dots = string.rep(".", math.floor(now * 3) % 3 + 1)
				local text = string.gsub(typingText[client.nwTyping or 1] or typingText[4], "%.+$", "") .. dots

				Outlined(text, "nwSpeechTyping", 0, y + (1 - t) * 16, Color(205, 210, 216), 230 * t * fade)
				y = y - 54 * t
			end

			-- the words, newest at the bottom
			for index = #(words or {}), 1, -1 do
				local entry = words[index]
				local age = now - entry.born
				local alpha = math.min(math.Clamp(age / 0.25, 0, 1), math.Clamp((entry.life - age) / 0.6, 0, 1))
				local lines = Lines(entry)

				for k = #lines, 1, -1 do
					Outlined(lines[k], "nwSpeech", 0, y + (1 - alpha) * 12, entry.color, 255 * alpha * fade)
					y = y - 56
				end

				y = y - 9
			end
		cam.End3D2D()
	end
end)
