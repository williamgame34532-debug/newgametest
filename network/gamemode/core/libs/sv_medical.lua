util.AddNetworkString("nwMedOpen")
util.AddNetworkString("nwMedData")
util.AddNetworkString("nwMedClose")
util.AddNetworkString("nwMedTreat")
util.AddNetworkString("nwMedStop")
util.AddNetworkString("nwMedGiveUp")
util.AddNetworkString("nwMedSelf")
util.AddNetworkString("nwMedGame")
util.AddNetworkString("nwMedGameHit")

for _, name in ipairs({"cmb_overlay.vmt", "soldier_overlay.vmt", "elite_overlay.vmt",
	"combine_overlay.vtf", "combine_overlay_normal.vtf", "cmb_overlay_normal.vtf",
	"soldier_overlay.vtf", "elite_overlay.vtf"}) do
	resource.AddFile("materials/framework/cmb/visor/" .. name)
end

resource.AddFile("materials/framework/hud/action_ring.png")

for _, name in ipairs({"soldier_overlay.vmt", "cmb_overlay.vmt", "elite_overlay.vmt",
	"soldier_overlay.vtf", "combine_overlay.vtf", "combine_overlay_normal.vtf",
	"elite_overlay.vtf"}) do
	resource.AddFile("materials/effects/" .. name)
end
resource.AddFile("resource/fonts/mono-regular.ttf")

for _, name in ipairs({
	"RussoOne-Regular.ttf",
	"Play-Regular.ttf",
	"Play-Bold.ttf",
	"FiraSansCondensed-Regular.ttf",
	"FiraSansCondensed-Medium.ttf",
	"FiraSansCondensed-SemiBold.ttf",
	"IBMPlexMono-Regular.ttf",
	"IBMPlexMono-Medium.ttf",
	"IBMPlexMono-SemiBold.ttf",
	"PTM55FT.ttf",
	"Ubuntu-Regular.ttf",
	"Ubuntu-Medium.ttf",
	"Ubuntu-Bold.ttf",
	"Ubuntu-Italic.ttf",
	"UbuntuCondensed-Regular.ttf",
	"PTSansNarrow-Regular.ttf",
	"PTSansNarrow-Bold.ttf"
}) do
	resource.AddFile("resource/fonts/" .. name)
end

local AddFile = resource.AddFile

local function AddFileSafe(path)
	if ((file.Size(path, "GAME") or 0) > 0) then
		AddFile(path)
	end
end

local function AddDirectory(path)
	local files, folders = file.Find(path .. "/*", "GAME")

	for _, name in ipairs(files or {}) do
		AddFileSafe(path .. "/" .. name)
	end

	for _, name in ipairs(folders or {}) do
		AddDirectory(path .. "/" .. name)
	end
end

AddDirectory("sound/framework")
AddDirectory("materials/framework/chat")
AddDirectory("materials/framework/icons")
AddDirectory("materials/framework/cursor")
AddDirectory("materials/framework/slots")
AddDirectory("materials/framework/voice")
AddDirectory("materials/framework/interact")
AddDirectory("materials/framework/graffiti")
AddDirectory("materials/framework/pattern")
AddDirectory("materials/framework/terminal")
AddDirectory("materials/framework/fx")

for _, name in ipairs({"handcuffs.mdl", "handcuffs.vvd", "handcuffs.dx90.vtx", "handcuffs.dx80.vtx",
	"handcuffs.sw.vtx", "handcuffs.phy", "v_handcuffs.mdl", "v_handcuffs.vvd", "v_handcuffs.dx90.vtx",
	"v_handcuffs.dx80.vtx", "v_handcuffs.sw.vtx", "w_handcuffs.mdl", "w_handcuffs.vvd",
	"w_handcuffs.dx90.vtx", "w_handcuffs.dx80.vtx", "w_handcuffs.sw.vtx"}) do
	AddFileSafe("models/chara/simplehandcuffs/" .. name)
end

for _, name in ipairs({"handcuffsmat.vmt", "handcuffsmat.vtf", "skin1.vmt", "skin1.vtf"}) do
	AddFileSafe("materials/chara/simplehandcuffs/" .. name)
end

for _, name in ipairs({"v_emptool.mdl", "v_emptool.vvd", "v_emptool.dx90.vtx", "v_emptool.dx80.vtx",
	"v_emptool.sw.vtx", "w_emptool.mdl", "w_emptool.vvd", "w_emptool.dx90.vtx", "w_emptool.dx80.vtx",
	"w_emptool.sw.vtx", "w_emptool.phy"}) do
	AddFileSafe("models/weapons/" .. name)
end

AddFileSafe("sound/framework/cuffs/tying.wav")
AddFileSafe("sound/framework/cuffs/handcuffs_open.mp3")

for _, name in ipairs({"allteamrespond", "lostbiosignal", "non-citizen", "reminder", "respondinf",
	"return12", "reward", "voice1", "voice2", "voice3", "voice4"}) do
	AddFileSafe("sound/framework/overwatch/" .. name .. ".wav")
end

for _, name in ipairs({"comshieldwall.vmt", "comshieldwall2.vmt", "comshieldwall2faded.vmt",
	"comshieldwall3.vmt", "comshieldwall.vtf", "comshieldwall_close.vtf",
	"com_shield002a.vmt", "com_shield002a.vtf", "com_shield002b.vtf", "com_shield003a.vmt",
	"com_shield004a.vmt", "com_shield004b.vtf"}) do
	AddFileSafe("materials/framework/forcefield/" .. name)
end

for _, name in ipairs({"body", "head", "chest", "stomach", "armleft", "armright",
	"legleft", "legright"}) do
	AddFileSafe("materials/framework/body/" .. name .. ".png")
end

local M = NETWORK.medical

M.watchers = M.watchers or {}

M.downTime = 40

local HOPELESS = {
	[DMG_DISSOLVE] = true,
	[DMG_REMOVENORAGDOLL] = true
}

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone, ...)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function BleedScale()
	return NETWORK.config.Get("medBleedScale") or 1
end

function M.GetBodyPos(target)
	if (IsValid(target.nwRagdollEntity)) then
		return target.nwRagdollEntity:WorldSpaceCenter()
	end

	return target:WorldSpaceCenter()
end

function M.InReach(medic, patient)
	if (medic == patient) then
		return true
	end

	return medic:WorldSpaceCenter():Distance(M.GetBodyPos(patient)) <= M.range
end

function M.GetBleeds(client)
	client.nwBleeds = client.nwBleeds or {}

	return client.nwBleeds
end

function M.GetBleedRate(client)
	local total = 0

	for _, entry in pairs(M.GetBleeds(client)) do
		if (!entry.tq) then
			total = total + M.bleedKinds[entry.kind].rate
		end
	end

	return total * BleedScale()
end

function M.HasActiveBleeding(client)
	for _, entry in pairs(M.GetBleeds(client)) do
		if (!entry.tq) then
			return true
		end
	end

	return false
end

function M.SyncBleeds(client)
	local parts = {}
	local total = 0

	for part, entry in pairs(M.GetBleeds(client)) do
		parts[#parts + 1] = part .. ":" .. entry.kind .. (entry.tq and ":t" or "")

		if (!entry.tq) then
			total = total + M.bleedKinds[entry.kind].rate
		end
	end

	table.sort(parts)

	client:SetNWString("nwBleedMap", table.concat(parts, ";"))
	NETWORK.bleed.Set(client, total / 30 * NETWORK.bleed.max)
end

function M.AddBleed(client, part, kind)
	if (!M.bleedKinds[kind] or !NETWORK.wound.GetPart(part)) then
		return false
	end

	if (NETWORK.toughness) then
		kind = NETWORK.toughness.AdjustBleed(client, kind)

		if (!kind) then
			return false
		end
	end

	local bleeds = M.GetBleeds(client)
	local existing = bleeds[part]

	if (existing and existing.tq) then
		return false
	end

	if (existing and M.bleedKinds[existing.kind].order >= M.bleedKinds[kind].order) then
		return false
	end

	bleeds[part] = {
		kind = kind,
		since = CurTime(),
		clot = kind == "minor" and CurTime() + math.Rand(40, 80) or nil
	}

	M.SyncBleeds(client)

	return true
end

function M.StopBleed(client, part)
	local bleeds = M.GetBleeds(client)

	if (!bleeds[part]) then
		return false
	end

	bleeds[part] = nil

	M.SyncBleeds(client)

	return true
end

function M.StopAllBleeding(client, bIncludeTourniquets)
	local bleeds = M.GetBleeds(client)

	for part, entry in pairs(bleeds) do
		if (bIncludeTourniquets or !entry.tq) then
			bleeds[part] = nil
		end
	end

	M.SyncBleeds(client)
end

function M.SetBlood(client, value)
	value = math.Clamp(math.Round(value), 0, M.bloodMax)

	client.nwBloodValue = value

	if (client:GetNWInt("nwBlood", M.bloodMax) != value) then
		client:SetNWInt("nwBlood", value)
	end
end

function M.GetBloodValue(client)
	return client.nwBloodValue or client:GetBlood()
end

function M.SetFracture(client, part, state)
	if (!M.IsLimb(part)) then
		return
	end

	if (state == 1 and NETWORK.toughness and
		!NETWORK.toughness.RollFracture(client)) then
		return
	end

	client:SetNWInt("nwFracture_" .. part, state or 0)

	M.RefreshLimp(client)
end

function M.SetPneumo(client, bValue)
	if (bValue and NETWORK.toughness and !NETWORK.toughness.CanPneumo(client)) then
		return false
	end

	client:SetNWBool("nwPneumo", bValue == true)

	NETWORK.movement.Apply(client)

	return true
end

function M.SetOxygen(client, value)
	value = math.Clamp(value, 0, M.oxygenMax)

	if (math.abs(client:GetOxygen() - value) >= 0.5 or value == 0 or
		value == M.oxygenMax) then
		client:SetNWFloat("nwOxygen", value)
	end

	client.nwOxygenValue = value
end

function M.GetOxygenValue(client)
	return client.nwOxygenValue or client:GetOxygen()
end

function M.RefreshLimp(client)
	local bLimp = NETWORK.wound.IsLimping(client) or M.HasLegFracture(client)

	client:SetNWBool("nwLimping", bLimp)

	NETWORK.movement.Apply(client)
end

function M.Reset(client)
	client.nwBleeds = {}
	client.nwTransfuse = nil
	client.nwMorphineAt = nil
	client.nwHypoxia = nil
	client.nwDowns = nil
	client.nwCritStart = nil
	client.nwMedPending = nil
	client.nwMedTask = nil

	M.SyncBleeds(client)
	M.SetBlood(client, M.bloodMax)
	M.SetOxygen(client, M.oxygenMax)

	for part in pairs(M.limbs) do
		client:SetNWInt("nwFracture_" .. part, 0)
	end

	client:SetNWBool("nwPneumo", false)
	client:SetNWBool("nwCritical", false)
	client:SetNWBool("nwStable", false)
	client:SetNWFloat("nwCritLeft", 0)
	client:SetNWBool("nwUnconscious", false)
	client:SetNWBool("nwTransfusing", false)

	M.RefreshLimp(client)
end

local function Chance(value)
	return math.random() < value
end

local function RandomPart(list)
	return list[math.random(#list)]
end

function M.Injure(target, info, damage)

	hook.Run("NetworkPlayerInjured", target, damage)

	local bBullet = info:IsBulletDamage() or info:IsDamageType(DMG_BUCKSHOT)
	local bSlash = info:IsDamageType(DMG_SLASH)
	local bBlast = info:IsExplosionDamage()
	local bBlunt = info:IsDamageType(DMG_CLUB) or info:IsDamageType(DMG_CRUSH)
	local part

	if ((target.nwMedPartTime or 0) + 0.2 >= CurTime()) then
		part = target.nwMedPart
	end

	if (bBlast) then
		local parts = {"chest", "stomach", "armLeft", "armRight", "legLeft", "legRight"}

		for _ = 1, damage >= 40 and 2 or 1 do
			local hit = RandomPart(parts)

			M.AddBleed(target, hit, Chance(0.35) and "major" or "minor")

			if (M.IsLimb(hit) and damage >= 35 and Chance(0.3)) then
				M.SetFracture(target, hit, 1)
			end
		end

		if (damage >= 20) then
			NETWORK.wound.Pain(target, math.Clamp(damage * 0.8, 10, 40))
		end

		return
	end

	if (!part and (bBullet or bSlash)) then
		part = "stomach"
	end

	if (!part) then
		if (bBlunt and damage >= 25) then
			local limb = RandomPart({"armLeft", "armRight", "legLeft", "legRight"})

			if (Chance(0.25)) then
				M.SetFracture(target, limb, 1)
			end

			NETWORK.wound.Pain(target, math.Clamp(damage * 0.6, 8, 25))
		end

		return
	end

	if (bBullet or bSlash) then
		if (M.IsLimb(part)) then
			if (damage >= 20 and Chance(bBullet and 0.35 or 0.25)) then
				M.AddBleed(target, part, "artery")
			elseif (damage >= 10) then
				M.AddBleed(target, part, "major")
			elseif (damage >= 4) then
				M.AddBleed(target, part, "minor")
			end

			if (bBullet and damage >= 25 and Chance(0.4)) then
				M.SetFracture(target, part, 1)
			end
		elseif (part == "chest" or part == "stomach") then
			local armour = NETWORK.wound.GetProtection(target, "armour")
			local bStopped = armour > 0 and Chance(armour)

			if (!bStopped) then
				M.AddBleed(target, part, damage >= 12 and "major" or "minor")

				if (part == "chest" and bBullet and damage >= 15 and Chance(0.3)) then
					if (M.SetPneumo(target, true)) then
						Notice(target, "medPneumoHit", "bad")
					end
				end
			elseif (damage >= 8) then
				M.AddBleed(target, part, "minor")
			end
		else
			M.AddBleed(target, part, "minor")
		end
	elseif (bBlunt) then
		if (M.IsLimb(part) and damage >= 25 and Chance(0.3)) then
			M.SetFracture(target, part, 1)
		end

		if (damage >= 30 and Chance(0.3)) then
			M.AddBleed(target, part, "minor")
		end
	end

	if (damage >= 15) then
		NETWORK.wound.Pain(target, math.Clamp(damage * 0.8, 8, 35))
	end
end

function M.CanGoCritical(target, info, damage)
	if (NETWORK.config.Get("medCritical") == false) then
		return false
	end

	if (target:WaterLevel() >= 3) then
		return false
	end

	for flag in pairs(HOPELESS) do
		if (info:IsDamageType(flag)) then
			return false
		end
	end

	if (damage - target:Health() >= M.overkill) then
		return false
	end

	if (target:LastHitGroup() == HITGROUP_HEAD and info:IsBulletDamage() and
		NETWORK.wound.GetProtection(target, "helmet") <= 0) then
		return false
	end

	return hook.Run("NetworkCanGoCritical", target, info) != false
end

function M.EnterCritical(client, attacker)
	client.nwMedPending = nil

	if (!client:Alive() or client:IsCritical()) then
		return
	end

	client.nwDowns = (client.nwDowns or 0) + 1
	client.nwCritStart = CurTime()

	local time = math.max(M.criticalTime / (1 + (client.nwDowns - 1) * 0.5),
		M.criticalMin)

	client:SetHealth(1)
	client:SetNWBool("nwCritical", true)
	client:SetNWBool("nwStable", false)
	client:SetNWFloat("nwCritLeft", time)

	client.nwCritLeft = time

	if (!M.HasActiveBleeding(client)) then
		M.AddBleed(client, "stomach", "major")
	end

	if (!IsValid(client.nwRagdollEntity)) then
		NETWORK.ragdoll.Start(client, M.downTime)
	end

	M.SetUnconscious(client, true)

	NETWORK.chat.Send(client, "me", L("medCriticalMe"))
	Notice(client, "medCriticalSelf", "bad")

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("death", string.format("%s тяжело ранен (%s)",
			NETWORK.log.Name(client), NETWORK.log.Name(attacker)), client:GetPos())
	end

	hook.Run("NetworkPlayerCritical", client, attacker)
end

function M.ExitCritical(client, health)
	if (!client:IsCritical()) then
		return
	end

	client:SetNWBool("nwCritical", false)
	client:SetNWBool("nwStable", false)
	client:SetNWFloat("nwCritLeft", 0)

	client.nwCritLeft = nil
	client.nwCritStart = nil

	client:SetHealth(math.Clamp(health or 25, 1, client:GetMaxHealth()))

	NETWORK.wound.Pain(client, 60)

	M.UpdateConsciousness(client)

	hook.Run("NetworkPlayerRevived", client)
end

function M.Kill(client, key)
	if (!client:Alive()) then
		return
	end

	client.nwMedKilling = true
	client:Kill()
	client.nwMedKilling = nil

	if (key) then
		Notice(client, key, "bad")
	end
end

function M.SetUnconscious(client, bValue)
	local bWas = client:IsUnconscious()

	client:SetNWBool("nwUnconscious", bValue)

	if (bValue) then
		if (!IsValid(client.nwRagdollEntity)) then
			NETWORK.ragdoll.Start(client, M.downTime)
		end

		client.nwRagdollUntil = CurTime() + M.downTime
		client:SetNWFloat("nwRagdollUntil", client.nwRagdollUntil)

		if (!bWas and !client:IsCritical()) then
			Notice(client, "medPassedOut", "bad")
			NETWORK.chat.Send(client, "me", L("medPassedOutMe"))
		end

		return
	end

	if (bWas and IsValid(client.nwRagdollEntity)) then

		client.nwRagdollUntil = CurTime() + 3
		client:SetNWFloat("nwRagdollUntil", client.nwRagdollUntil)

		Notice(client, "medWokeUp", "warn")
	end
end

function M.ShouldBeUnconscious(client)
	if (client:IsCritical()) then
		return true
	end

	local blood = M.GetBloodValue(client)

	if (client:IsUnconscious()) then
		if (blood < M.wakeAt) then
			return true
		end
	elseif (blood < M.unconsciousAt) then
		return true
	end

	return client:HasPneumothorax() and M.GetOxygenValue(client) <= 0
end

function M.UpdateConsciousness(client)
	local bShould = M.ShouldBeUnconscious(client)

	if (bShould != client:IsUnconscious()) then
		M.SetUnconscious(client, bShould)
	elseif (bShould and !IsValid(client.nwRagdollEntity)) then
		NETWORK.ragdoll.Start(client, M.downTime)
	end

	if (bShould) then
		local left = client:IsCritical() and math.max(client.nwCritLeft or 0, 1) or M.downTime

		if (client:IsCritical() or (client.nwRagdollUntil or 0) - CurTime() < 5) then
			client.nwRagdollUntil = CurTime() + left
			client:SetNWFloat("nwRagdollUntil", client.nwRagdollUntil)
		end
	end
end

local tick = 0

timer.Create("nwMedical", 1, 0, function()
	tick = tick + 1

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:HasCharacter()) then
			continue
		end

		local bleeds = M.GetBleeds(client)
		local bChanged = false

		for part, entry in pairs(bleeds) do
			if (entry.clot and !entry.tq and entry.clot <= CurTime()) then
				bleeds[part] = nil
				bChanged = true
			end
		end

		if (bChanged) then
			M.SyncBleeds(client)
		end

		local blood = M.GetBloodValue(client)
		local rate = M.GetBleedRate(client)

		if (rate > 0) then
			blood = blood - rate

			if (tick % 3 == 0) then
				NETWORK.bleed.Splatter(client)
			end
		elseif (!client:IsCritical() and client:GetHunger() > 25 and
			client:GetThirst() > 25) then
			blood = blood + M.bloodRegen
		end

		local transfuse = client.nwTransfuse or 0

		if (transfuse > 0) then
			local amount = math.min(transfuse, M.transfuseRate)

			blood = blood + amount
			client.nwTransfuse = transfuse - amount

			if (client.nwTransfuse <= 0) then
				client.nwTransfuse = nil
				client:SetNWBool("nwTransfusing", false)
			end
		end

		M.SetBlood(client, blood)

		local oxygen = M.GetOxygenValue(client)

		if (client:HasPneumothorax()) then
			oxygen = oxygen - M.oxygenDrain

			if (tick % 9 == 0 and !client:IsUnconscious()) then
				client:EmitSound("ambient/voices/cough" .. math.random(1, 4) .. ".wav",
					60, math.random(95, 110))
			end
		else
			oxygen = oxygen + M.oxygenRegen
		end

		M.SetOxygen(client, oxygen)

		if (client:HasPneumothorax() and M.GetOxygenValue(client) <= 0) then
			client.nwHypoxia = (client.nwHypoxia or 0) + 1

			if (client.nwHypoxia >= M.hypoxiaDeath) then
				M.Kill(client, "medDiedHypoxia")

				continue
			end
		else
			client.nwHypoxia = nil
		end

		if (M.GetBloodValue(client) <= M.deathAt) then
			M.Kill(client, "medDiedBlood")

			continue
		end

		if (client:IsCritical()) then
			local bStable = !M.HasActiveBleeding(client) and
				(!client:HasPneumothorax() or M.GetOxygenValue(client) > 0)

			if (bStable != client:IsStable()) then
				client:SetNWBool("nwStable", bStable)
			end

			if (!bStable) then
				client.nwCritLeft = (client.nwCritLeft or M.criticalTime) - 1

				client:SetNWFloat("nwCritLeft", client.nwCritLeft)

				if (client.nwCritLeft <= 0) then
					M.Kill(client, "medDiedCritical")

					continue
				end
			end
		end

		M.UpdateConsciousness(client)

		if (tick % 2 == 0) then
			NETWORK.movement.Apply(client)
		end
	end
end)

hook.Add("ScalePlayerDamage", "nwMedicalPart", function(client, hitgroup)
	local part = NETWORK.wound.hitgroups[hitgroup]

	if (part) then
		client.nwMedPart = part
		client.nwMedPartTime = CurTime()
	end
end)

hook.Add("EntityTakeDamage", "nwMedical", function(target, info)
	if (!IsValid(target) or !target:IsPlayer() or !target:HasCharacter() or
		!target:Alive() or target.nwMedKilling) then
		return
	end

	local damage = info:GetDamage()

	if (damage <= 0) then
		return
	end

	if (target:IsCritical()) then
		if (damage >= 3) then
			info:SetDamage(math.max(damage, target:Health() + target:Armor() + 10))
		else
			info:SetDamage(0)
		end

		return
	end

	if (target.nwMedPending) then
		info:SetDamage(0)

		return
	end

	if (NETWORK.toughness) then
		local scale = NETWORK.toughness.GetTakenScale(target, info) *
			NETWORK.toughness.GetDealtScale(info:GetAttacker(), info)

		if (scale != 1) then
			damage = damage * scale

			info:SetDamage(damage)

			if (damage <= 0) then
				return
			end
		end
	end

	if (info:IsFallDamage() and (target.nwFallSpeed or 0) > 650 and Chance(0.6)) then
		M.SetFracture(target, math.random() > 0.5 and "legLeft" or "legRight", 1)
		NETWORK.wound.Pain(target, 30)
	else
		M.Injure(target, info, damage)
	end

	if (damage < target:Health()) then
		return
	end

	if (!M.CanGoCritical(target, info, damage)) then
		return
	end

	info:SetDamage(math.max(target:Health() - 1, 0))

	target.nwMedPending = true

	local attacker = info:GetAttacker()

	timer.Simple(0, function()
		if (IsValid(target)) then
			if (target:Alive()) then
				M.EnterCritical(target, attacker)
			else
				target.nwMedPending = nil
			end
		end
	end)
end)

hook.Add("EntityTakeDamage", "nwDealtScale", function(target, info)
	if (!NETWORK.toughness or !IsValid(target)) then
		return
	end

	if (target:IsPlayer() and target:HasCharacter()) then
		return
	end

	local scale = NETWORK.toughness.GetDealtScale(info:GetAttacker(), info)

	if (scale != 1) then
		info:ScaleDamage(scale)
	end
end)

hook.Add("NetworkCanHelpUp", "nwMedical", function(client, target)
	if (target:IsUnconscious() or target:IsCritical()) then
		Notice(client, "medCantHelpUp", "warn")

		return false
	end
end)

hook.Add("NetworkMovementSpeed", "nwMedical", function(client, walk, run)
	local walkScale, runScale = 1, 1

	for part in pairs(M.legs) do
		local state = client:GetFracture(part)

		if (state == 1) then
			walkScale = walkScale * 0.6
			runScale = runScale * 0.45
		elseif (state == 2) then
			walkScale = walkScale * 0.9
			runScale = runScale * 0.75
		end
	end

	local class = M.GetBloodClass(M.GetBloodValue(client))

	if (class == 2) then
		runScale = runScale * 0.9
	elseif (class >= 3) then
		walkScale = walkScale * 0.8
		runScale = runScale * 0.7
	end

	if (client:HasPneumothorax()) then
		runScale = runScale * 0.8
	end

	if (walkScale == 1 and runScale == 1) then
		return
	end

	return math.Round(walk * walkScale), math.Round(run * runScale)
end)

hook.Add("StartCommand", "nwMedical", function(client, cmd)
	if (!client:Alive()) then
		return
	end

	if (M.HasLegFracture(client)) then
		cmd:RemoveKey(IN_SPEED)
		cmd:RemoveKey(IN_JUMP)
	end

	if (client:HasPneumothorax() and client:GetOxygen() < 50) then
		cmd:RemoveKey(IN_SPEED)
	end
end)

hook.Add("EntityFireBullets", "nwMedical", function(entity, data)
	if (!IsValid(entity) or !entity:IsPlayer()) then
		return
	end

	local spread = 0

	for part in pairs(M.arms) do
		local state = entity:GetFracture(part)

		if (state == 1) then
			spread = spread + 0.035
		elseif (state == 2) then
			spread = spread + 0.012
		end
	end

	if (spread <= 0) then
		return
	end

	for id, callback in pairs(hook.GetTable()["EntityFireBullets"] or {}) do
		if (id == "nwMedical" or !isstring(id)) then
			continue
		end

		local bOk, result = pcall(callback, entity, data)

		if (bOk and result == false) then
			return false
		end
	end

	data.Spread = (data.Spread or vector_origin) + Vector(spread, spread, 0)

	entity:ViewPunch(Angle(-math.Rand(1, 2.5) * spread * 40,
		math.Rand(-1, 1) * spread * 40, 0))

	return true
end)

hook.Add("PlayerSpawn", "nwMedical", function(client)
	M.Reset(client)
end)

hook.Add("NetworkCharacterLoaded", "nwMedical", function(client)
	M.Reset(client)
end)

hook.Add("PlayerDeath", "nwMedical", function(client)
	client:SetNWBool("nwCritical", false)
	client:SetNWBool("nwUnconscious", false)
	client.nwMedTask = nil
	client.nwMedPending = nil

	M.watchers[client] = nil
end)

hook.Add("NetworkCorpseCreated", "nwMedical", function(client, ragdoll)
	if (IsValid(ragdoll)) then
		ragdoll:SetNWFloat("nwDeathTime", CurTime())
	end
end)

hook.Add("PlayerDisconnected", "nwMedical", function(client)
	M.watchers[client] = nil
end)

net.Receive("nwMedGiveUp", function(_, client)
	if (!client:Alive() or !client:IsCritical()) then
		return
	end

	if (CurTime() - (client.nwCritStart or CurTime()) < M.giveUpAfter) then
		return
	end

	M.Kill(client)
end)

local function FirstBleeding(client, filter)
	local best, bestOrder

	for _, data in ipairs(NETWORK.wound.parts) do
		local entry = M.GetBleeds(client)[data.id]

		if (entry and !entry.tq and filter(data.id, entry)) then
			local order = M.bleedKinds[entry.kind].order

			if (!bestOrder or order > bestOrder) then
				best, bestOrder = data.id, order
			end
		end
	end

	return best
end

local function WorstWound(client)
	local best, value = nil, 0

	for _, data in ipairs(NETWORK.wound.parts) do
		local current = NETWORK.wound.Get(client, data.id)

		if (current > value) then
			best, value = data.id, current
		end
	end

	return best
end

local function Conscious(patient)
	return !patient:IsUnconscious()
end

local T = M.treatments

T.tourniquet.CanApply = function(medic, patient, part)
	local bleeds = M.GetBleeds(patient)

	if (part) then
		if (!M.IsLimb(part)) then
			return false, "medTourniquetLimbOnly"
		end

		local entry = bleeds[part]

		if (!entry or entry.tq) then
			return false, "medTourniquetNone"
		end

		return true, part
	end

	part = FirstBleeding(patient, function(id, entry)
		return M.IsLimb(id) and entry.kind != "minor"
	end)

	if (!part) then
		return false, "medTourniquetNone"
	end

	return true, part
end

T.tourniquet.Apply = function(medic, patient, part)
	local entry = M.GetBleeds(patient)[part]

	entry.tq = true
	entry.tqTime = CurTime()

	M.SyncBleeds(patient)
	NETWORK.wound.Pain(patient, 30)

	patient:EmitSound("physics/plastic/plastic_barrel_strain" .. math.random(1, 3) ..
		".wav", 55, 120, 0.6)

	return "medTourniquetDone", "good", NETWORK.wound.GetPart(part).name
end

T.bandage.CanApply = function(medic, patient, part)
	local bleeds = M.GetBleeds(patient)

	if (part) then
		local entry = bleeds[part]

		if (entry and !entry.tq and entry.kind == "artery") then
			return false, "medBandageArtery"
		end

		if ((entry and !entry.tq) or NETWORK.wound.Get(patient, part) > 0) then
			return true, part
		end

		return false, "medNothingToBandage"
	end

	part = FirstBleeding(patient, function(_, entry)
		return entry.kind != "artery"
	end)

	if (part) then
		return true, part
	end

	if (FirstBleeding(patient, function()
		return true
	end)) then
		return false, "medBandageArtery"
	end

	part = WorstWound(patient)

	if (part) then
		return true, part
	end

	return false, "medNothingToBandage"
end

T.bandage.Apply = function(medic, patient, part)
	M.StopBleed(patient, part)
	NETWORK.wound.Heal(patient, part, 25)

	if (!patient:IsCritical()) then
		patient:SetHealth(math.min(patient:Health() + 5, patient:GetMaxHealth()))
	end

	return "medBandageDone", "good", NETWORK.wound.GetPart(part).name
end

T.chestseal.CanApply = function(medic, patient)
	if (!patient:HasPneumothorax()) then
		return false, "medSealNone"
	end

	return true, "chest"
end

T.chestseal.Apply = function(medic, patient)
	M.SetPneumo(patient, false)

	patient.nwHypoxia = nil

	M.UpdateConsciousness(patient)

	return "medSealDone", "good"
end

T.splint.CanApply = function(medic, patient, part)
	if (part) then
		if (!M.IsLimb(part) or !patient:HasFracture(part)) then
			return false, "medSplintNone"
		end

		return true, part
	end

	for _, id in ipairs({"legLeft", "legRight", "armLeft", "armRight"}) do
		if (patient:HasFracture(id)) then
			return true, id
		end
	end

	return false, "medSplintNone"
end

T.splint.Apply = function(medic, patient, part)
	M.SetFracture(patient, part, 2)
	NETWORK.wound.Heal(patient, part, 20)

	patient:EmitSound("physics/wood/wood_box_break" .. math.random(1, 2) .. ".wav",
		55, 120, 0.5)

	if (NETWORK.wound.Pain(patient, 45)) then
		Notice(patient, "splintPain", "warn")
	end

	return "medSplintDone", "good", NETWORK.wound.GetPart(part).name
end

T.medkit.CanApply = function(medic, patient)
	if (M.HasActiveBleeding(patient) or WorstWound(patient) or patient:IsCritical() or
		patient:Health() < patient:GetMaxHealth()) then
		return true
	end

	for part in pairs(M.limbs) do
		if (patient:HasFracture(part)) then
			return true
		end
	end

	return false, "medNothingToDo"
end

T.medkit.Apply = function(medic, patient)

	M.StopAllBleeding(patient, true)

	for _, data in ipairs(NETWORK.wound.parts) do
		NETWORK.wound.Heal(patient, data.id, 50)
	end

	for part in pairs(M.limbs) do
		if (patient:HasFracture(part)) then
			M.SetFracture(patient, part, 2)
		end
	end

	patient:EmitSound("items/medshot4.wav", 65, 100)

	if (patient:IsCritical()) then
		if (!patient:HasPneumothorax() or M.GetOxygenValue(patient) > 20) then
			M.ExitCritical(patient, 40)

			return "medRevived", "good"
		end

		return "medStabilised", "warn"
	end

	patient:SetHealth(math.min(patient:Health() + 40, patient:GetMaxHealth()))

	return "medMedkitDone", "good"
end

T.syringe.CanApply = function(medic, patient)
	if (patient:IsCritical() and M.HasActiveBleeding(patient)) then
		return false, "medReviveUnstable"
	end

	return true
end

T.syringe.Apply = function(medic, patient)
	patient:EmitSound("framework/cmb/healthpen/inject1.mp3", 60, 100)

	for _, data in ipairs(NETWORK.wound.parts) do
		NETWORK.wound.Heal(patient, data.id, 12)
	end

	M.SetBlood(patient, M.GetBloodValue(patient) + 250)

	if (patient:IsCritical()) then
		M.ExitCritical(patient, 25)

		return "medRevived", "good"
	end

	patient:SetHealth(math.min(patient:Health() + 25, patient:GetMaxHealth()))

	return "medSyringeDone", "good"
end

T.bloodbag.CanApply = function(medic, patient)
	if ((patient.nwTransfuse or 0) > 0) then
		return false, "medAlreadyTransfusing"
	end

	if (M.GetBloodValue(patient) >= M.bloodMax - 100) then
		return false, "medBloodFull"
	end

	return true
end

T.bloodbag.Apply = function(medic, patient)
	patient.nwTransfuse = M.transfuseAmount
	patient:SetNWBool("nwTransfusing", true)

	return "medTransfuseDone", "good"
end

T.morphine.CanApply = function()
	return true
end

T.morphine.Apply = function(medic, patient)
	local bOverdose = (patient.nwMorphineAt or 0) + 90 > CurTime()

	patient.nwMorphineAt = CurTime()

	NETWORK.wound.Numb(patient, 300)

	patient:EmitSound("framework/cmb/healthpen/inject1.mp3", 55, 90)

	if (patient:IsCritical()) then
		patient.nwCritLeft = math.min((patient.nwCritLeft or 0) + 30, M.criticalTime)
		patient:SetNWFloat("nwCritLeft", patient.nwCritLeft)
	end

	if (bOverdose) then
		M.SetOxygen(patient, M.GetOxygenValue(patient) - 70)
		M.SetPneumo(patient, true)

		timer.Simple(40, function()
			if (IsValid(patient) and patient:Alive()) then
				M.SetPneumo(patient, false)
			end
		end)

		return "medOverdose", "bad"
	end

	return "medMorphineDone", "good"
end

T.painkillers.CanApply = function(medic, patient)
	if (!Conscious(patient)) then
		return false, "medPatientUnconscious"
	end

	return true
end

T.painkillers.Apply = function(medic, patient)
	NETWORK.wound.Numb(patient)

	patient:EmitSound("items/medshot4.wav", 50, 130, 0.6)

	return "painNumbed", "good"
end

local function CountItem(client, id)
	local count = 0
	local state = NETWORK.inventory.GetState(client)

	for _, item in pairs(state.items or {}) do
		if (istable(item) and item.id == id) then
			count = count + (item.amount or 1)
		end
	end

	return count
end

M.CountItem = CountItem

function M.CanTreat(medic, patient)
	if (!IsValid(medic) or !medic:Alive() or !medic:HasCharacter()) then
		return false
	end

	if (medic:IsUnconscious() or medic:IsDowned() or
		NETWORK.restraint.IsTied(medic)) then
		return false, "medCantNow"
	end

	if (!IsValid(patient) or !patient:IsPlayer() or !patient:Alive() or
		!patient:HasCharacter()) then
		return false, "medNoPatient"
	end

	if (!M.InReach(medic, patient)) then
		return false, "medTooFar"
	end

	return true
end

function M.Begin(medic, patient, id, part)
	local treatment = T[id]

	if (!treatment) then
		return false
	end

	if (medic.nwMedTask) then
		Notice(medic, "medBusy", "warn")

		return false
	end

	local bOk, key = M.CanTreat(medic, patient)

	if (!bOk) then
		if (key) then
			Notice(medic, key, "bad")
		end

		return false
	end

	if (CountItem(medic, id) <= 0) then
		Notice(medic, "medNoItem", "bad")

		return false
	end

	if (part == "") then
		part = nil
	end

	if (part and !NETWORK.wound.GetPart(part)) then
		return false
	end

	local bCan, result = treatment.CanApply(medic, patient, part)

	if (!bCan) then
		Notice(medic, result or "medNothingToDo", "warn")

		return false
	end

	part = isstring(result) and result or part

	local time = treatment.time * (medic == patient and 1.25 or 1)

	if (NETWORK.skills) then
		time = time * math.Clamp(1.3 - NETWORK.skills.Get(medic, "medicine") *
			NETWORK.skills.Effect("medicine", "time"), 0.5, 1.5)
	end

	medic.nwMedTask = {
		patient = patient,
		id = id,
		part = part,
		finish = CurTime() + time,
		total = time,
		hits = 0,
		origin = medic:GetPos(),

		pauseAt = CurTime() + math.Rand(2, 3)
	}

	Progress(medic, "medProgress_" .. id, time)

	medic.nwMedTask.part = part or "chest"

	local base = NETWORK.item.Get(id)

	NETWORK.chat.Send(medic, "me", medic == patient and
		L("medTreatSelfMe", base and base.name or id) or
		L("medTreatOtherMe", base and base.name or id))

	hook.Run("NetworkMedicalStarted", medic, patient, id)

	return true
end

function M.Cancel(medic, key)
	if (!medic.nwMedTask) then
		return
	end

	medic.nwMedTask = nil

	Progress(medic, "", 0)

	net.Start("nwMedGame")
		net.WriteBool(false)
	net.Send(medic)

	if (key) then
		Notice(medic, key, "warn")
	end
end

net.Receive("nwMedGameHit", function(_, client)
	local bHit = net.ReadBool()
	local task = client.nwMedTask

	if (!task or !task.bPaused) then
		return
	end

	if (bHit) then
		task.hits = task.hits + 1
		task.finish = task.finish - task.total * 0.1
	else
		task.finish = task.finish + task.total * 0.1
	end

	task.bPaused = false
	task.pauseAt = CurTime() + math.Rand(2, 3)

	net.Start("nwMedGame")
		net.WriteBool(false)
	net.Send(client)

	local left = math.max(task.finish - CurTime(), 0.05)

	Progress(client, "medProgress_" .. task.id, left)
end)

function M.Finish(medic)
	local task = medic.nwMedTask

	medic.nwMedTask = nil

	net.Start("nwMedGame")
		net.WriteBool(false)
	net.Send(medic)

	local patient = task.patient
	local treatment = T[task.id]

	if (!M.CanTreat(medic, patient)) then
		return
	end

	local bCan, result = treatment.CanApply(medic, patient, task.part)

	if (!bCan) then
		return Notice(medic, result or "medNothingToDo", "warn")
	end

	local part = isstring(result) and result or task.part

	if (!NETWORK.inventory.Take(medic, task.id, 1)) then
		return Notice(medic, "medNoItem", "bad")
	end

	NETWORK.inventory.Sync(medic)

	local medicine = NETWORK.skills and NETWORK.skills.Get(medic, "medicine") or 0

	patient.nwHealScale = math.Clamp(0.6 + medicine * NETWORK.skills.Effect("medicine", "heal"),
		0.4, 1.6)

	local key, tone, argument = treatment.Apply(medic, patient, part)

	patient.nwHealScale = nil

	if (medicine > 0 and patient:Alive() and !patient:IsCritical()) then
		patient:SetHealth(math.min(patient:Health() +
			medicine * NETWORK.skills.Effect("medicine", "health"), patient:GetMaxHealth()))
	end

	if (key) then
		Notice(medic, key, tone, argument or "")

		if (patient != medic) then
			Notice(patient, "medTreatedBy", "info",
				medic:GetRecognisedName(patient), L(NETWORK.item.Get(task.id).name))
		end
	end

	M.UpdateConsciousness(patient)
	M.PushAll(patient)

	hook.Run("NetworkPlayerTreated", medic, patient, task.id, part)
end

timer.Create("nwMedicalTasks", 0.1, 0, function()
	for _, medic in ipairs(player.GetAll()) do
		local task = medic.nwMedTask

		if (!task) then
			continue
		end

		if (!medic:Alive() or !IsValid(task.patient) or !task.patient:Alive()) then
			M.Cancel(medic, "medInterrupted")

			continue
		end

		if (medic:GetPos():Distance(task.origin) > M.moveTolerance or
			!M.InReach(medic, task.patient)) then
			M.Cancel(medic, "medInterrupted")

			continue
		end

		if (task.bPaused) then

			task.finish = task.finish + 0.1

			continue
		end

		if (task.pauseAt and CurTime() >= task.pauseAt and task.finish - CurTime() > 1) then
			task.bPaused = true

			Progress(medic, "medProgress_" .. task.id, 0)

			net.Start("nwMedGame")
				net.WriteBool(true)
				net.WriteString(task.part or "chest")
				net.WriteFloat(task.total)
				net.WriteString(task.id)
			net.Send(medic)

			continue
		end

		if (task.finish <= CurTime()) then
			M.Finish(medic)
		end
	end
end)

hook.Add("StartCommand", "nwMedicalTask", function(client, cmd)
	if (client.nwMedTask) then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		cmd:RemoveKey(IN_JUMP)
	end
end)

net.Receive("nwMedTreat", function(_, client)
	local patient = net.ReadEntity()
	local id = net.ReadString()
	local part = net.ReadString()

	if ((client.nwNextTreat or 0) > CurTime()) then
		return
	end

	client.nwNextTreat = CurTime() + 0.4

	M.Begin(client, patient, id, part)
end)

function M.BuildPanel(medic, patient)
	local parts = {}
	local bleeds = M.GetBleeds(patient)

	for _, data in ipairs(NETWORK.wound.parts) do
		local entry = bleeds[data.id]

		parts[#parts + 1] = {
			id = data.id,
			wound = math.Round(NETWORK.wound.Get(patient, data.id)),
			bleed = entry and entry.kind or "",
			tq = entry and entry.tq or false,
			fracture = M.IsLimb(data.id) and patient:GetFracture(data.id) or 0
		}
	end

	local blood = M.GetBloodValue(patient)

	return {
		name = patient == medic and medic:GetCharacterName() or
			patient:GetRecognisedName(medic),
		bSelf = patient == medic,
		bCritical = patient:IsCritical(),
		bStable = patient:IsStable(),
		left = math.Round(patient.nwCritLeft or 0),
		bUnconscious = patient:IsUnconscious(),
		bloodClass = (M.GetBloodClass(blood)),
		bloodFraction = math.Round(blood / M.bloodMax * 20) / 20,
		bPneumo = patient:HasPneumothorax(),
		oxygen = math.Round(M.GetOxygenValue(patient)),
		bTransfusing = (patient.nwTransfuse or 0) > 0,
		bNumb = NETWORK.wound.IsNumb(patient),
		bPain = NETWORK.wound.GetPain(patient) > 0,
		health = math.Round(patient:Health() / math.max(patient:GetMaxHealth(), 1) * 100),
		parts = parts
	}
end

function M.Push(medic, patient, bOpen)
	net.Start(bOpen and "nwMedOpen" or "nwMedData")
		net.WriteEntity(patient)
		NETWORK.util.WriteTable(M.BuildPanel(medic, patient))
	net.Send(medic)
end

function M.PushAll(patient)
	for medic, target in pairs(M.watchers) do
		if (IsValid(medic) and target == patient) then
			M.Push(medic, patient)
		end
	end
end

function M.OpenPanel(medic, patient)
	local bOk, key = M.CanTreat(medic, patient)

	if (!bOk) then
		if (key) then
			Notice(medic, key, "bad")
		end

		return
	end

	M.watchers[medic] = patient

	M.Push(medic, patient, true)
end

function M.ClosePanel(medic)
	M.watchers[medic] = nil

	net.Start("nwMedClose")
	net.Send(medic)
end

timer.Create("nwMedicalWatch", 1, 0, function()
	for medic, patient in pairs(M.watchers) do
		if (!IsValid(medic)) then
			M.watchers[medic] = nil

			continue
		end

		if (!M.CanTreat(medic, patient)) then
			M.ClosePanel(medic)

			continue
		end

		M.Push(medic, patient)
	end
end)

net.Receive("nwMedStop", function(_, client)
	M.watchers[client] = nil
end)

net.Receive("nwMedSelf", function(_, client)
	if (client:Alive() and client:HasCharacter() and !client:IsUnconscious()) then
		M.OpenPanel(client, client)
	end
end)

NETWORK.command.Register("examine", {
	description = "cmdExamine",
	usage = "/examine",
	aliases = {"osmotr", "med"},
	OnRun = function(command, client)
		if (client:IsUnconscious()) then
			return
		end

		M.OpenPanel(client, client)
	end
})

NETWORK.command.Register("heal", {
	description = "cmdHeal",
	usage = "/heal [игрок]",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local target = client

		if (arguments[1] and arguments[1] != "") then
			local query = NETWORK.util.Lower(arguments[1])

			target = nil

			for _, other in ipairs(player.GetAll()) do
				if (string.find(NETWORK.util.Lower(other:GetCharacterName()), query, 1, true) or
					string.find(NETWORK.util.Lower(other:SteamName()), query, 1, true)) then
					target = other

					break
				end
			end

			if (!target) then
				return Notice(client, "medNoPatient", "bad")
			end
		end

		if (!IsValid(target) or !target:Alive()) then
			return
		end

		if (target:IsCritical()) then
			M.ExitCritical(target, target:GetMaxHealth())
		end

		M.Reset(target)

		if (NETWORK.wound.Reset) then
			NETWORK.wound.Reset(target)
		end

		target:SetHealth(target:GetMaxHealth())

		if (IsValid(target.nwRagdollEntity)) then
			NETWORK.ragdoll.Stop(target, true)
		end

		Notice(client, "medHealed", "good")
	end
})
