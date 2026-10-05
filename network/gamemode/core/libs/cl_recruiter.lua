net.Receive("nwRecruiterSync", function()
	NETWORK.recruiter.configs = NETWORK.util.ReadTable() or {}
end)

net.Receive("nwRecruiterOpen", function()
	local entity = net.ReadEntity()

	if (IsValid(entity)) then
		NETWORK.gui.OpenRecruiter(entity)
	end
end)

net.Receive("nwRecruiterEditor", function()
	local id = net.ReadString()
	local position = net.ReadVector()
	local yaw = net.ReadFloat()

	NETWORK.gui.OpenRecruiterEditor(id, position, yaw)
end)

function NETWORK.recruiter.Pick(key, spawnIndex)
	net.Start("nwRecruiterPick")
		net.WriteString(tostring(key))
		net.WriteUInt(spawnIndex or 0, 8)
	net.SendToServer()
end

function NETWORK.recruiter.Save(id, data)
	net.Start("nwRecruiterSave")
		net.WriteString(id)
		NETWORK.util.WriteTable(data)
	net.SendToServer()
end
