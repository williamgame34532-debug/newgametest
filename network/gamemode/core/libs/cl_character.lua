NETWORK.character = NETWORK.character or {}
NETWORK.character.list = NETWORK.character.list or {}
NETWORK.character.bLoaded = NETWORK.character.bLoaded or false

function NETWORK.character.GetAll()
	return NETWORK.character.list
end

function NETWORK.character.GetSlot(index)
	return NETWORK.character.list[index]
end

function NETWORK.character.GetByID(id)
	id = tonumber(id) or 0

	for _, character in ipairs(NETWORK.character.list) do
		if (character:GetID() == id) then
			return character
		end
	end
end

function NETWORK.character.Count()
	return #NETWORK.character.list
end

function NETWORK.character.HasFreeSlot()
	return NETWORK.character.Count() < NETWORK.character.maxSlots
end

function NETWORK.character.Request()
	net.Start("nwCharacterRequest")
	net.SendToServer()
end

function NETWORK.character.RequestCreate(payload)
	net.Start("nwCharacterCreate")
		NETWORK.util.WriteTable(payload)
	net.SendToServer()
end

function NETWORK.character.RequestDelete(id)
	net.Start("nwCharacterDelete")
		net.WriteUInt(tonumber(id) or 0, 32)
	net.SendToServer()
end

function NETWORK.character.RequestSelect(id)
	net.Start("nwCharacterSelect")
		net.WriteUInt(tonumber(id) or 0, 32)
	net.SendToServer()
end

net.Receive("nwCharacterList", function()
	local maxSlots = net.ReadUInt(8)
	local payload = NETWORK.util.ReadTable()
	local list = {}

	for _, data in ipairs(payload) do
		list[#list + 1] = NETWORK.character.New(data)
	end

	NETWORK.character.maxSlots = math.max(maxSlots, 1)
	NETWORK.character.list = list
	NETWORK.character.bLoaded = true

	hook.Run("NetworkCharacterListUpdated", list)
end)

net.Receive("nwCharacterResult", function()
	local action = net.ReadString()
	local bSuccess = net.ReadBool()
	local key = net.ReadString()
	local arguments = NETWORK.util.ReadTable()
	local text = key != "" and L(key, unpack(arguments)) or ""

	hook.Run("NetworkCharacterResult", action, bSuccess, text, key)

	if (!bSuccess) then
		NETWORK.sound.Play("hover3", 92, 0.5)
	end
end)

concommand.Add("network_characters_refresh", function()
	NETWORK.character.Request()
end)

NETWORK.character.descriptions = NETWORK.character.descriptions or {}

net.Receive("nwCharacterDesc", function()
	local index = net.ReadUInt(16)
	local text = net.ReadString()

	NETWORK.character.descriptions[index] = text
end)

hook.Add("EntityRemoved", "nwCharacterDesc", function(entity)
	if (NETWORK.character.descriptions and IsValid(entity) and entity:IsPlayer()) then
		NETWORK.character.descriptions[entity:EntIndex()] = nil
	end
end)

local descRequested = {}

function NETWORK.character.RequestDescription(client)
	if (!IsValid(client)) then
		return
	end

	local index = client:EntIndex()

	if ((descRequested[index] or 0) > RealTime()) then
		return
	end

	descRequested[index] = RealTime() + 5

	net.Start("nwCharacterDescReq")
		net.WriteUInt(index, 16)
	net.SendToServer()
end

net.Receive("nwCharacterRefresh", function()
	NETWORK.character.Request()

	hook.Run("NetworkCharacterRefreshed")

	local menu = NETWORK.gui.tabMenu

	if (IsValid(menu)) then
		menu:RefreshTab()
	end
end)

local lastCharacter = 0

hook.Add("Think", "nwCharacterLoadedSignal", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local id = client:GetCharacterID()

	if (id == lastCharacter) then
		return
	end

	lastCharacter = id

	if (id <= 0) then
		hook.Run("NetworkCharacterUnloaded", client)

		return
	end

	hook.Run("NetworkCharacterLoaded", client, client:GetCharacter())
end)
