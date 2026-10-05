util.AddNetworkString("nwShieldFlash")
util.AddNetworkString("nwShieldHit")

local shield = NETWORK.shield

shield.callouts = {
	{sound = "framework/vo/wallhammer/preparing_shield_01.wav",
		text = "shieldCallWall"},
	{sound = "framework/vo/wallhammer/preparing_shield_02.wav",
		text = "shieldCallReady"},
	{sound = "framework/vo/wallhammer/preparing_shield_03.wav",
		text = "shieldCallRaise"}
}

shield.graceTime = 15

function NETWORK.shield.IsInvulnerable(client)
	return IsValid(client) and shield.IsActive(client) and
		client:GetNWFloat("nwShieldGrace", 0) > CurTime()
end

function NETWORK.shield.Set(client, state)
	if (state == shield.IsActive(client)) then
		return
	end

	client:SetNWBool("nwShieldActive", state)

	client:EmitSound("npc/combine_soldier/gear" .. math.random(1, 6) .. ".wav", 65,
		state and 95 or 85)

	timer.Simple(0.18, function()
		if (IsValid(client)) then
			client:EmitSound(state and "physics/metal/metal_box_impact_soft" ..
				math.random(1, 3) .. ".wav" or "physics/metal/metal_box_strain" ..
				math.random(1, 4) .. ".wav", 62, state and 80 or 95)
		end
	end)

	hook.Run("NetworkShieldToggled", client, state)

	if (!state) then
		client:SetNWFloat("nwShieldGrace", 0)

		return
	end

	client:SetNWFloat("nwShieldGrace", CurTime() + shield.graceTime)

	local callout = shield.callouts[math.random(#shield.callouts)]

	client:EmitSound(callout.sound, 85, math.random(97, 103), 1, CHAN_VOICE)

	NETWORK.chat.Send(client, "ic", L(callout.text))
end

function NETWORK.shield.Break(client)
	if (shield.IsBroken(client)) then
		return
	end

	client.nwShieldExact = 0
	client.nwShieldSent = nil

	client:SetNWFloat("nwShieldEnergy", 0)
	client:SetNWFloat("nwShieldBroken", CurTime() + shield.breakPenalty)

	shield.Set(client, false)

	client:EmitSound("weapons/physcannon/energy_disintegrate4.wav", 80, 90)

	local effect = EffectData()
	effect:SetOrigin(shield.GetOrigin(client))
	effect:SetScale(1.4)
	util.Effect("cball_explode", effect, true, true)
end

concommand.Add("nw_shield", function(client)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return
	end

	if ((client.nwShieldDebounce or 0) > CurTime()) then
		return
	end

	client.nwShieldDebounce = CurTime() + 0.25

	if (!shield.IsUser(client)) then
		return
	end

	if (shield.IsActive(client)) then
		return shield.Set(client, false)
	end

	if (shield.IsBroken(client) or shield.GetExact(client) <= 1) then
		client:EmitSound("buttons/combine_button_locked.wav", 60, 60)

		return
	end

	shield.Set(client, true)
end)

concommand.Add("nw_shieldflash", function(client)
	if (!IsValid(client) or !shield.IsActive(client) or !client:Alive()) then
		return
	end

	if ((client.nwShieldNextFlash or 0) > CurTime() or
		shield.GetExact(client) < shield.flashCost) then
		return
	end

	client.nwShieldNextFlash = CurTime() + shield.flashDelay
	shield.PushEnergy(client, shield.GetExact(client) - shield.flashCost, true)
	client:SetNWFloat("nwShieldFlashT", CurTime())

	local origin = shield.GetOrigin(client)
	local forward = shield.GetForward(client)

	client:EmitSound("npc/scanner/scanner_photo1.wav", 90, 90)

	for _, target in ipairs(player.GetAll()) do
		if (target == client or !target:Alive()) then
			continue
		end

		local offset = target:EyePos() - origin
		local distance = offset:Length()

		if (distance > shield.flashRange) then
			continue
		end

		offset:Normalize()

		if (forward:Dot(offset) < 0.2 or
			target:GetAimVector():Dot(-offset) < 0.35) then
			continue
		end

		if (!util.TraceLine({
			start = origin,
			endpos = target:EyePos(),
			filter = {client, target},
			mask = MASK_VISIBLE
		}).Hit) then
			net.Start("nwShieldFlash")
				net.WriteFloat(1 - (distance / shield.flashRange) * 0.5)
			net.Send(target)
		end
	end
end)

shield.energyStep = 1

function shield.GetExact(client)
	return client.nwShieldExact or shield.GetEnergy(client)
end

function shield.PushEnergy(client, value, bForce)
	value = math.Clamp(value, 0, shield.maxEnergy)

	client.nwShieldExact = value

	local sent = client.nwShieldSent

	if (!bForce and sent and math.abs(sent - value) < shield.energyStep and
		value > 0 and value < shield.maxEnergy) then
		return value
	end

	client.nwShieldSent = value

	client:SetNWFloat("nwShieldEnergy", value)

	return value
end

hook.Add("Think", "nwShieldTick", function()
	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive()) then
			continue
		end

		local active = shield.IsActive(client)

		if (active and !shield.IsUser(client)) then
			shield.Set(client, false)

			continue
		end

		if (!shield.IsUser(client)) then
			continue
		end

		local energy = shield.GetExact(client)

		if (active) then
			energy = shield.PushEnergy(client,
				energy - (shield.maxEnergy / shield.holdTime) * FrameTime())

			if (energy <= 0) then
				shield.Break(client)
			end
		elseif (energy < shield.maxEnergy) then
			local rate = shield.regen * (shield.IsBroken(client) and 0.5 or 1)

			shield.PushEnergy(client, energy + rate * FrameTime())
		end
	end
end)

local BLOCKED = bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER, DMG_AIRBOAT)

local UNSTOPPABLE = bit.bor(DMG_FALL, DMG_DROWN, DMG_POISON, DMG_RADIATION,
	DMG_CRUSH, DMG_VEHICLE, DMG_NERVEGAS)

function NETWORK.shield.Blocks(client, from, damageType)
	if (!IsValid(client) or !shield.IsActive(client) or
		shield.IsBroken(client)) then
		return false
	end

	if (damageType and bit.band(damageType, UNSTOPPABLE) != 0) then
		return false
	end

	if (!from or from:IsZero()) then
		return false
	end

	if (from:DistToSqr(client:WorldSpaceCenter()) < 40 * 40) then
		return true
	end

	if (from:DistToSqr(client:WorldSpaceCenter()) < 40 * 40) then
		return true
	end

	local direction = from - shield.GetOrigin(client)

	direction:Normalize()

	return shield.GetForward(client):Dot(direction) >= shield.blockDot
end

hook.Add("EntityTakeDamage", "nwShieldBlock", function(victim, damage)
	if (!victim:IsPlayer() or !shield.IsActive(victim) or
		shield.IsBroken(victim)) then
		return
	end

	local bGrace = shield.IsInvulnerable(victim)

	local kind = damage:GetDamageType()
	local blast = bit.band(kind, DMG_BLAST) != 0

	if (bit.band(kind, UNSTOPPABLE) != 0) then
		return
	end

	local origin = shield.GetOrigin(victim)
	local from = damage:GetDamagePosition()

	if (from:IsZero()) then
		local attacker = damage:GetAttacker()

		if (!IsValid(attacker)) then
			return
		end

		from = attacker:WorldSpaceCenter()
	end

	local direction = from - origin
	direction:Normalize()

	if (shield.GetForward(victim):Dot(direction) < shield.blockDot) then
		return
	end

	if (bGrace) then
		damage:SetDamage(0)

		victim:EmitSound("weapons/physcannon/energy_bounce" ..
			math.random(1, 2) .. ".wav", 70, math.random(120, 130))

		net.Start("nwShieldHit")
			net.WriteEntity(victim)
			net.WriteVector(from)
		net.Broadcast()

		return true
	end

	local blocked = blast and damage:GetDamage() * 0.5 or damage:GetDamage()

	local cost = math.Clamp(shield.hitCost + blocked * 0.25,
		shield.maxEnergy / math.max(shield.maxShots or shield.minShots, 1),
		shield.maxEnergy / math.max(shield.minShots, 1))

	shield.PushEnergy(victim, shield.GetExact(victim) - cost, true)

	if (blast) then
		damage:ScaleDamage(0.5)
	else
		damage:SetDamage(0)
	end

	victim:EmitSound("weapons/physcannon/energy_bounce" ..
		math.random(1, 2) .. ".wav", 70, math.random(110, 125), 0.85)

	net.Start("nwShieldHit")
		net.WriteEntity(victim)
		net.WriteVector(origin + direction * 36)
	net.SendPVS(origin)

	if (shield.GetExact(victim) <= 0) then
		NETWORK.shield.Break(victim)
	end

	if (blast) then
		return
	end

	return true
end)

local function Reset(client)
	client:SetNWBool("nwShieldActive", false)
	shield.PushEnergy(client, shield.maxEnergy, true)
	client:SetNWFloat("nwShieldBroken", 0)
end

hook.Add("PlayerTraceAttack", "nwShieldNoBlood", function(client, damage,
	direction, trace)
	local from = damage:GetDamagePosition()

	if (from:IsZero() and trace) then
		from = trace.StartPos
	end

	if (shield.Blocks(client, from, damage:GetDamageType())) then
		return true
	end
end)

hook.Add("ScalePlayerDamage", "nwShieldNoBlood", function(client, group, damage)
	local from = damage:GetDamagePosition()

	if (from:IsZero()) then
		local attacker = damage:GetAttacker()

		if (IsValid(attacker)) then
			from = attacker:WorldSpaceCenter()
		end
	end

	if (shield.Blocks(client, from, damage:GetDamageType())) then
		damage:SetDamage(0)

		return true
	end
end)

hook.Add("PlayerDeath", "nwShieldReset", Reset)
hook.Add("PlayerSpawn", "nwShieldReset", Reset)

util.AddNetworkString("nwShieldSettings")
util.AddNetworkString("nwShieldSaveRequest")
util.AddNetworkString("nwShieldSave")

NETWORK.shield.settingsPath = "network/shield.txt"
NETWORK.shield.server = NETWORK.shield.server or nil

local SETTING_KEYS = {"f", "r", "u", "pitch", "yaw", "roll", "scale", "fw", "fh", "ff", "hand"}

function NETWORK.shield.LoadSettings()
	local raw = file.Read(NETWORK.shield.settingsPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	NETWORK.shield.server = istable(data) and next(data) != nil and data or nil
end

function NETWORK.shield.SaveSettings()
	file.CreateDir("network")

	if (NETWORK.shield.server) then
		file.Write(NETWORK.shield.settingsPath, util.TableToJSON(NETWORK.shield.server, true))
	else
		file.Delete(NETWORK.shield.settingsPath)
	end
end

function NETWORK.shield.SendSettings(client)
	net.Start("nwShieldSettings")
		NETWORK.util.WriteTable(NETWORK.shield.server or {})

	if (IsValid(client)) then
		net.Send(client)
	else
		net.Broadcast()
	end
end

hook.Add("Initialize", "nwShieldSettings", NETWORK.shield.LoadSettings)

hook.Add("PlayerInitialSpawn", "nwShieldSettings", function(client)
	timer.Simple(3, function()
		if (IsValid(client) and NETWORK.shield.server) then
			NETWORK.shield.SendSettings(client)
		end
	end)
end)

net.Receive("nwShieldSave", function(_, client)
	if (!client:IsAdmin() or !client.nwShieldSaveAsked) then
		return
	end

	client.nwShieldSaveAsked = nil

	local data = NETWORK.util.ReadTable() or {}
	local clean = {}

	for _, key in ipairs(SETTING_KEYS) do
		local value = tonumber(data[key])

		if (value) then
			clean[key] = math.Clamp(value, -720, 720)
		end
	end

	NETWORK.shield.server = clean
	NETWORK.shield.SaveSettings()
	NETWORK.shield.SendSettings()

	NETWORK.notice.Send(client, "shieldSaved", "good")
end)

NETWORK.command.Register("shieldsave", {
	adminOnly = true,
	description = "cmdShieldsave",
	usage = "/shieldsave",
	OnRun = function(command, client)
		client.nwShieldSaveAsked = true

		net.Start("nwShieldSaveRequest")
		net.Send(client)
	end
})

NETWORK.command.Register("shieldreset", {
	adminOnly = true,
	description = "cmdShieldreset",
	usage = "/shieldreset",
	OnRun = function(command, client)
		NETWORK.shield.server = nil
		NETWORK.shield.SaveSettings()
		NETWORK.shield.SendSettings()

		NETWORK.notice.Send(client, "shieldResetDone", "good")
	end
})

NETWORK.command.Register("shieldedit", {
	adminOnly = true,
	description = "cmdShieldedit",
	usage = "/shieldedit",
	OnRun = function(command, client)
		client:ConCommand("nw_shieldedit")
	end
})
