NETWORK.vortsweep = NETWORK.vortsweep or {}

local SWEEP = NETWORK.vortsweep

SWEEP.weapon = "weapon_cbroom"
SWEEP.range = 110
SWEEP.strokeTime = 2
SWEEP.strokes = 3
SWEEP.reward = 1

function SWEEP.CanSweep(client)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return false
	end

	local weapon = client:GetActiveWeapon()

	return IsValid(weapon) and weapon:GetClass() == SWEEP.weapon
end

function SWEEP.IsJunk(entity)
	return IsValid(entity) and entity:GetClass() == "nw_junk" and !entity.nwSwept
end

function SWEEP.GetTarget(client)
	return NETWORK.util.FindLookedAt(client, SWEEP.range, SWEEP.IsJunk)
end

if (CLIENT) then
	return
end

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone or "info", ...)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

function SWEEP.Clean(client, entity)
	entity.nwSwept = true
	entity.nwSweepCount = nil
	entity.nwSweeper = nil

	entity:SetSearched(true)
	entity:SetNoDraw(true)
	entity:SetNotSolid(true)
	entity:EmitSound("physics/cardboard/cardboard_box_break" .. math.random(1, 3) .. ".wav",
		60, math.random(95, 105))

	local refill = NETWORK.junk.GetRefill(entity)

	if (refill > 0) then
		timer.Simple(refill, function()
			if (!IsValid(entity)) then
				return
			end

			entity.nwSwept = nil

			entity:SetSearched(false)
			entity:SetNoDraw(false)
			entity:SetNotSolid(false)
		end)
	end

	if (SWEEP.reward > 0 and NETWORK.currency and NETWORK.currency.Add) then
		NETWORK.currency.Add(client, SWEEP.reward)
	end

	Notice(client, "vortSweepDone", "good")

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("item", string.format("%s убрал мусор", NETWORK.log.Name(client)),
			entity:GetPos())
	end

	hook.Run("NetworkJunkSwept", client, entity)
end

function SWEEP.Stroke(client)
	if (!SWEEP.CanSweep(client) or client:IsInSequence()) then
		return
	end

	if ((client.nwSweepNext or 0) > CurTime()) then
		return
	end

	local entity = SWEEP.GetTarget(client)

	if (!entity) then
		return Notice(client, "vortSweepNoTarget", "warn")
	end

	if (IsValid(entity.nwSweeper) and entity.nwSweeper != client and
		(entity.nwSweepTime or 0) + 30 > CurTime()) then
		return Notice(client, "vortSweepBusy", "warn")
	end

	if (entity.nwSweeper != client) then
		entity.nwSweepCount = 0
	end

	entity.nwSweeper = client
	entity.nwSweepTime = CurTime()

	client.nwSweepNext = CurTime() + SWEEP.strokeTime

	local duration = client:ForceSequence("sweep", nil, SWEEP.strokeTime)

	if (!duration) then
		return
	end

	client:EmitSound("physics/cardboard/cardboard_box_scrape_smooth_loop1.wav", 55,
		math.random(95, 105), 0.5)

	Progress(client, "vortSweepProgress", SWEEP.strokeTime)

	timer.Simple(SWEEP.strokeTime, function()

		if (IsValid(client)) then
			client:StopSound("physics/cardboard/cardboard_box_scrape_smooth_loop1.wav")
		end

		if (!IsValid(client) or !IsValid(entity)) then
			return
		end

		if (entity.nwSweeper != client or entity.nwSwept) then
			return
		end

		if (!client:Alive() or client:GetPos():Distance(entity:GetPos()) > SWEEP.range + 40) then
			return Notice(client, "vortSweepInterrupted", "warn")
		end

		entity.nwSweepCount = (entity.nwSweepCount or 0) + 1

		if (entity.nwSweepCount >= SWEEP.strokes) then
			return SWEEP.Clean(client, entity)
		end

		Notice(client, "vortSweepProgressLine", "info", entity.nwSweepCount, SWEEP.strokes)
	end)
end

hook.Add("KeyPress", "nwVortSweep", function(client, key)
	if (key != IN_ATTACK or !SWEEP.CanSweep(client)) then
		return
	end

	SWEEP.Stroke(client)
end)

hook.Add("PlayerDisconnected", "nwVortSweep", function(client)
	for _, entity in ipairs(ents.FindByClass("nw_junk")) do
		if (entity.nwSweeper == client) then
			entity.nwSweeper = nil
			entity.nwSweepCount = nil
		end
	end
end)
