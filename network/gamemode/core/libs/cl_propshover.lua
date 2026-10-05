NETWORK.propshover = NETWORK.propshover or {}

local HOVER = NETWORK.propshover

HOVER.events = {
	"PreDrawHalos",
	"PostDrawOpaqueRenderables",
	"PostDrawTranslucentRenderables",
	"PostDrawEffects",
	"HUDPaint"
}

function HOVER.Strip()
	local hooks = hook.GetTable()

	for _, event in ipairs(HOVER.events) do
		for name in pairs(hooks[event] or {}) do
			if (isstring(name) and string.find(string.lower(name), "propert")) then
				hook.Remove(event, name)
			end
		end
	end
end

hook.Add("InitPostEntity", "nwPropsHoverStrip", HOVER.Strip)
hook.Add("OnContextMenuOpen", "nwPropsHoverStrip", HOVER.Strip)

timer.Simple(3, HOVER.Strip)

function HOVER.IsOpen()
	return IsValid(g_ContextMenu) and g_ContextMenu:IsVisible() and vgui.CursorVisible()
end

function HOVER.Target()
	if (!HOVER.IsOpen()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local x, y = input.GetCursorPos()
	local trace = util.TraceLine({
		start = EyePos(),
		endpos = EyePos() + gui.ScreenToVector(x, y) * 4096,
		filter = client
	})

	local entity = trace.Entity

	if (!IsValid(entity) or entity:IsWorld()) then
		return
	end

	return entity, x, y
end

hook.Add("PreDrawHalos", "nwPropsHover", function()
	local entity = HOVER.Target()

	if (!entity) then
		return
	end

	halo.Add({entity}, NETWORK.theme.combine, 1, 1, 1, true, true)
end)

local function Name(entity)
	if (entity.GetDisplayName) then
		local ok, name = pcall(entity.GetDisplayName, entity)

		if (ok and isstring(name) and name != "") then
			return name
		end
	end

	if (entity:IsPlayer()) then
		return entity.GetCharacterName and entity:GetCharacterName() or entity:Nick()
	end

	return entity.PrintName or entity:GetClass()
end

hook.Add("HUDPaint", "nwPropsHover", function()
	local entity, x, y = HOVER.Target()

	if (!entity) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local title = Name(entity)
	local model = entity:GetModel() or ""
	local lines = {title, entity:GetClass()}

	if (model != "") then
		lines[#lines + 1] = model
	end

	surface.SetFont("nwHudSmall")

	local width = 0

	for _, line in ipairs(lines) do
		width = math.max(width, select(1, surface.GetTextSize(line)))
	end

	local lineHeight = draw.GetFontHeight("nwHudSmall")
	local boxWidth = width + Sc(20)
	local boxHeight = lineHeight * #lines + Sc(14)
	local boxX = math.Clamp(x + Sc(18), 0, ScrW() - boxWidth)
	local boxY = math.Clamp(y + Sc(18), 0, ScrH() - boxHeight)
	local radius = math.max(Sc(6), 4)

	NETWORK.util.DrawBlurScreen(boxX, boxY, boxWidth, boxHeight, 3)

	draw.RoundedBox(radius, boxX, boxY, boxWidth, boxHeight, Color(8, 9, 10, 215))

	NETWORK.util.DrawRoundedBorder(boxX, boxY, boxWidth, boxHeight, radius,
		math.max(Sc(1), 1), ColorAlpha(theme.combine, 150))

	for index, line in ipairs(lines) do
		draw.SimpleText(line, "nwHudSmall", boxX + Sc(10),
			boxY + Sc(7) + (index - 1) * lineHeight,
			index == 1 and theme.text or theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end)
