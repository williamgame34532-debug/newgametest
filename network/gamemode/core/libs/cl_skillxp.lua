NETWORK.skillxp = NETWORK.skillxp or {}
NETWORK.skillxp.list = NETWORK.skillxp.list or {}

NETWORK.skillxp.life = 2.5
NETWORK.skillxp.max = 4

local popupsConVar = CreateClientConVar("network_skill_popups", "1", true, false,
	"Показывать всплывающий опыт навыков")

NETWORK.option.Register("skillPopups", {
	name = "optSkillPopups",
	description = "optSkillPopupsDesc",
	category = "hud",
	type = "bool",
	convar = "network_skill_popups",
	default = true
})

net.Receive("nwSkillXP", function()
	local id = net.ReadString()
	local amount = net.ReadUInt(16)
	local bLevelled = net.ReadBool()

	if (!popupsConVar:GetBool()) then
		return
	end

	local definition = NETWORK.skills.GetDefinition(id)
	local list = NETWORK.skillxp.list

	local last = list[#list]

	if (last and last.id == id and !last.bLevelled and !bLevelled and
		RealTime() - last.born < 0.8) then
		last.amount = last.amount + amount
		last.born = RealTime()

		return
	end

	list[#list + 1] = {
		id = id,
		name = definition and L(definition.name) or id,
		amount = amount,
		bLevelled = bLevelled,
		born = RealTime()
	}

	while (#list > NETWORK.skillxp.max) do
		table.remove(list, 1)
	end
end)

local function DrawIcon(name, x, y, size, color)
	local material = NETWORK.util.GetMaterial("framework/icons/" .. name .. ".png",
		"smooth")

	if (!material or material:IsError()) then
		return false
	end

	surface.SetMaterial(material)
	surface.SetDrawColor(color.r, color.g, color.b, color.a)
	surface.DrawTexturedRect(math.Round(x), math.Round(y), size, size)

	return true
end

hook.Add("HUDPaint", "nwSkillXP", function()
	local list = NETWORK.skillxp.list

	if (#list == 0 or NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local life = NETWORK.skillxp.life
	local now = RealTime()

	local right = ScrW() - Sc(34)
	local bottom = ScrH() - Sc(28) - Sc(130)
	local height = Sc(30)
	local gap = Sc(6)
	local iconSize = Sc(16)

	for index = #list, 1, -1 do
		local entry = list[index]
		local age = now - entry.born

		if (age >= life) then
			table.remove(list, index)

			continue
		end

		local fadeIn = math.min(1, age / 0.25)
		local fadeOut = math.min(1, (life - age) / 0.6)
		local ease = NETWORK.util.EaseOut(fadeIn)
		local alpha = ease * fadeOut
		local slot = #list - index
		local y = bottom - slot * (height + gap) - (1 - ease) * Sc(12) -
			(1 - fadeOut) * Sc(10)
		local accent = entry.bLevelled and theme.combine or theme.textDim
		local text = "+" .. entry.amount
		local name = NETWORK.util.Upper(entry.name)

		surface.SetFont("nwInvName")

		local amountWidth = surface.GetTextSize(text)

		surface.SetFont("nwInvKey")

		local nameWidth = surface.GetTextSize(name)
		local width = Sc(12) + iconSize + Sc(8) + amountWidth + Sc(10) + nameWidth + Sc(14)
		local x = right - width

		surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b, 215 * alpha)
		surface.DrawRect(x, y - height, width, height)

		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 200 * alpha)
		surface.DrawOutlinedRect(x, y - height, width, height, 1)

		surface.SetDrawColor(accent.r, accent.g, accent.b,
			(entry.bLevelled and 240 or 120) * alpha)
		surface.DrawRect(x, y - height, math.max(Sc(2), 2), height)

		local cursor = x + Sc(12)
		local middle = y - height * 0.5

		DrawIcon(entry.bLevelled and "workspace_premium" or "trending_up", cursor,
			middle - iconSize * 0.5, iconSize, ColorAlpha(accent, 240 * alpha))

		cursor = cursor + iconSize + Sc(8)

		draw.SimpleText(text, "nwInvName", cursor, middle,
			ColorAlpha(entry.bLevelled and theme.combine or theme.text, 250 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + amountWidth + Sc(10)

		draw.SimpleText(name, "nwInvKey", cursor, middle + Sc(1),
			ColorAlpha(theme.textDim, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end)
