NETWORK.jail.data = NETWORK.jail.data or {list = {}, points = 0}

function NETWORK.jail.Send(action, index, term, reason)
	net.Start("nwJailAction")
		net.WriteString(action)
		net.WriteUInt(index or 0, 16)
		net.WriteUInt(math.Clamp(term or 0, 0, 65535), 16)
		net.WriteString(reason or "")
	net.SendToServer()
end

function NETWORK.jail.Find(index)
	for _, entry in ipairs(NETWORK.jail.data.list) do
		if (entry.index == index) then
			return entry
		end
	end
end

net.Receive("nwJailOpen", function()
	local entity = net.ReadEntity()
	local bootTime = net.ReadFloat()

	NETWORK.gui.OpenJail(entity, bootTime)
end)

net.Receive("nwJailClose", function()
	NETWORK.gui.CloseJail()
end)

net.Receive("nwJailData", function()
	local data = NETWORK.util.ReadTable()

	NETWORK.jail.data = {
		list = istable(data.list) and data.list or {},
		points = tonumber(data.points) or 0
	}

	if (IsValid(NETWORK.gui.jail)) then
		NETWORK.gui.jail:OnData()
	end
end)
