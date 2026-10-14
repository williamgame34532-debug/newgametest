-- No stock HUD at all: health, armour, ammo, crosshair, weapon selection, damage indicators,
-- pickup history, death notices, target names - everything the engine and sandbox draw is off.
-- Only the HUDPaint hook (for the framework's own HUD), menus and the net graph stay; the chat
-- (cl_chat.lua) and the weapon selection (cl_weaponselect.lua) are the framework's own.

local KEEP = {
	CHudGMod = true,       -- runs HUDPaint: off would also hide everything the framework draws
	CHudMenu = true,       -- vote / radio menus of addons
	NetGraph = true
}

function GM:HUDShouldDraw(name)
	return KEEP[name] == true
end

function GM:HUDDrawTargetID()
end

function GM:HUDDrawPickupHistory()
end

function GM:HUDItemPickedUp()
end

function GM:HUDAmmoPickedUp()
end

function GM:HUDWeaponPickedUp()
end

function GM:DrawDeathNotice()
end

function GM:AddDeathNotice()
end

-- the red / white flash of damage and the drown overlay come from the engine's HUD elements
-- (hidden above); the sandbox hint pop-ups are disabled too
function GM:SuppressHint()
	return true
end

hook.Add("InitPostEntity", "nwNoHints", function()
	RunConsoleCommand("cl_showhints", "0")
end)

-- weapon selection: cl_weaponselect.lua

-- ---------------------------------------------------------------- stamina --
-- Bottom centre: a thin dark bar with a yellow fill and the running icon on the left. Fully
-- visible while it is not full (and a moment after), dim when rested; red-ish and pulsing while
-- exhausted. nw_stamina_always 0 hides it completely when full.
local always = CreateClientConVar("nw_stamina_always", "1", true, false, "Стамина всегда на экране")
local shown = {value = 100, alpha = 0, full = 0}

hook.Add("HUDPaint", "nwStamina", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or client:GetCharacterID() == 0 or (NW.menu and NW.menu.active)) then
		return
	end

	local inventory = NW.inventory and NW.inventory.IsOpen and NW.inventory.IsOpen()
	local stamina = client:GetStamina()
	local exhausted = client:IsExhausted()

	shown.value = Lerp(math.Clamp(FrameTime() * 8, 0, 1), shown.value, stamina)

	if (stamina < 99.5) then
		shown.full = CurTime()
	end

	local active = CurTime() - shown.full < 2
	local want = inventory and 0 or (active and 1 or (always:GetBool() and 0.4 or 0))

	shown.alpha = math.Approach(shown.alpha, want, FrameTime() * 3)

	if (shown.alpha <= 0.01) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local w = math.Round(sw * 0.26)
	local h = math.max(5, math.Round(sh * 0.0068))
	local is = math.Round(sh * 0.032)
	local x = math.Round((sw - w) / 2 + is / 2 + sh * 0.008)
	local y = math.Round(sh * 0.955)
	local a = shown.alpha
	local fill = exhausted and Color(214, 112, 72) or Color(232, 194, 64)
	local pulse = exhausted and (0.65 + math.sin(RealTime() * 8) * 0.35) or 1

	NW.ui.DrawIcon("stamina", x - is - sh * 0.012, y + h / 2 - is / 2, is, fill, a * pulse)

	-- track, fill, a light edge on the fill
	draw.RoundedBox(h / 2, x - 1, y - 1, w + 2, h + 2, Color(10, 9, 6, 200 * a))
	draw.RoundedBox(h / 2, x, y, w, h, Color(52, 44, 18, 200 * a))

	local fw = math.max(h, w * math.Clamp(shown.value / 100, 0, 1))

	draw.RoundedBox(h / 2, x, y, fw, h, Color(fill.r, fill.g, fill.b, 235 * a * pulse))
	surface.SetDrawColor(255, 244, 200, 90 * a)
	surface.DrawRect(x + h / 2, y, math.max(0, fw - h), 1)
end)
