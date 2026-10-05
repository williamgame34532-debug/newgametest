NETWORK.sway = NETWORK.sway or {}

local enabled = CreateClientConVar("network_camerasway", "1", true, false,
	"Динамическая камера при повороте мыши")

local current = Angle(0, 0, 0)
local target = Angle(0, 0, 0)
local previous = Angle(0, 0, 0)

NETWORK.view.Register("sway", 40, function(client, view)
	if (!enabled:GetBool() or !client:Alive()) then
		return
	end

	if (IsValid(NETWORK.gui.dialogue) or IsValid(NETWORK.gui.menu)) then
		return
	end

	local frame = math.min(FrameTime(), 0.1)
	local deltaYaw = math.NormalizeAngle(view.angles.y - previous.y)
	local deltaPitch = math.NormalizeAngle(view.angles.p - previous.p)

	previous = Angle(view.angles.p, view.angles.y, view.angles.r)

	target.r = math.Clamp(-deltaYaw * 0.22, -2.4, 2.4)
	target.p = math.Clamp(-deltaPitch * 0.12, -1.6, 1.6)
	target.y = math.Clamp(-deltaYaw * 0.08, -1.2, 1.2)

	local rate = math.Clamp(frame * 7, 0, 1)

	current.p = Lerp(rate, current.p, target.p)
	current.y = Lerp(rate, current.y, target.y)
	current.r = Lerp(rate, current.r, target.r)

	local speed = client:GetVelocity():Length2D()
	local bob = math.sin(CurTime() * 9) * math.Clamp(speed / 200, 0, 1) * 0.35

	view.angles = Angle(view.angles.p + current.p + bob, view.angles.y + current.y,
		view.angles.r + current.r)

	return true
end)
