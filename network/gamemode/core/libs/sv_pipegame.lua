util.AddNetworkString("nwPipeOpen")
util.AddNetworkString("nwPipeSolved")
util.AddNetworkString("nwPipeCancel")
util.AddNetworkString("nwPipeClose")

NETWORK.pipe = NETWORK.pipe or {}

NETWORK.pipe.active = NETWORK.pipe.active or {}

function NETWORK.pipe.Start(client, entity, callback, onCancel, mode)
	if (!IsValid(client) or !IsValid(entity)) then
		return
	end

	NETWORK.pipe.active[client] = {
		entity = entity,
		callback = callback,
		onCancel = onCancel,
		position = client:GetPos(),
		time = CurTime()
	}

	net.Start("nwPipeOpen")
		net.WriteString(mode or "")
	net.Send(client)
end

function NETWORK.pipe.Stop(client)
	NETWORK.pipe.active[client] = nil
end

function NETWORK.pipe.Cancel(client)
	local entry = NETWORK.pipe.active[client]

	NETWORK.pipe.active[client] = nil

	if (entry and entry.onCancel) then
		entry.onCancel(client, entry.entity)
	end
end

net.Receive("nwPipeCancel", function(_, client)
	NETWORK.pipe.Cancel(client)
end)

net.Receive("nwPipeSolved", function(_, client)
	local entry = NETWORK.pipe.active[client]

	if (!entry) then
		return
	end

	NETWORK.pipe.Stop(client)

	if (!IsValid(entry.entity) or !client:Alive()) then
		return
	end

	if (client:GetPos():Distance(entry.position) > 200) then
		return NETWORK.chat.Notice(client, "pipeTooFar")
	end

	if (CurTime() - entry.time < 3) then
		return
	end

	if (entry.callback) then
		entry.callback(client, entry.entity)
	end
end)

hook.Add("PlayerDeath", "nwPipe", function(client)
	NETWORK.pipe.Cancel(client)
end)

hook.Add("PlayerDisconnected", "nwPipe", function(client)
	NETWORK.pipe.Stop(client)
end)

hook.Add("NetworkForcefieldRepair", "nwPipe", function(client, entity)
	NETWORK.pipe.Start(client, entity, function(_, field)
		if (!IsValid(field)) then
			return
		end

		field:SetDisabled(false)
		field:EmitSound("ambient/energy/zap9.wav", 75, 100)

		NETWORK.chat.Notice(client, "pipeFieldFixed")

		NETWORK.log.Add("lock", string.format("%s восстановил силовое поле",
			NETWORK.log.Name(client)), field:GetPos())

		hook.Run("NetworkMechanicRepaired", client, field)
	end)
end)
