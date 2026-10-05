NETWORK.medical = NETWORK.medical or {}

local M = NETWORK.medical

M.bloodMax = 5000
M.unconsciousAt = 3000
M.wakeAt = 3200
M.deathAt = 1500
M.bloodRegen = 2
M.transfuseRate = 25
M.transfuseAmount = 1500

M.oxygenMax = 100
M.oxygenDrain = 0.45
M.oxygenRegen = 2.5
M.hypoxiaDeath = 60

M.criticalTime = 120
M.criticalMin = 45
M.giveUpAfter = 30
M.overkill = 120

M.range = 110
M.moveTolerance = 48

M.bleedKinds = {
	minor = {rate = 3, name = "medBleedMinor", order = 1},
	major = {rate = 9, name = "medBleedMajor", order = 2},
	artery = {rate = 22, name = "medBleedArtery", order = 3}
}

M.limbs = {
	armLeft = true,
	armRight = true,
	legLeft = true,
	legRight = true
}

M.legs = {legLeft = true, legRight = true}
M.arms = {armLeft = true, armRight = true}

M.bloodClasses = {
	{above = 4250, name = "medBloodClass1", color = Color(120, 220, 140)},
	{above = 3500, name = "medBloodClass2", color = Color(226, 208, 110)},
	{above = 3000, name = "medBloodClass3", color = Color(240, 150, 74)},
	{above = 0, name = "medBloodClass4", color = Color(232, 84, 76)}
}

M.treatments = {
	tourniquet = {time = 3, target = "limb", order = 1, glyph = "minus"},
	bandage = {time = 4, target = "bleed", order = 2, glyph = "plus"},
	chestseal = {time = 4, target = "chest", order = 3, glyph = "shield"},
	splint = {time = 6, target = "limb", order = 4, glyph = "split"},
	medkit = {time = 10, target = "body", order = 5, glyph = "plus"},
	syringe = {time = 2, target = "body", order = 6, glyph = "chevron"},
	bloodbag = {time = 8, target = "body", order = 7, glyph = "down"},
	morphine = {time = 3, target = "body", order = 8, glyph = "chevron"},
	painkillers = {time = 2, target = "body", order = 9, glyph = "dot"},
	heal = {time = 3, target = "body", order = 10, glyph = "plus"},
	stim = {time = 2, target = "body", order = 11, glyph = "chevron"}
}

-- Эффекты, которые можно выбрать созданному в редакторе медицинскому предмету.
M.effects = {"heal", "stim", "bandage", "tourniquet", "chestseal", "splint", "medkit",
	"syringe", "bloodbag", "morphine", "painkillers"}

M.stimSpeed = 1.15

M.customTreatments = M.customTreatments or {}

-- Встроенные предметы лечат по своему ID, созданные — по выбранному эффекту (medEffect).
function M.GetTreatment(id)
	if (!isstring(id)) then
		return
	end

	local treatment = M.treatments[id]

	if (treatment) then
		return treatment
	end

	local base = NETWORK.item and NETWORK.item.Get and NETWORK.item.Get(id)
	local effect = base and (base.medEffect or (base.customBase == "medical" and "heal"))
	local template = isstring(effect) and M.treatments[effect]

	if (!template) then
		return
	end

	local cached = M.customTreatments[id]

	if (cached and cached.base == base and cached.effect == effect) then
		return cached.treatment
	end

	local time = tonumber(base.medTime)

	treatment = setmetatable({
		effect = effect,
		strength = tonumber(base.healWound) or 25,
		time = (time and time > 0) and time or template.time,
		order = template.order + 0.5
	}, {__index = template})

	M.customTreatments[id] = {base = base, effect = effect, treatment = treatment}

	return treatment
end

function M.IsTreatment(id)
	return M.GetTreatment(id) != nil
end

hook.Add("NetworkMovementSpeed", "nwStim", function(client, walk, run)
	if (client:GetNWFloat("nwStimUntil", 0) <= CurTime()) then
		return
	end

	return walk, run * M.stimSpeed
end)

function M.IsLimb(part)
	return M.limbs[part] == true
end

local PLAYER = FindMetaTable("Player")

function PLAYER:GetBlood()
	return self:GetNWInt("nwBlood", M.bloodMax)
end

function PLAYER:GetBloodFraction()
	return math.Clamp(self:GetBlood() / M.bloodMax, 0, 1)
end

function PLAYER:GetOxygen()
	return self:GetNWFloat("nwOxygen", M.oxygenMax)
end

function PLAYER:HasPneumothorax()
	return self:GetNWBool("nwPneumo", false)
end

function PLAYER:GetFracture(part)
	return self:GetNWInt("nwFracture_" .. part, 0)
end

function PLAYER:HasFracture(part)
	return self:GetFracture(part) == 1
end

function PLAYER:IsCritical()
	return self:GetNWBool("nwCritical", false)
end

function PLAYER:GetCriticalLeft()
	return self:GetNWFloat("nwCritLeft", 0)
end

function PLAYER:IsStable()
	return self:GetNWBool("nwStable", false)
end

function PLAYER:IsUnconscious()
	return self:GetNWBool("nwUnconscious", false)
end

function PLAYER:IsDowned()
	return IsValid(self:GetNWEntity("nwRagdollEntity", NULL))
end

function PLAYER:GetBleedMap()
	local text = self:GetNWString("nwBleedMap", "")

	if (self.nwBleedCacheText == text and self.nwBleedCache) then
		return self.nwBleedCache
	end

	local map = {}

	for chunk in string.gmatch(text, "[^;]+") do
		local part, kind, flag = string.match(chunk, "^(%w+):(%w+):?(%w*)$")

		if (part and M.bleedKinds[kind]) then
			map[part] = {kind = kind, tq = flag == "t"}
		end
	end

	self.nwBleedCacheText = text
	self.nwBleedCache = map

	return map
end

function M.GetBloodClass(blood)
	for index, data in ipairs(M.bloodClasses) do
		if (blood > data.above) then
			return index, data
		end
	end

	return #M.bloodClasses, M.bloodClasses[#M.bloodClasses]
end

function M.HasLegFracture(client)
	return client:HasFracture("legLeft") or client:HasFracture("legRight")
end

function M.HasArmFracture(client)
	return client:HasFracture("armLeft") or client:HasFracture("armRight")
end

function M.PartNeedsCare(client, part)
	if (NETWORK.wound.Get(client, part) > 0) then
		return true
	end

	local bleed = client:GetBleedMap()[part]

	if (bleed and !bleed.tq) then
		return true
	end

	if (M.IsLimb(part) and client:HasFracture(part)) then
		return true
	end

	return part == "chest" and client:HasPneumothorax()
end

function M.GetPulse(target)
	if (!IsValid(target) or !target:IsPlayer() or !target:Alive()) then
		return 0, "none"
	end

	local blood = target:GetBlood()
	local loss = 1 - blood / M.bloodMax
	local bpm = 72

	if (loss > 0.15) then
		bpm = bpm + (loss - 0.15) * 220
	end

	if (NETWORK.wound and NETWORK.wound.GetPain and
		NETWORK.wound.GetPain(target) > 0) then
		bpm = bpm + 12
	end

	if (NETWORK.wound and NETWORK.wound.IsNumb and NETWORK.wound.IsNumb(target)) then
		bpm = bpm - 8
	end

	if (target.IsCombat and target:IsCombat()) then
		bpm = bpm + 18
	end

	if (target:HasPneumothorax()) then
		bpm = bpm + 14
	end

	if (target:IsDowned() and !target:IsUnconscious()) then
		bpm = bpm + 8
	end

	if (target:IsCritical()) then
		bpm = math.max(bpm, 132) + (target:IsStable() and -12 or 10)
	end

	bpm = math.Round(math.Clamp(bpm + math.random(-4, 4), 38, 190))

	local quality = "normal"

	if (target:IsCritical() or target:IsUnconscious() or loss > 0.4) then
		quality = "thready"
	elseif (loss > 0.3 or bpm > 125) then
		quality = "weak"
	elseif (bpm > 100) then
		quality = "fast"
	end

	return bpm, quality
end

NETWORK.config.RegisterCategory("medical", "cfgCatMedical", 32)

NETWORK.config.Register("medCritical", {
	name = "cfgMedCritical",
	description = "cfgMedCriticalDesc",
	category = "medical",
	type = "bool",
	default = true
})

NETWORK.config.Register("medCriticalTime", {
	name = "cfgMedCriticalTime",
	description = "cfgMedCriticalTimeDesc",
	category = "medical",
	default = 120,
	min = 30,
	max = 600,
	decimals = 0,
	OnChanged = function(value)
		M.criticalTime = value
	end
})

NETWORK.config.Register("medBleedScale", {
	name = "cfgMedBleedScale",
	description = "cfgMedBleedScaleDesc",
	category = "medical",
	default = 1,
	min = 0.25,
	max = 3,
	decimals = 2
})

NETWORK.config.Register("allianceFrisk", {
	name = "cfgAllianceFrisk",
	description = "cfgAllianceFriskDesc",
	category = "characters",
	type = "bool",
	default = false
})

M.silentAllowed = {
	ooc = true,
	looc = true
}

function M.IsSilenced(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	if (!client:Alive()) then
		return true
	end

	return client:IsDowned() or client:IsUnconscious() or client:IsCritical()
end
