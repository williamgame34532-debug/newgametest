function NETWORK.fabricator.GetEntity()
	return NETWORK.fabricator.entity
end

function NETWORK.fabricator.Request(action, id)
	net.Start("nwFabricatorAction")
		net.WriteString(action)
		net.WriteString(id or "")
	net.SendToServer()
end

function NETWORK.fabricator.Have(id)
	return NETWORK.fabricator.Count(NETWORK.inventory.state, id)
end

net.Receive("nwFabricatorOpen", function()
	local entity = net.ReadEntity()

	if (!IsValid(entity)) then
		return
	end

	NETWORK.fabricator.entity = entity

	NETWORK.gui.OpenFabricator(entity)
end)

net.Receive("nwFabricatorClose", function()
	NETWORK.fabricator.entity = nil

	NETWORK.gui.CloseFabricator()
end)

net.Receive("nwFabricatorSync", function()
	if (IsValid(NETWORK.gui.fabricator)) then
		NETWORK.gui.fabricator:OnCrafted()
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwFabricatorLabel", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or NETWORK.hud.IsHidden()) then
		return
	end

	local theme = NETWORK.theme
	local util = NETWORK.util
	local eyePos = EyePos()
	local range = NETWORK.fabricator.labelRange

	for _, entity in ipairs(ents.FindInSphere(eyePos, range)) do
		if (!IsValid(entity) or entity:GetClass() != "nw_fabricator") then
			continue
		end

		local center = entity:LocalToWorld(entity:OBBCenter())
		local distance = eyePos:Distance(center)
		local fade = 1 - math.Clamp((distance - range * 0.55) / (range * 0.45), 0, 1)

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

		local name = util.Upper(entity:GetDisplayName())
		local hint = L("fabHint")

		cam.Start3D2D(position, angles, 0.12)
			local nameWidth = util.TextSpacedSize(name, "nwChat", 4)

			surface.SetFont("nwHudSmall")

			local width = math.max(nameWidth, surface.GetTextSize(hint)) + 40
			local height = 50

			surface.SetDrawColor(9, 24, 32, 215 * fade)
			surface.DrawRect(-width * 0.5, -height * 0.5, width, height)

			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 235 * fade)
			surface.DrawRect(-width * 0.5, -height * 0.5, 3, height)

			util.DrawTextSpaced(name, "nwChat", -nameWidth * 0.5, -height * 0.5 + 16,
				ColorAlpha(theme.text, 250 * fade), 4, TEXT_ALIGN_CENTER)

			draw.SimpleText(hint, "nwHudSmall", 0, height * 0.5 - 15,
				ColorAlpha(theme.textDim, 240 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end)
