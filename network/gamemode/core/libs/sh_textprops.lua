if (SERVER) then
	util.AddNetworkString("nwTextConfig")

	local function Notice(client, text)
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(text)
		net.Send(client)
	end

	net.Receive("nwTextConfig", function(_, client)
		if (!client:IsAdmin()) then
			return
		end

		local entity = net.ReadEntity()
		local payload = NETWORK.util.ReadTable()

		if (!IsValid(entity) or entity:GetClass() != "nw_text") then
			return
		end

		entity:SetText(NETWORK.util.Sanitise(payload.text, 128, true))
		entity:SetTextSize(math.Clamp(math.Round(tonumber(payload.size) or 30), 4, 200))
		entity:SetTextColor(Vector(
			math.Clamp(tonumber(payload.r) or 0.35, 0, 1),
			math.Clamp(tonumber(payload.g) or 0.84, 0, 1),
			math.Clamp(tonumber(payload.b) or 1, 0, 1)
		))
	end)

	NETWORK.command.Register("textpanel", {
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local trace = client:GetEyeTrace()
			local entity = ents.Create("nw_text")

			if (!IsValid(entity)) then
				return
			end

			entity:SetPos(trace.HitPos + trace.HitNormal * 2)
			entity:SetAngles(trace.HitNormal:Angle())
			entity:Spawn()
			entity:Activate()

			if (#arguments > 0) then
				entity:SetText(table.concat(arguments, " "))
			end
		end
	})

	NETWORK.command.Register("settext", {
		adminOnly = true,
		description = "cmdSetText",
		usage = "/settext <текст>",
		OnRun = function(command, client, arguments)
			local text = NETWORK.util.Sanitise(table.concat(arguments, " "), 128, true)

			if (text == "") then
				return Notice(client, L("textEmpty"))
			end

			local start = client:GetPos() + Vector(0, 0, 8)
			local trace = util.TraceLine({
				start = start,
				endpos = start - Vector(0, 0, 96),
				filter = client
			})

			local position = (trace.Hit and trace.HitPos or client:GetPos()) +
				Vector(0, 0, 2)
			local angles = (trace.Hit and trace.HitNormal or Vector(0, 0, 1)):Angle()

			angles:RotateAroundAxis(angles:Forward(), client:EyeAngles().y + 90)

			local entity = ents.Create("nw_text")

			if (!IsValid(entity)) then
				return
			end

			entity:SetPos(position)
			entity:SetAngles(angles)
			entity:Spawn()
			entity:Activate()
			entity:SetText(text)

			Notice(client, L("textPlaced"))
		end
	})

	NETWORK.command.Register("deltext", {
		adminOnly = true,
		description = "cmdDelText",
		usage = "/deltext",
		OnRun = function(command, client)
			local closest, distance

			for _, entity in ipairs(ents.FindInSphere(client:GetPos(), 200)) do
				if (entity:GetClass() != "nw_text") then
					continue
				end

				local range = entity:GetPos():Distance(client:GetPos())

				if (!distance or range < distance) then
					closest, distance = entity, range
				end
			end

			if (!IsValid(closest)) then
				return Notice(client, L("textNone"))
			end

			closest:Remove()

			Notice(client, L("textRemoved"))
		end
	})
else
	function NETWORK.gui.SendTextConfig(entity, payload)
		net.Start("nwTextConfig")
			net.WriteEntity(entity)
			NETWORK.util.WriteTable(payload)
		net.SendToServer()
	end
end

properties.Add("nwTextConfig", {
	MenuLabel = "Настроить табло",
	Order = 1,
	MenuIcon = "icon16/font.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_text" and client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenTextConfig(entity)
	end
})
