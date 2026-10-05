local B = NETWORK.barricade

local VALID = Color(80, 235, 130)
local INVALID = Color(235, 80, 72)

B.rotation = B.rotation or 0

function B.IsPlacing()
	return B.active != nil
end

local function ClearGhost()
	if (IsValid(B.ghost)) then
		B.ghost:Remove()
	end

	B.ghost = nil
end

function B.Stop(bTell)
	B.active = nil

	ClearGhost()

	if (bTell) then
		net.Start("nwBarricadeCancel")
		net.SendToServer()
	end
end

function B.Begin(id)
	local data = B.Get(id)

	if (!data) then
		return
	end

	ClearGhost()

	if (IsValid(NETWORK.gui.menu) and NETWORK.gui.menu.Close) then
		NETWORK.gui.menu:Close()
	end

	B.active = data
	B.rotation = 0
	B.ghost = ClientsideModel(B.PickModel(data), RENDERGROUP_TRANSLUCENT)

	if (IsValid(B.ghost)) then
		B.ghost:SetNoDraw(true)
	end

	NETWORK.gui.Notify(L(data.bBoard and "barricadeHintBoard" or "barricadeHint"),
		NETWORK.theme.accentSoft)
end

net.Receive("nwBarricadeBegin", function()
	B.Begin(net.ReadString())
end)

net.Receive("nwBarricadeCancel", function()
	B.Stop(false)
end)

hook.Add("PostDrawTranslucentRenderables", "nwBarricadeGhost", function(_, bSkybox)
	if (bSkybox or !B.IsPlacing()) then
		return
	end

	local client = LocalPlayer()
	local data = B.active
	local ghost = B.ghost

	if (!IsValid(client) or !IsValid(ghost)) then
		return
	end

	local position, angles, bValid = B.GetSpot(client, data, B.rotation)
	local colour = bValid and VALID or INVALID

	ghost:SetPos(position)
	ghost:SetAngles(angles)
	ghost:SetupBones()

	render.SetColorModulation(colour.r / 255, colour.g / 255, colour.b / 255)
	render.SetBlend(0.45)
		ghost:DrawModel()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end)

hook.Add("PlayerBindPress", "nwBarricadeGhost", function(client, bind, bPressed)
	if (!B.IsPlacing() or !bPressed) then
		return
	end

	if (string.find(bind, "+reload", 1, true)) then
		B.rotation = (B.rotation + B.rotateStep) % 360

		surface.PlaySound("buttons/lightswitch2.wav")

		return true
	end

	if (string.find(bind, "+attack2", 1, true)) then
		B.Stop(true)

		return true
	end

	if (string.find(bind, "+attack", 1, true)) then
		local data = B.active
		local position, _, bValid = B.GetSpot(client, data, B.rotation)

		if (!bValid) then
			surface.PlaySound("buttons/button10.wav")

			return true
		end

		net.Start("nwBarricadePlace")
			net.WriteString(data.id)
			net.WriteVector(position)
			net.WriteFloat(B.rotation)
		net.SendToServer()

		B.Stop(false)

		return true
	end
end)

hook.Add("PlayerSwitchWeapon", "nwBarricadeGhost", function()
	if (B.IsPlacing()) then
		B.Stop(true)
	end
end)

local function IsMine(client, entity)
	if (client:IsAdmin()) then
		return true
	end

	local owner = entity.GetOwnerChar and entity:GetOwnerChar() or 0

	return owner != 0 and owner == client:GetCharacterID()
end

if (NETWORK.interact and NETWORK.interact.Register) then
	NETWORK.interact.Register("nw_barricade", {
		label = "interactDismantle",

		icon = "dismantle",

		CanUse = function(client, entity)
			local data = entity.GetTypeData and entity:GetTypeData()

			if (data and data.repair and entity:GetFraction() < 1) then
				return true
			end

			return IsMine(client, entity)
		end
	})

	NETWORK.interact.Register("nw_padlock", {
		label = "interactPadlock",
		icon = "lock"
	})
end

local function Plate(title, subtitle, fraction, tint)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local line = math.max(Sc(1), 1)

	surface.SetFont("nwHudSmall")

	local titleWidth = surface.GetTextSize(title)
	local subWidth = subtitle and surface.GetTextSize(subtitle) or 0
	local width = math.max(Sc(180), titleWidth + Sc(24), subWidth + Sc(24))
	local height = subtitle and Sc(46) or Sc(34)
	local x = math.Round(ScrW() * 0.5 - width * 0.5)
	local y = math.Round(ScrH() * 0.5 + Sc(48))

	surface.SetDrawColor(8, 9, 10, 205)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(255, 255, 255, 30)
	surface.DrawOutlinedRect(x, y, width, height, line)

	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 230)
	surface.DrawRect(x, y, width, math.max(Sc(2), 2))

	draw.SimpleText(title, "nwHudSmall", x + Sc(12), y + Sc(14), theme.text,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (subtitle) then
		draw.SimpleText(subtitle, "nwHudSmall", x + Sc(12), y + Sc(29), theme.textDim,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if (fraction) then
		local barY = y + height - Sc(8)
		local barWidth = width - Sc(24)
		local colour = tint or (fraction > 0.5 and theme.positive or
			(fraction > 0.25 and theme.warning or theme.danger))

		surface.SetDrawColor(255, 255, 255, 22)
		surface.DrawRect(x + Sc(12), barY, barWidth, math.max(Sc(3), 2))

		surface.SetDrawColor(colour.r, colour.g, colour.b, 235)
		surface.DrawRect(x + Sc(12), barY, math.Round(barWidth * fraction), math.max(Sc(3), 2))
	end
end

hook.Add("HUDPaint", "nwBarricadeLabel", function()
	if (NETWORK.hud and NETWORK.hud.IsHidden and NETWORK.hud.IsHidden()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or !client:Alive() or B.IsPlacing()) then
		return
	end

	if (IsValid(NETWORK.gui.menu)) then
		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or client:GetShootPos():Distance(trace.HitPos) > B.labelRange) then
		return
	end

	local class = entity:GetClass()

	if (class == "nw_barricade") then
		local data = entity:GetTypeData()
		local fraction = entity:GetFraction()

		local subtitle = string.format("%d / %d", entity:GetDurability(),
			entity:GetMaxDurability())

		if (data and data.repair and fraction < 1) then
			local parts = {}

			for id, amount in pairs(data.repair.items or {}) do
				local base = NETWORK.item.Get(id)

				parts[#parts + 1] = (base and base.name or id) .. " ×" .. amount
			end

			subtitle = subtitle .. "   ·   " .. L("barricadeRepairHint", table.concat(parts, ", "))
		end

		return Plate(data and L(data.name) or L("barricadeName"), subtitle, fraction)
	end

	if (class == "nw_padlock") then
		return Plate(L("padlockName"), L(entity:GetLocked() and "padlockStateLocked" or
			"padlockStateOpen"), entity:GetFraction())
	end

	if (NETWORK.door.IsDoor(entity)) then
		local seal = B.IsDoorSealed(entity)

		if (seal == "boarded") then
			return Plate(L("doorBoardedLabel"), L("doorBoardedCount", #B.GetBoards(entity),
				B.maxBoards))
		end

		if (seal == "padlock") then
			return Plate(L("doorPadlockedLabel"), L("padlockStateLocked"))
		end
	end
end)
