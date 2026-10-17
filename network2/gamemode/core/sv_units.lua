-- Units of the Alliance, server (sh_units.lua): the unit name on joining, the civil name back on
-- leaving, the callsign, the dispatcher's voice.

util.AddNetworkString("nwDispatchVoice")
util.AddNetworkString("nwNpcCallsigns")

local UN = NW.units
local C = NW.char

-- the dispatcher says these sounds to these players, one after another
function UN.Voice(targets, list)
	if (!istable(list) or #list == 0) then
		return
	end

	net.Start("nwDispatchVoice")
		net.WriteUInt(math.min(#list, 15), 4)

		for i = 1, math.min(#list, 15) do
			net.WriteString(list[i])
		end
	net.Send(targets)
end

-- the character's name, everywhere and in the database
function C.SetName(client, name)
	local character = client.nwCharacter

	if (!character or !isstring(name) or name == "") then
		return
	end

	character.name = name
	client:SetNW2String("nwCharName", name)

	if (!character.test and client:GetCharacterID() != 0) then
		sql.Query("UPDATE nw_characters SET name = " .. sql.SQLStr(name) .. " WHERE id = " .. client:GetCharacterID())
	end
end

local function Prefix(faction)
	local data = C.factions[faction or ""]

	return data and data.unitPrefix
end

-- a number nobody in the game has (000..999)
local function FreeNumber()
	local used = {}

	for _, other in ipairs(player.GetAll()) do
		local data = other.nwCharacter and other.nwCharacter.data

		if (data and data.unitNum) then
			used[data.unitNum] = true
		end
	end

	for _ = 1, 50 do
		local number = math.random(0, 999)

		if (!used[number]) then
			return number
		end
	end

	return math.random(0, 999)
end

-- "C24.MPD.RCT:443 (Виктор-4)"
function UN.Compose(client)
	local character = client.nwCharacter
	local data = character and character.data or {}
	local prefix = Prefix(character and character.faction)

	if (!prefix or !data.unitNum) then
		return
	end

	local name = prefix .. string.format("%03d", data.unitNum)
	local side = UN.Side(character.faction)
	local callsign = data.callsignSide == side and UN.CallsignText(side, data.callsign)

	return callsign and (name .. " (" .. callsign .. ")") or name
end

-- joining / leaving a faction of units
local function Apply(client, faction)
	local character = client.nwCharacter

	if (!character) then
		return
	end

	character.data = character.data or {}

	local data = character.data

	if (Prefix(faction)) then
		if (!data.civName) then
			data.civName = character.name
		end

		data.unitNum = data.unitNum or FreeNumber()

		-- another side: the old callsign does not fit
		if (data.callsignSide and data.callsignSide != UN.Side(faction)) then
			data.callsign, data.callsignSide = nil, nil
		end

		C.SetName(client, UN.Compose(client))
	elseif (data.civName) then
		C.SetName(client, data.civName)
		data.civName = nil
		data.callsign, data.callsignSide = nil, nil
	end

	C.SaveData(client)
end

hook.Add("NWFactionChanged", "nwUnits", Apply)

-- a unit made before this system (or by hand in the database) gets its unit name on loading
hook.Add("NWCharacterLoaded", "nwUnits", function(client, character)
	if (Prefix(character.faction) and !(character.data and character.data.unitNum)) then
		Apply(client, character.faction)
	end
end)

-- the callsigns taken now on a side ({["victor:4"] = true}), not counting `except`
function UN.Taken(side, except)
	local out = {}

	for _, other in ipairs(player.GetAll()) do
		local data = other != except and other.nwCharacter and other.nwCharacter.data

		if (data and data.callsignSide == side and istable(data.callsign)) then
			out[data.callsign.id .. ":" .. data.callsign.num] = true
		end
	end

	return out
end

function UN.SetCallsign(client, id, number)
	local character = client.nwCharacter
	local side = character and UN.Side(character.faction)
	number = math.floor(tonumber(number) or 0)

	if (!character or !Prefix(character.faction)) then
		return false, "Позывные выдаются только юнитам Альянса"
	end

	if (!UN.byID[side][id] or number < 1 or number > 9) then
		return false, "Нет такого позывного"
	end

	if (UN.Taken(side, client)[id .. ":" .. number]) then
		return false, "Этот позывной уже занят"
	end

	character.data.callsign = {id = id, num = number}
	character.data.callsignSide = side
	C.SetName(client, UN.Compose(client))
	C.SaveData(client)

	-- the dispatcher confirms it on the radio
	local voice = {side == "ota" and "npc/combine_soldier/vo/on1.wav" or "npc/metropolice/vo/on1.wav"}

	for _, path in ipairs(UN.VoiceFor(side, character.data.callsign)) do
		voice[#voice + 1] = path
	end

	voice[#voice + 1] = side == "ota" and "npc/combine_soldier/vo/off1.wav" or "npc/metropolice/vo/off1.wav"
	UN.Voice(client, voice)

	return true
end

-- the NPC with the answer "Выдать позывной" (sv_npc.lua actions)
function UN.SendChoice(client, entity)
	local character = client.nwCharacter
	local side = character and UN.Side(character.faction)

	net.Start("nwNpcCallsigns")
		net.WriteEntity(entity)
		net.WriteString(util.TableToJSON({
			side = side,
			unit = Prefix(character and character.faction) != nil,
			taken = UN.Taken(side, client),
			current = character and character.data and character.data.callsignSide == side and
				character.data.callsign or nil
		}))
	net.Send(client)
end
