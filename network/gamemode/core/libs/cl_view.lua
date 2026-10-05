NETWORK.view = NETWORK.view or {}

NETWORK.view.bobScale = 1
NETWORK.view.rollScale = 1
NETWORK.view.landScale = 1
NETWORK.view.stiffness = 130
NETWORK.view.damping = 14

local bobConVar = CreateClientConVar("network_viewbob", "1", true, false,
	"Сила покачивания камеры Network")
local rollConVar = CreateClientConVar("network_viewroll", "1", true, false,
	"Сила наклона камеры при движении")

local cycle = 0
local amount = 0
local strafe = 0
local land = 0
local landVelocity = 0
local bWasGround = true

hook.Add("OnPlayerHitGround", "nwViewLand", function(client, bWater, bFloater, speed)
	if (client != LocalPlayer() or bWater) then
		return
	end

	landVelocity = landVelocity + math.Clamp(speed / 420, 0.15, 1) * 30 *
		NETWORK.view.landScale * bobConVar:GetFloat()
end)

NETWORK.view.Register("viewbob", 35, function(client, view)
	if (!client:Alive() or !client:HasCharacter()) then
		return
	end

	local bob = GetConVar("network_viewbob")
	local roll = GetConVar("network_viewroll")

	if (!bob or !roll) then
		return
	end

	local velocity = client:GetVelocity()
	local speed = velocity:Length2D()
	local fraction = math.Clamp(speed / math.max(NETWORK.movement.runSpeed, 1), 0, 1)
	local time = CurTime()

	view.angles = Angle(
		view.angles.p + math.sin(time * 9) * fraction * 0.45 * bob:GetFloat(),
		view.angles.y + math.cos(time * 5) * fraction * 0.35 * bob:GetFloat(),
		view.angles.r + view.angles:Right():Dot(velocity) / 220 * roll:GetFloat()
	)

	return true
end)
