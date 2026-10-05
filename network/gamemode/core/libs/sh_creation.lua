NETWORK.creation = NETWORK.creation or {}

NETWORK.creation.nameMin = 4
NETWORK.creation.nameMax = 32
NETWORK.creation.descriptionMin = 24
NETWORK.creation.descriptionMax = 400

NETWORK.creation.heightMin = 165
NETWORK.creation.heightMax = 188
NETWORK.creation.heightDefault = 176
NETWORK.creation.skillPoints = 10
NETWORK.creation.skillMax = 5

NETWORK.creation.faction = "citizen"
NETWORK.creation.hintIcon = "framework/icons/warning.png"
NETWORK.creation.hintIconSize = 18

NETWORK.creation.unitsToCm = 2.54

NETWORK.creation.modelHeights = {}

local heightCache = {}

function NETWORK.creation.GetModelHeight(path)
	local fallback = NETWORK.creation.heightDefault

	if (!isstring(path) or path == "") then
		return fallback
	end

	local override = NETWORK.creation.modelHeights[path]

	if (override) then
		return override
	end

	if (heightCache[path]) then
		return heightCache[path]
	end

	local height = fallback

	if (util.IsValidModel(path)) then
		local entity

		if (SERVER) then
			entity = ents.Create("base_anim")

			if (IsValid(entity)) then
				entity:SetModel(path)
			end
		else
			entity = ClientsideModel(path, RENDERGROUP_OPAQUE)

			if (IsValid(entity)) then
				entity:SetNoDraw(true)
			end
		end

		if (IsValid(entity)) then
			local mins, maxs = entity:GetModelBounds()

			if (mins and maxs and (maxs.z - mins.z) > 1) then
				height = (maxs.z - mins.z) * NETWORK.creation.unitsToCm
			end

			entity:Remove()
		end
	end

	heightCache[path] = height

	return height
end

function NETWORK.creation.GetModelScale(path, heightCm)
	heightCm = tonumber(heightCm) or NETWORK.creation.heightDefault

	local natural = NETWORK.creation.modelHeights[path] or
		NETWORK.creation.heightDefault

	if (natural <= 0) then
		return 1
	end

	return math.Clamp(heightCm / natural, 0.94, 1.07)
end

function NETWORK.creation.GetFrameUnits()
	return NETWORK.creation.heightMax / NETWORK.creation.unitsToCm
end

NETWORK.creation.bodygroupOptions = 3

NETWORK.creation.bodygroupCategories = 3

NETWORK.creation.bodygroupMax = 32
NETWORK.creation.bodygroupSkip = {}

local appearanceCache = {}

local function ProbeModel(path)
	if (appearanceCache[path]) then
		return appearanceCache[path]
	end

	local result = {groups = {}, skins = 1}

	if (isstring(path) and path != "" and util.IsValidModel(path)) then
		local entity

		if (SERVER) then
			entity = ents.Create("base_anim")

			if (IsValid(entity)) then
				entity:SetModel(path)
			end
		else
			entity = ClientsideModel(path, RENDERGROUP_OPAQUE)

			if (IsValid(entity)) then
				entity:SetNoDraw(true)
			end
		end

		if (IsValid(entity)) then
			result.skins = math.max(entity:SkinCount() or 1, 1)

			for _, data in pairs(entity:GetBodyGroups() or {}) do
				local count = tonumber(data.num) or 0

				if (count > 1 and !NETWORK.creation.bodygroupSkip[data.name]) then

					result.groups[#result.groups + 1] = {
						id = data.id,
						name = data.name or tostring(data.id),
						count = math.min(count, NETWORK.creation.bodygroupOptions)
					}
				end
			end

			table.sort(result.groups, function(a, b)
				return a.id < b.id
			end)

			while (#result.groups > NETWORK.creation.bodygroupCategories) do
				table.remove(result.groups)
			end

			entity:Remove()
		end
	end

	appearanceCache[path] = result

	return result
end

function NETWORK.creation.GetBodygroups(path)
	return ProbeModel(path).groups
end

function NETWORK.creation.GetBodygroup(path, id)
	for _, group in ipairs(NETWORK.creation.GetBodygroups(path)) do
		if (group.id == id) then
			return group
		end
	end
end

function NETWORK.creation.GetSkinCount(path)
	return ProbeModel(path).skins
end

function NETWORK.creation.GetGender(path)
	if (isstring(path) and string.find(string.lower(path), "female", 1, true)) then
		return "female"
	end

	return "male"
end

function NETWORK.creation.GetBodygroupLabel(name)
	local key = "bodygroup_" .. string.lower(name or "")

	if (NETWORK.lang.Exists(key)) then
		return L(key)
	end

	name = string.gsub(name or "", "[_%-]+", " ")

	return NETWORK.util.Upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end

function NETWORK.creation.ValidateBodygroups(payload)
	local model = payload.model
	local groups = payload.bodygroups

	if (groups == nil) then
		return true
	end

	if (!istable(groups)) then
		return false, "errBodygroups"
	end

	local total = 0

	for index, value in pairs(groups) do
		total = total + 1

		if (total > NETWORK.creation.bodygroupMax) then
			return false, "errBodygroups"
		end

		local id = tonumber(index)
		local group = id and NETWORK.creation.GetBodygroup(model, id)

		value = tonumber(value)

		if (!group or !value or value != math.floor(value) or value < 0 or
			value >= group.count) then
			return false, "errBodygroups"
		end
	end

	local skin = tonumber(payload.skin or 0)

	if (!skin or skin != math.floor(skin) or skin < 0 or
		skin >= NETWORK.creation.GetSkinCount(model)) then
		return false, "errBodygroups"
	end

	return true
end

NETWORK.creation.skills = {
	{id = "strength", name = "skillStrength", description = "skillStrengthDescription"},
	{id = "agility", name = "skillAgility", description = "skillAgilityDescription"},
	{id = "endurance", name = "skillEndurance", description = "skillEnduranceDescription"},
	{id = "intellect", name = "skillIntellect", description = "skillIntellectDescription"},
	{id = "medicine", name = "skillMedicine", description = "skillMedicineDescription"},
	{id = "charisma", name = "skillCharisma", description = "skillCharismaDescription"},
	{id = "crafting", name = "skillCrafting", description = "skillCraftingDescription"},

	{id = "stress", name = "skillStress", description = "skillStressDescription"}
}

NETWORK.creation.kits = {
	{
		id = "worker",
		name = "kitWorker",
		description = "kitWorkerDescription",

		items = {"Металлолом", "Паёк", "Вода"},

		give = {"scrap", "ration", "water"}
	},
	{
		id = "drifter",
		name = "kitDrifter",
		description = "kitDrifterDescription",

		items = {"Вода", "Консервы", "Бинт"},
		give = {"water", "canned_fruit", "bandage"}
	},
	{
		id = "medic",
		name = "kitMedic",
		description = "kitMedicDescription",
		items = {"Аптечка", "Шприц", "Бинты х2"},
		give = {"medkit", "syringe", "bandage", "bandage"}
	}
}

local skillLookup
local kitLookup

function NETWORK.creation.GetSkill(id)
	if (!skillLookup) then
		skillLookup = {}

		for i = 1, #NETWORK.creation.skills do
			skillLookup[NETWORK.creation.skills[i].id] = NETWORK.creation.skills[i]
		end
	end

	return skillLookup[id]
end

function NETWORK.creation.GetKit(id)
	if (!kitLookup) then
		kitLookup = {}

		for i = 1, #NETWORK.creation.kits do
			kitLookup[NETWORK.creation.kits[i].id] = NETWORK.creation.kits[i]
		end
	end

	return kitLookup[id]
end

function NETWORK.creation.GetModels(faction)
	return NETWORK.factions.GetModels(faction or NETWORK.creation.faction)
end

function NETWORK.creation.ValidateIdentity(payload)
	local config = NETWORK.creation
	local util = NETWORK.util

	local name = string.Trim((payload.name or "") .. " " .. (payload.surname or ""))
	local description = payload.description or ""

	if (name == "") then
		return false, "errNameEmpty"
	end

	if (util.Length(name) > config.nameMax * 2) then
		return false, "errNameLong"
	end

	if (!payload.bGenerated and !util.IsName(name)) then
		return false, "errNameInvalid"
	end

	if (util.Length(name) < config.nameMin) then
		return false, "errNameShort", config.nameMin
	end

	return NETWORK.creation.ValidateDescription(description)
end

function NETWORK.creation.ValidateDescription(description)
	local config = NETWORK.creation
	local length = NETWORK.util.Length(description or "")

	if (length < config.descriptionMin) then
		return false, "errDescriptionShort", config.descriptionMin,
			config.descriptionMin - length
	end

	if (length > config.descriptionMax) then
		return false, "errDescriptionLong"
	end

	return true
end

function NETWORK.creation.ValidateAppearance(payload, client)
	local config = NETWORK.creation
	local faction = payload.faction or config.faction

	if (!NETWORK.factions.Get(faction) or !NETWORK.factions.CanUse(client, faction)) then
		return false, "errFaction"
	end

	if (!NETWORK.factions.HasModel(faction, payload.model)) then
		return false, "errModel"
	end

	local height = tonumber(payload.height)

	if (!height or height != math.floor(height) or
		height < config.heightMin or height > config.heightMax) then
		return false, "errHeight"
	end

	return NETWORK.creation.ValidateBodygroups(payload)
end

function NETWORK.creation.ValidateSkills(payload)
	local config = NETWORK.creation
	local skills = payload.skills

	if (!istable(skills)) then
		return false, "errSkillValue"
	end

	local total = 0

	for id, value in pairs(skills) do
		if (!config.GetSkill(id)) then
			return false, "errSkillValue"
		end

		value = tonumber(value)

		if (!value or value != math.floor(value) or value < 0 or value > config.skillMax) then
			return false, "errSkillValue"
		end

		total = total + value
	end

	if (total != config.skillPoints) then
		return false, "errSkillPoints"
	end

	return true
end

function NETWORK.creation.ValidateGear(payload)
	if (!NETWORK.creation.GetKit(payload.kit)) then
		return false, "errKit"
	end

	return true
end

function NETWORK.creation.Validate(payload, client)
	if (!istable(payload)) then
		return false, "errUnknown"
	end

	local validators = {
		NETWORK.creation.ValidateIdentity,
		NETWORK.creation.ValidateAppearance,
		NETWORK.creation.ValidateSkills,
		NETWORK.creation.ValidateGear
	}

	for i = 1, #validators do
		local bValid, key, a, b = validators[i](payload, client)

		if (!bValid) then
			return false, key, a, b
		end
	end

	local bAllowed, key = hook.Run("NetworkCanCreateCharacter", client, payload)

	if (bAllowed == false) then
		return false, key or "errNoAccess"
	end

	return true
end

function NETWORK.creation.Sanitise(payload)
	local config = NETWORK.creation
	local util = NETWORK.util

	if (!istable(payload)) then
		return {}
	end

	local skills = {}

	for i = 1, #config.skills do
		local id = config.skills[i].id
		local value = istable(payload.skills) and tonumber(payload.skills[id]) or 0

		skills[id] = math.Clamp(math.floor(value or 0), 0, config.skillMax)
	end

	local bodygroups = {}
	local total = 0

	if (istable(payload.bodygroups)) then
		for index, value in pairs(payload.bodygroups) do
			total = total + 1

			if (total > config.bodygroupMax) then
				break
			end

			local id = tonumber(index)

			if (id) then
				bodygroups[math.floor(id)] = math.max(math.floor(tonumber(value) or 0), 0)
			end
		end
	end

	return {
		name = util.Sanitise(string.Trim((payload.name or "") .. " " ..
			(payload.surname or "")), config.nameMax * 2),

		surname = "",
		description = util.Sanitise(payload.description, config.descriptionMax, true),
		faction = isstring(payload.faction) and payload.faction or config.faction,
		model = isstring(payload.model) and payload.model or "",
		height = math.Clamp(math.floor(tonumber(payload.height) or config.heightDefault),
			config.heightMin, config.heightMax),
		skills = skills,
		kit = isstring(payload.kit) and payload.kit or "",
		bodygroups = bodygroups,
		skin = math.max(math.floor(tonumber(payload.skin) or 0), 0)
	}
end
