NETWORK.label = NETWORK.label or {}

NETWORK.label.range = 260
NETWORK.label.fade = 60

function NETWORK.label.Frame(x, y, width, height, color, alpha)
	alpha = alpha == nil and 1 or alpha

	local radius = 6

	draw.RoundedBox(radius, x, y, width, height, Color(8, 9, 10, 200 * alpha))

	NETWORK.util.DrawRoundedBorder(x, y, width, height, radius, 1,
		Color(255, 255, 255, 30 * alpha))

	local bar = 3
	local barHeight = math.Round(height * 0.5)

	draw.RoundedBox(2, x + 5, y + math.Round((height - barHeight) * 0.5), bar, barHeight,
		ColorAlpha(color, 240 * alpha))
end

function NETWORK.label.Draw(entity, title, subtitle, color)
	local client = LocalPlayer()

	if (!IsValid(client) or !IsValid(entity)) then
		return
	end

	local position = entity:GetPos() + Vector(0, 0, entity:OBBMaxs().z + 10)
	local distance = client:GetPos():Distance(position)
	local range = NETWORK.label.range

	if (distance > range) then
		return
	end

	local alpha = math.Clamp((range - distance) / NETWORK.label.fade, 0, 1)

	if (alpha <= 0.01) then
		return
	end

	local direction = position - EyePos()

	direction.z = 0

	if (direction:LengthSqr() < 0.01) then
		return
	end

	local angles = direction:Angle()

	angles:RotateAroundAxis(angles:Up(), -90)
	angles:RotateAroundAxis(angles:Forward(), 90)

	color = color or NETWORK.theme.accent
	title = NETWORK.util.Upper(title or "")

	surface.SetFont("nwTagDesc")

	local titleWidth = surface.GetTextSize(title)
	local subWidth = 0

	if (subtitle and subtitle != "") then
		surface.SetFont("nwHudSmall")

		subWidth = surface.GetTextSize(subtitle)
	end

	local width = math.max(titleWidth, subWidth) + 58
	local height = (subtitle and subtitle != "") and 48 or 34
	local x = -width * 0.5

	cam.Start3D2D(position, angles, 0.1)

		NETWORK.label.Frame(x, -height * 0.5, width, height, color, alpha)

		local textY = (subtitle and subtitle != "") and -8 or 0

		draw.SimpleText(title, "nwTagDesc", 8, textY,
			ColorAlpha(NETWORK.theme.text, 252 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		if (subtitle and subtitle != "") then
			draw.SimpleText(subtitle, "nwInvKey", 8, 13,
				ColorAlpha(color, 240 * alpha), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end
	cam.End3D2D()
end
