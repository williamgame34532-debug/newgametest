NETWORK.flash = NETWORK.flash or {}

NETWORK.flash.time = 0.45
NETWORK.flash.hurt = Color(196, 42, 36)
NETWORK.flash.heal = Color(72, 210, 118)

local flash = {amount = 0, color = NETWORK.flash.hurt}
local lastHealth = 0

local vignette = Material("vgui/gradient-r")
local gradientUp = Material("vgui/gradient-u")
local gradientDown = Material("vgui/gradient-d")

function NETWORK.flash.Play(color, strength)
	flash.color = color
	flash.amount = math.min(math.max(flash.amount, 0) + (strength or 1), 1.4)
end

hook.Add("Think", "nwDamageFlash", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		lastHealth = 0

		return
	end

	local health = client:Health()

	if (lastHealth == 0) then
		lastHealth = health

		return
	end

	if (health != lastHealth) then
		local difference = health - lastHealth
		local maximum = math.max(client:GetMaxHealth(), 1)

		local strength = math.Clamp(math.abs(difference) / (maximum * 0.35), 0.35, 1)

		NETWORK.flash.Play(difference > 0 and NETWORK.flash.heal or
			NETWORK.flash.hurt, strength)

		lastHealth = health
	end

	flash.amount = math.max(flash.amount - FrameTime() / NETWORK.flash.time, 0)
end)

hook.Add("HUDPaint", "nwDamageFlash", function()
	if (flash.amount <= 0.01 or NETWORK.hud.IsHidden()) then
		return
	end

	local width, height = ScrW(), ScrH()
	local color = flash.color
	local amount = math.min(flash.amount, 1)

	local band = math.Round(height * 0.22)
	local side = math.Round(width * 0.18)

	surface.SetDrawColor(color.r, color.g, color.b, 150 * amount)
	surface.SetMaterial(gradientDown)
	surface.DrawTexturedRect(0, 0, width, band)

	surface.SetMaterial(gradientUp)
	surface.DrawTexturedRect(0, height - band, width, band)

	surface.SetDrawColor(color.r, color.g, color.b, 120 * amount)
	surface.SetMaterial(vignette)
	surface.DrawTexturedRect(0, 0, side, height)
	surface.DrawTexturedRectRotated(width - side * 0.5, height * 0.5, side, height,
		180)

	surface.SetDrawColor(color.r, color.g, color.b, 26 * amount)
	surface.DrawRect(0, 0, width, height)
end)
