NETWORK.recognition = NETWORK.recognition or {}

NETWORK.recognition.modes = {
	{id = "target", name = "recogTarget", range = 220},
	{id = "whisper", name = "recogWhisper", range = 110},
	{id = "normal", name = "recogNormal", range = 280},
	{id = "yell", name = "recogYell", range = 640},

	{id = "radio", name = "recogRadio", range = 0, hint = "recogRadioHint"}
}

NETWORK.recognition.range = 280

function NETWORK.recognition.GetMode(id)
	for _, data in ipairs(NETWORK.recognition.modes) do
		if (data.id == id) then
			return data
		end
	end

	return NETWORK.recognition.modes[3]
end

local PLAYER = FindMetaTable("Player")

function PLAYER:IsRecognised(target)
	if (!IsValid(target) or target == self) then
		return true
	end

	local id = target:GetCharacterID()

	if (id <= 0) then
		return true
	end

	local bSelfAlliance = NETWORK.factions.IsAlliance(self)
	local bTargetAlliance = NETWORK.factions.IsAlliance(target)

	if (bSelfAlliance and bTargetAlliance) then
		return true
	end

	if (bSelfAlliance and NETWORK.config and NETWORK.config.Get and
		NETWORK.config.Get("allianceKnowsAll") == true) then
		return true
	end

	if (bTargetAlliance) then
		return false
	end

	if (CLIENT) then
		return NETWORK.recognition.known[id] == true
	end

	return (self.nwRecognised or {})[id] == true
end

function PLAYER:IsUnknownFemale()
	if (NETWORK.voice and NETWORK.voice.IsFemale) then
		return NETWORK.voice.IsFemale(self)
	end

	return string.find(string.lower(self:GetModel() or ""), "female") != nil
end

function PLAYER:GetUnknownName()
	local factionID = self:GetCharacterFaction()
	local faction = factionID and NETWORK.factions.Get(factionID)
	local bFemale = self:IsUnknownFemale()

	if (faction and faction.unknownName) then
		if (bFemale and NETWORK.lang.Exists(faction.unknownName .. "Female")) then
			return L(faction.unknownName .. "Female")
		end

		return L(faction.unknownName)
	end

	return L(bFemale and "recogUnknownFemale" or "recogUnknown")
end

NETWORK.recognition.strangerColor = Color(150, 158, 166)
NETWORK.recognition.strangerIcon = "framework/icons/person.png"

function PLAYER:KnowsRoleOf(target)
	return self:IsRecognised(target)
end

function PLAYER:GetRecognisedName(observer)
	observer = observer or (CLIENT and LocalPlayer() or nil)

	if (!IsValid(observer) or observer:IsRecognised(self)) then
		return self:GetCharacterName()
	end

	return self:GetUnknownName()
end

timer.Simple(0, function()
	if (NETWORK.config and NETWORK.config.Register) then
		NETWORK.config.Register("allianceKnowsAll", {
			name = "cfgAllianceKnowsAll",
			description = "cfgAllianceKnowsAllDesc",
			category = "characters",
			type = "bool",
			default = false
		})
	end
end)
