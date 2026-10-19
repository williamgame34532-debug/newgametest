-- The registration sweep of the Alliance doors (sv_doors.lua sends it): from the door a fan of light comes
-- out and a scanning frame runs down the one at the door, head to feet, twice - blue when the door knows
-- the unit, red when it refuses.

local BEAM = Material("effects/laser1")
local GLOW = Material("sprites/light_glow02_add")
local DURATION = 1.1
local BLUE = Color(90, 190, 255)
local RED = Color(255, 70, 60)

local scans = {}

net.Receive("nwDoorScan", function()
	local door, client, bGranted = net.ReadEntity(), net.ReadEntity(), net.ReadBool()

	if (IsValid(door) and IsValid(client)) then
		scans[#scans + 1] = {door = door, client = client, color = bGranted and BLUE or RED, start = CurTime()}
	end
end)

-- the frame around the body at the height z
local function Frame(center, z, radius, color, width)
	local corners = {
		Vector(center.x - radius, center.y - radius, z), Vector(center.x + radius, center.y - radius, z),
		Vector(center.x + radius, center.y + radius, z), Vector(center.x - radius, center.y + radius, z)
	}

	for index = 1, 4 do
		render.DrawBeam(corners[index], corners[index % 4 + 1], width, 0, 1, color)
	end

	return corners
end

hook.Add("PostDrawTranslucentRenderables", "nwDoorScan", function(bDepth, bSkybox)
	if (bDepth or bSkybox or #scans == 0) then
		return
	end

	local now = CurTime()

	for index = #scans, 1, -1 do
		local scan = scans[index]
		local client = scan.client
		local fraction = (now - scan.start) / DURATION

		if (fraction >= 1 or !IsValid(scan.door) or !IsValid(client)) then
			table.remove(scans, index)
		else
			-- two passes down, the second fainter; fades at the end
			local pass = fraction < 0.5 and fraction * 2 or (fraction - 0.5) * 2
			local alpha = (fraction < 0.5 and 255 or 150) * math.min(1, (1 - fraction) * 5)
			local color = ColorAlpha(scan.color, alpha)
			local bottom, top = client:GetPos().z, client:GetPos().z + client:OBBMaxs().z
			local z = Lerp(math.ease.InOutSine(pass), top + 2, bottom + 2)
			local center = client:GetPos()
			local origin = scan.door:NearestPoint(client:EyePos())

			origin.z = math.min(origin.z, top + 10)

			render.SetMaterial(BEAM)

			local corners = Frame(center, z, 20, color, 2.5)

			Frame(center, z + 4, 18, ColorAlpha(scan.color, alpha * 0.35), 1.5)

			for corner = 1, 4 do
				render.DrawBeam(origin, corners[corner], 1.2, 0, 1, ColorAlpha(scan.color, alpha * 0.4))
			end

			render.SetMaterial(GLOW)
			render.DrawSprite(origin, 14, 14, color)
		end
	end
end)
