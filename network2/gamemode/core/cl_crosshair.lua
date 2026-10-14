-- A living crosshair (materials/network2/ui/crosshair.png): a small soft ring in the centre of the
-- screen that breathes with the player - it opens up when moving, running, in the air and after
-- a shot (with four thin ticks around it showing the spread), narrows when standing still,
-- turns accent-coloured and grows a little over something you can use (an item, a door, a
-- player close by), and is small and dim while the weapon is on safety. Hidden in the menus,
-- with the cursor on the screen and while dead. Only with the hands, the physics gun and the
-- tool gun - real weapons have none. nw_crosshair 0 turns it off.

local enabled = CreateClientConVar("nw_crosshair", "1", true, false, "Динамичный прицел")
local RING = Material("network2/ui/crosshair.png", "smooth mips")
local ACCENT = Color(232, 196, 72)

local state = {spread = 0, kick = 0, use = 0, alpha = 0, safe = 0}

hook.Add("EntityFireBullets", "nwCrosshair", function(entity)
	if (CLIENT and entity == LocalPlayer()) then
		state.kick = math.min(state.kick + 0.6, 1.4)
	end
end)

local WITH = {nw_hands = true, weapon_physgun = true, gmod_tool = true}

local USABLE = {nw_item = true, prop_door_rotating = true, func_door = true, func_door_rotating = true,
	func_button = true}

hook.Add("HUDPaint", "nwCrosshair", function()
	local client = LocalPlayer()
	local weapon = IsValid(client) and client:GetActiveWeapon()
	local hidden = !enabled:GetBool() or !IsValid(client) or !client:Alive() or client:GetCharacterID() == 0 or
		(NW.menu and NW.menu.active) or vgui.CursorVisible() or client:InVehicle() or
		(IsValid(weapon) and !WITH[weapon:GetClass()])
	local dt = FrameTime()

	state.alpha = math.Approach(state.alpha, hidden and 0 or 1, dt * 6)

	if (state.alpha <= 0) then
		return
	end

	-- how open: speed, air, the last shots
	local speed = client:GetVelocity():Length2D()
	local want = math.Clamp(speed / 220, 0, 1) * 0.8 + (client:OnGround() and 0 or 0.6) +
		(client:Crouching() and -0.15 or 0)

	state.kick = math.Approach(state.kick, 0, dt * 2.2)
	state.spread = Lerp(math.Clamp(dt * 9, 0, 1), state.spread, math.max(want, 0) + state.kick)

	-- something to use under it
	local trace = client:GetEyeTrace()
	local entity = trace.Entity
	local usable = IsValid(entity) and trace.HitPos:DistToSqr(client:EyePos()) < 120 * 120 and
		(USABLE[entity:GetClass()] or entity:IsPlayer() or (entity:GetClass() == "prop_physics" and
		IsValid(entity:GetPhysicsObject()) and entity:GetPhysicsObject():GetMass() < 100))

	state.use = Lerp(math.Clamp(dt * 10, 0, 1), state.use, usable and 1 or 0)
	state.safe = Lerp(math.Clamp(dt * 8, 0, 1), state.safe, client:IsSafetyOn() and 1 or 0)

	local sh = ScrH()
	local cx, cy = ScrW() / 2, sh / 2
	local base = sh * 0.024 * (1 - state.safe * 0.3)
	local size = base * (1 + state.spread * 0.55 + state.use * 0.25)
	local alpha = 255 * state.alpha * (1 - state.safe * 0.45)
	local r = Lerp(state.use, 255, ACCENT.r)
	local g = Lerp(state.use, 255, ACCENT.g)
	local b = Lerp(state.use, 255, ACCENT.b)

	surface.SetMaterial(RING)
	surface.SetDrawColor(r, g, b, alpha)
	surface.DrawTexturedRect(cx - size / 2, cy - size / 2, size, size)

	-- the spread: four thin ticks moving out
	local open = state.spread

	if (open > 0.05 and state.safe < 0.5) then
		local gap = size * 0.5 + sh * 0.004 + open * sh * 0.012
		local len = math.Round(sh * 0.006)
		local a = alpha * math.Clamp(open * 2, 0, 1) * 0.8

		surface.SetDrawColor(r, g, b, a)
		surface.DrawRect(cx - 1, cy - gap - len, 2, len)
		surface.DrawRect(cx - 1, cy + gap, 2, len)
		surface.DrawRect(cx - gap - len, cy - 1, len, 2)
		surface.DrawRect(cx + gap, cy - 1, len, 2)
	end
end)
