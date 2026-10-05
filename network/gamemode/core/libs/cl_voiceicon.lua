NETWORK.voiceicon = NETWORK.voiceicon or {}
NETWORK.voiceicon.list = NETWORK.voiceicon.list or {}
NETWORK.voiceicon.range = 700
NETWORK.voiceicon.size = 44

local ICON = Material("framework/icons/voice.png", "smooth")

local OVERHEAD_SPEAK = {"framework/voice/waves.png", "framework/chat/ui_mic.png"}
local OVERHEAD_RADIO = {"framework/voice/broadcast.png", "framework/status/radio.png"}
local OVERHEAD_WHISPER = {"framework/voice/whisper.png", "framework/icons/volume_down.png"}
local OVERHEAD_YELL = {"framework/voice/yell.png", "framework/chat/ui_mic.png"}

local function FirstMaterial(chain)
	for _, path in ipairs(chain) do
		local material = NETWORK.util.GetMaterial(path, "smooth")

		if (material and !material:IsError()) then
			return material
		end
	end
end

local function GetOverheadMaterial(speaker, bRadio, level)
	if (bRadio) then
		return FirstMaterial(OVERHEAD_RADIO)
	end

	local index = 2

	if (NETWORK.act and NETWORK.act.GetVoiceMode) then
		local _, modeIndex = NETWORK.act.GetVoiceMode(speaker)

		index = modeIndex or 2
	end

	if (index == 1) then
		return FirstMaterial(OVERHEAD_WHISPER)
	elseif (index == 3) then
		return FirstMaterial(OVERHEAD_YELL)
	end

	return FirstMaterial(OVERHEAD_SPEAK)
end

local function IsOnRadio(speaker)
	local client = LocalPlayer()

	if (!IsValid(client) or !speaker:GetNWBool("nwRadio", false)) then
		return false
	end

	local squad = speaker:GetNWString("nwSquad", "")

	return squad != "" and client:GetNWString("nwSquad", "") == squad
end

local function IsHelmetRadio(speaker)
	local client = LocalPlayer()

	if (!IsValid(client) or !IsValid(speaker) or !speaker:HasCharacter()) then
		return false
	end

	if (!NETWORK.factions.IsAlliance(speaker)) then
		return false
	end

	return client:GetPos():Distance(speaker:GetPos()) <= NETWORK.voiceicon.range
end

local function PlaySquelch(sounds)
	if (!sounds or #sounds == 0) then
		return
	end

	surface.PlaySound(sounds[math.random(#sounds)])
end

function NETWORK.voiceicon.Start(speaker)
	if (!IsValid(speaker)) then
		return
	end

	NETWORK.voiceicon.list[speaker:EntIndex()] = speaker

	if (IsOnRadio(speaker)) then
		PlaySquelch(NETWORK.chat.radioOn)
	elseif (IsHelmetRadio(speaker)) then
		PlaySquelch(NETWORK.chat.radioOnRadio or NETWORK.chat.radioOn)
	end
end

function NETWORK.voiceicon.Stop(speaker)
	if (!IsValid(speaker)) then
		return
	end

	NETWORK.voiceicon.list[speaker:EntIndex()] = nil

	if (IsOnRadio(speaker)) then
		PlaySquelch(NETWORK.chat.radioOff)
	elseif (IsHelmetRadio(speaker)) then
		PlaySquelch(NETWORK.chat.radioOff)
	end
end

hook.Add("HUDPaint", "nwVoiceIcon", function()
	if (NETWORK.hud.IsHidden()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or IsValid(NETWORK.gui.menu)) then
		return
	end

	local Sc = NETWORK.util.Scale
	local eyePos = client:EyePos()
	local size = Sc(NETWORK.voiceicon.size)

	for index, speaker in pairs(NETWORK.voiceicon.list) do
		if (!IsValid(speaker) or !speaker:Alive() or !speaker:IsSpeaking()) then
			NETWORK.voiceicon.list[index] = nil

			continue
		end

		local top = NETWORK.nameplate.GetAnchor(speaker) + Vector(0, 0, 12)
		local distance = eyePos:Distance(top)

		if (distance > NETWORK.voiceicon.range) then
			continue
		end

		if (speaker:GetMoveType() == MOVETYPE_NOCLIP) then
			continue
		end

		local overhead = NETWORK.gui.voice and NETWORK.gui.voice.overhead and
			NETWORK.gui.voice.overhead[index]

		if (overhead and RealTime() - overhead < 0.2) then
			continue
		end

		local trace = util.TraceLine({
			start = eyePos,
			endpos = top,
			filter = {client, speaker},
			mask = MASK_VISIBLE
		})

		if (trace.Hit) then
			continue
		end

		local screen = top:ToScreen()

		if (!screen.visible) then
			continue
		end

		local fade = 1 - math.Clamp((distance - NETWORK.voiceicon.range * 0.6) /
			(NETWORK.voiceicon.range * 0.4), 0, 1)

		local level = math.Clamp(speaker:VoiceVolume() * 2.2, 0, 1)
		local factionID = speaker:GetCharacterFaction()
		local faction = factionID and NETWORK.factions.Get(factionID)
		local colour = faction and faction.color or NETWORK.theme.text

		if (!LocalPlayer():KnowsRoleOf(speaker)) then
			colour = NETWORK.recognition.strangerColor
		end

		local bRadio = IsOnRadio(speaker) or IsHelmetRadio(speaker)

		local material = GetOverheadMaterial(speaker, bRadio, level)
		local iconSize = math.Round(size * 0.5 * (1 + level * 0.25))
		local x = math.Round(screen.x - iconSize * 0.5)
		local y = math.Round(screen.y - iconSize)

		if (material and !material:IsError()) then
			surface.SetMaterial(material)
			surface.SetDrawColor(0, 0, 0, 170 * fade)
			surface.DrawTexturedRect(x + 1, y + 2, iconSize, iconSize)
			surface.SetDrawColor(colour.r, colour.g, colour.b, 250 * fade)
			surface.DrawTexturedRect(x, y, iconSize, iconSize)
		else
			local bar = math.max(Sc(3), 2)

			surface.SetDrawColor(colour.r, colour.g, colour.b, 250 * fade)
			surface.DrawRect(math.Round(screen.x - bar * 0.5), y, bar, iconSize)
		end

		local lineWidth = math.Round(size * 0.5)
		local lineX = math.Round(screen.x - lineWidth * 0.5)
		local lineY = math.Round(screen.y) + Sc(2)
		local thick = math.max(Sc(3), 2)
		local radius = math.floor(thick * 0.5)
		local fill = math.Round(lineWidth * level)

		draw.RoundedBox(radius + 1, lineX - 1, lineY - 1, lineWidth + 2, thick + 2,
			Color(0, 0, 0, 150 * fade))
		draw.RoundedBox(radius, lineX, lineY, lineWidth, thick,
			Color(colour.r, colour.g, colour.b, 90 * fade))

		if (fill >= thick) then
			draw.RoundedBox(radius, lineX, lineY, fill, thick,
				Color(colour.r, colour.g, colour.b, 250 * fade))
		end
	end
end)
