NETWORK.deploy.ghost = NETWORK.deploy.ghost or nil

local VALID = Color(80, 235, 130)
local INVALID = Color(235, 80, 72)

function NETWORK.deploy.IsPlacing()
	return NETWORK.deploy.active != nil
end

local function ClearGhost()
	if (IsValid(NETWORK.deploy.ghost)) then
		NETWORK.deploy.ghost:Remove()
	end

	NETWORK.deploy.ghost = nil
end

function NETWORK.deploy.Stop(bTell)
	NETWORK.deploy.active = nil
	NETWORK.deploy.anchor = nil
	NETWORK.deploy.anchorNormal = nil

	ClearGhost()

	if (bTell) then
		net.Start("nwDeployCancel")
		net.SendToServer()
	end
end

function NETWORK.deploy.Begin(id)
	local data = NETWORK.deploy.Get(id)

	if (!data) then
		return
	end

	ClearGhost()

	NETWORK.deploy.active = data
	NETWORK.deploy.anchor = nil
	NETWORK.deploy.anchorNormal = nil
	NETWORK.deploy.ghost = ClientsideModel(NETWORK.deploy.GetModel(data),
		RENDERGROUP_TRANSLUCENT)

	if (IsValid(NETWORK.deploy.ghost)) then
		NETWORK.deploy.ghost:SetNoDraw(true)
	end

	NETWORK.gui.Notify(L(data.hint or "deployHint"), NETWORK.theme.accentSoft)
end

net.Receive("nwDeployBegin", function()
	NETWORK.deploy.Begin(net.ReadString())
end)

net.Receive("nwDeployCancel", function()
	NETWORK.deploy.Stop(false)
end)

hook.Add("PostDrawTranslucentRenderables", "nwDeployGhost", function(_, bSkybox)
	if (bSkybox or !NETWORK.deploy.IsPlacing()) then
		return
	end

	local client = LocalPlayer()
	local data = NETWORK.deploy.active
	local ghost = NETWORK.deploy.ghost

	if (!IsValid(client) or !IsValid(ghost)) then
		return
	end

	local position, angles, bValid = NETWORK.deploy.GetSpot(client, data)
	local anchor = NETWORK.deploy.anchor

	if (anchor) then
		local bWire = bValid and anchor:Distance(position) <= (data.wireLength or 250) and
			anchor:Distance(position) >= (data.wireMin or 24)

		if (bWire) then
			local wire = util.TraceLine({
				start = anchor + NETWORK.deploy.anchorNormal * 2,
				endpos = position,
				mask = MASK_SOLID_BRUSHONLY
			})

			bWire = !wire.Hit or wire.Fraction >= 0.98
		end

		local wireColour = bWire and VALID or INVALID

		render.SetColorMaterial()
		render.DrawBeam(anchor + NETWORK.deploy.anchorNormal * 2, position, 0.6, 0, 1,
			ColorAlpha(wireColour, 200))

		position = anchor + NETWORK.deploy.anchorNormal * (data.offset or 0)
		angles = NETWORK.deploy.anchorAngles or angles
		bValid = bWire
	end

	local colour = bValid and VALID or INVALID

	ghost:SetPos(position)
	ghost:SetAngles(angles)
	ghost:SetupBones()

	render.SetColorModulation(colour.r / 255, colour.g / 255, colour.b / 255)
	render.SetBlend(0.45)
		ghost:DrawModel()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)

	if ((data.mount or "floor") == "floor") then
		render.SetColorMaterial()
		render.DrawQuadEasy(position + Vector(0, 0, 1), Vector(0, 0, 1), 64, 64,
			ColorAlpha(colour, 40), 0)
	end
end)

hook.Add("PlayerBindPress", "nwDeployGhost", function(client, bind, bPressed)
	if (!NETWORK.deploy.IsPlacing() or !bPressed) then
		return
	end

	if (string.find(bind, "+attack2")) then
		NETWORK.deploy.Stop(true)

		return true
	end

	if (string.find(bind, "+attack")) then
		local data = NETWORK.deploy.active
		local position, angles, bValid, normal = NETWORK.deploy.GetSpot(client, data)

		if (!bValid) then
			surface.PlaySound("buttons/button10.wav")

			return true
		end

		if (data.bTwoPoint) then
			local anchor = NETWORK.deploy.anchor

			if (!anchor) then
				NETWORK.deploy.anchor = position - (normal or vector_up) * (data.offset or 0)
				NETWORK.deploy.anchorNormal = normal or vector_up
				NETWORK.deploy.anchorAngles = angles

				surface.PlaySound("buttons/lightswitch2.wav")
				NETWORK.gui.Notify(L(data.hint2 or "deployHint"), NETWORK.theme.accentSoft)

				return true
			end

			local distance = anchor:Distance(position)

			if (distance > (data.wireLength or 250) or distance < (data.wireMin or 24)) then
				surface.PlaySound("buttons/button10.wav")

				return true
			end

			net.Start("nwDeployPlace")
				net.WriteString(data.id)
				net.WriteVector(anchor)
				net.WriteAngle(NETWORK.deploy.anchorAngles or angles)
				net.WriteBool(true)
				net.WriteVector(NETWORK.deploy.anchorNormal)
			net.SendToServer()

			NETWORK.deploy.Stop(false)

			return true
		end

		net.Start("nwDeployPlace")
			net.WriteString(data.id)
			net.WriteVector(position)
			net.WriteAngle(angles)
			net.WriteBool(false)
		net.SendToServer()

		NETWORK.deploy.Stop(false)

		return true
	end
end)

hook.Add("PlayerSwitchWeapon", "nwDeployGhost", function()
	if (NETWORK.deploy.IsPlacing()) then
		NETWORK.deploy.Stop(true)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwDeployLabel", function(_, bSkybox)
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
	local range = 260

	for _, entity in ipairs(ents.FindInSphere(eyePos, range)) do
		local id = IsValid(entity) and entity:GetNWString("nwDeploy", "") or ""
		local data = id != "" and NETWORK.deploy.Get(id)

		if (!data) then
			continue
		end

		if (data.bHidden) then
			if (!NETWORK.deploy.CanUseType(client, data)) then
				continue
			end

			local sight = _G.util.TraceLine({
				start = eyePos,
				endpos = entity:WorldSpaceCenter(),
				filter = {client, entity},
				mask = MASK_SOLID_BRUSHONLY
			})

			if (sight.Hit) then
				continue
			end
		end

		local center = entity:LocalToWorld(entity:OBBCenter())
		local distance = eyePos:Distance(center)
		local fade = 1 - math.Clamp((distance - range * 0.55) / (range * 0.45), 0, 1)

		if (fade <= 0.02) then
			continue
		end

		local _, worldMaxs = entity:GetRotatedAABB(entity:OBBMins(), entity:OBBMaxs())
		local position = entity:GetPos() + Vector(0, 0, worldMaxs.z + 12)
		local direction = position - eyePos

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			continue
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local name = util.Upper(L(data.name))
		local hint

		if (data.labelHint) then
			hint = L(data.labelHint)
		elseif (NETWORK.deploy.CanUseType(client, data)) then
			hint = L("deployTakeHint")
		else
			hint = L(data.labelForeign or "deployAlliance")
		end

		cam.Start3D2D(position, angles, 0.1)
			local nameWidth = util.TextSpacedSize(name, "nwChat", 4)

			surface.SetFont("nwHudSmall")

			local width = math.max(nameWidth, surface.GetTextSize(hint)) + 40
			local height = 50

			surface.SetDrawColor(9, 24, 32, 210 * fade)
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
