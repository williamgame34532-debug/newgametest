-- Characters, shared part: limits, the skill list, validation (the same rules on both sides),
-- the citizen models per gender, and the player's name: with a character loaded, Nick / Name /
-- GetName return the character's name everywhere (chat, scoreboards, addons).

NW.char = NW.char or {}

local C = NW.char

C.maxCharacters = 2
C.name = {min = 3, max = 40}
C.description = {min = 16, max = 1000}
C.height = {min = 0.94, max = 1.06, baseCm = 178}

-- skill points: a budget to spread, each skill 0..max
C.skillBudget = 10
C.skillMax = 5
C.skills = {
	{id = "strength", name = "Сила", icon = "strength", text = "Переноска тяжестей, ближний бой"},
	{id = "endurance", name = "Выносливость", icon = "endurance", text = "Бег, усталость, холод"},
	{id = "medicine", name = "Медицина", icon = "medicine", text = "Перевязки, лечение, диагнозы"},
	{id = "engineering", name = "Инженерия", icon = "engineering", text = "Ремонт, техника, электрика"},
	{id = "stealth", name = "Скрытность", icon = "stealth", text = "Тихий шаг, слежка, укрытия"},
	{id = "speech", name = "Убеждение", icon = "speech", text = "Разговор, торговля, допрос"}
}

-- factions: one file each in framework/gamefactions/<id>.lua (FACTION.name, description, color,
-- logo = materials/network2/factions/<logo>.png, models = {male = {...}, female = {...}},
-- default = true for the faction new characters get)
C.factions = C.factions or {}

local FACTIONS = (GM or GAMEMODE).FolderName .. "/gamemode/framework/gamefactions/"

for _, name in ipairs(file.Find(FACTIONS .. "*.lua", "LUA")) do
	if (SERVER) then
		AddCSLuaFile(FACTIONS .. name)
	end

	FACTION = {}
	include(FACTIONS .. name)
	FACTION.id = string.StripExtension(name)
	C.factions[FACTION.id] = FACTION
	FACTION = nil
end

-- the faction new characters get
function C.DefaultFaction()
	for id, faction in pairs(C.factions) do
		if (faction.default) then
			return id
		end
	end

	return "citizen"
end

-- logos shipped for the factions to come
C.logos = {"citizen_logo", "civilprotection_logo", "combineclaw_logo", "combineclaw_full_logo",
	"combineclaw_upright_logo", "engineercore_logo", "headcrab_logo"}

-- the models of a faction by gender (its file in framework/gamefactions, or the citizen models of
-- sh_models.lua when it lists none)
function C.GetModels(gender, faction)
	local out = {}
	local class = gender == "female" and "citizen_female" or "citizen_male"
	local data = C.factions[faction or C.DefaultFaction()]
	local list = data and data.models and data.models[gender == "female" and "female" or "male"]

	-- the faction's own list (framework/gamefactions)
	if (list) then
		local titles = {}

		for _, entry in ipairs(NW.models.list) do
			titles[entry[1]] = entry.title or entry[4]
		end

		for _, path in ipairs(list) do
			out[#out + 1] = {path = path, title = titles[path] or string.StripExtension(string.GetFileFromFilename(path))}
		end

		return out
	end

	for _, entry in ipairs(NW.models.list) do
		if (entry[2] == class) then
			out[#out + 1] = {path = entry[1], title = entry.title}
		end
	end

	return out
end

function C.IsModelAllowed(gender, model)
	for _, entry in ipairs(C.GetModels(gender)) do
		if (entry.path == model) then
			return true
		end
	end

	return false
end

local function Length(text)
	return utf8.len(text or "") or #(text or "")
end

-- name: letters (latin / cyrillic), spaces, hyphen, apostrophe; two words at least
function C.CheckName(name)
	name = string.Trim(name or "")

	local length = Length(name)

	if (length < C.name.min) then
		return false, "Имя слишком короткое"
	end

	if (length > C.name.max) then
		return false, "Имя слишком длинное"
	end

	for _, code in utf8.codes(name) do
		local ok = (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or      -- A-Z a-z
			(code >= 0x410 and code <= 0x44F) or code == 0x401 or code == 0x451 or      -- А-я Ёё
			code == 32 or code == 45 or code == 39

		if (!ok) then
			return false, "Только буквы, пробел, дефис и апостроф"
		end
	end

	if (!string.find(name, "%S+%s+%S+")) then
		return false, "Введите имя и фамилию"
	end

	return true, name
end

function C.CheckDescription(text)
	text = string.Trim(text or "")

	local length = Length(text)

	if (length < C.description.min) then
		return false, "Опишите персонажа подробнее (от " .. C.description.min .. " символов)"
	end

	if (length > C.description.max) then
		return false, "Описание слишком длинное"
	end

	return true, text
end

function C.CheckSkills(skills)
	local total = 0

	for _, skill in ipairs(C.skills) do
		local value = math.floor(tonumber(skills[skill.id]) or 0)

		if (value < 0 or value > C.skillMax) then
			return false, "Неверное значение навыка"
		end

		total = total + value
	end

	if (total > C.skillBudget) then
		return false, "Распределено больше очков, чем есть"
	end

	return true
end

-- the character's name is the player's name
local meta = FindMetaTable("Player")

C.steamName = C.steamName or meta.Nick

local function CharacterName(self)
	local name = self:GetNW2String("nwCharName", "")

	if (name != "") then
		return name
	end

	return C.steamName(self)
end

meta.Nick = CharacterName
meta.Name = CharacterName
meta.GetName = CharacterName

function meta:SteamName()
	return C.steamName(self)
end

function meta:GetCharacterID()
	return self:GetNW2Int("nwCharID", 0)
end

function meta:GetFaction()
	return self:GetNW2String("nwCharFaction", "")
end

function meta:GetCharacterDescription()
	return self:GetNW2String("nwCharDesc", "")
end

-- recognition: does `client` know `target`? For now everyone knows only themselves; the
-- recognition system plugs in through the NWRecognizes hook (return true / false).
function C.Knows(client, target)
	if (client == target) then
		return true
	end

	local result = hook.Run("NWRecognizes", client, target)

	return result == true
end
