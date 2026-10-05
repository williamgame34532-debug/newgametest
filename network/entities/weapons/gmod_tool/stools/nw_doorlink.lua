TOOL.Category = "Network"
TOOL.Name = "Связать двери"
TOOL.Command = nil
TOOL.ConfigName = ""

if (CLIENT) then
	language.Add("tool.nw_doorlink.name", "Связать двери")
	language.Add("tool.nw_doorlink.desc", "Вход и выход бизнеса — одна дверь.")
	language.Add("tool.nw_doorlink.0", "ЛКМ: первая дверь (главная), затем вторая. ПКМ: снять связь. R: сброс.")
end

local function IsDoor(entity)
	return NETWORK and NETWORK.door and NETWORK.door.IsDoor(entity)
end

function TOOL:LeftClick(trace)
	local entity = trace.Entity

	if (!IsDoor(entity)) then
		return false
	end

	if (CLIENT) then
		return true
	end

	local client = self:GetOwner()

	if (!client:IsAdmin()) then
		return false
	end

	local first = self:GetWeapon().nwLinkFirst

	if (!IsValid(first) or first == entity) then
		self:GetWeapon().nwLinkFirst = entity

		NETWORK.notice.Send(client, "doorLinkFirst", "info")

		return true
	end

	local masterKey = NETWORK.door.GetKey(first)
	local slaveKey = NETWORK.door.GetKey(entity)

	if (!masterKey or !slaveKey) then
		return false
	end

	NETWORK.door.list[masterKey] = NETWORK.door.list[masterKey] or {type = "residential"}

	local slave = NETWORK.door.list[slaveKey] or {}

	slave.linkKey = masterKey
	slave.owner = nil
	slave.owners = nil
	NETWORK.door.list[slaveKey] = slave

	NETWORK.door.Save()

	if (NETWORK.door.ApplyAll) then
		NETWORK.door.ApplyAll()
	end

	if (NETWORK.door.Sync) then
		NETWORK.door.Sync()
	end

	self:GetWeapon().nwLinkFirst = nil

	NETWORK.notice.Send(client, "doorLinkDone", "good")

	return true
end

function TOOL:RightClick(trace)
	local entity = trace.Entity

	if (!IsDoor(entity)) then
		return false
	end

	if (CLIENT) then
		return true
	end

	local client = self:GetOwner()

	if (!client:IsAdmin()) then
		return false
	end

	local key = NETWORK.door.GetKey(entity)
	local data = key and NETWORK.door.list[key]

	if (data and data.linkKey) then
		data.linkKey = nil

		NETWORK.door.Save()

		if (NETWORK.door.Sync) then
			NETWORK.door.Sync()
		end

		NETWORK.notice.Send(client, "doorLinkCleared", "good")
	end

	return true
end

function TOOL:Reload(trace)
	if (SERVER) then
		self:GetWeapon().nwLinkFirst = nil
	end

	return true
end

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {Description = "ЛКМ по первой двери, потом по второй — они станут одной: общий владелец и замок. ПКМ снимает связь."})
end
