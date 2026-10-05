NETWORK.factorywork = NETWORK.factorywork or {}

local WORK = NETWORK.factorywork

WORK.class = "worker_factory"
WORK.boxSize = 5
WORK.quotas = 4

function WORK.IsWorker(client)
	return IsValid(client) and client:IsPlayer() and client:HasCharacter() and
		client:GetNWString("nwClass", "") == WORK.class
end

function WORK.GetOwn(client)
	return {
		made = client:GetNWInt("nwWorkShiftMade", 0),
		delivered = client:GetNWInt("nwWorkShiftDelivered", 0),
		box = client:GetNWInt("nwWorkBox", 0),
		quotas = client:GetNWInt("nwWorkQuotas", 0),
		bDone = client:GetNWBool("nwWorkDone", false),
		totalMade = client:GetNWInt("nwWorkMade", 0),
		totalDelivered = client:GetNWInt("nwWorkDelivered", 0),
		shifts = client:GetNWInt("nwWorkShifts", 0),
		earned = client:GetNWInt("nwWorkEarned", 0),
		points = client:GetNWInt("nwWorkPoints", 0)
	}
end

WORK.steps = {
	{short = "workStepShort1", text = "workStep1"},
	{short = "workStepShort2", text = "workStep2"},
	{short = "workStepShort3", text = "workStep3"},
	{short = "workStepShort4", text = "workStep4"}
}

function WORK.GetProgress(stats)
	if (stats.bDone) then
		return 1
	end

	local total = WORK.boxSize * WORK.quotas
	local done = (stats.quotas or 0) * WORK.boxSize + (stats.box or 0)

	return math.Clamp(done / total, 0, 1)
end
