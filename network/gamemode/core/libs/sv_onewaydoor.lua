NETWORK.oneway = NETWORK.oneway or {}

local O = NETWORK.oneway

O.pryTime = 3
O.pryTools = {
	weapon_crowbar = true,
	nw_crowbar = true,
	weapon_nwcrowbar = true
}

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone or "info", ...)
end

function O.IsOneWay(data)
	return istable(data) and istable(data.oneway)
end

function O.IsAllowedSide(entity, data, client)
	if (!O.IsOneWay(data)) then
		return true
	end

	local side = Vector(data.oneway[1] or 0, data.oneway[2] or 0, 0)

	if (side:Length() < 0.01) then
		return true
	end

	side:Normalize()

	local offset = client:GetPos() - entity:GetPos()

	offset.z = 0
	offset:Normalize()

	return offset:Dot(side) > 0
end

function O.HasTool(client)
	local weapon = client:GetActiveWeapon()

	return IsValid(weapon) and O.pryTools[weapon:GetClass()] == true
end

function O.Pry(client, entity)
	if (client.nwPryTask) then
		return
	end

	client.nwPryTask = entity

	net.Start("nwProgress")
		net.WriteString("doorPry")
		net.WriteFloat(O.pryTime)
	net.Send(client)

	entity:EmitSound("physics/metal/metal_box_strain" .. math.random(2, 4) .. ".wav",
		75, 90)

	timer.Simple(O.pryTime, function()
		if (!IsValid(client)) then
			return
		end

		client.nwPryTask = nil

		if (!IsValid(entity) or !client:Alive() or
			client:GetPos():Distance(entity:GetPos()) > 120) then
			return Notice(client, "doorPryFailed", "warn")
		end

		entity:EmitSound("doors/heavy_metal_stop1.wav", 80, 95)
		entity:Fire("Open")
		entity:Fire("Unlock")

		timer.Simple(6, function()
			if (IsValid(entity)) then
				entity:Fire("Close")
			end
		end)

		Notice(client, "doorPried", "good")
	end)
end

hook.Add("PlayerUse", "nwOneWayDoor", function(client, entity)
	if (!NETWORK.door.IsDoor(entity) or !client:HasCharacter()) then
		return
	end

	local data = NETWORK.door.GetData(entity)

	if (!O.IsOneWay(data) or O.IsAllowedSide(entity, data, client)) then
		return
	end

	if ((client.nwNextPry or 0) > CurTime()) then
		return false
	end

	client.nwNextPry = CurTime() + 0.6

	if (!O.HasTool(client)) then
		entity:EmitSound("doors/default_locked.wav", 60, 100)

		Notice(client, "doorOneWay", "warn")

		return false
	end

	O.Pry(client, entity)

	return false
end)

NETWORK.command.Register("doorway", {
	description = "cmdDoorWay",
	usage = "/doorway",
	adminOnly = true,
	aliases = {"odnostoronnyaya"},
	OnRun = function(command, client)
		local entity = client:GetEyeTrace().Entity

		if (!NETWORK.door.IsDoor(entity) or
			client:GetPos():Distance(entity:GetPos()) > 200) then
			return Notice(client, "doorNotDoor", "warn")
		end

		local data = NETWORK.door.GetData(entity) or {}

		if (O.IsOneWay(data)) then
			data.oneway = nil

			NETWORK.door.Set(entity, data)

			return Notice(client, "doorOneWayOff", "good")
		end

		local offset = client:GetPos() - entity:GetPos()

		offset.z = 0
		offset:Normalize()

		data.oneway = {math.Round(offset.x, 3), math.Round(offset.y, 3)}
		data.type = data.type or "public"

		NETWORK.door.Set(entity, data)

		Notice(client, "doorOneWayOn", "good")
	end
})
