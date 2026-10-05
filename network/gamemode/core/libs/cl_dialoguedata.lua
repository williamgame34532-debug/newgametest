NETWORK.dialogue.custom = NETWORK.dialogue.custom or {}

net.Receive("nwDialogueSync", function()
	NETWORK.dialogue.custom = NETWORK.util.ReadTable()

	for id, data in pairs(NETWORK.dialogue.custom) do
		NETWORK.dialogue.Register(id, table.Copy(data))

		for questID, quest in pairs(data.quests or {}) do
			NETWORK.quest.Register(questID, table.Copy(quest))
		end
	end

	hook.Run("NetworkDialoguesUpdated")
end)

net.Receive("nwDialogueEditor", function()
	NETWORK.gui.OpenDialogueEditor(net.ReadString())
end)

function NETWORK.dialogue.Clean(data)
	local clean = {
		name = tostring(data.name or ""),
		start = tostring(data.start or "greeting"),
		nodes = {},
		quests = {},

		starts = {},
		factions = nil
	}

	local function CleanFactions(list)
		if (!istable(list)) then
			return nil
		end

		local out = {}

		for _, entry in ipairs(list) do
			if (isstring(entry) and entry != "") then
				out[#out + 1] = string.lower(entry)
			end
		end

		return #out > 0 and out or nil
	end

	clean.factions = CleanFactions(data.factions)

	for id, node in pairs(data.starts or {}) do
		if (isstring(id) and isstring(node)) then
			clean.starts[string.lower(id)] = node
		end
	end

	for id, node in pairs(data.nodes or {}) do
		local replies = {}

		for _, reply in ipairs(node.replies or {}) do
			replies[#replies + 1] = {
				text = tostring(reply.text or ""),
				to = isstring(reply.to) and reply.to or nil,
				quest = isstring(reply.quest) and reply.quest or nil,
				complete = isstring(reply.complete) and reply.complete or nil,
				exit = reply.exit and true or nil,
				factions = CleanFactions(reply.factions),
				unlock = istable(reply.unlock) and isstring(reply.unlock.id) and
					reply.unlock.id != "" and {
						id = reply.unlock.id,
						amount = math.Clamp(math.Round(
							tonumber(reply.unlock.amount) or 1), 1, 99),
						trader = isstring(reply.unlock.trader) and
							reply.unlock.trader or ""
					} or nil
			}
		end

		clean.nodes[tostring(id)] = {
			x = tonumber(node.x) or 0,
			y = tonumber(node.y) or 0,
			text = tostring(node.text or ""),
			replies = replies
		}
	end

	for id, quest in pairs(data.quests or {}) do
		local objectives = {}
		local items = {}

		for _, objective in ipairs(quest.objectives or {}) do
			local type = "item"

			for _, allowed in ipairs(NETWORK.quest.types) do
				if (objective.type == allowed) then
					type = allowed

					break
				end
			end

			local clean = {
				type = type,
				id = tostring(objective.id or ""),
				amount = math.max(tonumber(objective.amount) or 1, 1)
			}

			if (NETWORK.quest.IsPointType(type) and istable(objective.pos)) then
				clean.pos = {
					tonumber(objective.pos[1]) or 0,
					tonumber(objective.pos[2]) or 0,
					tonumber(objective.pos[3]) or 0
				}
				clean.radius = math.Clamp(math.Round(
					tonumber(objective.radius) or 96), 16, 1024)
				clean.name = tostring(objective.name or "")
				clean.map = tostring(objective.map or "")
				clean.class = tostring(objective.class or "")
				clean.amount = 1
			end

			objectives[#objectives + 1] = clean
		end

		for _, reward in ipairs((quest.rewards or {}).items or {}) do
			items[#items + 1] = {
				id = tostring(reward.id or ""),
				amount = math.max(tonumber(reward.amount) or 1, 1)
			}
		end

		clean.quests[tostring(id)] = {
			name = tostring(quest.name or id),
			description = tostring(quest.description or ""),
			objectives = objectives,
			rewards = {
				items = items,
				trader = istable(quest.rewards and quest.rewards.trader) and
					(quest.rewards.trader.id and {
						id = tostring(quest.rewards.trader.id),
						level = math.Clamp(math.Round(
							tonumber(quest.rewards.trader.level) or 2), 1, 5)
					} or nil) or nil
			},
			marker = istable(quest.marker) and {
				tonumber(quest.marker[1]) or 0,
				tonumber(quest.marker[2]) or 0,
				tonumber(quest.marker[3]) or 0
			} or nil,
			markerMap = isstring(quest.markerMap) and quest.markerMap or nil
		}
	end

	return clean
end

function NETWORK.dialogue.Save(id, data)
	id = string.gsub(string.lower(string.Trim(id or "")), "[^%w_]", "")

	if (id == "") then
		NETWORK.gui.Notify(L("editorBadID"), NETWORK.theme.danger)

		return
	end

	local clean = NETWORK.dialogue.Clean(data)

	if (!util.TableToJSON(clean)) then
		NETWORK.gui.Notify(L("editorSaveFailed"), NETWORK.theme.danger)

		return
	end

	net.Start("nwDialogueSave")
		net.WriteString(id)
		NETWORK.util.WriteTable(clean)
	net.SendToServer()
end

NETWORK.dialogue.cursors = NETWORK.dialogue.cursors or {}

net.Receive("nwDialogueCursor", function()
	local client = net.ReadEntity()
	local id = net.ReadString()
	local x = net.ReadFloat()
	local y = net.ReadFloat()

	if (!IsValid(client)) then
		return
	end

	NETWORK.dialogue.cursors[client:EntIndex()] = {
		client = client,
		id = id,
		x = x,
		y = y,
		time = CurTime()
	}
end)

function NETWORK.gui.DrawEditorCursors(editor)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	for key, data in pairs(NETWORK.dialogue.cursors) do
		if (!IsValid(data.client) or CurTime() - data.time > 3) then
			NETWORK.dialogue.cursors[key] = nil

			continue
		end

		if (data.id != editor.id) then
			continue
		end

		local x = data.x * editor.zoom + editor.offsetX
		local y = data.y * editor.zoom + editor.offsetY

		util.DrawThickLine(x, y, x + Sc(10), y + Sc(16), math.max(Sc(3), 2),
			Color(240, 200, 90))
		util.DrawThickLine(x, y, x + Sc(3), y + Sc(18), math.max(Sc(3), 2),
			Color(240, 200, 90))

		draw.SimpleText(data.client:GetCharacterName(), "nwHudSmall", x + Sc(16),
			y + Sc(18), Color(240, 200, 90, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function NETWORK.dialogue.SendCursor(id, x, y)
	net.Start("nwDialogueCursor")
		net.WriteString(id)
		net.WriteFloat(x)
		net.WriteFloat(y)
	net.SendToServer()
end
