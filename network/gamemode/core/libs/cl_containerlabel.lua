NETWORK.container.labelRange = 260

local lockMaterial = Material("framework/icons/lock.png", "smooth mips")

hook.Add("PostDrawTranslucentRenderables", "nwContainerLabel", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local eyePos = EyePos()

	for _, entity in ipairs(ents.FindInSphere(eyePos, NETWORK.container.labelRange)) do
		if (!IsValid(entity) or entity:GetClass() != "nw_container") then
			continue
		end

		local center = entity:LocalToWorld(entity:OBBCenter())
		local distance = eyePos:Distance(center)
		local fade = 1 - math.Clamp((distance - NETWORK.container.labelRange * 0.55) /
			(NETWORK.container.labelRange * 0.45), 0, 1)

		if (fade <= 0.02) then
			continue
		end

		local _, worldMaxs = entity:GetRotatedAABB(entity:OBBMins(), entity:OBBMaxs())
		local position = entity:GetPos() + Vector(0, 0, worldMaxs.z + 14)

		local direction = position - eyePos

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			continue
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local name = entity:GetDisplayName()
		local description = entity:GetDisplayDescription()

		cam.Start3D2D(position, angles, 0.12)
			surface.SetFont("nwChat")

			local nameWidth = surface.GetTextSize(name)

			surface.SetFont("nwHudSmall")

			local descWidth = description != "" and surface.GetTextSize(description) or 0
			local bLocked = NETWORK.container.IsLocked(entity)
			local lockSize = 18
			local lockShift = bLocked and math.Round((lockSize + 6) * 0.5) or 0
			local width = math.max(nameWidth + lockShift * 2, descWidth) + 34
			local height = description != "" and 48 or 30

			NETWORK.label.Frame(-width * 0.5, -height * 0.5, width, height,
				theme.combine, fade)

			local nameY = -height * 0.5 + (description != "" and 14 or 15)

			draw.SimpleText(name, "nwChat", lockShift, nameY,
				ColorAlpha(theme.text, 250 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			if (bLocked) then
				surface.SetMaterial(lockMaterial)
				surface.SetDrawColor(theme.warning.r, theme.warning.g, theme.warning.b,
					240 * fade)
				surface.DrawTexturedRect(lockShift - math.Round(nameWidth * 0.5) - lockSize - 6,
					math.Round(nameY - lockSize * 0.5), lockSize, lockSize)
			end

			if (description != "") then
				draw.SimpleText(description, "nwHudSmall", 0, height * 0.5 - 14,
					ColorAlpha(theme.textDim, 240 * fade), TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)
			end
		cam.End3D2D()
	end
end)
