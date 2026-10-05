if (CLIENT) then

	NETWORK.holdmenu = NETWORK.holdmenu or {}
	NETWORK.holdmenu.range = 120
	NETWORK.holdmenu.holdTime = 0.25

	local ragdolls = {
		prop_ragdoll = true,
		nw_ragdoll = true
	}

	function NETWORK.holdmenu.GetTarget()
		local client = LocalPlayer()

		if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
			return
		end

		local trace = util.TraceLine({
			start = client:EyePos(),
			endpos = client:EyePos() + client:GetAimVector() * NETWORK.holdmenu.range,
			filter = client,
			mask = MASK_SHOT
		})

		local entity = trace.Entity

		if (!IsValid(entity)) then
			return
		end

		if (ragdolls[entity:GetClass()]) then
			return entity, "body"
		end

		if (NETWORK.door.IsDoor(entity) and
			trace.HitPos:Distance(client:GetPos()) <= 110) then
			return entity, "door"
		end
	end

	function NETWORK.holdmenu.BuildOptions(entity, kind)
		local client = LocalPlayer()
		local options = {}

		if (kind == "body") then
			options[#options + 1] = {
				label = L("bodybagPack"),
				callback = function()
					net.Start("nwBodybagPack")
						net.WriteEntity(entity)
					net.SendToServer()
				end
			}

			return options
		end

		options[#options + 1] = {
			label = L("doorBreachKick"),
			hint = L("radialBreachHint"),
			callback = function()
				net.Start("nwDoorBreach")
					net.WriteEntity(entity)
					net.WriteString("kick")
				net.SendToServer()
			end
		}

		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and weapon:GetClass() == "tfa_nmrih_crowbar") then
			options[#options + 1] = {
				label = L("doorBreachCrowbar"),
				callback = function()
					net.Start("nwDoorBreach")
						net.WriteEntity(entity)
						net.WriteString("crowbar")
					net.SendToServer()
				end
			}
		end

		options[#options + 1] = {
			label = L("doorBreachValve"),
			callback = function()
				net.Start("nwDoorBreach")
					net.WriteEntity(entity)
					net.WriteString("valve")
				net.SendToServer()
			end
		}

		return options
	end

	function NETWORK.holdmenu.Open(entity, kind)
		if (IsValid(NETWORK.holdmenu.panel)) then
			return
		end

		local options = NETWORK.holdmenu.BuildOptions(entity, kind)

		if (#options == 0) then
			return
		end

		local theme = NETWORK.theme
		local Sc = NETWORK.util.Scale

		local panel = vgui.Create("DPanel")

		panel:SetSize(ScrW(), ScrH())
		panel:SetPos(0, 0)
		panel:MakePopup()
		panel:SetKeyboardInputEnabled(true)
		panel:SetCursor("arrow")
		panel.Paint = function() end

		NETWORK.holdmenu.panel = panel

		local width = Sc(260)
		local height = Sc(42)
		local padding = Sc(6)
		local total = #options * (height + padding) + padding

		local card = panel:Add("DPanel")

		card:SetSize(width, total)
		card:SetPos(ScrW() * 0.5 - width * 0.5, ScrH() * 0.5 - total * 0.5)
		card.Paint = function(this, w, h)
			surface.SetDrawColor(9, 16, 30, 238)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 190)
			surface.DrawOutlinedRect(0, 0, w, h)
		end

		for index, option in ipairs(options) do
			local button = card:Add("DButton")

			button:SetSize(width - padding * 2, height)
			button:SetPos(padding, padding + (index - 1) * (height + padding))
			button:SetText("")

			button.Paint = function(this, w, h)
				local bHover = this:IsHovered()

				surface.SetDrawColor(bHover and 20 or 13, bHover and 36 or 23,
					bHover and 60 or 41, 255)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(theme.accent.r, theme.accent.g,
					theme.accent.b, bHover and 235 or 140)
				surface.DrawRect(0, 0, Sc(3), h)

				draw.SimpleText(option.label, "nwChat", Sc(16),
					option.hint and h * 0.35 or h * 0.5,
					bHover and theme.accentSoft or theme.text, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)

				if (option.hint) then
					draw.SimpleText(option.hint, "nwHudSmall", Sc(16), h * 0.7,
						theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
			end

			button.DoClick = function()
				if (NETWORK.sound and NETWORK.sound.Click) then
					NETWORK.sound.Click()
				end

				option.callback()

				NETWORK.holdmenu.Close()
			end
		end

		panel.OnMousePressed = function(_, code)

			if (code == MOUSE_RIGHT or code == MOUSE_LEFT) then
				NETWORK.holdmenu.Close()
			end
		end

		panel.OnKeyCodePressed = function(_, key)
			if (key == KEY_ESCAPE) then
				NETWORK.holdmenu.Close()
			end
		end

		panel.Think = function()
			if (!IsValid(entity)) then
				NETWORK.holdmenu.Close()
			end
		end

		if (NETWORK.sound and NETWORK.sound.Soft) then
			NETWORK.sound.Soft()
		end
	end

	function NETWORK.holdmenu.Close()
		if (IsValid(NETWORK.holdmenu.panel)) then
			NETWORK.holdmenu.panel:Remove()
		end

		NETWORK.holdmenu.panel = nil
	end

	local holdStart

	hook.Add("PlayerBindPress", "nwInteractHold", function(client, bind, bPressed)
		if (string.lower(bind) != "+reload") then
			return
		end

		if (!bPressed) then
			holdStart = nil

			return
		end

		if (IsValid(NETWORK.holdmenu.panel)) then
			return true
		end

		if (!NETWORK.holdmenu.GetTarget()) then
			holdStart = nil

			return
		end

		holdStart = holdStart or SysTime()

		return true
	end)

	NETWORK.holdmenu.bDisabled = true

	hook.Add("Think", "nwInteractHold", function()
		if (NETWORK.holdmenu.bDisabled) then
			holdStart = nil

			return
		end

		if (!holdStart or IsValid(NETWORK.holdmenu.panel)) then
			return
		end

		if (SysTime() - holdStart < NETWORK.holdmenu.holdTime) then
			return
		end

		holdStart = nil

		local entity, kind = NETWORK.holdmenu.GetTarget()

		if (!entity) then
			return
		end

		NETWORK.holdmenu.Open(entity, kind)
	end)
end
