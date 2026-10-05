NETWORK.quest.active = NETWORK.quest.active or {}

net.Receive("nwQuestSync", function()
	NETWORK.quest.active = NETWORK.util.ReadTable()

	hook.Run("NetworkQuestsUpdated")
end)

hook.Add("NetworkDrawHUD", "nwQuest", function()
	local client = LocalPlayer()
	local list = {}

	for id in pairs(NETWORK.quest.active) do
		local quest = NETWORK.quest.Get(id)

		if (quest) then
			list[#list + 1] = quest
		end
	end

	if (#list == 0) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local shadow = math.max(Sc(2), 1)
	local x = ScrW() - Sc(48)
	local y = math.Round(ScrH() * 0.5) - Sc(60)
	local top = y

	for _, quest in ipairs(list) do
		util.DrawTextSpacedShadow(util.Upper(quest.name), "nwField",
			x - util.TextSpacedSize(util.Upper(quest.name), "nwField", Sc(3)), y,
			ColorAlpha(theme.accentSoft, 250), Sc(3), TEXT_ALIGN_CENTER, shadow)

		y = y + Sc(24)

		for index, objective in ipairs(quest.objectives) do
			local have, need = NETWORK.quest.GetProgress(client, quest.id, index)
			local text = NETWORK.quest.GetObjectiveText(objective) .. "  " .. have .. " / " .. need
			local color = have >= need and Color(120, 220, 140) or theme.textDim

			util.DrawSimpleTextShadow(text, "nwHudSmall", x, y, ColorAlpha(color, 235),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, shadow)

			y = y + Sc(18)
		end

		y = y + Sc(14)
	end

	NETWORK.quest.hudTop = top
	NETWORK.quest.hudBottom = y
	NETWORK.quest.hudAt = CurTime()
end)

hook.Add("PostDrawTranslucentRenderables", "nwQuestPoints", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	local client = LocalPlayer()

	render.SetColorMaterial()

	for id in pairs(NETWORK.quest.active) do
		for _, point in ipairs(NETWORK.quest.GetOpenPoints(client, id)) do
			if (point.bDone) then
				continue
			end

			local radius = math.max(tonumber(point.objective.radius) or 96, 16)
			local color = point.objective.type == "use" and Color(126, 224, 250, 190) or
				Color(96, 224, 140, 190)

			render.DrawWireframeSphere(point.position, radius, 12, 12,
				ColorAlpha(color, 60), true)
			render.DrawWireframeSphere(point.position +
				Vector(0, 0, 40 + math.sin(CurTime() * 2) * 4), 10, 8, 8, color, true)
		end
	end
end)

hook.Add("NetworkDrawHUD", "nwQuestPoints", function()
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local client = LocalPlayer()
	local shadow = math.max(Sc(2), 1)

	for id in pairs(NETWORK.quest.active) do
		for _, point in ipairs(NETWORK.quest.GetOpenPoints(client, id)) do
			if (point.bDone) then
				continue
			end

			local screen = (point.position + Vector(0, 0, 56)):ToScreen()

			if (!screen.visible) then
				continue
			end

			local color = point.objective.type == "use" and NETWORK.theme.accentSoft or
				Color(96, 224, 140)
			local distance = math.Round(
				client:GetPos():Distance(point.position) * 0.0254)

			util.DrawSimpleTextShadow(
				NETWORK.quest.GetObjectiveText(point.objective), "nwField",
				math.Round(screen.x), math.Round(screen.y), ColorAlpha(color, 250),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

			util.DrawSimpleTextShadow(distance .. " " .. L("questMetres"),
				"nwHudSmall", math.Round(screen.x), math.Round(screen.y) + Sc(18),
				ColorAlpha(NETWORK.theme.textDim, 235), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER, shadow)
		end
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwQuestMarker", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	local client = LocalPlayer()

	render.SetColorMaterial()

	for id in pairs(NETWORK.quest.active) do
		local quest = NETWORK.quest.Get(id)

		if (!quest or !quest.marker) then
			continue
		end

		if (quest.markerMap and quest.markerMap != game.GetMap()) then
			continue
		end

		local position = Vector(quest.marker[1], quest.marker[2], quest.marker[3]) +
			Vector(0, 0, 40 + math.sin(CurTime() * 2) * 4)

		render.DrawWireframeSphere(position, 10, 8, 8, Color(240, 200, 90, 220), true)
	end
end)

hook.Add("NetworkDrawHUD", "nwQuestMarker", function()
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local client = LocalPlayer()
	local shadow = math.max(Sc(2), 1)

	for id in pairs(NETWORK.quest.active) do
		local quest = NETWORK.quest.Get(id)

		if (!quest or !quest.marker) then
			continue
		end

		if (quest.markerMap and quest.markerMap != game.GetMap()) then
			continue
		end

		local position = Vector(quest.marker[1], quest.marker[2], quest.marker[3]) +
			Vector(0, 0, 56)
		local screen = position:ToScreen()

		if (!screen.visible) then
			continue
		end

		local x = math.Round(screen.x)
		local y = math.Round(screen.y)
		local distance = math.Round(client:GetPos():Distance(position) * 0.0254)

		util.DrawSimpleTextShadow(quest.name, "nwField", x, y,
			ColorAlpha(Color(240, 200, 90), 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

		util.DrawSimpleTextShadow(distance .. L("invWeightUnit"):gsub("кг", "м"):gsub("kg", "m"),
			"nwHudSmall", x, y + Sc(18), ColorAlpha(NETWORK.theme.textDim, 235),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

		local lineY = y + Sc(38)

		for index, objective in ipairs(quest.objectives) do
			local have, need = NETWORK.quest.GetProgress(client, id, index)
			local color = have >= need and Color(120, 220, 140) or NETWORK.theme.textDim

			util.DrawSimpleTextShadow(NETWORK.quest.GetObjectiveText(objective) .. "  " ..
				have .. " / " .. need, "nwHudSmall", x, lineY, ColorAlpha(color, 235),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

			lineY = lineY + Sc(16)
		end
	end
end)
