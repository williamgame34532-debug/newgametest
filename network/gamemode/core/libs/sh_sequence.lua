local PLAYER = FindMetaTable("Player")

function PLAYER:GetForcedSequence()
	local sequence = self:GetNWInt("nwForcedSequence", -1)

	return sequence > 0 and sequence or nil
end

function PLAYER:IsInSequence()
	return self:GetForcedSequence() != nil
end

if (SERVER) then
	util.AddNetworkString("nwSequenceSet")
	util.AddNetworkString("nwSequenceReset")

	function PLAYER:ForceSequence(name, callback, time, bNoFreeze)
		local sequence = self:LookupSequence(tostring(name))

		if (!sequence or sequence < 1) then
			if (callback) then
				callback()
			end

			return false
		end

		time = time or self:SequenceDuration(sequence)

		self.nwSeqCallback = callback

		self:SetCycle(0)
		self:SetPlaybackRate(1)
		self:SetNWInt("nwForcedSequence", sequence)

		if (!bNoFreeze) then
			self:SetMoveType(MOVETYPE_NONE)
		end

		timer.Remove("nwSeq" .. self:EntIndex())

		if (time > 0) then
			timer.Create("nwSeq" .. self:EntIndex(), time, 1, function()
				if (IsValid(self)) then
					self:LeaveSequence()
				end
			end)
		end

		self:SetPlaybackRate(1)

		if (self.SetLayerBlendIn) then
			self.nwSeqBlend = true
		end

		self.nwSeqName = tostring(name)
		self.nwSeqUntil = time > 0 and (CurTime() + time) or math.huge

		net.Start("nwSequenceSet")
			net.WriteEntity(self)
			net.WriteUInt(sequence, 14)
		net.Broadcast()

		return time
	end

	function PLAYER:RefreshSequence(bBroadcast)
		if (!self:IsInSequence() or !self.nwSeqName) then
			return
		end

		local sequence = self:LookupSequence(self.nwSeqName)

		if (!sequence or sequence < 1) then
			return
		end

		local bDrifted = self:GetNWInt("nwForcedSequence", -1) != sequence

		if (bDrifted) then
			self:SetNWInt("nwForcedSequence", sequence)
		end

		if (!bDrifted and !bBroadcast) then
			return
		end

		net.Start("nwSequenceSet")
			net.WriteEntity(self)
			net.WriteUInt(sequence, 14)
		net.Broadcast()
	end

	function PLAYER:LeaveSequence()
		timer.Remove("nwSeq" .. self:EntIndex())

		self.nwSeqName = nil
		self.nwSeqUntil = nil

		self:SetNWInt("nwForcedSequence", -1)
		self:SetMoveType(MOVETYPE_WALK)

		net.Start("nwSequenceReset")
			net.WriteEntity(self)
		net.Broadcast()

		local callback = self.nwSeqCallback

		self.nwSeqCallback = nil

		if (callback) then
			callback()
		end
	end

	hook.Add("PlayerDeath", "nwSequence", function(client)
		if (client:IsInSequence()) then
			client:LeaveSequence()
		end
	end)

	hook.Add("PlayerSpawn", "nwSequence", function(client)
		client:SetNWInt("nwForcedSequence", -1)
		client.nwSeqCallback = nil
		client.nwSeqName = nil
		client.nwSeqUntil = nil
	end)

	hook.Add("PlayerSwitchWeapon", "nwSequence", function(client)
		if (!client:IsInSequence()) then
			return
		end

		timer.Simple(0, function()
			if (IsValid(client)) then
				client:RefreshSequence(true)
			end
		end)
	end)

	timer.Create("nwSequenceWatch", 1, 0, function()
		for _, client in ipairs(player.GetAll()) do
			if (!client:IsInSequence() or !client.nwSeqName) then
				continue
			end

			if ((client.nwSeqUntil or 0) < CurTime()) then
				continue
			end

			client:RefreshSequence()
		end
	end)
else
	net.Receive("nwSequenceSet", function()
		local entity = net.ReadEntity()
		local sequence = net.ReadUInt(14)

		if (!IsValid(entity)) then
			return
		end

		if (entity.nwLocalSequence != sequence) then
			entity:SetCycle(0)

			entity.nwSeqBlendStart = CurTime()
		end

		entity:SetPlaybackRate(1)
		entity.nwLocalSequence = sequence
	end)

	net.Receive("nwSequenceReset", function()
		local entity = net.ReadEntity()

		if (IsValid(entity)) then
			entity.nwLocalSequence = nil
		end
	end)
end
