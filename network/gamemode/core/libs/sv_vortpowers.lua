util.AddNetworkString("nwVortAura")
util.AddNetworkString("nwVortCast")
util.AddNetworkString("nwVortOmen")
util.AddNetworkString("nwVortFx")
util.AddNetworkString("nwVortGlow")

local VORT = NETWORK.vort
local M = NETWORK.medical

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone or "info", ...)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function Zap(position, magnitude)
	local effect = EffectData()

	effect:SetOrigin(position)
	effect:SetMagnitude(magnitude or 2)
	effect:SetScale(1)
	effect:SetRadius(4)

	util.Effect("Sparks", effect)
end

local function SetEnergy(client, value)
	client:SetNWFloat("nwVortEnergy", math.Clamp(value, 0, VORT.energyMax))
end

VORT.loopSounds = {"npc/vort/health_charge.wav", "npc/vort/attack_charge.wav"}

local function LoopTimer(client, path)
	return "nwVortLoop" .. client:UserID() .. path
end

function VORT.StopLoop(client, path)
	if (!IsValid(client)) then
		return
	end

	local patch = client.nwVortLoops and client.nwVortLoops[path]

	if (patch) then
		patch:Stop()
		client.nwVortLoops[path] = nil
	end

	client:StopSound(path)
	timer.Remove(LoopTimer(client, path))
end

function VORT.StopLoops(client)
	if (!IsValid(client)) then
		return
	end

	for _, path in ipairs(VORT.loopSounds) do
		VORT.StopLoop(client, path)
	end
end

function VORT.PlayLoop(client, path, duration, level, pitch, volume)
	if (!IsValid(client)) then
		return
	end

	VORT.StopLoop(client, path)

	local patch = CreateSound(client, path)

	if (!patch) then
		return
	end

	patch:SetSoundLevel(level or 70)
	patch:PlayEx(volume or 1, pitch or 100)

	client.nwVortLoops = client.nwVortLoops or {}
	client.nwVortLoops[path] = patch

	timer.Create(LoopTimer(client, path), math.max(duration or 1, 0.1), 1, function()
		VORT.StopLoop(client, path)
	end)
end

function VORT.Spectacle(client, id, power)
	if (!IsValid(client)) then
		return
	end

	local origin = client:WorldSpaceCenter()
	local scale = power or VORT.GetScale(client)
	local radius = VORT.auraRadius * scale

	for index = 1, math.Clamp(math.floor(4 * scale), 4, 16) do
		local angle = (index / math.Clamp(math.floor(4 * scale), 4, 16)) * 360

		Zap(origin + Vector(math.cos(math.rad(angle)), math.sin(math.rad(angle)), 0) *
			(radius * 0.4), 4)
	end

	local effect = EffectData()

	effect:SetOrigin(client:GetPos())
	effect:SetScale(radius * 0.5)
	effect:SetMagnitude(radius * 0.5)
	util.Effect("ThumperDust", effect)

	sound.Play("ambient/levels/citadel/portal_beam_shoot" .. math.random(1, 6) .. ".wav",
		origin, 85, math.random(90, 110))
	client:EmitSound("npc/vort/attack_shoot.wav", 90, 80)

	net.Start("nwVortFx")
		net.WriteEntity(client)
		net.WriteString(id or "")
		net.WriteVector(origin)
		net.WriteFloat(scale)
	net.Broadcast()

	for _, target in ipairs(player.GetAll()) do
		if (target:GetPos():Distance(origin) <= radius * 1.5) then
			util.ScreenShake(target:GetPos(), 6 * scale, 8, 0.8, radius * 1.5)
		end
	end
end

local function Heal(target, health, woundAmount)
	if (health > 0) then
		target:SetHealth(math.min(target:Health() + health, target:GetMaxHealth()))
	end

	if (woundAmount > 0 and NETWORK.wound and NETWORK.wound.Heal) then
		for _, part in ipairs(NETWORK.wound.parts) do
			if (NETWORK.wound.Get(target, part.id) > 0) then
				NETWORK.wound.Heal(target, part.id, woundAmount)
			end
		end
	end
end

VORT.castStyle = {
	heal = {color = Color(120, 235, 140),
		sound = "ambient/energy/newspark04.wav", pitch = 120},
	wave = {color = Color(120, 160, 255),
		sound = "ambient/energy/zap9.wav", pitch = 80},
	sight = {color = Color(150, 200, 255),
		sound = "ambient/levels/citadel/pod_open1.wav", pitch = 140},
	pray = {color = Color(140, 255, 150),
		sound = "ambient/levels/citadel/portal_beam_shoot4.wav", pitch = 90}
}

function VORT.CastGlow(client, id, duration)
	local style = VORT.castStyle[id]

	if (!style or !IsValid(client)) then
		return
	end

	client:EmitSound(style.sound, 70, style.pitch, 0.7, CHAN_STATIC)

	net.Start("nwVortGlow")
		net.WriteEntity(client)
		net.WriteColor(style.color)
		net.WriteFloat(math.max(duration or 1, 0.4))
	net.Broadcast()
end

local function PlayCast(client, cast, time, callback)

	if (VORT.IsHigh(client)) then
		VORT.Spectacle(client, cast.id or "cast")
	end

	VORT.CastGlow(client, cast.id or "", time or cast.time or 1)

	local name = VORT.FindSequence(client, cast.sequence,
		{"gest", "chant", "heal", "attack", "signal"})

	local duration = time or cast.time

	if (!name) then
		if (callback and duration and duration > 0) then
			timer.Simple(duration, function()
				if (IsValid(client)) then
					callback()
				end
			end)
		elseif (callback) then
			callback()
		end

		return
	end

	client:ForceSequence(name, callback, duration)
end

function VORT.SetAura(client, id)
	local data = VORT.GetAuraData(id)

	if (!data) then
		return
	end

	if (id != "none" and !VORT.IsFree(client)) then
		return Notice(client, "vortCollared", "warn")
	end

	if (id != "none" and !VORT.IsHigh(client) and VORT.GetEnergy(client) < 10) then
		return Notice(client, "vortNoEnergy", "warn")
	end

	if (VORT.GetAura(client) == id) then
		id = "none"
		data = VORT.GetAuraData(id)
	end

	client:SetNWString("nwVortAura", id)

	if (id != "none") then
		VORT.PlayLoop(client, "npc/vort/health_charge.wav", 1, 55, 120, 0.6)
	else
		VORT.StopLoop(client, "npc/vort/health_charge.wav")
		client:EmitSound("ambient/energy/zap1.wav", 55, 90, 0.6)
	end

	if (id != "none") then

		hook.Run("NetworkVortPower", client, "aura", id)

		if (VORT.IsHigh(client)) then
			VORT.Spectacle(client, "aura")
		end
	end

	Notice(client, id != "none" and "vortAuraOn" or "vortAuraOff", "info", L(data.name))
end

net.Receive("nwVortAura", function(_, client)
	local id = net.ReadString()

	if (!VORT.IsVort(client) or !client:Alive()) then
		return
	end

	if ((client.nwVortAuraNext or 0) > CurTime()) then
		return
	end

	client.nwVortAuraNext = CurTime() + 1

	VORT.SetAura(client, id)
end)

local function AuraAmmo(vort, power)
	for _, target in ipairs(ents.FindInSphere(vort:GetPos(), VORT.GetAuraRadius(vort))) do
		if (!target:IsPlayer() or !target:Alive() or !VORT.IsVort(target)) then
			continue
		end

		local weapon = target:GetActiveWeapon()

		if (!IsValid(weapon)) then
			continue
		end

		local maximum = weapon:GetMaxClip1() or 0

		if (maximum > 0 and weapon:Clip1() < maximum) then
			weapon:SetClip1(math.min(weapon:Clip1() + math.ceil(power), maximum))
		end

		local ammoType = weapon:GetPrimaryAmmoType()

		if (ammoType and ammoType > 0 and target:GetAmmoCount(ammoType) < 120) then
			target:GiveAmmo(math.ceil(power), ammoType, true)
		end
	end
end

local function AuraHeal(vort, power)
	for _, target in ipairs(ents.FindInSphere(vort:GetPos(), VORT.GetAuraRadius(vort))) do
		if (!VORT.IsAlly(target) or (target.IsCritical and target:IsCritical())) then
			continue
		end

		Heal(target, math.ceil(VORT.auraHeal * power), VORT.auraWound * power)

		if (M and M.GetBleeds) then
			local bleeds = M.GetBleeds(target)
			local bChanged = false

			for part, entry in pairs(bleeds) do
				if (entry.kind == "minor" and !entry.tq) then
					bleeds[part] = nil
					bChanged = true
				end
			end

			if (bChanged) then
				M.SyncBleeds(target)
			end
		end
	end
end

local function AuraDread(vort)
	local until_ = CurTime() + VORT.auraTick + 0.5

	for _, target in ipairs(ents.FindInSphere(vort:GetPos(), VORT.GetAuraRadius(vort))) do
		if (target:IsPlayer() and VORT.IsEnemy(target)) then
			local bWas = target:GetNWFloat("nwVortDreaded", 0) > CurTime()

			target:SetNWFloat("nwVortDreaded", until_)

			if (!bWas) then
				NETWORK.movement.Apply(target)
				Notice(target, "vortDreadFelt", "warn")
			end
		end
	end
end

timer.Create("nwVortAura", VORT.auraTick, 0, function()
	for _, vort in ipairs(player.GetAll()) do
		if (!VORT.IsVort(vort) or !vort:Alive()) then
			continue
		end

		local aura = VORT.GetAura(vort)

		if (aura == "none") then
			continue
		end

		if (!VORT.IsFree(vort)) then
			vort:SetNWString("nwVortAura", "none")

			continue
		end

		local drain = VORT.GetAuraDrain(vort)

		if (drain <= 0) then
			SetEnergy(vort, VORT.energyMax)
		else
			local energy = VORT.GetEnergy(vort) - drain

			SetEnergy(vort, energy)

			if (energy <= 0) then
				vort:SetNWString("nwVortAura", "none")
				Notice(vort, "vortAuraEmpty", "warn")

				continue
			end
		end

		if (aura == "heal") then
			AuraHeal(vort, VORT.GetPower(vort))
		elseif (aura == "dread") then
			AuraDread(vort)
		end

		AuraAmmo(vort, VORT.GetPower(vort))
	end
end)

timer.Create("nwVortEnergy", 1, 0, function()
	for _, vort in ipairs(player.GetAll()) do
		if (!VORT.IsVort(vort) or !vort:Alive()) then
			continue
		end

		if (VORT.GetAura(vort) != "none" and VORT.GetAuraDrain(vort) > 0) then
			continue
		end

		local energy = VORT.GetEnergy(vort)

		if (energy < VORT.energyMax) then
			SetEnergy(vort, energy + VORT.energyRegen *
				(VORT.HasUnity(vort) and 2 or 1) * VORT.GetScale(vort))
		end
	end

	for _, client in ipairs(player.GetAll()) do
		local dread = client:GetNWFloat("nwVortDreaded", 0)

		if (dread > 0 and dread <= CurTime()) then
			client:SetNWFloat("nwVortDreaded", 0)
			NETWORK.movement.Apply(client)
		end
	end
end)

local function NearAura(position, id)
	for _, vort in ipairs(ents.FindInSphere(position,
		VORT.auraRadius * VORT.highScale)) do
		if (VORT.IsVort(vort) and vort:Alive() and VORT.GetAura(vort) == id and
			vort:GetPos():Distance(position) <= VORT.GetAuraRadius(vort)) then
			return vort
		end
	end
end

hook.Add("NetworkDamageTakenScale", "nwVort", function(target)
	if (!IsValid(target) or !target:IsPlayer()) then
		return
	end

	local scale = 1

	if (VORT.HasUnity(target)) then
		scale = scale * VORT.unityTaken
	end

	if (VORT.IsAlly(target)) then
		local vort = NearAura(target:GetPos(), "ward")

		if (vort) then
			local reduce = (1 - VORT.wardScale) * VORT.GetPower(vort)

			scale = scale * math.max(1 - reduce, 0.4)
		end
	end

	return scale
end)

hook.Add("NetworkDamageDealtScale", "nwVort", function(attacker)
	local scale = 1

	if (VORT.HasUnity(attacker)) then
		scale = scale * VORT.unityDealt
	end

	if (attacker:GetNWFloat("nwVortDreaded", 0) > CurTime()) then
		scale = scale * VORT.dreadDealt
	end

	return scale
end)

local CASTS = {}

function CASTS.heal(client, cast)
	local target = VORT.GetHealTarget(client)

	if (!IsValid(target)) then
		return false, "vortHealNoTarget"
	end

	client.nwVortHealTarget = target

	PlayCast(client, cast)

	VORT.PlayLoop(client, "npc/vort/health_charge.wav", cast.time, 70)

	Progress(client, "vortHealProgress", cast.time)
	Notice(target, "vortHealIncoming", "good", client:GetCharacterName())

	timer.Simple(cast.time, function()
		if (!IsValid(client) or client.nwVortHealTarget != target) then
			return
		end

		VORT.StopLoop(client, "npc/vort/health_charge.wav")

		client.nwVortHealTarget = nil

		if (!client:Alive() or !IsValid(target) or !target:Alive() or
			client:GetPos():Distance(target:GetPos()) >
			VORT.healRange * VORT.GetScale(client) + 60) then
			return Notice(client, "vortHealInterrupted", "warn")
		end

		local power = VORT.GetPower(client)

		Heal(target, math.ceil(VORT.healAmount * power), VORT.healWound * power)

		if (M) then
			M.StopAllBleeding(target, false)
			M.SetBlood(target, M.GetBloodValue(target) + VORT.healBlood * power)

			if (target:HasPneumothorax()) then
				M.SetPneumo(target, false)
				target.nwHypoxia = nil
			end

			if (target:IsCritical()) then
				M.ExitCritical(target, math.ceil(40 * power))
			end

			M.UpdateConsciousness(target)
		end

		if (NETWORK.wound.Numb) then
			NETWORK.wound.Numb(target, 60)
		end

		target:EmitSound("npc/vort/attack_shoot.wav", 65, 140, 0.6)
		Zap(target:WorldSpaceCenter(), 3)

		Notice(client, "vortHealDone", "good", target:GetCharacterName())
		Notice(target, "vortHealed", "good")

		NETWORK.chat.Send(client, "me", L("vortHealMe"))
	end)

	return true
end

function CASTS.wave(client, cast)
	PlayCast(client, cast)

	VORT.PlayLoop(client, "npc/vort/attack_charge.wav", cast.time * 0.6, 75)

	timer.Simple(cast.time * 0.6, function()
		VORT.StopLoop(client, "npc/vort/attack_charge.wav")

		if (!IsValid(client) or !client:Alive()) then
			return
		end

		local origin = client:WorldSpaceCenter()
		local hits = 0
		local scale = VORT.GetScale(client)
		local radius = cast.radius * scale

		client:EmitSound("npc/vort/attack_shoot.wav", 85, 90)

		local effect = EffectData()

		effect:SetOrigin(client:GetPos())
		effect:SetScale(radius)
		effect:SetMagnitude(radius)
		util.Effect("ThumperDust", effect)

		for _, target in ipairs(ents.FindInSphere(origin, radius)) do
			if (!VORT.IsEnemy(target)) then
				continue
			end

			local direction = (target:WorldSpaceCenter() - origin):GetNormalized()
			local info = DamageInfo()

			info:SetDamage(cast.damage * scale)
			info:SetDamageType(DMG_SHOCK)
			info:SetAttacker(client)
			info:SetInflictor(client)
			info:SetDamageForce(direction * 12000)
			info:SetDamagePosition(target:WorldSpaceCenter())

			target:TakeDamageInfo(info)

			if (target:IsPlayer()) then
				target:SetVelocity(direction * (420 * scale) + Vector(0, 0, 180 * scale))
			end

			Zap(target:WorldSpaceCenter(), 4)

			hits = hits + 1
		end

		Notice(client, "vortWaveDone", "info", hits)
	end)

	return true
end

function CASTS.sight(client, cast)
	PlayCast(client, cast)

	local duration = cast.duration * VORT.GetScale(client)

	client:SetNWFloat("nwVortSight", CurTime() + duration)
	client:EmitSound("ambient/levels/citadel/pod_open1.wav", 55, 140, 0.5)

	Notice(client, "vortSightOn", "info", math.floor(duration))

	return true
end

function CASTS.pray(client, cast)
	if (VORT.IsPraying(client)) then
		client:SetNWFloat("nwVortPraying", 0)

		if (client:IsInSequence()) then
			client:LeaveSequence()
		end

		Notice(client, "vortPrayStop", "info")

		return true, nil, true
	end

	client:SetNWFloat("nwVortPraying", CurTime() + VORT.prayTime)

	PlayCast(client, cast, VORT.prayTime, function()
		if (IsValid(client)) then
			client:SetNWFloat("nwVortPraying", 0)
		end
	end)

	client:EmitSound("npc/vort/vort_pain3.wav", 60, 70, 0.5)
	NETWORK.chat.Send(client, "me", L("vortPrayMe"))

	local ready = (VORT.unityReady or 0) - CurTime()

	if (ready > 0) then
		Notice(client, "vortRitualCooldown", "warn", math.ceil(ready / 60))
	else
		Notice(client, "vortPrayStart", "info", VORT.GetUnityNeeded(client))
	end

	return true
end

function VORT.Cast(client, id)
	local cast = VORT.casts[id]

	if (id == "pray" and VORT.IsPraying(client)) then
		return CASTS.pray(client, cast)
	end
	local bOk, reason = VORT.CanCast(client, id)

	if (!bOk) then
		if (reason == "vortCooldown") then
			return Notice(client, reason, "warn", math.ceil(VORT.GetCooldown(client, id)))
		end

		return Notice(client, reason, "warn")
	end

	if (client.IsCritical and client:IsCritical()) or
		(client.IsDowned and client:IsDowned()) then
		return
	end

	if (client:IsInSequence() and id != "pray") then
		return Notice(client, "vortBusy", "warn")
	end

	local bDone, failKey, bNoCost = CASTS[id](client, cast)

	if (!bDone) then
		return Notice(client, failKey, "warn")
	end

	if (bNoCost) then
		return
	end

	hook.Run("NetworkVortPower", client, "cast", id)

	SetEnergy(client, VORT.GetEnergy(client) - VORT.GetCost(client, id))
	client:SetNWFloat("nwVortCD_" .. id, CurTime() + VORT.GetCooldownTime(client, id))
end

net.Receive("nwVortCast", function(_, client)
	local id = net.ReadString()

	if (!VORT.IsVort(client) or !client:Alive() or !VORT.casts[id]) then
		return
	end

	if ((client.nwVortCastNext or 0) > CurTime()) then
		return
	end

	client.nwVortCastNext = CurTime() + 1

	VORT.Cast(client, id)
end)

VORT.omens = {
	{
		id = "dread",
		Run = function(center)
			for _, target in ipairs(player.GetAll()) do
				if (VORT.IsEnemy(target) and target:GetPos():Distance(center) <= 1500 * (VORT.omenScale or 1)) then
					target:SetNWFloat("nwVortDreaded", CurTime() + 60)
					NETWORK.movement.Apply(target)
				end
			end
		end
	},
	{
		id = "surge",
		Run = function(center)
			for _, field in ipairs(ents.FindByClass("nw_forcefield")) do
				if (field:IsWorking() and field:GetPos():Distance(center) <= 1600 * (VORT.omenScale or 1)) then
					Zap(field:WorldSpaceCenter(), 4)
					field:Shutdown()
				end
			end
		end
	},
	{
		id = "mend",
		Run = function(center)
			for _, target in ipairs(player.GetAll()) do
				if (!VORT.IsAlly(target) or target:GetPos():Distance(center) > 900 * (VORT.omenScale or 1)) then
					continue
				end

				target:SetHealth(target:GetMaxHealth())

				if (M) then
					M.StopAllBleeding(target, true)
					M.SetBlood(target, M.bloodMax)

					if (target:IsCritical()) then
						M.ExitCritical(target, target:GetMaxHealth())
					end
				end
			end
		end
	},
	{
		id = "haze",
		Run = function(center)
			for _, target in ipairs(player.GetAll()) do
				if (VORT.IsEnemy(target) and target:GetPos():Distance(center) <= 1200 * (VORT.omenScale or 1)) then
					target:SetNWFloat("nwVortHaze", CurTime() + 25)

					if (NETWORK.wound.Pain) then
						NETWORK.wound.Pain(target, 20)
					end
				end
			end
		end
	}
}

function VORT.CompleteRitual(members)

	local cooldown = VORT.unityCooldown
	local scale = 1

	for _, member in ipairs(members) do
		scale = math.max(scale, VORT.GetScale(member))
	end

	VORT.omenScale = scale
	VORT.unityReady = CurTime() + cooldown / scale

	local center = Vector(0, 0, 0)

	for _, member in ipairs(members) do
		center = center + member:GetPos()
	end

	center = center / #members

	local omen = VORT.omens[math.random(#VORT.omens)]

	for _, member in ipairs(members) do
		member:SetNWFloat("nwVortPraying", 0)
		member:SetNWFloat("nwVortUnity", CurTime() + VORT.unityTime * scale)
		SetEnergy(member, VORT.energyMax)

		if (VORT.IsHigh(member)) then
			VORT.Spectacle(member, "ritual")
		end

		if (member:IsInSequence()) then
			member:LeaveSequence()
		end

		Zap(member:WorldSpaceCenter(), 5)
		Notice(member, "vortUnityGained", "good", math.floor(VORT.unityTime / 60))
	end

	omen.Run(center, members)

	sound.Play("ambient/levels/citadel/portal_beam_shoot" .. math.random(1, 6) .. ".wav",
		center, 100, 80)

	net.Start("nwVortOmen")
		net.WriteString(omen.id)
		net.WriteVector(center)
	net.Broadcast()

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("admin", string.format("Ритуал вортигонтов (%s), участников: %d",
			omen.id, #members), center)
	end

	hook.Run("NetworkVortRitual", members, omen.id, center)
end

timer.Create("nwVortRitual", 1, 0, function()
	if ((VORT.unityReady or 0) > CurTime()) then
		return
	end

	local praying = {}

	for _, client in ipairs(player.GetAll()) do
		if (VORT.IsVort(client) and client:Alive() and VORT.IsPraying(client)) then
			praying[#praying + 1] = client
		end
	end

	if (#praying < 1) then
		return
	end

	for _, client in ipairs(praying) do
		local circle = {}
		local needed = VORT.GetUnityNeeded(client)

		for _, other in ipairs(praying) do
			if (other:GetPos():Distance(client:GetPos()) <=
				VORT.prayRadius * VORT.GetScale(client)) then
				circle[#circle + 1] = other
				needed = math.min(needed, VORT.GetUnityNeeded(other))
			end
		end

		if (#circle >= needed) then
			return VORT.CompleteRitual(circle)
		end
	end
end)

local function FieldOnRay(start, direction)
	local best, bestDistance

	for _, field in ipairs(ents.FindByClass("nw_forcefield")) do
		if (!field:IsWorking()) then
			continue
		end

		local origin = field:GetPos()
		local normal = field:GetForward()
		local along = field:GetRight() * -1
		local denominator = direction:Dot(normal)

		if (math.abs(denominator) < 0.001) then
			continue
		end

		local distance = (origin - start):Dot(normal) / denominator

		if (distance <= 0 or distance > VORT.fieldRange) then
			continue
		end

		local hit = start + direction * distance
		local offset = hit - origin
		local length = field:GetSpan():Length()
		local position = offset:Dot(along)

		if (position < -16 or position > length + 16 or
			offset.z < -field.Base - 8 or offset.z > field.Height + 8) then
			continue
		end

		local trace = util.TraceLine({
			start = start,
			endpos = hit,
			mask = MASK_SOLID_BRUSHONLY
		})

		if (trace.Hit and trace.Fraction < 0.98) then
			continue
		end

		if (!bestDistance or distance < bestDistance) then
			best, bestDistance = field, distance
		end
	end

	return best, bestDistance and (start + direction * bestDistance)
end

function VORT.HitField(client, field, position)
	field.nwVortHits = field.nwVortHits or {}

	local hits = field.nwVortHits

	if ((hits.time or 0) + VORT.fieldMemory < CurTime()) then
		hits.count = 0
	end

	hits.count = (hits.count or 0) + 1
	hits.time = CurTime()

	Zap(position, 3)
	field:EmitSound("framework/cmb/forcefield/attack" .. math.random(2, 3) .. ".mp3", 75)

	if (hits.count < VORT.fieldHits) then
		return Notice(client, "vortFieldHit", "info", hits.count, VORT.fieldHits)
	end

	hits.count = 0

	Zap(field:WorldSpaceCenter(), 6)
	field:Shutdown()

	Notice(client, "vortFieldBroken", "good")

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("emp", string.format("%s выжег силовое поле разрядом",
			NETWORK.log.Name(client)), field:GetPos())
	end
end

hook.Add("Think", "nwVortBeamShots", function()

	if (!NETWORK.util.Throttle("vort.beam", 0.05)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (!VORT.IsVort(client) or !client:Alive()) then
			continue
		end

		local weapon = client:GetActiveWeapon()

		if (!IsValid(weapon) or weapon:GetClass() != VORT.beam) then
			client.nwVortLastFire = nil

			continue
		end

		local nextFire = weapon:GetNextPrimaryFire()
		local last = client.nwVortLastFire

		client.nwVortLastFire = nextFire

		if (!last or nextFire <= last + 0.05 or nextFire < CurTime()) then
			continue
		end

		local field, position = FieldOnRay(client:GetShootPos(), client:GetAimVector())

		if (IsValid(field)) then
			VORT.HitField(client, field, position)
		end
	end
end)

local function Reset(client)
	VORT.StopLoops(client)

	client:SetNWFloat("nwVortPraying", 0)
	client:SetNWFloat("nwVortSight", 0)
	client:SetNWString("nwVortAura", "none")
	client.nwVortHealTarget = nil

	if (VORT.IsVort(client)) then
		SetEnergy(client, VORT.energyMax)
	end
end

hook.Add("PlayerDeath", "nwVort", function(client)
	Reset(client)
	client:SetNWFloat("nwVortUnity", 0)
end)

hook.Add("NetworkCharacterLoaded", "nwVort", function(client)
	Reset(client)
	client:SetNWFloat("nwVortUnity", 0)
	client:SetNWFloat("nwVortDreaded", 0)
end)

hook.Add("PlayerSilentDeath", "nwVortLoops", VORT.StopLoops)
hook.Add("PlayerSpawn", "nwVortLoops", VORT.StopLoops)
hook.Add("PlayerDisconnected", "nwVortLoops", VORT.StopLoops)
hook.Add("NetworkCharacterUnloaded", "nwVortLoops", VORT.StopLoops)
