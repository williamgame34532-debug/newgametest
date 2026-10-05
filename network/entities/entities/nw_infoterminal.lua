AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "nw_terminal"
ENT.PrintName = "Информационный терминал"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_BOTH

local function FormatUntil(hours)
	local total = math.max(math.Round(hours * 60), 0)

	return L("periodDuration", math.floor(total / 60), total % 60)
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_infoterminal")
		local angles = trace.HitNormal:Angle()

		angles.p = 0
		angles.r = 0

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer()) then
			return
		end

		if (self:GetNWBool("nwBroken", false)) then
			self:EmitSound("framework/cmb/forcefield/sparkle" .. math.random(4) .. ".mp3", 60, 110)
			NETWORK.chat.Notice(activator, "empTerminalBroken")

			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 1

		local period = NETWORK.schedule.GetCurrent()
		local _, untilNext = NETWORK.schedule.GetNext()

		self:EmitSound(NETWORK.terminal.sounds.select, 65)

		NETWORK.chat.Notice(activator, L("infoTerminalNotice", L(period.name),
			FormatUntil(untilNext)))
	end

	function ENT:Think()
		return false
	end

	function ENT:OnRemove()
	end
else
	local style = {
		brand = "CITY INFO",
		color = Color(126, 226, 240),
		background = Color(6, 30, 38)
	}

	local weatherIcons = {
		clear = "wb_sunny",
		overcast = "cloud",
		fog = "cloud",
		rain = "umbrella",
		storm = "umbrella"
	}

	local function DrawIcon(name, x, y, size, color, alpha)
		local material = NETWORK.util.GetMaterial("framework/icons/" .. name .. ".png",
			"smooth")

		if (!material or material:IsError()) then
			return false
		end

		surface.SetMaterial(material)
		surface.SetDrawColor(0, 0, 0, 160 * (alpha or 1))
		surface.DrawTexturedRect(x + 1, y + 1, size, size)
		surface.SetDrawColor(color.r, color.g, color.b, 255 * (alpha or 1))
		surface.DrawTexturedRect(x, y, size, size)

		return true
	end

	local function FormatHours(hours)
		return string.format("%02d:%02d", math.floor(hours % 24),
			math.Round((hours % 1) * 60))
	end

	function style.Body(entity, width, height, color)
		local util = NETWORK.util
		local schedule = NETWORK.schedule
		local current = schedule.GetCurrent()
		local nextPeriod, untilNext = schedule.GetNext()
		local middle = width * 0.5
		local dim = ColorAlpha(color, 170)

		draw.SimpleText(NETWORK.time.GetFormatted(), "nwTermScreenClock", 30, 116,
			color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local periodName = util.Upper(L(current.name))
		local infoX = middle + 20

		surface.SetFont("nwTermScreenBody")

		local iconSize = 26

		if (DrawIcon(current.icon, infoX, 84, iconSize, color)) then
			draw.SimpleText(periodName, "nwTermScreenBody", infoX + iconSize + 10, 97,
				color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(periodName, "nwTermScreenBody", infoX, 97, color,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		draw.SimpleText(util.Upper(L("periodNext")) .. ": " .. FormatUntil(untilNext) ..
			"  ·  " .. util.Upper(L(nextPeriod.name)), "nwTermScreenSmall", infoX, 128,
			dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local periods = schedule.periods
		local gap = 8
		local chipHeight = 46
		local chipY = 160
		local chipWidth = math.floor((width - 60 - gap * (#periods - 1)) / #periods)

		for index, period in ipairs(periods) do
			local x = 30 + (index - 1) * (chipWidth + gap)
			local bActive = period.id == current.id
			local textColor = bActive and Color(8, 22, 26) or dim

			if (bActive) then
				surface.SetDrawColor(color.r, color.g, color.b, 225)
				surface.DrawRect(x, chipY, chipWidth, chipHeight)
			else
				surface.SetDrawColor(color.r, color.g, color.b, 24)
				surface.DrawRect(x, chipY, chipWidth, chipHeight)
				surface.SetDrawColor(color.r, color.g, color.b, 90)
				surface.DrawOutlinedRect(x, chipY, chipWidth, chipHeight, 1)
			end

			local chipIcon = 18
			local chipMiddle = x + chipWidth * 0.5

			if (DrawIcon(period.icon, chipMiddle - chipIcon * 0.5, chipY + 5, chipIcon,
				textColor, bActive and 1 or 0.85)) then
				draw.SimpleText(FormatHours(period.from) .. "–" ..
					FormatHours(period.to), "nwTermScreenSmall", chipMiddle,
					chipY + 34, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText(FormatHours(period.from) .. "–" ..
					FormatHours(period.to), "nwTermScreenSmall", chipMiddle,
					chipY + chipHeight * 0.5, textColor, TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)
			end
		end

		local lineY = 244
		local lineIcon = 20
		local weather = NETWORK.weather and NETWORK.weather.GetCurrent()

		surface.SetDrawColor(color.r, color.g, color.b, 60)
		surface.DrawRect(30, lineY - 22, width - 60, 1)

		if (weather) then
			local textX = 30

			if (DrawIcon(weatherIcons[weather.id] or "cloud", 30, lineY - lineIcon * 0.5,
				lineIcon, color)) then
				textX = 30 + lineIcon + 8
			end

			draw.SimpleText(util.Upper(L(weather.name)), "nwTermScreenSmall", textX,
				lineY, dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local bCurfew = schedule.IsCurfew()
		local curfewColor = bCurfew and Color(240, 120, 100) or Color(140, 226, 160)
		local curfewText = util.Upper(L(bCurfew and "periodCurfewOn" or "periodCurfewOff"))

		surface.SetFont("nwTermScreenSmall")

		local curfewWidth = surface.GetTextSize(curfewText)
		local curfewX = width - 30 - curfewWidth

		draw.SimpleText(curfewText, "nwTermScreenSmall", width - 30, lineY, curfewColor,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		DrawIcon(bCurfew and "warning" or "check_circle", curfewX - lineIcon - 8,
			lineY - lineIcon * 0.5, lineIcon, curfewColor)

		local pulse = 150 + math.abs(math.cos(RealTime() * 2)) * 100

		draw.SimpleText(util.Upper(L("interactInfo")), "nwTermScreenSmall", middle,
			height - 24, ColorAlpha(color, pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function ENT:Draw()
		self:DrawModel()

		NETWORK.terminal.DrawScreen(self, style)
	end
end
