-- Chat kinds, shared: the commands, how far each one carries, how it looks (cl_chat.lua).
--   text            IC speech      "<name> сказал: "..."" (beige)          normal talking range
--   /w text         whisper        "<name> шепнул: "..."" (grey, smaller)  short range
--   /y text         yell           "<name> крикнул: "..."" (red, larger)   long range
--   // text, /ooc   OOC            "|OOC| <name> (<steam>): ..." (white)   everyone
--   .// text, /looc LOOC           "|LOOC| <name> (<steam>): ..." (white)  talking range
--   /pm <who> text  private        "|PM| *<steam>*: "..."" (purple)        the two players
--   /roll [max]     dice           "<name> roll N (0-max)" (purple)        talking range
--   /me action      action         "*<name> action*" (green)               talking range
--   /it text        surroundings   "** text" (steel blue, no name)         talking range
--   /achat text     admin chat     "|A| <steam>: text" (orange)            admins only
-- Staff commands (/achat, /spawnadd, /spawnremove, /givetokens) are hidden from everyone else:
-- no hints, and typing them says "unknown command".

NW.chatKinds = NW.chatKinds or {}

local K = NW.chatKinds

K.IC, K.WHISPER, K.YELL, K.OOC, K.LOOC, K.PM, K.ROLL, K.ME, K.IT, K.ADMIN = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10

K.range = {
	[K.IC] = 300,
	[K.WHISPER] = 90,
	[K.YELL] = 750,
	[K.LOOC] = 300,
	[K.ROLL] = 300,
	[K.ME] = 300,
	[K.IT] = 300
}

-- command word -> kind
K.commands = {
	w = K.WHISPER, whisper = K.WHISPER, ["ш"] = K.WHISPER,
	y = K.YELL, yell = K.YELL, ["к"] = K.YELL,
	ooc = K.OOC,
	looc = K.LOOC,
	pm = K.PM,
	roll = K.ROLL,
	me = K.ME,
	it = K.IT,
	achat = K.ADMIN
}

-- what the input shows above itself while typing (the kind of message being written)
K.names = {
	[K.IC] = "Сказать",
	[K.WHISPER] = "Шёпот",
	[K.YELL] = "Крик",
	[K.OOC] = "OOC — для всех",
	[K.LOOC] = "LOOC — для тех, кто рядом",
	[K.PM] = "Личное сообщение",
	[K.ROLL] = "Бросок кубика",
	[K.ME] = "Действие",
	[K.IT] = "Окружение",
	[K.ADMIN] = "Админ-чат"
}

-- the command hints (typing "/" in the chat)
K.help = {
	{command = "/w", args = "<текст>", kind = K.WHISPER, text = "шёпот, слышно совсем рядом", also = {"whisper", "ш"}},
	{command = "/y", args = "<текст>", kind = K.YELL, text = "крик, слышно далеко", also = {"yell", "к"}},
	{command = "/me", args = "<действие>", kind = K.ME, text = "действие от лица персонажа"},
	{command = "/it", args = "<описание>", kind = K.IT, text = "описание окружения"},
	{command = "/looc", args = "<текст>", kind = K.LOOC, text = "вне роли, для тех, кто рядом (или .//)"},
	{command = "/ooc", args = "<текст>", kind = K.OOC, text = "вне роли, для всех (или //)"},
	{command = "/pm", args = "<имя> <текст>", kind = K.PM, text = "личное сообщение игроку"},
	{command = "/roll", args = "[максимум]", kind = K.ROLL, text = "бросить кубик, по умолчанию до 100"},
	-- staff only (admin = true): nobody else sees them
	{command = "/achat", args = "<текст>", kind = K.ADMIN, text = "чат администрации", admin = true},
	{command = "/spawnadd", args = "[фракция]", text = "точка появления фракции здесь (по умолчанию — вашей)",
		admin = true},
	{command = "/spawnremove", args = "", text = "убрать ближайшую точку появления", admin = true},
	{command = "/givetokens", args = "<имя> <число>", text = "выдать токены персонажу (минус — забрать)",
		admin = true}
}

-- may this player use / see this hint?
function K.Allowed(entry, client)
	return !entry.admin or (IsValid(client) and client:IsAdmin())
end

-- a known command word (by name or alias) this player may use: its hint entry
function K.Find(word, client)
	word = string.lower(word or "")

	for _, entry in ipairs(K.help) do
		if (K.Allowed(entry, client)) then
			if (string.sub(entry.command, 2) == word) then
				return entry
			end

			for _, alias in ipairs(entry.also or {}) do
				if (alias == word) then
					return entry
				end
			end
		end
	end
end

-- talking gestures (HL2 citizen gesture sequences): one of them may play with an IC message
K.gestures = {"g_puncuate", "g_shrug", "g_palm_out_l", "g_palm_up_high_l", "g_lhandease",
	"g_mid_relaxed_hand_accent", "g_righthandroll", "g_present", "g_chestup", "g_armsout"}
K.gestureChance = 0.6

-- what shows over the head while typing
K.typing = {"Говорит...", "Шепчет...", "Кричит...", "Пишет..."}

-- text -> kind, the rest of the text
function K.Parse(text)
	text = string.Trim(text)

	if (string.sub(text, 1, 3) == ".//") then
		return K.LOOC, string.Trim(string.sub(text, 4))
	end

	if (string.sub(text, 1, 2) == "//") then
		return K.OOC, string.Trim(string.sub(text, 3))
	end

	local prefix = string.sub(text, 1, 1)

	if (prefix == "/" or prefix == "!") then
		local word, rest = string.match(text, "^[/!](%S+)%s*(.*)$")

		if (word) then
			local kind = K.commands[string.lower(word)]

			if (kind) then
				return kind, string.Trim(rest or "")
			end

			return nil, word, string.Trim(rest or "")
		end
	end

	return K.IC, text
end
