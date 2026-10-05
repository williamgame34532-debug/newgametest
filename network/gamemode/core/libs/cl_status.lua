NETWORK.status = NETWORK.status or {}

local S = NETWORK.status

S.cardTime = 5
S.size = 28
S.gap = 12

S.states = {
	{
		id = "bleeding",
		glyph = "drop",
		color = Color(226, 74, 66),
		Check = function(client)
			for _, level in pairs(client:GetBleedMap() or {}) do
				if (level and level != false) then
					return true
				end
			end

			return false
		end
	},
	{
		id = "fracture",
		glyph = "cross",
		color = Color(226, 140, 70),
		Check = function(client)
			for _, part in ipairs(NETWORK.wound and NETWORK.wound.parts or {}) do
				if (client:GetFracture(part.id) > 0) then
					return true
				end
			end

			return false
		end
	},
	{

		id = "sick",
		glyph = "cross",
		color = Color(150, 200, 90),
		Check = function(client)
			return client:GetNWString("nwDisease", "") != ""
		end
	},
	{
		id = "hunger",
		glyph = "meal",
		color = Color(226, 190, 70),
		Check = function(client)
			return client:GetHunger() <= 50
		end
	},
	{
		id = "thirst",
		glyph = "drop",
		color = Color(120, 190, 235),
		Check = function(client)
			return client:GetThirst() <= 50
		end
	},
	{
		id = "tired",
		glyph = "spark",
		color = Color(200, 200, 120),
		Check = function(client)
			return client:IsExhausted() or
				(NETWORK.stamina.Get and (NETWORK.stamina.Get(client) or 100) <= 25)
		end
	},
	{
		id = "cold",
		glyph = "spark",
		color = Color(150, 205, 245),
		Check = function(client)
			return client.GetCold != nil and client:GetCold() >= (NETWORK.climate and NETWORK.climate.coldWarn or 40)
		end
	},
	{
		id = "wet",
		glyph = "drop",
		color = Color(96, 160, 220),
		Check = function(client)
			return client.GetWet != nil and client:GetWet() >= (NETWORK.climate and NETWORK.climate.wetWarn or 40)
		end
	},
	{
		id = "tied",
		glyph = "cuffs",
		color = Color(226, 96, 96),
		Check = function(client)
			return NETWORK.restraint.IsTied(client) and !client:GetNWBool("nwCuffed", false)
		end
	},
	{
		id = "cuffed",
		glyph = "cuffs",
		color = Color(226, 120, 96),
		Check = function(client)
			return client:GetNWBool("nwCuffed", false)
		end
	},
	{
		id = "searched",
		glyph = "hand",
		color = Color(226, 190, 70),
		Check = function(client)
			return client:GetNWBool("nwSearched", false)
		end
	},
	{
		id = "radio",
		glyph = "radio",
		color = Color(126, 176, 220),
		Check = function(client)
			return client:GetNWBool("nwRadio", false) or
				client:GetNWBool("nwRadioTx", false)
		end
	}
}

S.shown = S.shown or {}

S.demoUntil = S.demoUntil or 0

concommand.Add("network_status_test", function()
	S.demoUntil = CurTime() + 12
	S.shown = {}
	S.anim = {}
end, nil, "Показать все значки состояния на двенадцать секунд")

function S.Active(client)
	local list = {}

	if (S.demoUntil > CurTime()) then
		for _, entry in ipairs(S.states) do
			list[#list + 1] = entry
		end

		return list
	end

	for _, entry in ipairs(S.states) do
		local bOk, bActive = pcall(entry.Check, client)

		if (bOk and bActive) then
			list[#list + 1] = entry
		end
	end

	return list
end

function S.StartY(count)
	local Sc = NETWORK.util.Scale
	local height = count * Sc(S.chipHeight or S.size) + math.max(count - 1, 0) * Sc(S.gap)
	local y = math.Round(ScrH() * 0.5 - height * 0.5)
	local questBottom = NETWORK.quest and NETWORK.quest.hudBottom

	if (questBottom and questBottom > 0 and CurTime() - (NETWORK.quest.hudAt or 0) < 0.5) then
		y = math.max(y, questBottom + Sc(18))
	end

	return y, height
end

function S.Value(client, entry)
	if (entry.id == "hunger") then
		return math.Round(client:GetHunger()) .. "%"
	elseif (entry.id == "thirst") then
		return math.Round(client:GetThirst()) .. "%"
	elseif (entry.id == "tired" and NETWORK.stamina and NETWORK.stamina.Get) then
		return math.Round(NETWORK.stamina.Get(client) or 0) .. "%"
	elseif (entry.id == "cold" and client.GetCold) then
		return math.Round(client:GetCold()) .. "%"
	elseif (entry.id == "wet" and client.GetWet) then
		return math.Round(client:GetWet()) .. "%"
	elseif (entry.id == "sick" and NETWORK.disease and NETWORK.disease.TimeLeft) then
		return math.max(math.ceil(NETWORK.disease.TimeLeft(client) / 60), 1) .. " " ..
			L("jailMinutesShort")
	end
end

S.chipHeight = S.size
S.urgent = {bleeding = true, fracture = true, tied = true, cold = true}
S.revealTime = 0.35
S.hideTime = 0.3

S.anim = S.anim or {}

function S.Column(list)
	local active = {}
	local column = {}

	for _, entry in ipairs(list) do
		active[entry.id] = true
	end

	for _, entry in ipairs(S.states) do
		local anim = S.anim[entry.id]

		if (active[entry.id] or (anim and anim.reveal > 0.001)) then
			column[#column + 1] = entry
		end
	end

	return column, active
end

function S.DrawLabel(client, entry, iconX, iconY, size, age)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local fadeIn = math.Clamp(age / 0.3, 0, 1)
	local fadeOut = math.Clamp((S.cardTime - age) / 0.5, 0, 1)
	local alpha = NETWORK.util.EaseOut(fadeIn) * fadeOut

	if (alpha <= 0.01) then
		return
	end

	local title = NETWORK.util.Upper(L("status" .. entry.id))
	local value = S.Value(client, entry)
	local text = L("status" .. entry.id .. "Desc")
	local slide = math.Round((1 - NETWORK.util.EaseOut(fadeIn)) * Sc(26))
	local right = iconX - Sc(12) + slide
	local centerY = iconY + math.Round(size * 0.5)

	surface.SetFont("nwStatusLabel")

	local titleWidth, titleHeight = surface.GetTextSize(title)

	surface.SetFont("nwStatusDesc")

	local descWidth = surface.GetTextSize(text)
	local valueWidth = 0

	if (value) then
		surface.SetFont("nwInvKey")
		valueWidth = surface.GetTextSize(value) + Sc(8)
	end

	local width = math.max(titleWidth + valueWidth, descWidth) + Sc(24)
	local height = Sc(38)
	local x = right - width
	local y = centerY - math.Round(height * 0.5)

	NETWORK.util.DrawBlurScreen(x, y, width, height, 3 * alpha)

	surface.SetDrawColor(6, 7, 9, 150 * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(entry.color.r, entry.color.g, entry.color.b, 200 * alpha)
	surface.DrawRect(x + width - math.max(Sc(2), 2), y, math.max(Sc(2), 2), height)

	local textX = right - Sc(12)

	draw.SimpleText(title, "nwStatusLabel", textX - valueWidth, y + Sc(11),
		ColorAlpha(entry.color, 250 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (value) then
		draw.SimpleText(value, "nwInvKey", textX, y + Sc(11),
			ColorAlpha(theme.text, 230 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	draw.SimpleText(text, "nwStatusDesc", textX, y + Sc(27),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

function S.Draw()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		S.anim = {}
		S.shown = {}

		return
	end

	if (NETWORK.hud and NETWORK.hud.IsHidden and NETWORK.hud.IsHidden()) then
		return
	end

	local list = S.Active(client)
	local column, active = S.Column(list)

	if (#column == 0) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local size = Sc(S.size)
	local right = ScrW() - Sc(30)
	local y = S.StartY(#column)
	local frame = math.min(FrameTime(), 0.05)
	local now = CurTime()

	for _, entry in ipairs(column) do
		local anim = S.anim[entry.id]

		if (!anim) then
			anim = {reveal = 0, shown = now}
			S.anim[entry.id] = anim
			S.shown[entry.id] = now
		end

		local bActive = active[entry.id]

		if (bActive) then
			anim.reveal = math.min(anim.reveal + frame / S.revealTime, 1)
		else
			anim.reveal = math.max(anim.reveal - frame / S.hideTime, 0)
		end

		local reveal = util.EaseOut(anim.reveal)
		local bUrgent = S.urgent[entry.id]
		local pulse = bUrgent and (0.6 + math.abs(math.sin(now * 3.2)) * 0.4) or 1

		local scale = 1 + (1 - reveal) * 0.6
		local drawSize = math.Round(size * scale)
		local x = right - size + math.Round((1 - reveal) * Sc(16))
		local iconX = x + math.Round((size - drawSize) * 0.5)
		local iconY = y + math.Round((size - drawSize) * 0.5)
		local alpha = 255 * reveal * pulse

		local material = util.GetMaterial("framework/status/" .. entry.id .. ".png", "smooth")

		if (material and !material:IsError()) then
			surface.SetMaterial(material)
			surface.SetDrawColor(0, 0, 0, 160 * reveal)
			surface.DrawTexturedRect(iconX + 1, iconY + 2, drawSize, drawSize)
			surface.SetDrawColor(entry.color.r, entry.color.g, entry.color.b, alpha)
			surface.DrawTexturedRect(iconX, iconY, drawSize, drawSize)
		else
			local glyph = math.Round(drawSize * 0.8)

			NETWORK.gui.DrawGlyph(entry.glyph, iconX + math.Round((drawSize - glyph) * 0.5),
				iconY + math.Round((drawSize - glyph) * 0.5), glyph,
				ColorAlpha(entry.color, alpha))
		end

		if (bActive) then
			local age = now - anim.shown

			if (age < S.cardTime) then
				S.DrawLabel(client, entry, x, y, size, age)
			end
		end

		y = y + size + Sc(S.gap)
	end

	for id, anim in pairs(S.anim) do
		if (!active[id] and anim.reveal <= 0.001) then
			S.anim[id] = nil
			S.shown[id] = nil
		end
	end
end

hook.Add("HUDPaint", "nwStatus", function()
	local bOk, err = pcall(S.Draw)

	if (!bOk and !S.reported) then
		S.reported = true

		ErrorNoHalt("[network] status: " .. tostring(err) .. "\n")
	end
end)
