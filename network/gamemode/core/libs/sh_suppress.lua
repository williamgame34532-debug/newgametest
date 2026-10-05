NETWORK.suppress = NETWORK.suppress or {}

NETWORK.suppress.radius = 110
NETWORK.suppress.time = 2.5
NETWORK.suppress.punch = 0.55
NETWORK.suppress.range = 4096

NETWORK.suppress.gain = 0.45

NETWORK.suppress.muzzle = 72

NETWORK.suppress.ringAt = 0.8

function NETWORK.suppress.Get(client)
	return math.max(client:GetNWFloat("nwSuppress", 0) - CurTime(), 0)
end

function NETWORK.suppress.GetLevel(client)
	local left = NETWORK.suppress.Get(client)

	if (left <= 0) then
		return 0
	end

	local length = math.max(client:GetNWFloat("nwSuppressLen", NETWORK.suppress.time), 0.1)

	return math.Clamp(client:GetNWFloat("nwSuppressLvl", 1) *
		math.Clamp(left / length, 0, 1), 0, 1)
end

function NETWORK.suppress.Resist(client)
	if (NETWORK.skills and NETWORK.skills.SuppressFactor) then
		return NETWORK.skills.SuppressFactor(client)
	end

	return 1
end

if (SERVER) then
	util.AddNetworkString("nwSuppressHit")

	local function DistanceToLine(point, start, finish)
		local direction = finish - start
		local length = direction:Length()

		if (length < 1) then
			return point:Distance(start), 0
		end

		direction:Normalize()

		local along = math.Clamp((point - start):Dot(direction), 0, length)

		return point:Distance(start + direction * along), along, start + direction * along
	end

	local function IsShooter(entity)
		return IsValid(entity) and (entity:IsPlayer() or entity:IsNPC())
	end

	function NETWORK.suppress.Apply(client, strength, point, bHit)
		if (!client:Alive() or !client:HasCharacter()) then
			return
		end

		local now = CurTime()

		if (point and !bHit and (client.nwSuppressWhizz or 0) <= now) then
			client.nwSuppressWhizz = now + 0.12

			net.Start("nwSuppressHit")
				net.WriteVector(point)
				net.WriteFloat(strength)
			net.Send(client)
		end

		if (now - (client.nwSuppressAt or 0) < 0.05) then
			local last = client.nwSuppressLast or 0

			if (strength <= last) then
				return
			end

			client.nwSuppressLast = strength
			strength = strength - last
		else
			client.nwSuppressAt = now
			client.nwSuppressLast = strength
		end

		local factor = NETWORK.suppress.Resist(client)
		local gain = strength * factor

		if (gain <= 0.01) then
			return
		end

		local level = math.min(NETWORK.suppress.GetLevel(client) +
			gain * NETWORK.suppress.gain, 1)
		local length = NETWORK.suppress.time * (0.5 + 0.5 * factor)

		client:SetNWFloat("nwSuppressLvl", level)
		client:SetNWFloat("nwSuppressLen", length)
		client:SetNWFloat("nwSuppress", now + length)

		client.nwSuppressPeak = math.max(client.nwSuppressPeak or 0, level)
		client.nwSuppressUntil = now + length

		if ((client.nwNextPunch or 0) < now) then
			client.nwNextPunch = now + 0.25

			client:ViewPunch(Angle(
				-NETWORK.suppress.punch * gain,
				math.Rand(-1, 1) * NETWORK.suppress.punch * gain,
				math.Rand(-0.6, 0.6) * NETWORK.suppress.punch * gain
			))
		end

		if (level >= NETWORK.suppress.ringAt and (client.nwSuppressRing or 0) < now) then
			client.nwSuppressRing = now + 8

			local ringAt = now

			client.nwSuppressDSPAt = ringAt
			client:SetDSP(math.random(32, 34), false)

			timer.Simple(4, function()
				if (IsValid(client) and client.nwSuppressDSPAt == ringAt) then
					client.nwSuppressDSPAt = nil
					client:SetDSP(0, false)
				end
			end)
		end
	end

	function NETWORK.suppress.Process(shooter, start, finish, hitEntity)
		for _, client in ipairs(player.GetAll()) do
			if (client == shooter or !client:Alive()) then
				continue
			end

			local distance, along, point = DistanceToLine(client:EyePos(), start, finish)
			local center, centerAlong, centerPoint = DistanceToLine(client:WorldSpaceCenter(),
				start, finish)

			if (center < distance) then
				distance, along, point = center, centerAlong, centerPoint
			end

			if (distance > NETWORK.suppress.radius or along < NETWORK.suppress.muzzle) then
				continue
			end

			NETWORK.suppress.Apply(client, 1 - distance / NETWORK.suppress.radius,
				point, hitEntity == client)
		end
	end

	hook.Add("PostEntityFireBullets", "nwSuppress", function(entity, data)
		NETWORK.suppress.bPostHook = true

		if (IsValid(entity) and entity:IsWeapon()) then
			entity = entity:GetOwner()
		end

		if (!IsShooter(entity) or !istable(data)) then
			return
		end

		local trace = data.Trace
		local start = data.Src or (trace and trace.StartPos)

		if (!start) then
			return
		end

		local finish = trace and trace.HitPos

		if (!finish and data.Dir) then
			finish = start + data.Dir * math.min(data.Distance or
				NETWORK.suppress.range, NETWORK.suppress.range)
		end

		if (!finish) then
			return
		end

		NETWORK.suppress.Process(entity, start, finish, trace and trace.Entity)
	end)

	hook.Add("EntityFireBullets", "nwSuppress", function(entity, data)
		if (NETWORK.suppress.bPostHook or !IsShooter(entity) or !istable(data) or
			!data.Src or !data.Dir) then
			return
		end

		if (entity:IsPlayer() and entity:HasCharacter() and !entity:IsWeaponRaised()) then
			return
		end

		local start = data.Src
		local distance = math.min(data.Distance or NETWORK.suppress.range,
			NETWORK.suppress.range)
		local trace = util.TraceLine({
			start = start,
			endpos = start + data.Dir:GetNormalized() * distance,
			filter = entity,
			mask = MASK_SHOT
		})

		NETWORK.suppress.Process(entity, start, trace.HitPos, trace.Entity)
	end)

	timer.Create("nwSuppressSurvive", 1, 0, function()
		local now = CurTime()

		for _, client in ipairs(player.GetAll()) do
			if (!client.nwSuppressPeak or (client.nwSuppressUntil or 0) > now) then
				continue
			end

			local peak = client.nwSuppressPeak

			client.nwSuppressPeak = nil

			local bDowned = client.IsDowned and client:IsDowned()

			if (client:Alive() and client:HasCharacter() and !bDowned) then
				hook.Run("NetworkSuppressSurvived", client, peak)
			end
		end
	end)

	local function Reset(client)
		client:SetNWFloat("nwSuppress", 0)
		client:SetNWFloat("nwSuppressLvl", 0)

		client.nwSuppressPeak = nil

		if (client.nwSuppressDSPAt) then
			client.nwSuppressDSPAt = nil
			client:SetDSP(0, false)
		end
	end

	hook.Add("PlayerSpawn", "nwSuppress", Reset)
	hook.Add("PlayerDeath", "nwSuppress", Reset)
else
	local BLUR = Material("pp/blurscreen")

	local WHIZZ = {"03", "04", "06", "07", "09", "10", "13", "14"}

	net.Receive("nwSuppressHit", function()
		local point = net.ReadVector()
		local strength = net.ReadFloat()

		sound.Play("weapons/fx/nearmiss/bulletltor" .. WHIZZ[math.random(#WHIZZ)] .. ".wav",
			point, 75, math.random(92, 108), math.Clamp(0.45 + strength * 0.5, 0.3, 0.95))
	end)

	hook.Add("RenderScreenspaceEffects", "nwSuppress", function()
		local client = LocalPlayer()

		if (!IsValid(client) or !client:Alive()) then
			return
		end

		local amount = NETWORK.suppress.GetLevel(client)

		if (amount <= 0.01) then
			return
		end

		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.05 * amount,
			["$pp_colour_contrast"] = 1 + 0.2 * amount,
			["$pp_colour_colour"] = 1 - 0.6 * amount,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})

		if (amount < 0.2) then
			return
		end

		BLUR:SetFloat("$blur", (amount - 0.2) * 2.5)
		BLUR:Recompute()

		render.UpdateScreenEffectTexture()
		surface.SetMaterial(BLUR)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	end)

	hook.Add("NetworkDrawHUD", "nwSuppress", function()
		local client = LocalPlayer()
		local amount = NETWORK.suppress.GetLevel(client) * NETWORK.hud.GetFade()

		if (amount <= 0.01) then
			return
		end

		local width, height = ScrW(), ScrH()
		local band = math.Round(height * 0.18 * amount)

		for step = 0, band, 2 do
			local alpha = 120 * amount * (1 - step / math.max(band, 1))

			surface.SetDrawColor(0, 0, 0, alpha)
			surface.DrawRect(0, step, width, 2)
			surface.DrawRect(0, height - step - 2, width, 2)
		end
	end)

	NETWORK.view.Register("suppress", 46, function(client, view)
		if (!client:Alive()) then
			return
		end

		local amount = NETWORK.suppress.GetLevel(client)

		if (amount <= 0.01) then
			return
		end

		local time = RealTime()
		local sway = amount * amount * 1.3

		view.angles = Angle(
			view.angles.p + (math.sin(time * 2.3) + math.sin(time * 5.1) * 0.35) * sway * 0.6,
			view.angles.y + (math.cos(time * 1.7) + math.sin(time * 4.3) * 0.3) * sway,
			view.angles.r + math.sin(time * 1.3) * sway * 0.8
		)

		view.fov = (view.fov or 75) - 3 * amount

		return true
	end)
end
