NETWORK.character = NETWORK.character or {}
NETWORK.character.maxSlots = 2

NETWORK.meta.character = NETWORK.meta.character or {}

local CHARACTER = NETWORK.meta.character

CHARACTER.__index = CHARACTER
CHARACTER.id = 0
CHARACTER.name = ""
CHARACTER.surname = ""
CHARACTER.description = ""
CHARACTER.model = ""
CHARACTER.faction = "citizen"
CHARACTER.kit = ""
CHARACTER.height = 175
CHARACTER.steamID = ""

function CHARACTER:__tostring()
	return "character[" .. self.id .. "][" .. self:GetName() .. "]"
end

function CHARACTER:GetID()
	return self.id
end

function CHARACTER:GetName()
	return string.Trim((self.name or "") .. " " .. (self.surname or ""))
end

function CHARACTER:GetFirstName()
	return self.name or ""
end

function CHARACTER:GetSurname()
	return self.surname or ""
end

function CHARACTER:GetDescription()
	return self.description or ""
end

function CHARACTER:GetModel()
	return self.model or ""
end

function CHARACTER:GetHeight()

	return math.Clamp(tonumber(self.height) or NETWORK.creation.heightDefault,
		NETWORK.creation.heightMin, NETWORK.creation.heightMax)
end

function CHARACTER:GetScale()
	return NETWORK.creation.GetModelScale(self:GetModel(), self:GetHeight())
end

function CHARACTER:GetFaction()
	return self.faction
end

function CHARACTER:GetFactionTable()
	return NETWORK.factions.Get(self.faction)
end

function CHARACTER:GetFactionName()
	return NETWORK.factions.GetName(self.faction)
end

function CHARACTER:GetVitals()
	return self.vitals or {}
end

function CHARACTER:GetHealth()
	return math.Clamp(tonumber(self:GetVitals().health) or 100, 0, 100)
end

function CHARACTER:GetHunger()
	return math.Clamp(tonumber(self:GetVitals().hunger) or 100, 0, 100)
end

function CHARACTER:GetThirst()
	return math.Clamp(tonumber(self:GetVitals().thirst) or 100, 0, 100)
end

function CHARACTER:GetKit()
	return self.kit
end

function CHARACTER:GetKitTable()
	return NETWORK.creation.GetKit(self.kit)
end

function CHARACTER:GetSkills()
	return self.skills or {}
end

function CHARACTER:GetSkill(id)
	return (self.skills or {})[id] or 0
end

function CHARACTER:GetBodygroups()
	local groups = {}

	for index, value in pairs(self.bodygroups or {}) do
		groups[tonumber(index) or 0] = math.Round(tonumber(value) or 0)
	end

	return groups
end

function CHARACTER:GetSkin()
	return math.Round(tonumber(self.skin) or 0)
end

function CHARACTER:IsModelForced()
	return tonumber(self.modelforced) == 1
end

function CHARACTER:GetSteamID()
	return self.steamID or ""
end

function CHARACTER:GetPlayer()
	for _, client in ipairs(player.GetAll()) do
		if (client:GetCharacterID() == self.id) then
			return client
		end
	end
end

function CHARACTER:GetNetworkData()
	return {
		id = self.id,
		name = self.name,
		surname = self.surname,
		description = self.description,
		model = self.model,
		faction = self.faction,
		kit = self.kit,
		height = self.height,
		skills = self.skills,
		bodygroups = self.bodygroups,
		skin = self.skin,
		created = self.created
	}
end

function NETWORK.character.New(data)
	local character = setmetatable({}, CHARACTER)

	for key, value in pairs(data or {}) do
		character[key] = value
	end

	character.id = tonumber(character.id) or 0
	character.height = tonumber(character.height) or NETWORK.creation.heightDefault
	character.skills = character.skills or {}
	character.bodygroups = character.bodygroups or {}
	character.skin = tonumber(character.skin) or 0

	return character
end

function NETWORK.character.IsCharacter(value)
	return istable(value) and getmetatable(value) == CHARACTER
end

local PLAYER = FindMetaTable("Player")

PLAYER.SteamName = PLAYER.SteamName or PLAYER.Name

function PLAYER:GetCharacterID()
	return self:GetNWInt("nwCharacterID", 0)
end

function PLAYER:HasCharacter()
	return self:GetCharacterID() > 0
end

function PLAYER:GetCharacter()
	if (SERVER) then
		return self.nwCharacter
	end

	if (self == LocalPlayer()) then
		return NETWORK.character.GetByID(self:GetCharacterID())
	end
end

function PLAYER:GetCharacterName()

	local callsign = self:GetNWString("nwCallsign", "")

	if (callsign != "") then
		return callsign
	end

	local networked = self:GetNWString("nwCharacterName", "")

	if (networked != "") then
		return networked
	end

	local character = self:GetCharacter()

	if (character) then
		return character:GetName()
	end

	return self:SteamName()
end

PLAYER.Nick = PLAYER.GetCharacterName
PLAYER.Name = PLAYER.GetCharacterName
PLAYER.GetName = PLAYER.GetCharacterName

function PLAYER:GetCharacterDescription()
	local character = self:GetCharacter()

	if (character) then
		return character:GetDescription()
	end

	if (CLIENT and NETWORK.character.descriptions) then
		local full = NETWORK.character.descriptions[self:EntIndex()]

		if (isstring(full)) then
			return full
		end

		if (NETWORK.character.RequestDescription) then
			NETWORK.character.RequestDescription(self)
		end
	end

	return self:GetNWString("nwCharacterDescription", "")
end

function PLAYER:GetCharacterFaction()
	local character = self:GetCharacter()

	if (character) then
		return character:GetFaction()
	end

	local faction = self:GetNWString("nwCharacterFaction", "")

	return faction != "" and faction or nil
end

function PLAYER:GetSkill(id)
	local character = self:GetCharacter()

	return character and character:GetSkill(id) or 0
end

local PLAYER_META = FindMetaTable("Player")

function PLAYER_META:GetCharacterModel()
	local model = self:GetNWString("nwCharacterModel", "")

	if (model != "") then
		return model
	end

	return self:GetModel()
end
