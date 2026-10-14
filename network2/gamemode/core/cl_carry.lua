-- A line from the hand to the object a player carries with the hands (nw_hands), drawn flat on
-- the screen: a thin straight line in the accent colour with a small square on the object, a
-- dot on the hand. It grows out of the hand when the object is picked up (like the arrow of
-- the Helix tooltips) and fades when it is let go.

local COLOR = Color(120, 200, 245)
local state = {}

local function Ease(t)
	return 1 - (1 - t) ^ 5
end

hook.Add("HUDPaint", "nwCarryLine", function()
	local now = RealTime()

	for _, client in ipairs(player.GetAll()) do
		local entity = client:GetNW2Entity("nwHeldEntity")
		local holding = IsValid(entity) and client:Alive() and client:GetNW2Bool("nwHoldingObject", false)
		local s = state[client]

		if (holding) then
			if (!s or s.entity != entity) then
				s = {entity = entity, start = now, alpha = 0}
				state[client] = s
			end
		end

		if (!s) then
			continue
		end

		s.alpha = math.Approach(s.alpha, holding and 1 or 0, FrameTime() * 6)

		if (s.alpha <= 0 or !IsValid(s.entity)) then
			state[client] = nil
			continue
		end

		-- the hand (or under the eyes when the player is not drawn)
		local from
		local bone = client:LookupBone("ValveBiped.Bip01_R_Hand")

		if (bone and (client != LocalPlayer() or client:ShouldDrawLocalPlayer())) then
			from = client:GetBonePosition(bone)
		end

		from = from or (client:EyePos() + client:GetAimVector() * 16 - Vector(0, 0, 12))

		local a = from:ToScreen()
		local b = s.entity:WorldSpaceCenter():ToScreen()

		if (!a.visible and !b.visible) then
			continue
		end

		local fraction = Ease(math.Clamp((now - s.start) / 0.35, 0, 1))
		local x2 = a.x + (b.x - a.x) * fraction
		local y2 = a.y + (b.y - a.y) * fraction
		local alpha = 255 * s.alpha

		surface.SetDrawColor(COLOR.r, COLOR.g, COLOR.b, alpha)
		surface.DrawLine(a.x, a.y, x2, y2)
		surface.DrawRect(a.x - 1, a.y - 1, 2, 2)
		surface.DrawRect(x2 - 2, y2 - 2, 4, 4)
	end
end)
