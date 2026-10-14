-- NPCs (entities/entities/nw_npc.lua): talking characters - dialogues, trade, quests. Everything
-- an NPC is lives in one config table, edited in game by admins (cl_npc.lua → Редактировать) and
-- saved with the map (sv_npc.lua):
--   name, description, model, skin, sequence (an idle animation; empty = the model's idle)
--   start          the id of the first line
--   nodes          the lines: {id, text, answers = {{text, action, target}, ...}}
--                    action "goto"  → the line `target`
--                           "trade" → the trade window
--                           "quest" → the quest `target` (take it / hand it in)
--                           "close" → end the talk
--   shop           what is sold: {item, price (tokens), priceItem, priceCount (another item as the
--                  price, or with tokens), stock (-1 = endless), sell (tokens the NPC pays for one;
--                  0 = does not buy it)}
--   quests         {id, name, description, need = {{item, count}}, rewardTokens,
--                  rewardItems = {{item, count}}, repeatable}
-- NW.npc.Sanitize makes any table (from the editor, from a file) a valid config.

NW.npc = NW.npc or {}

local NPC = NW.npc
local I = NW.items

NPC.ACTIONS = {
	{"goto", "Перейти к реплике"},
	{"trade", "Открыть торговлю"},
	{"quest", "Задание"},
	{"close", "Закончить разговор"}
}

function NPC.Default()
	return {
		name = "Торговец",
		description = "Немолодой мужчина в потёртой куртке. Смотрит оценивающе.",
		model = "models/humans/group01/male_07.mdl",
		skin = 0,
		sequence = "",
		start = "start",
		nodes = {
			{id = "start", text = "Чего надо? Если по делу — говори, если нет — проходи.", answers = {
				{text = "Покажи, что у тебя есть.", action = "trade"},
				{text = "Есть работа?", action = "goto", target = "work"},
				{text = "Ничего. Бывай.", action = "close"}
			}},
			{id = "work", text = "Работа есть всегда. Принеси пустых банок — сдам их на переработку, тебе заплачу.",
				answers = {
				{text = "Что нужно сделать?", action = "quest", target = "cans"},
				{text = "Вернёмся к делу.", action = "goto", target = "start"}
			}}
		},
		shop = {
			{item = "water", price = 5, priceItem = "", priceCount = 0, stock = -1, sell = 2},
			{item = "bread", price = 4, priceItem = "", priceCount = 0, stock = -1, sell = 1},
			{item = "bandage", price = 0, priceItem = "can_empty", priceCount = 2, stock = 10, sell = 0}
		},
		quests = {
			{id = "cans", name = "Пустые банки", description = "Собери три пустые банки и принеси торговцу.",
				need = {{item = "can_empty", count = 3}}, rewardTokens = 10, rewardItems = {}, repeatable = true}
		}
	}
end

local function Text(value, max, fallback)
	value = string.Trim(tostring(value or ""))

	if (value == "") then
		return fallback or ""
	end

	return string.sub(value, 1, max)
end

local function Int(value, min, max, fallback)
	return math.Clamp(math.floor(tonumber(value) or fallback or 0), min, max)
end

local function ID(value, fallback)
	value = string.lower(string.gsub(tostring(value or ""), "[^%w_]", ""))

	return value != "" and string.sub(value, 1, 32) or fallback
end

local function ItemList(list, max)
	local out = {}

	for _, entry in ipairs(istable(list) and list or {}) do
		if (#out < max and istable(entry) and I.Get(entry.item)) then
			out[#out + 1] = {item = entry.item, count = Int(entry.count, 1, 50, 1)}
		end
	end

	return out
end

function NPC.Sanitize(config)
	config = istable(config) and config or {}

	local out = {
		name = Text(config.name, 48, "NPC"),
		description = Text(config.description, 400),
		model = Text(config.model, 200, "models/humans/group01/male_07.mdl"),
		skin = Int(config.skin, 0, 63, 0),
		sequence = Text(config.sequence, 64),
		nodes = {},
		shop = {},
		quests = {}
	}

	local seen = {}

	for index, node in ipairs(istable(config.nodes) and config.nodes or {}) do
		if (#out.nodes < 60 and istable(node)) then
			local id = ID(node.id, "line" .. index)

			if (!seen[id]) then
				seen[id] = true

				local answers = {}

				for _, answer in ipairs(istable(node.answers) and node.answers or {}) do
					if (#answers < 9 and istable(answer)) then
						local action = answer.action

						if (action != "goto" and action != "trade" and action != "quest" and action != "close") then
							action = "close"
						end

						answers[#answers + 1] = {text = Text(answer.text, 160, "…"), action = action,
							target = ID(answer.target, "")}
					end
				end

				out.nodes[#out.nodes + 1] = {id = id, text = Text(node.text, 1200, "…"), answers = answers}
			end
		end
	end

	if (#out.nodes == 0) then
		out.nodes[1] = {id = "start", text = "…", answers = {{text = "Пока.", action = "close", target = ""}}}
	end

	out.start = seen[ID(config.start, "")] and ID(config.start, "") or out.nodes[1].id

	for _, line in ipairs(istable(config.shop) and config.shop or {}) do
		if (#out.shop < 60 and istable(line) and I.Get(line.item)) then
			local priceItem = I.Get(line.priceItem) and line.priceItem or ""

			out.shop[#out.shop + 1] = {
				item = line.item,
				price = Int(line.price, 0, 1000000, 0),
				priceItem = priceItem,
				priceCount = priceItem != "" and Int(line.priceCount, 1, 50, 1) or 0,
				stock = Int(line.stock, -1, 10000, -1),
				sell = Int(line.sell, 0, 1000000, 0)
			}
		end
	end

	local questIDs = {}

	for index, quest in ipairs(istable(config.quests) and config.quests or {}) do
		if (#out.quests < 30 and istable(quest)) then
			local id = ID(quest.id, "quest" .. index)

			if (!questIDs[id]) then
				questIDs[id] = true
				out.quests[#out.quests + 1] = {
					id = id,
					name = Text(quest.name, 64, "Задание"),
					description = Text(quest.description, 800),
					need = ItemList(quest.need, 8),
					rewardTokens = Int(quest.rewardTokens, 0, 1000000, 0),
					rewardItems = ItemList(quest.rewardItems, 8),
					repeatable = quest.repeatable == true
				}
			end
		end
	end

	return out
end

function NPC.Node(config, id)
	for _, node in ipairs(config.nodes) do
		if (node.id == id) then
			return node
		end
	end
end

function NPC.Quest(config, id)
	for _, quest in ipairs(config.quests) do
		if (quest.id == id) then
			return quest
		end
	end
end

-- how many of an item lie in this grid ({[index] = {id = ...}})
function NPC.Count(grid, id)
	local count = 0

	for _, cell in pairs(grid or {}) do
		if (cell.id == id) then
			count = count + 1
		end
	end

	return count
end
