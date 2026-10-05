NETWORK.crosshair = NETWORK.crosshair or {}

NETWORK.crosshair.gapMax = 25
NETWORK.crosshair.dot = 4
NETWORK.crosshair.rangeMax = 1000

local enabled = CreateClientConVar("network_crosshair", "1", true, false,
	"Прицел из точек")

local currentGap = 0
local currentAlpha = 0
local kick = 0
local lit = 0

hook.Add("HUDShouldDraw", "nwCrosshair", function(element)
	if (element == "CHudCrosshair") then
		return false
	end
end)

hook.Add("PreDrawHUD", "nwCrosshairHide", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and weapon.DrawCrosshair != false) then
		weapon.DrawCrosshair = false
	end
end)

local function DrawDot(x, y, size, fill, alpha)
	local half = math.floor(size * 0.5)

	surface.SetDrawColor(0, 0, 0, 200 * alpha)
	surface.DrawOutlinedRect(x - half - 1, y - half - 1, size + 2, size + 2, 1)

	surface.SetDrawColor(fill.r, fill.g, fill.b, 235 * alpha)
	surface.DrawRect(x - half, y - half, size, size)
end

function NETWORK.crosshair.ShouldDraw(client)
	if (!enabled:GetBool() or !IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return false
	end

	if (IsValid(NETWORK.gui.dialogue) or IsValid(client:GetNWEntity("nwRagdollEntity", NULL))) then
		return false
	end

	if (vgui.CursorVisible()) then
		return false
	end

	if (hook.Run("ShouldDrawCrosshair", client, client:GetActiveWeapon()) == false) then
		return false
	end

	return true
end

hook.Add("HUDPaint", "nwCrosshair", function()
	local client = LocalPlayer()
	local frame = math.min(FrameTime(), 0.1)
	local bShow = NETWORK.crosshair.ShouldDraw(client)

	if (NETWORK.hud and NETWORK.hud.IsHidden and NETWORK.hud.IsHidden()) then
		bShow = false
	end

	if (bShow and IsValid(client:GetActiveWeapon()) and client:IsWeaponRaised()) then
		bShow = false
	end

	currentAlpha = Lerp(math.Clamp(frame * 12, 0, 1), currentAlpha, bShow and 1 or 0)

	if (currentAlpha < 0.02) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local angles = client:EyeAngles() + client:GetViewPunchAngles()
	local start = client:GetShootPos()
	local trace = util.TraceLine({
		start = start,
		endpos = start + angles:Forward() * 32768,
		filter = client,
		mask = MASK_SHOT
	})

	local screen = trace.HitPos:ToScreen()
	local x = math.Round(screen.x)
	local y = math.Round(screen.y)
	local size = math.max(Sc(4), 4)
	local half = math.floor(size * 0.5)

	local bUse = false

	if (NETWORK.interact and NETWORK.interact.GetTarget) then
		bUse = IsValid((NETWORK.interact.GetTarget(client)))
	end

	lit = Lerp(math.Clamp(frame * 10, 0, 1), lit, bUse and 1 or 0)

	local fill = Color(Lerp(lit, 255, theme.combine.r), Lerp(lit, 255, theme.combine.g),
		Lerp(lit, 255, theme.combine.b))

	surface.SetDrawColor(0, 0, 0, 90 * currentAlpha)
	surface.DrawRect(x - half - 1, y - half - 1, size + 2, size + 2)
	surface.SetDrawColor(fill.r, fill.g, fill.b, (90 + 120 * lit) * currentAlpha)
	surface.DrawRect(x - half, y - half, size, size)
end)
