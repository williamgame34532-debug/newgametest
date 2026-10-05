NETWORK.squad = NETWORK.squad or {}
NETWORK.squad.orders = NETWORK.squad.orders or {}

NETWORK.squad.orderList = {
	{id = "hold", name = "orderHold", glyph = "shield",
		color = Color(96, 190, 255)},
	{id = "advance", name = "orderAdvance", glyph = "arrow",
		color = Color(120, 220, 150)},
	{id = "regroup", name = "orderRegroup", glyph = "group",
		color = Color(120, 220, 150)},
	{id = "search", name = "orderSearch", glyph = "eye",
		color = Color(240, 200, 90)},
	{id = "detain", name = "orderDetain", glyph = "lock",
		color = Color(240, 200, 90)},
	{id = "fallback", name = "orderFallback", glyph = "warning",
		color = Color(232, 92, 92)}
}

function NETWORK.squad.GetOrder(id)
	for _, order in ipairs(NETWORK.squad.orderList) do
		if (order.id == id) then
			return order
		end
	end
end

NETWORK.squad.selectTime = 15

function NETWORK.squad.GetTargets(leader)
	local id = leader:GetSquad()

	if (!id) then
		return {}
	end

	local selected = leader.nwSquadSelected

	if (IsValid(selected) and selected:GetSquad() == id and
		(leader.nwSquadSelectedAt or 0) + NETWORK.squad.selectTime >
		CurTime()) then
		return {selected}, true
	end

	local list = {}

	for _, member in ipairs(NETWORK.squad.GetMembers(id)) do
		if (member != leader) then
			list[#list + 1] = member
		end
	end

	return list, false
end

if (SERVER) then
	util.AddNetworkString("nwSquadSelect")
	util.AddNetworkString("nwSquadOrder")
	util.AddNetworkString("nwSquadOrderShow")

	net.Receive("nwSquadSelect", function(_, client)
		if (!IsValid(client) or !client:HasCharacter() or
			!client:IsSquadLeader()) then
			return
		end

		local target = net.ReadEntity()

		if (!IsValid(target) or !target:IsPlayer() or target == client or
			target:GetSquad() != client:GetSquad()) then

			client.nwSquadSelected = nil

			net.Start("nwSquadSelect")
				net.WriteEntity(NULL)
			net.Send(client)

			return
		end

		client.nwSquadSelected = target
		client.nwSquadSelectedAt = CurTime()

		client:EmitSound("framework/cmb/hud/squadadd.mp3", 55, 120, 0.4)

		net.Start("nwSquadSelect")
			net.WriteEntity(target)
		net.Send(client)
	end)

	net.Receive("nwSquadOrder", function(_, client)
		if (!IsValid(client) or !client:HasCharacter() or
			!client:IsSquadLeader()) then
			return
		end

		local order = NETWORK.squad.GetOrder(net.ReadString())

		if (!order) then
			return
		end

		if ((client.nwNextOrder or 0) > CurTime()) then
			return
		end

		client.nwNextOrder = CurTime() + 1

		local targets, bPersonal = NETWORK.squad.GetTargets(client)

		if (#targets == 0) then
			return NETWORK.chat.Notice(client, "orderNoTargets")
		end

		for _, member in ipairs(targets) do
			net.Start("nwSquadOrderShow")
				net.WriteString(order.id)
				net.WriteString(client:GetCharacterName())
				net.WriteBool(bPersonal)
			net.Send(member)
		end

		client.nwSquadSelected = nil

		net.Start("nwSquadSelect")
			net.WriteEntity(NULL)
		net.Send(client)

		NETWORK.chat.Notice(client, bPersonal and "orderSentOne" or
			"orderSentAll")
	end)
end
