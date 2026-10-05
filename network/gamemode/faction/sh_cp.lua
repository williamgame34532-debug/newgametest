local FACTION = {}

FACTION.name = "factionCP"
FACTION.description = "factionCPDescription"
FACTION.icon = "framework/icons/cp.png"
FACTION.unknownName = "unknownCP"

FACTION.color = Color(112, 186, 232)
FACTION.bDefault = false
FACTION.bWhitelist = true

FACTION.radios = {"radiocp", "radiotac"}
FACTION.bCombine = true

FACTION.toughness = {
	damage = 0.85,
	bleedSoften = 0.3,
	fracture = 0.6,
	pain = 0.6,
	wound = 0.8
}

FACTION.models = {
	"models/wn7new/metropolice/male_07.mdl",
	"models/wn7new/metropolice/male_08.mdl",
	"models/wn7new/metropolice/male_09.mdl"
}

FACTION.namePrefix = "C24.MPD.RCT"
FACTION.numberDigits = 3

function FACTION:GetDefaultName(client, character)
	local taken = {}

	for _, other in ipairs(player.GetAll()) do
		local otherCharacter = other:GetCharacter()

		if (otherCharacter and otherCharacter != character) then
			taken[otherCharacter:GetName()] = true
		end
	end

	for _ = 1, 24 do
		local name = self.namePrefix .. ":" ..
			NETWORK.factions.ZeroNumber(math.random(0, 999), self.numberDigits)

		if (!taken[name]) then
			return name
		end
	end

	for number = 0, 999 do
		local name = self.namePrefix .. ":" ..
			NETWORK.factions.ZeroNumber(number, self.numberDigits)

		if (!taken[name]) then
			return name
		end
	end

	return self.namePrefix .. ":000"
end

function FACTION:OnTransferred(client, character, fields)
	fields.model = self.models[math.random(#self.models)]
end

if (SERVER) then
	local ISSUE_ITEM = "stunstick"
	local issuePath = "network/cpissue.txt"
	local issued

	local function GetIssued()
		if (issued) then
			return issued
		end

		local contents = file.Read(issuePath, "DATA")

		issued = contents and util.JSONToTable(contents) or {}

		return issued
	end

	local function HasOne(client)
		local state = NETWORK.inventory.GetState(client)

		for _, group in ipairs({state.items, state.equipped, state.storage}) do
			for _, item in pairs(group or {}) do
				if (item.id == ISSUE_ITEM) then
					return true
				end
			end
		end

		return false
	end

	local function Issue(client, character)
		local list = GetIssued()
		local key = tostring(character:GetID())

		if (list[key] or HasOne(client)) then
			list[key] = true

			return
		end

		if (!NETWORK.inventory.Give(client, ISSUE_ITEM, 1)) then
			return
		end

		list[key] = true

		file.CreateDir("network")
		file.Write(issuePath, util.TableToJSON(list, true))
	end

	hook.Add("NetworkPlayerLoadout", "nwCPIssue", function(client, character)
		if (!IsValid(client) or !character or character:GetFaction() != "cp") then
			return
		end

		timer.Simple(0.5, function()
			if (IsValid(client) and client:GetCharacter() == character) then
				Issue(client, character)
			end
		end)
	end)
end

NETWORK.factions.Register("cp", FACTION)
