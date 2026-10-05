NETWORK.city = NETWORK.city or {}

local enabled = CreateClientConVar("network_cityfeel", "1", true, false,
	"Атмосферные эффекты города")

local dust = CreateClientConVar("network_cityfeel_dust", "1", true, false,
	"Пыль в воздухе")

NETWORK.city.dustCount = 90
NETWORK.city.dustRange = 420

local dustMaterial = Material("particle/particle_glow_04")

local motes

local function EnsureMotes()
	if (motes) then
		return
	end

	motes = {}

	for index = 1, NETWORK.city.dustCount do
		motes[index] = {
			pos = VectorRand() * NETWORK.city.dustRange,
			speed = math.Rand(1.5, 6),
			drift = math.Rand(-4, 4),
			size = math.Rand(0.6, 2.2),
			phase = math.Rand(0, 6)
		}
	end
end

hook.Add("PostDrawTranslucentRenderables", "nwCityDust", function(bDepth, bSkybox)
	if (bSkybox or !enabled:GetBool() or !dust:GetBool()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	EnsureMotes()

	if (NETWORK.weather and NETWORK.weather.bIndoor) then
		return
	end

	local origin = client:EyePos()
	local frame = math.min(FrameTime(), 0.1)

	local night = NETWORK.time and NETWORK.time.IsNight and
		NETWORK.time.IsNight()
	local alpha = night and 22 or 46

	render.SetMaterial(dustMaterial)

	for _, mote in ipairs(motes) do

		mote.pos.z = mote.pos.z - mote.speed * frame
		mote.pos.x = mote.pos.x + math.sin(CurTime() * 0.4 + mote.phase) *
			mote.drift * frame

		if (mote.pos.z < -NETWORK.city.dustRange * 0.5 or
			mote.pos:Length() > NETWORK.city.dustRange) then
			mote.pos = VectorRand() * NETWORK.city.dustRange * 0.8
			mote.pos.z = math.abs(mote.pos.z)
		end

		local position = origin + mote.pos

		if (math.abs(math.sin(CurTime() * 3 + mote.phase)) > 0.985) then
			local contents = util.PointContents(position)

			mote.bHidden = bit.band(contents, CONTENTS_SOLID) != 0

			local floor = util.TraceLine({
				start = position,
				endpos = position - Vector(0, 0, 6),
				mask = MASK_SOLID_BRUSHONLY
			})

			if (floor.Hit) then
				mote.pos = VectorRand() * NETWORK.city.dustRange * 0.8
				mote.pos.z = math.abs(mote.pos.z)
				mote.bHidden = false

				continue
			end
		end

		if (mote.bHidden) then
			continue
		end

		render.DrawSprite(position, mote.size, mote.size,
			Color(220, 225, 235, alpha))
	end
end)

hook.Add("RenderScreenspaceEffects", "nwCityFeel", function()
	if (!enabled:GetBool()) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = -0.004,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0.010,
		["$pp_colour_brightness"] = 0,
		["$pp_colour_contrast"] = 1.01,
		["$pp_colour_colour"] = 1,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0.02
	})
end)

if (!NETWORK.view or !NETWORK.view.Register) then
	return
end

NETWORK.view.Register("citybreath", 50, function(client, view)
	if (!enabled:GetBool() or !client:Alive()) then
		return
	end

	if (client:InVehicle() or client:IsWeaponRaised()) then
		return
	end

	view.fov = (view.fov or 90) + math.sin(CurTime() * 1.05) * 0.22
end)
