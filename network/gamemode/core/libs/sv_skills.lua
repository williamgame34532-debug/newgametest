util.AddNetworkString("nwSkills")
util.AddNetworkString("nwSkillXP")

NETWORK.skills.stored = NETWORK.skills.stored or {}

local path = "network/skills.txt"

local function Score(progress, id)
	local levels = istable(progress) and istable(progress.levels) and
		tonumber(progress.levels[id]) or 0
	local xp = istable(progress) and istable(progress.xp) and tonumber(progress.xp[id]) or 0

	return levels, xp
end

function NETWORK.skills.Merge(target, source)
	target.levels = istable(target.levels) and target.levels or {}
	target.xp = istable(target.xp) and target.xp or {}

	if (!istable(source)) then
		return target
	end

	local ids = {}

	for _, list in ipairs({source.levels, source.xp}) do
		if (istable(list)) then
			for id in pairs(list) do
				ids[tostring(id)] = true
			end
		end
	end

	for id in pairs(ids) do
		local levels, xp = Score(source, id)
		local ownLevels, ownXP = Score(target, id)

		if (levels > ownLevels or (levels == ownLevels and xp > ownXP)) then
			target.levels[id] = levels
			target.xp[id] = xp
		end
	end

	return target
end

function NETWORK.skills.Normalise(data)
	local stored = {}

	for key, progress in pairs(istable(data) and data or {}) do
		if (!istable(progress)) then
			continue
		end

		key = tostring(key)

		if (stored[key]) then
			NETWORK.skills.Merge(stored[key], progress)
		else
			stored[key] = NETWORK.skills.Merge({levels = {}, xp = {}}, progress)
		end
	end

	return stored
end

function NETWORK.skills.Load()
	local raw = file.Read(path, "DATA")

	if (!raw or raw == "") then
		NETWORK.skills.stored = NETWORK.skills.Normalise(NETWORK.skills.stored)

		return
	end

	local data = util.JSONToTable(raw)

	if (!istable(data)) then
		file.CreateDir("network")
		file.Write("network/skills_broken_" .. os.time() .. ".txt", raw)

		NETWORK.util.PrintWarning("[НАВЫКИ] skills.txt не читается — копия отложена, " ..
			"прогресс восстановится из сохранения персонажей.")

		data = {}
	end

	local merged = NETWORK.skills.Normalise(data)

	for key, progress in pairs(NETWORK.skills.Normalise(NETWORK.skills.stored)) do
		merged[key] = merged[key] and NETWORK.skills.Merge(merged[key], progress) or progress
	end

	NETWORK.skills.stored = merged
end

function NETWORK.skills.Save()
	timer.Remove("nwSkillsSave")

	file.CreateDir("network")
	file.Write(path, util.TableToJSON(NETWORK.skills.stored, true))
end

function NETWORK.skills.QueueSave()
	if (timer.Exists("nwSkillsSave")) then
		return
	end

	timer.Create("nwSkillsSave", 5, 1, NETWORK.skills.Save)
end

hook.Add("Initialize", "nwSkills", NETWORK.skills.Load)
hook.Add("ShutDown", "nwSkills", NETWORK.skills.Save)

hook.Add("PlayerDisconnected", "nwSkills", NETWORK.skills.Save)
hook.Add("NetworkCharacterUnloaded", "nwSkills", NETWORK.skills.Save)

hook.Add("NetworkPersistenceCollect", "nwSkills", function(client, data)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local progress = NETWORK.skills.GetProgress(client)

	data.skills = {
		levels = table.Copy(progress.levels or {}),
		xp = table.Copy(progress.xp or {})
	}
end)

hook.Add("NetworkPersistenceRestore", "nwSkills", function(client, data)
	if (!IsValid(client) or !client:HasCharacter() or !istable(data) or
		!istable(data.skills)) then
		return
	end

	local progress = NETWORK.skills.GetProgress(client)
	local before = util.TableToJSON(progress)

	NETWORK.skills.Merge(progress, data.skills)

	if (util.TableToJSON(progress) != before) then
		NETWORK.util.Print(string.format("[НАВЫКИ] персонажу #%s прогресс возвращён из сохранения",
			tostring(client:GetCharacterID())))

		NETWORK.skills.QueueSave()
		NETWORK.skills.Sync(client)

		if (NETWORK.movement and NETWORK.movement.Apply) then
			NETWORK.movement.Apply(client)
		end
	end
end)

function NETWORK.skills.Sync(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local progress = NETWORK.skills.GetProgress(client)

	for _, data in ipairs(NETWORK.skills.List()) do
		client:SetNWInt("nwSkill_" .. data.id, NETWORK.skills.Get(client, data.id))
	end

	net.Start("nwSkills")
		net.WriteString(util.TableToJSON({
			levels = progress.levels or {},
			xp = progress.xp or {}
		}))
	net.Send(client)
end

hook.Add("NetworkCharacterLoaded", "nwSkills", function(client)
	timer.Simple(0.5, function()
		if (IsValid(client)) then
			NETWORK.skills.Sync(client)
			NETWORK.movement.Apply(client)
		end
	end)
end)

function NETWORK.skills.AddXP(client, id, amount, reason)
	if (!IsValid(client) or !client:HasCharacter() or !NETWORK.skills.GetDefinition(id)) then
		return false
	end

	amount = math.Round(tonumber(amount) or 0)

	if (amount <= 0) then
		return false
	end

	local progress = NETWORK.skills.GetProgress(client)

	progress.levels = progress.levels or {}
	progress.xp = progress.xp or {}

	local total = NETWORK.skills.Get(client, id)

	if (total >= NETWORK.skills.maxLevel) then
		return false
	end

	local xp = (tonumber(progress.xp[id]) or 0) + amount
	local bLevelled = false

	while (xp >= NETWORK.skills.Need(total) and total < NETWORK.skills.maxLevel) do
		xp = xp - NETWORK.skills.Need(total)
		progress.levels[id] = (tonumber(progress.levels[id]) or 0) + 1
		total = total + 1
		bLevelled = true
	end

	if (total >= NETWORK.skills.maxLevel) then
		xp = 0
	end

	progress.xp[id] = xp

	NETWORK.skills.QueueSave()
	NETWORK.skills.Sync(client)

	net.Start("nwSkillXP")
		net.WriteString(id)
		net.WriteUInt(math.min(amount, 65535), 16)
		net.WriteBool(bLevelled)
	net.Send(client)

	if (bLevelled) then
		local definition = NETWORK.skills.GetDefinition(id)

		NETWORK.notice.Send(client, "skillLevelUp", "good", L(definition.name), total)

		client:EmitSound("buttons/button9.wav", 55, 120)

		NETWORK.movement.Apply(client)

		hook.Run("NetworkSkillLevelled", client, id, total)
	end

	return true
end

function NETWORK.skills.AddXPThrottled(client, id, amount, key, delay)
	client.nwSkillThrottle = client.nwSkillThrottle or {}

	if ((client.nwSkillThrottle[key] or 0) > CurTime()) then
		return false
	end

	client.nwSkillThrottle[key] = CurTime() + (delay or 10)

	return NETWORK.skills.AddXP(client, id, amount)
end

NETWORK.skills.treatmentXP = {
	tourniquet = 10, bandage = 12, chestseal = 20, splint = 18,
	medkit = 30, syringe = 10, bloodbag = 22, morphine = 6, painkillers = 6
}

hook.Add("NetworkPlayerTreated", "nwSkills", function(medic, patient, id)
	local amount = NETWORK.skills.treatmentXP[id] or 8

	if (medic == patient) then
		amount = math.ceil(amount * 0.5)
	end

	NETWORK.skills.AddXP(medic, "medicine", amount)
end)

hook.Add("NetworkScannerRepaired", "nwSkills", function(client)
	NETWORK.skills.AddXP(client, "intellect", 20)
end)

hook.Add("NetworkMechanicRepaired", "nwSkills", function(client)
	NETWORK.skills.AddXP(client, "intellect", 16)
end)

hook.Add("NetworkFabricatorCrafted", "nwSkills", function(client)
	NETWORK.skills.AddXP(client, "intellect", 10)
	NETWORK.skills.AddXP(client, "crafting", 8)
end)

hook.Add("NetworkWorkbenchCrafted", "nwSkills", function(client)
	NETWORK.skills.AddXP(client, "crafting", 12)
end)

hook.Add("NetworkJunkSearched", "nwSkills", function(client, entity, rolled)
	NETWORK.skills.AddXPThrottled(client, "intellect", 2 + #(rolled or {}), "junk", 20)
end)

hook.Add("NetworkQuestCompleted", "nwSkills", function(client)
	NETWORK.skills.AddXP(client, "intellect", 15)
	NETWORK.skills.AddXP(client, "charisma", 8)
end)

hook.Add("NetworkTokensTransferred", "nwSkills", function(client, target, amount)
	NETWORK.skills.AddXPThrottled(client, "charisma", 3, "tokens", 30)
end)

hook.Add("NetworkTraded", "nwSkills", function(client, action, price)
	local amount = math.Clamp(math.ceil((tonumber(price) or 0) / 10), 1, 15)

	NETWORK.skills.AddXPThrottled(client, "charisma", amount, "trade", 5)
end)

hook.Add("NetworkChatSent", "nwSkills", function(speaker, classID, text, receivers)
	if (classID != "ic" and classID != "yell" and classID != "whisper") then
		return
	end

	if (#(text or "") < 12 or #(receivers or {}) < 2) then
		return
	end

	NETWORK.skills.AddXPThrottled(speaker, "charisma", 1, "chat", 45)
end)

hook.Add("NetworkPunchLanded", "nwSkills", function(client, target)
	NETWORK.skills.AddXPThrottled(client, "strength", 3, "punch", 2)
end)

hook.Add("NetworkPlayerPushed", "nwSkills", function(client)
	NETWORK.skills.AddXPThrottled(client, "strength", 1, "push", 6)
end)

hook.Add("PlayerHurt", "nwSkills", function(client, attacker, healthLeft, amount)
	if (!IsValid(client) or !client:HasCharacter() or healthLeft <= 0) then
		return
	end

	client.nwSkillDamage = (client.nwSkillDamage or 0) + amount

	if (client.nwSkillDamage >= 15) then
		client.nwSkillDamage = 0

		NETWORK.skills.AddXPThrottled(client, "endurance", 3, "hurt", 3)
	end
end)

hook.Add("NetworkSuppressSurvived", "nwSkills", function(client, peak)
	local amount = math.Round(4 + math.Clamp(tonumber(peak) or 0, 0, 1) * 8)

	NETWORK.skills.AddXPThrottled(client, "stress", amount, "suppress", 20)
end)

timer.Create("nwSkillsMovement", 10, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter() or !client:Alive()) then
			continue
		end

		local speed = client:GetVelocity():Length2D()

		if (client:KeyDown(IN_SPEED) and speed > NETWORK.movement.walkSpeed * 1.1) then
			NETWORK.skills.AddXP(client, "agility", 2)
			NETWORK.skills.AddXP(client, "endurance", 1)
		end

		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and weapon:GetClass() == "weapon_nwhands" and
			IsValid(weapon.carried)) then
			local physics = weapon:GetCarriedPhysics()

			if (IsValid(physics) and physics:GetMass() > 60) then
				NETWORK.skills.AddXP(client, "strength", 2)
			end
		end

		if (client:IsExhausted()) then
			NETWORK.skills.AddXPThrottled(client, "endurance", 2, "exhausted", 30)
		end
	end
end)

hook.Add("EntityTakeDamage", "nwSkillsEndurance", function(target, info)
	if (!target:IsPlayer() or !target:HasCharacter()) then
		return
	end

	if (target:LastHitGroup() == HITGROUP_HEAD) then
		return
	end

	local level = NETWORK.skills.Get(target, "endurance")

	if (level <= 0) then
		return
	end

	info:ScaleDamage(math.Clamp(1 - level * NETWORK.skills.Effect("endurance", "damage"), 0.6, 1))
end)

NETWORK.command.Register("skills", {
	description = "cmdSkills",
	usage = "/skills",
	OnRun = function(command, client)
		if (!client:HasCharacter()) then
			return
		end

		for _, data in ipairs(NETWORK.skills.List()) do
			local level = NETWORK.skills.Get(client, data.id)
			local xp = NETWORK.skills.GetXP(client, data.id)
			local need = level >= NETWORK.skills.maxLevel and 0 or NETWORK.skills.Need(level)

			NETWORK.notice.Send(client, "skillLine", "info", L(data.name), level,
				NETWORK.skills.maxLevel, xp, need)
		end
	end
})

NETWORK.command.Register("setskill", {
	adminOnly = true,
	description = "cmdSetskill",
	usage = "/setskill <игрок> <навык> <уровень>",
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1])

		if (!IsValid(target) or !target:HasCharacter()) then
			return NETWORK.chat.Notice(client, "permNoTarget")
		end

		local id = string.lower(arguments[2] or "")

		if (!NETWORK.skills.GetDefinition(id)) then
			return NETWORK.chat.Notice(client, "skillUnknown")
		end

		local wanted = math.Clamp(math.Round(tonumber(arguments[3]) or 0), 0, NETWORK.skills.maxLevel)
		local progress = NETWORK.skills.GetProgress(target)

		progress.levels = progress.levels or {}
		progress.xp = progress.xp or {}
		progress.levels[id] = math.max(wanted - NETWORK.skills.GetBase(target, id), 0)
		progress.xp[id] = 0

		NETWORK.skills.QueueSave()
		NETWORK.skills.Sync(target)
		NETWORK.movement.Apply(target)

		NETWORK.chat.Notice(client, "adminDone")
	end
})

NETWORK.command.Register("addskillxp", {
	adminOnly = true,
	description = "cmdAddskillxp",
	usage = "/addskillxp <игрок> <навык> <опыт>",
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1])

		if (!IsValid(target) or !target:HasCharacter()) then
			return NETWORK.chat.Notice(client, "permNoTarget")
		end

		local id = string.lower(arguments[2] or "")

		if (!NETWORK.skills.GetDefinition(id)) then
			return NETWORK.chat.Notice(client, "skillUnknown")
		end

		NETWORK.skills.AddXP(target, id, tonumber(arguments[3]) or 0)
		NETWORK.chat.Notice(client, "adminDone")
	end
})
