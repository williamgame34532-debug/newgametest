NETWORK.factions = NETWORK.factions or {}
NETWORK.factions.stored = NETWORK.factions.stored or {}
NETWORK.factions.order = NETWORK.factions.order or {}

function NETWORK.factions.Register(id, data)
	data.id = id
	data.name = data.name or id
	data.description = data.description or ""
	data.color = data.color or Color(88, 214, 255)
	data.models = data.models or {}
	data.icon = data.icon
	data.unknownName = data.unknownName
	data.bDefault = tobool(data.bDefault)

	if (data.bWhitelist == nil) then
		data.bWhitelist = false
	end

	data.modelLookup = {}

	for i = 1, #data.models do
		data.modelLookup[data.models[i]] = i
	end

	if (!NETWORK.factions.stored[id]) then
		NETWORK.factions.order[#NETWORK.factions.order + 1] = id
	end

	NETWORK.factions.stored[id] = data

	return data
end

function NETWORK.factions.Get(id)
	return NETWORK.factions.stored[id]
end

function NETWORK.factions.Find(text)
	text = NETWORK.util.Lower(string.Trim(text or ""))
	if (text == "cwu" or text == "гср" or text == "disinfector") then text = "worker" end

	if (text == "") then
		return
	end

	if (NETWORK.factions.stored[text]) then
		return NETWORK.factions.stored[text]
	end

	for _, id in ipairs(NETWORK.factions.order) do
		if (string.sub(id, 1, string.len(text)) == text) then
			return NETWORK.factions.stored[id]
		end
	end

	for _, id in ipairs(NETWORK.factions.order) do
		local faction = NETWORK.factions.stored[id]

		if (string.find(NETWORK.util.Lower(L(faction.name)), text, 1, true)) then
			return faction
		end
	end
end

function NETWORK.factions.GetName(id)
	local faction = NETWORK.factions.Get(id)

	return faction and L(faction.name) or tostring(id)
end

function NETWORK.factions.GetDefault()
	for i = 1, #NETWORK.factions.order do
		local faction = NETWORK.factions.stored[NETWORK.factions.order[i]]

		if (faction and faction.bDefault) then
			return faction
		end
	end

	return NETWORK.factions.stored[NETWORK.factions.order[1]]
end

function NETWORK.factions.GetModels(id)
	local faction = NETWORK.factions.Get(id) or NETWORK.factions.GetDefault()

	if (!faction) then
		return {}
	end

	return faction.models
end

function NETWORK.factions.HasModel(id, path)
	local faction = NETWORK.factions.Get(id)

	if (!faction or !isstring(path)) then
		return false
	end

	return faction.modelLookup[path] != nil
end

function NETWORK.factions.CanUse(client, id)
	local faction = NETWORK.factions.Get(id)

	if (!faction or id == "disinfector") then
		return false
	end

	local bAllowed = hook.Run("NetworkCanUseFaction", client, faction)

	if (bAllowed != nil) then
		return bAllowed
	end

	if (faction.OnCanUse) then
		return faction:OnCanUse(client) != false
	end

	if (!faction.bWhitelist) then
		return true
	end

	return client:IsAdmin() or client:IsWhitelisted(faction.id)
end

function NETWORK.factions.Transfer(client, character, faction)
	if (!faction) then
		return
	end

	local fields = {}

	if (faction.GetDefaultName) then
		local name = faction:GetDefaultName(client, character)

		if (isstring(name) and name != "") then
			fields.name = name
			fields.surname = ""
		end
	end

	if (faction.OnTransferred) then
		faction:OnTransferred(client, character, fields)
	end

	hook.Run("NetworkFactionTransferred", client, character, faction)

	return fields
end

function NETWORK.factions.ZeroNumber(number, digits)
	number = math.floor(tonumber(number) or 0)
	digits = digits or 3

	return string.rep("0", math.max(digits - #tostring(number), 0)) .. number
end

local PLAYER = FindMetaTable("Player")

NETWORK.factions.whitelist = NETWORK.factions.whitelist or {}

function PLAYER:IsWhitelisted(id)
	if (!id or id == "") then
		return false
	end

	if (SERVER) then
		return (self.nwWhitelist or {})[id] == true
	end

	if (self == LocalPlayer() and NETWORK.factions.whitelist[id]) then
		return true
	end

	for _, entry in ipairs(string.Explode(",", self:GetNWString("nwWhitelist", ""))) do
		if (entry == id) then
			return true
		end
	end

	return false
end

if (CLIENT) then
	net.Receive("nwWhitelist", function()
		local list = {}

		for index = 1, net.ReadUInt(8) do
			list[net.ReadString()] = true
		end

		NETWORK.factions.whitelist = list

		hook.Run("NetworkWhitelistUpdated", list)
	end)

	hook.Add("InitPostEntity", "nwWhitelist", function()
		net.Start("nwWhitelistRequest")
		net.SendToServer()
	end)
end

function NETWORK.factions.HasRadio(client, channel)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	local data = NETWORK.factions.Get(client:GetCharacterFaction())

	if (!data) then
		return false
	end

	for _, id in ipairs(data.radios or {}) do
		if (id == channel) then
			return true
		end
	end

	return false
end

function PLAYER:IsCombine()
	local faction = self:GetCharacterFaction()
	local data = faction and NETWORK.factions.Get(faction)

	return data != nil and data.bCombine == true
end

function PLAYER:IsCWUMember()
	local faction = self:GetCharacterFaction()
	local data = faction and NETWORK.factions.Get(faction)

	return data != nil and data.bCWU == true
end

function NETWORK.factions.GetIcon(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return
	end

	local class = NETWORK.classes and
		NETWORK.classes.Get(client:GetNWString("nwClass", ""))

	if (class and class.icon) then
		return class.icon
	end

	local faction = NETWORK.factions.Get(client:GetCharacterFaction())

	return faction and faction.icon
end

function NETWORK.factions.IsCWU(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	return client:IsCWUMember()
end

function NETWORK.factions.IsAlliance(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	return client:IsCombine()
end

NETWORK.factions.docClasses = {cmd = true}

function NETWORK.factions.CanCheckDocuments(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	if (NETWORK.factions.IsAlliance(client)) then
		return true
	end

	return NETWORK.factions.docClasses[client:GetNWString("nwClass", "")] == true
end

function NETWORK.factions.IsOverwatch(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	local data = NETWORK.factions.Get(client:GetCharacterFaction())

	return data != nil and data.bOverwatch == true
end

function NETWORK.factions.CanControlCombine(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	return NETWORK.factions.IsAlliance(client) or client:IsAdmin()
end
