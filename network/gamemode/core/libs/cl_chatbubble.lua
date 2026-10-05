local TraceLine = util.TraceLine

NETWORK.bubble = NETWORK.bubble or {}
NETWORK.bubble.list = NETWORK.bubble.list or {}

NETWORK.bubble.lifetime = 7
NETWORK.bubble.fade = 1.5
NETWORK.bubble.maxLines = 4
NETWORK.bubble.maxPerPlayer = 3
NETWORK.bubble.range = 700

local typingClasses = {
	ic = true,
	yell = true,
	whisper = true,
	me = true,
	radio = true,
	radiocp = true,
	radiota = true,
	radiotac = true,
	squadc = true
}

local function DrawTyping(typing, x, y, fade)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local class = NETWORK.chat.Get(typing)
	local path = NETWORK.chat.GetIcon(typing) or "framework/chat/md_ic.png"
	local material = NETWORK.util.GetMaterial(path, "smooth")

	if (!material or material:IsError()) then
		material = NETWORK.util.GetMaterial("framework/chat/md_ic.png", "smooth")
	end

	local color = class and class.color or theme.textFaint
	local size = Sc(18)
	local iconX = x - math.Round(size * 0.5)
	local iconY = y - math.Round(size * 0.5)

	if (material and !material:IsError()) then
		surface.SetMaterial(material)
		surface.SetDrawColor(0, 0, 0, 170 * fade)
		surface.DrawTexturedRect(iconX + 1, iconY + 1, size, size)
		surface.SetDrawColor(color.r, color.g, color.b, 235 * fade)
		surface.DrawTexturedRect(iconX, iconY, size, size)
	end

	local dot = math.max(Sc(3), 2)
	local dotX = iconX + size + Sc(6)
	local dotY = y - math.floor(dot * 0.5)

	for i = 1, 3 do
		local pulse = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(RealTime() * 6 + i))

		surface.SetDrawColor(0, 0, 0, 150 * fade)
		surface.DrawRect(dotX + 1, dotY + 1, dot, dot)
		surface.SetDrawColor(color.r, color.g, color.b, 235 * pulse * fade)
		surface.DrawRect(dotX, dotY, dot, dot)

		dotX = dotX + dot * 2
	end
end

function NETWORK.bubble.GetStyle(id)
	if (id == "yell") then
		return "nwBubbleBig", Color(255, 122, 96), 1
	end

	if (id == "whisper") then
		return "nwBubbleSmall", Color(158, 172, 186), 1
	end

	if (id == "me") then
		return "nwBubbleItalic", Color(196, 160, 255), 1
	end

	local class = NETWORK.chat.Get(id)

	if (class and class.bRadio) then
		return "nwBubble", class.color, 1
	end

	return "nwBubble", Color(232, 240, 248), 1
end

function NETWORK.bubble.Add(speaker, id, text)
	if (!IsValid(speaker) or !speaker:IsPlayer()) then
		return
	end

	local class = NETWORK.chat.Get(id)

	if (!class or !class.bBubble) then
		return
	end

	if (id == "me") then
		text = "* " .. text .. " *"
	end

	text = NETWORK.chat.WrapAlliance(id, speaker, text)

	if (class.bRadio) then
		text = "⟨" .. L("bubbleRadio") .. "⟩ " .. text
	end

	local key = speaker:EntIndex()
	local list = NETWORK.bubble.list[key] or {}
	local font = NETWORK.bubble.GetStyle(id)

	list[#list + 1] = {
		id = id,
		lines = NETWORK.util.WrapText(text, font, NETWORK.util.Scale(340),
			NETWORK.bubble.maxLines),
		time = CurTime()
	}

	while (#list > NETWORK.bubble.maxPerPlayer) do
		table.remove(list, 1)
	end

	NETWORK.bubble.list[key] = list
end

function NETWORK.bubble.GetHeight(target)
	if (!IsValid(target)) then
		return 0
	end

	local Sc = NETWORK.util.Scale
	local key = target:EntIndex()
	local list = NETWORK.bubble.list[key]
	local typing = target:GetNWString("nwTyping", "")
	local height = 0
	local time = CurTime()

	if (typing != "" and typingClasses[typing]) then
		height = height + Sc(20)
	end

	for index = 1, #(list or {}) do
		local bubble = list[index]

		if (time - bubble.time > NETWORK.bubble.lifetime + NETWORK.bubble.fade) then
			continue
		end

		local font = NETWORK.bubble.GetStyle(bubble.id)

		surface.SetFont(font)

		local _, lineHeight = surface.GetTextSize("A")

		height = height + lineHeight * #bubble.lines + Sc(6)
	end

	if (height > 0) then
		height = height + Sc(8)
	end

	return height
end

hook.Add("NetworkChatMessage", "nwBubble", function(id, speaker, name, text)
	NETWORK.bubble.Add(speaker, id, text)
end)

hook.Add("HUDPaint", "nwBubble", function()
	if (NETWORK.hud.IsHidden()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or IsValid(NETWORK.gui.menu)) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local eyePos = client:EyePos()
	local time = CurTime()

	for _, target in ipairs(player.GetAll()) do
		if (target:GetNWBool("nwHidden", false)) then
			continue
		end

		if (target == client and NETWORK.thirdperson and !NETWORK.thirdperson.IsEnabled()) then
			continue
		end

		if (!target:Alive() or !target:HasCharacter()) then
			continue
		end

		local key = target:EntIndex()
		local list = NETWORK.bubble.list[key]
		local typing = target:GetNWString("nwTyping", "")

		if ((!list or #list == 0) and typing == "") then
			continue
		end

		local top = NETWORK.nameplate.GetAnchor(target)
		local distance = eyePos:Distance(top)

		if (distance > NETWORK.bubble.range) then
			continue
		end

		local screen = top:ToScreen()

		if (!screen.visible) then
			continue
		end

		local trace = TraceLine({
			start = eyePos,
			endpos = target:EyePos(),
			filter = {client, target},
			mask = MASK_SHOT
		})

		if (trace.Hit) then
			local second = TraceLine({
				start = eyePos,
				endpos = top,
				filter = {client, target},
				mask = MASK_SHOT
			})

			if (second.Hit) then
				continue
			end
		end

		local x = math.Round(screen.x)

		local y = math.Round(screen.y) - Sc(26)
		local fade = 1 - math.Clamp((distance - NETWORK.bubble.range * 0.6) /
			(NETWORK.bubble.range * 0.4), 0, 1)

		if (typing != "" and typingClasses[typing]) then
			DrawTyping(typing, x, y, fade)

			y = y - Sc(20)
		end

		if (!list) then
			continue
		end

		for index = #list, 1, -1 do
			local bubble = list[index]
			local age = time - bubble.time

			if (age > NETWORK.bubble.lifetime + NETWORK.bubble.fade) then
				table.remove(list, index)

				continue
			end

			local font, color = NETWORK.bubble.GetStyle(bubble.id)
			local alpha = fade

			if (age > NETWORK.bubble.lifetime) then
				alpha = alpha * (1 - (age - NETWORK.bubble.lifetime) / NETWORK.bubble.fade)
			end

			surface.SetFont(font)

			local _, lineHeight = surface.GetTextSize("A")
			local fonts = {font, "nwBubbleBold", "nwBubbleItalic"}
			local class = NETWORK.chat.Get(bubble.id)
			local bRadio = class and class.bRadio
			local shadow = math.max(Sc(2), 1)

			for line = #bubble.lines, 1, -1 do
				if (bubble.id == "me") then
					util.DrawSimpleTextShadow(bubble.lines[line], font, x, y,
						ColorAlpha(color, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)
				else
					util.DrawStyledText(bubble.lines[line], fonts, x, y,
						ColorAlpha(color, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)
				end

				y = y - lineHeight
			end

			if (bRadio) then
				local width = util.StyledTextSize(bubble.lines[1] or "", fonts)

				draw.RoundedBox(math.max(Sc(2), 2), x - math.Round(width * 0.5) - Sc(10),
					y + lineHeight - Sc(2), math.max(Sc(3), 2), lineHeight * #bubble.lines - Sc(4),
					ColorAlpha(color, 235 * alpha))
			end

			y = y - Sc(6)
		end
	end
end)

hook.Add("EntityRemoved", "nwBubble", function(entity)
	if (entity:IsPlayer()) then
		NETWORK.bubble.list[entity:EntIndex()] = nil
	end
end)
