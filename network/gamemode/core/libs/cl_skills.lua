NETWORK.skills.localData = NETWORK.skills.localData or {levels = {}, xp = {}}

net.Receive("nwSkills", function()
	local data = util.JSONToTable(net.ReadString() or "") or {}

	NETWORK.skills.localData = {
		levels = istable(data.levels) and data.levels or {},
		xp = istable(data.xp) and data.xp or {}
	}

	hook.Run("NetworkSkillsUpdated")
end)
