function NETWORK.junk.SendConfig(entity, payload)
	net.Start("nwJunkConfig")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(payload)
	net.SendToServer()
end

hook.Add("PostDrawTranslucentRenderables", "nwJunkLabel", function(_, bSkybox)
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
	local range = 190

	for _, entity in ipairs(ents.FindInSphere(eyePos, range)) do
		if (!IsValid(entity) or entity:GetClass() != "nw_junk") then
			continue
		end

		local center = entity:LocalToWorld(entity:OBBCenter())
		local distance = eyePos:Distance(center)
		local fade = 1 - math.Clamp((distance - range * 0.5) / (range * 0.5), 0, 1)

		if (fade <= 0.02) then
			continue
		end

		local _, worldMaxs = entity:GetRotatedAABB(entity:OBBMins(), entity:OBBMaxs())
		local position = entity:GetPos() + Vector(0, 0, worldMaxs.z + 10)
		local direction = position - eyePos

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			continue
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local bSearched = entity:GetSearched()
		local name = util.Upper(L("junkName"))
		local hint = L(bSearched and "junkEmptyHint" or "junkHint")

		cam.Start3D2D(position, angles, 0.08)
			local nameWidth = util.TextSpacedSize(name, "nwChat", 4)

			surface.SetFont("nwHudSmall")

			local width = math.max(nameWidth, surface.GetTextSize(hint)) + 40
			local height = 50

			surface.SetDrawColor(9, 24, 32, 200 * fade)
			surface.DrawRect(-width * 0.5, -height * 0.5, width, height)

			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
				(bSearched and 90 or 235) * fade)
			surface.DrawRect(-width * 0.5, -height * 0.5, 3, height)

			util.DrawTextSpaced(name, "nwChat", -nameWidth * 0.5, -height * 0.5 + 16,
				ColorAlpha(bSearched and theme.textFaint or theme.text, 250 * fade), 4,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(hint, "nwHudSmall", 0, height * 0.5 - 15,
				ColorAlpha(theme.textDim, 240 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end)
