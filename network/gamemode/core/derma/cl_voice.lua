NETWORK.gui.voice = NETWORK.gui.voice or {}

local speakers = {}

local function GetName(client)
	if (!IsValid(client)) then
		return "?"
	end

	if (client:HasCharacter()) then
		return client:GetRecognisedName(LocalPlayer())
	end

	return client:SteamName()
end

hook.Add("InitPostEntity", "nwVoiceHide", function()
	if (g_VoicePanelList) then
		g_VoicePanelList:SetVisible(false)
	end
end)

hook.Add("PlayerStartVoice", "nwVoice", function(client)

	if (NETWORK.gui.voice.IsBroken and NETWORK.gui.voice.IsBroken()) then
		if (g_VoicePanelList) then
			g_VoicePanelList:SetVisible(true)
		end

		return
	end

	if (g_VoicePanelList and g_VoicePanelList:IsVisible()) then
		g_VoicePanelList:SetVisible(false)
	end

	if (!IsValid(client)) then
		return
	end

	local key = client:EntIndex()
	local entry = speakers[key] or {alpha = 0, level = 0, y = -1}

	entry.client = client
	entry.name = GetName(client)
	entry.bActive = true

	if (client == LocalPlayer() and NETWORK.medical and NETWORK.medical.IsSilenced(client)) then
		entry.name = entry.name .. "  ·  " .. L("voiceSilenced")
	end
	entry.time = CurTime()

	speakers[key] = entry

	if (NETWORK.voiceicon) then
		NETWORK.voiceicon.Start(client)
	end

	return true
end)

hook.Add("PlayerEndVoice", "nwVoice", function(client)
	local entry = speakers[IsValid(client) and client:EntIndex() or 0]

	if (entry) then
		entry.bActive = false
	end

	if (NETWORK.voiceicon) then
		NETWORK.voiceicon.Stop(client)
	end

	if (NETWORK.gui.voice.IsBroken and NETWORK.gui.voice.IsBroken()) then
		return
	end

	return true
end)

local indicatorVar = CreateClientConVar("network_voice_indicator", "panel", true, false,
	"Индикатор голоса: panel или icon")

local function DrawCompact(entry, x, y, color, alpha, bOverhead)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local size = Sc(28)
	local half = math.Round(size * 0.5)
	local centerX = x + half
	local centerY = y + half
	local level = entry.level
	local time = RealTime()

	util.DrawCircleOutline(centerX, centerY, half + math.Round(level * Sc(6)),
		ColorAlpha(color, (90 + 140 * level) * alpha), math.max(Sc(2), 2))
	util.DrawCircle(centerX, centerY, half - Sc(3), Color(8, 9, 10, 220 * alpha))

	local barWidth = math.max(Sc(2), 2)
	local gap = math.max(Sc(2), 1)
	local total = 5 * barWidth + 4 * gap
	local startX = centerX - math.Round(total * 0.5)

	for index = 0, 4 do
		local wave = 0.35 + 0.65 * math.abs(math.sin(time * 9 + index * 1.3))
		local height = math.max(Sc(3), math.Round(Sc(12) * level * wave + Sc(2)))

		surface.SetDrawColor(color.r, color.g, color.b, 240 * alpha)
		surface.DrawRect(startX + index * (barWidth + gap), centerY - math.Round(height * 0.5),
			barWidth, height)
	end

	if (bOverhead) then
		return size
	end

	draw.SimpleText(entry.name, "nwInvBody", x + size + Sc(10), centerY,
		ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	return size
end

local order = {}

local function SortSpeakers(a, b)
	local first, second = speakers[a], speakers[b]
	local client = LocalPlayer()
	local bFirstLocal = first.client == client
	local bSecondLocal = second.client == client

	if (bFirstLocal != bSecondLocal) then
		return bFirstLocal
	end

	if ((first.time or 0) != (second.time or 0)) then
		return (first.time or 0) < (second.time or 0)
	end

	return a < b
end

local VOICE_ICON_PERSON = {"framework/voice/speak.png", "framework/icons/person.png"}
local VOICE_ICON_ALLIANCE = {"framework/voice/alliance.png", "framework/icons/masks.png"}
local VOICE_ICON_RADIO = {"framework/voice/radio.png", "framework/status/radio.png"}
local VOICE_ICON_WHISPER = {"framework/voice/whisper.png", "framework/icons/volume_down.png"}
local VOICE_ICON_YELL = {"framework/voice/yell.png", "framework/icons/record_voice_over.png"}
local VOICE_ICON_MUTED = {"framework/voice/muted.png", "framework/chat/ui_mic.png"}
local VOICE_ICON_LAST = "framework/chat/ui_mic.png"

local function GetVoiceMaterial(chain)
	local getMaterial = NETWORK.util.GetMaterial

	for _, path in ipairs(chain) do
		local material = getMaterial(path, "smooth")

		if (material and !material:IsError()) then
			return material
		end
	end

	local material = getMaterial(VOICE_ICON_LAST, "smooth")

	if (material and !material:IsError()) then
		return material
	end
end

local function GetVoiceIconChain(client, bRadio)
	if (bRadio) then
		return VOICE_ICON_RADIO
	end

	if (client == LocalPlayer() and NETWORK.medical and NETWORK.medical.IsSilenced and
		NETWORK.medical.IsSilenced(client)) then
		return VOICE_ICON_MUTED
	end

	if (NETWORK.factions.IsAlliance(client)) then
		return VOICE_ICON_ALLIANCE
	end

	local act = NETWORK.act
	local index = 2

	if (act and act.GetVoiceMode) then
		local _, modeIndex = act.GetVoiceMode(client)

		index = modeIndex or 2
	end

	if (index == 1) then
		return VOICE_ICON_WHISPER
	elseif (index == 3) then
		return VOICE_ICON_YELL
	end

	return VOICE_ICON_PERSON
end

local function DrawLevelBars(right, centerY, level, color, alpha)
	local Sc = NETWORK.util.Scale
	local barWidth = math.max(Sc(3), 2)
	local gap = math.max(Sc(2), 1)
	local maxHeight = math.max(Sc(18), 10)
	local minHeight = math.max(Sc(3), 2)
	local total = barWidth * 5 + gap * 4
	local x = right - total
	local time = RealTime()
	local radius = math.floor(barWidth * 0.5)

	for index = 0, 4 do
		local wave = 0.45 + 0.55 * math.abs(math.sin(time * 8 + index * 1.7))
		local height = math.max(minHeight, math.Round(maxHeight * math.Clamp(level * wave, 0, 1)))

		draw.RoundedBox(radius, x + index * (barWidth + gap), centerY + math.Round(maxHeight * 0.5) - height,
			barWidth, height, ColorAlpha(color, (150 + 100 * level) * alpha))
	end

	return total
end

local function DrawVoicePanel()
	if (table.IsEmpty(speakers) or IsValid(NETWORK.gui.menu)) then
		return
	end

	local bCompact = indicatorVar:GetString() == "icon"

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local S = NETWORK.style
	local frame = math.min(FrameTime(), 0.1)
	local width = Sc(280)
	local rowHeight = Sc(50)
	local x = ScrW() - width - Sc(48)
	local cursor = ScrH() - Sc(220)
	local localPlayer = LocalPlayer()

	table.Empty(order)

	for key in pairs(speakers) do
		order[#order + 1] = key
	end

	table.sort(order, SortSpeakers)

	for _, key in ipairs(order) do
		local entry = speakers[key]
		local client = entry.client

		if (!IsValid(client)) then
			speakers[key] = nil

			continue
		end

		entry.alpha = Lerp(math.Clamp(frame * (entry.bActive and 12 or 5), 0, 1),
			entry.alpha, entry.bActive and 1 or 0)

		if (!entry.bActive and entry.alpha < 0.01) then
			speakers[key] = nil

			continue
		end

		local target = entry.bActive and math.Clamp(client:VoiceVolume() * 2.4, 0.08, 1) or 0

		entry.level = Lerp(math.Clamp(frame * 16, 0, 1), entry.level, target)

		if (entry.y < 0) then
			entry.y = cursor
		end

		entry.y = Lerp(math.Clamp(frame * 12, 0, 1), entry.y, cursor)

		local alpha = util.EaseOut(entry.alpha)
		local y = entry.y
		local slide = math.Round((1 - alpha) * Sc(60))

		local bOverhead = false

		if (client != localPlayer and client:Alive() and NETWORK.nameplate and
			NETWORK.nameplate.GetAnchor) then

			local bone = client:LookupBone("ValveBiped.Bip01_Head1")
			local matrix = bone and client:GetBoneMatrix(bone)
			local top = matrix and (matrix:GetTranslation() + Vector(0, 0, 6)) or
				(client:GetPos() + Vector(0, 0, client:OBBMaxs().z + 2))
			local eyePos = localPlayer:EyePos()
			local range = (NETWORK.voiceicon and NETWORK.voiceicon.range or 700)

			if (eyePos:Distance(top) <= range) then

				local trace = _G.util.TraceLine({
					start = eyePos,
					endpos = top,
					filter = {localPlayer, client},
					mask = MASK_VISIBLE
				})

				if (!trace.Hit) then
					local screen = top:ToScreen()

					if (screen.visible) then
						bOverhead = true
						x = math.Clamp(math.Round(screen.x - width * 0.5), Sc(8), ScrW() - width - Sc(8))

						y = math.Clamp(math.Round(screen.y - (rowHeight - Sc(8)) - entry.level * Sc(14)),
							Sc(8), ScrH() - rowHeight)
						slide = 0
					end
				end
			end
		end

		if (!bOverhead) then
			x = ScrW() - width - Sc(48)
		end

		NETWORK.gui.voice.overhead = NETWORK.gui.voice.overhead or {}
		NETWORK.gui.voice.overhead[client:EntIndex()] = bOverhead and RealTime() or nil
		local factionID = client:GetCharacterFaction()
		local faction = factionID and NETWORK.factions.Get(factionID)
		local color = faction and faction.color or theme.accent
		local bKnownRole = client == LocalPlayer() or LocalPlayer():KnowsRoleOf(client)

		if (!bKnownRole) then
			faction = nil
			color = NETWORK.recognition.strangerColor
		end

		local bRadio = client:GetNWBool("nwVoiceRadio", false)

		if (bRadio) then
			color = theme.radio or Color(96, 186, 255)
		end

		if (bCompact) then
			local compactX = bOverhead and math.Round(x + width * 0.5 - Sc(14)) or (ScrW() - Sc(48) - Sc(220))
			local compactY = bOverhead and (y + rowHeight - Sc(40)) or y

			DrawCompact(entry, compactX, compactY, color, alpha, bOverhead)

			if (!bOverhead) then
				cursor = cursor - Sc(40)
			end

			continue
		end

		local rowTall = rowHeight - Sc(6)
		local rowX = x + slide
		local rowY = math.Round(y)
		local centerY = rowY + math.Round(rowTall * 0.5)
		local radius = S.Radius("card")

		S.Card(rowX, rowY, width, rowTall, alpha, {
			radius = radius,
			accent = color,
			border = ColorAlpha(color, 70),
			glow = bRadio and (0.25 + math.sin(RealTime() * 2.4) * 0.15) or entry.level * 0.3
		})

		local rail = math.max(Sc(3), 2)
		local railHeight = math.Round((rowTall - Sc(16)) * (0.45 + 0.55 * entry.level))

		draw.RoundedBox(math.floor(rail * 0.5), rowX + Sc(4), centerY - math.Round(railHeight * 0.5),
			rail, railHeight, ColorAlpha(color, 230 * alpha))

		local avatar = math.max(Sc(32), 20)
		local avatarX = rowX + Sc(12)
		local avatarY = centerY - math.Round(avatar * 0.5)
		local cell = S.Radius("cell")

		draw.RoundedBox(cell, avatarX, avatarY, avatar, avatar, Color(0, 0, 0, 110 * alpha))
		util.DrawRoundedBorder(avatarX, avatarY, avatar, avatar, cell, 1,
			ColorAlpha(color, (70 + 110 * entry.level) * alpha))

		local iconMaterial = GetVoiceMaterial(GetVoiceIconChain(client, bRadio))

		if (iconMaterial) then
			local iconSize = math.Round(avatar * 0.56)

			surface.SetMaterial(iconMaterial)
			surface.SetDrawColor(color.r, color.g, color.b, 245 * alpha)
			surface.DrawTexturedRect(avatarX + math.Round((avatar - iconSize) * 0.5),
				avatarY + math.Round((avatar - iconSize) * 0.5), iconSize, iconSize)
		end

		local right = rowX + width - Sc(12)
		local rightWidth

		if (bRadio) then
			local frequency = client:GetNWString("nwRadioFreq", "")
			local chipText = frequency != "" and frequency or util.Upper(L("voiceRadioTag"))

			surface.SetFont("nwInvKey")

			local _, chipTextHeight = surface.GetTextSize(chipText)
			local padY = math.max(Sc(2), 1)

			rightWidth = S.Chip(chipText, "nwInvKey", right,
				centerY - math.Round(chipTextHeight * 0.5) - padY, color, alpha,
				{alignRight = true, padX = math.max(Sc(6), 4), padY = padY})
		else
			rightWidth = DrawLevelBars(right, centerY, entry.level, color, alpha)
		end

		local textX = avatarX + avatar + Sc(10)
		local textMax = math.max(right - rightWidth - Sc(10) - textX, Sc(40))
		local bSelf = client == localPlayer
		local selfText = bSelf and L("voiceYou") or nil
		local selfWidth = 0

		if (selfText) then
			surface.SetFont("nwInvKey")
			selfWidth = surface.GetTextSize(selfText) + math.max(Sc(5), 3) * 2 + Sc(6)
		end

		local nameY = centerY - Sc(8)
		local name = util.TruncateWidth(entry.name or "?", "nwInvName",
			math.max(textMax - selfWidth, Sc(30)))

		draw.SimpleText(name, "nwInvName", textX, nameY, ColorAlpha(theme.text, 245 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (selfText) then
			surface.SetFont("nwInvName")

			local nameWidth = surface.GetTextSize(name)
			local padY = math.max(Sc(1), 1)

			surface.SetFont("nwInvKey")

			local _, selfHeight = surface.GetTextSize(selfText)

			S.Chip(selfText, "nwInvKey", textX + nameWidth + Sc(6),
				nameY - math.Round(selfHeight * 0.5) - padY, S.Accent(), alpha,
				{padX = math.max(Sc(5), 3), padY = padY})
		end

		local service = util.Upper(faction and L(faction.name) or
			L(bKnownRole and "playersNoFaction" or "recogStranger"))

		if (bRadio) then
			service = util.Upper(L("voiceRadioTag")) .. " · " .. service
		end

		local fxLabel = NETWORK.voicefx and NETWORK.voicefx.GetLabel and
			NETWORK.voicefx.GetLabel(client)

		if (fxLabel and !bRadio) then
			service = util.Upper(fxLabel) .. " · " .. service
		end

		draw.SimpleText(util.TruncateWidth(service, "nwInvKey", textMax), "nwInvKey",
			textX, centerY + Sc(9), ColorAlpha(color, 215 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		if (!bOverhead) then
			cursor = cursor - rowHeight
		end
	end
end

NETWORK.gui.voice.lastError = 0

hook.Add("HUDPaint", "nwVoice", function()
	local bOk, err = xpcall(DrawVoicePanel, debug.traceback)

	if (!bOk) then
		local now = RealTime()

		if (now - (NETWORK.gui.voice.lastReport or 0) > 5) then
			NETWORK.gui.voice.lastReport = now

			MsgC(Color(240, 90, 80), "[Network] Ошибка панели голоса: " .. tostring(err) .. "\n")
		end

		NETWORK.gui.voice.lastError = now
	end
end)

function NETWORK.gui.voice.IsBroken()
	return RealTime() - (NETWORK.gui.voice.lastError or 0) < 10
end
