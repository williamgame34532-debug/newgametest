util.AddNetworkString("nwDialogueOpen")
util.AddNetworkString("nwDialogueNode")
util.AddNetworkString("nwDialogueClose")
util.AddNetworkString("nwDialogueReply")

NETWORK.dialogue.range = 160

NETWORK.dialogue.gestures = {
	"g_look_small",
	"g_medpuct_mid",
	"g_noway_small"
}

NETWORK.dialogue.gestureChance = 90

local FALLBACK_ACTS = {
	ACT_GMOD_GESTURE_AGREE,
	ACT_GMOD_GESTURE_DISAGREE,
	ACT_GMOD_GESTURE_WAVE
}

function NETWORK.dialogue.Gesture(entity)
	if (!IsValid(entity) or math.random(100) > NETWORK.dialogue.gestureChance) then
		return
	end

	local name = NETWORK.dialogue.gestures[math.random(#NETWORK.dialogue.gestures)]

	if (entity:IsPlayer()) then
		entity:AnimRestartGesture(GESTURE_SLOT_CUSTOM,
			FALLBACK_ACTS[math.random(#FALLBACK_ACTS)], true)

		return
	end

	if (entity.PlayGesture) then
		entity:PlayGesture(name)
	end
end

function NETWORK.dialogue.Send(client, entity, id, node)
	local data = NETWORK.dialogue.GetNode(id, node)

	if (!data) then
		return NETWORK.dialogue.Stop(client)
	end

	client.nwDialogue = {entity = entity, id = id, node = node}

	NETWORK.dialogue.Gesture(entity)

	net.Start("nwDialogueNode")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable({
			name = entity:GetNPCName(),
			text = data.text,
			replies = NETWORK.dialogue.GetReplies(id, node, client)
		})
	net.Send(client)
end

function NETWORK.dialogue.TakeItem(client, id, amount)
	amount = math.max(math.Round(tonumber(amount) or 1), 1)

	if (NETWORK.dialogue.CountItem(client, id) < amount) then
		return false
	end

	local state = NETWORK.inventory.GetState(client)
	local left = amount

	for _, list in ipairs({"items", "storage"}) do
		for index, item in pairs(state[list]) do
			if (left <= 0) then
				break
			end

			if (item.id != id) then
				continue
			end

			local taken = math.min(item.amount or 1, left)

			left = left - taken

			if ((item.amount or 1) > taken) then
				item.amount = item.amount - taken
			else
				state[list][index] = nil
			end
		end
	end

	NETWORK.inventory.Sync(client)

	return true
end

NETWORK.npcface = NETWORK.npcface or {}

local FACE = NETWORK.npcface

FACE.step = 9

FACE.release = 320

function FACE.YawTo(entity, target)
	if (!IsValid(entity) or !IsValid(target)) then
		return nil
	end

	local direction = target:GetPos() - entity:GetPos()

	direction.z = 0

	if (direction:LengthSqr() < 1) then
		return nil
	end

	return direction:Angle().y
end

function FACE.Base(entity)
	return entity.baseAngles or entity:GetAngles()
end

function FACE.Face(entity, target)
	if (!IsValid(entity) or !IsValid(target)) then
		return
	end

	entity.baseAngles = entity.baseAngles or entity:GetAngles()
	entity.nwFaceTarget = target

	local yaw = FACE.YawTo(entity, target)

	if (yaw) then
		entity.targetYaw = yaw
	end
end

function FACE.Release(entity, target)
	if (!IsValid(entity)) then
		return
	end

	if (target != nil and IsValid(entity.nwFaceTarget) and
		entity.nwFaceTarget != target) then
		return
	end

	entity.nwFaceTarget = nil
	entity.targetYaw = FACE.Base(entity).y
end

function FACE.Think(entity)
	local target = entity.nwFaceTarget

	if (target != nil) then
		if (!IsValid(target) or (target.Alive and !target:Alive()) or
			target:GetPos():DistToSqr(entity:GetPos()) > FACE.release * FACE.release) then
			FACE.Release(entity)
		else
			entity.targetYaw = FACE.YawTo(entity, target) or entity.targetYaw
		end
	end

	if (!entity.targetYaw) then
		return
	end

	local angles = entity:GetAngles()
	local difference = math.AngleDifference(entity.targetYaw, angles.y)

	if (math.abs(difference) < 0.6) then
		if (angles.y != entity.targetYaw or angles.p != 0 or angles.r != 0) then
			entity:SetAngles(Angle(0, entity.targetYaw, 0))
		end

		return
	end

	entity:SetAngles(Angle(0, angles.y + math.Clamp(difference, -FACE.step, FACE.step), 0))
end

function NETWORK.dialogue.Start(client, entity)
	local id = entity:GetDialogue()
	local data = NETWORK.dialogue.Get(id)

	if (!data) then
		return
	end

	if (!NETWORK.dialogue.FactionAllowed(client, data.factions)) then
		return
	end

	if (entity.FaceEntity) then
		entity:FaceEntity(client)
	else
		local yaw = FACE.YawTo(entity, client)

		if (yaw) then
			entity:SetAngles(Angle(0, yaw, 0))
		end
	end

	net.Start("nwDialogueOpen")
		net.WriteEntity(entity)
	net.Send(client)

	NETWORK.dialogue.Send(client, entity, id, NETWORK.dialogue.GetStart(id, client))
end

function NETWORK.dialogue.Stop(client)
	local session = client.nwDialogue

	if (session and IsValid(session.entity) and session.entity.RestoreAngles) then
		session.entity:RestoreAngles(client)
	end

	client.nwDialogue = nil

	net.Start("nwDialogueClose")
	net.Send(client)
end

net.Receive("nwDialogueReply", function(_, client)
	local index = net.ReadUInt(8)
	local session = client.nwDialogue

	if (!session or !IsValid(session.entity)) then
		return
	end

	if (client:GetPos():Distance(session.entity:GetPos()) > NETWORK.dialogue.range) then
		return NETWORK.dialogue.Stop(client)
	end

	if (index == 255) then
		return NETWORK.dialogue.Stop(client)
	end

	if (index == 0) then
		client.nwTrader = session.entity

		return NETWORK.dialogue.Stop(client)
	end

	local node = NETWORK.dialogue.GetNode(session.id, session.node)
	local reply = node and node.replies and node.replies[index]

	if (!reply) then
		return NETWORK.dialogue.Stop(client)
	end

	NETWORK.dialogue.Gesture(client)

	if (!NETWORK.dialogue.FactionAllowed(client, reply.factions)) then
		return NETWORK.dialogue.Stop(client)
	end

	if (istable(reply.unlock)) then
		local unlock = reply.unlock

		if (!NETWORK.dialogue.TakeItem(client, unlock.id, unlock.amount)) then
			return NETWORK.dialogue.Stop(client)
		end

		NETWORK.trade.SetUnlocked(client,
			unlock.trader != "" and unlock.trader or session.entity:GetTraderID())

		session.entity:EmitSound("buttons/button9.wav", 60)
	end

	if (reply.quest) then
		NETWORK.quest.Start(client, reply.quest)
	end

	if (reply.complete) then
		NETWORK.quest.Complete(client, reply.complete)
	end

	if (reply.OnRun) then
		reply.OnRun(client, session.entity)
	end

	if (reply.exit or !reply.to) then
		return NETWORK.dialogue.Stop(client)
	end

	NETWORK.dialogue.Send(client, session.entity, session.id, reply.to)
end)

hook.Add("Think", "nwDialogueRange", function()
	if (!NETWORK.util.Throttle("dialogue.range", 0.25)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		local session = client.nwDialogue

		if (!session) then
			continue
		end

		if (!IsValid(session.entity) or !client:Alive() or
			client:GetPos():Distance(session.entity:GetPos()) > NETWORK.dialogue.range) then
			NETWORK.dialogue.Stop(client)
		end
	end
end)

hook.Add("PlayerDisconnected", "nwDialogue", function(client)

	local session = client.nwDialogue

	if (session and IsValid(session.entity) and session.entity.RestoreAngles) then
		session.entity:RestoreAngles(client)
	end

	client.nwDialogue = nil
end)

concommand.Add("network_gesture_test", function(client)
	if (!IsValid(client)) then
		return
	end

	local entity = client:GetEyeTrace().Entity

	NETWORK.dialogue.gestureChance = 100

	NETWORK.dialogue.Gesture(client)

	if (IsValid(entity) and entity.PlayGesture) then
		NETWORK.dialogue.Gesture(entity)

		NETWORK.util.Print("Жест отправлен на " .. entity:GetClass())
	else
		NETWORK.util.Print("Наведитесь на NPC для проверки его жеста")
	end

	NETWORK.dialogue.gestureChance = 90
end)
