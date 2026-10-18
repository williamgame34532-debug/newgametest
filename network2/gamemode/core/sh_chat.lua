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
-- Staff commands (/achat, /spawnadd, /spawnremove, /givetokens, /areaedit, /door, /setfaction, /announce, /whitelist, /unwhitelist) are hidden from everyone else:
-- no hints, and typing them says "unknown command".

NW.chatKinds = NW.chatKinds or {}

local K = NW.chatKinds

K.IC, K.WHISPER, K.YELL, K.OOC, K.LOOC, K.PM, K.ROLL, K.ME, K.IT, K.ADMIN = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
-- the radios of the Alliance: /t - Civil Protection, /tr - with the Combine, /r - the squad (sh_squads.lua)
K.RADIO, K.RADIO_ALL, K.SQUAD = 11, 12, 13
-- the hidden radio of the Resistance: /rr (sh_rebels.lua)
K.REBEL = 14

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
	achat = K.ADMIN,
	t = K.RADIO,
	tr = K.RADIO_ALL,
	r = K.SQUAD,
	rr = K.REBEL
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
	[K.ADMIN] = "Админ-чат",
	[K.RADIO] = "Рация ГО",
	[K.RADIO_ALL] = "Общая рация Альянса",
	[K.SQUAD] = "Рация отряда",
	[K.REBEL] = "Частота Сопротивления"
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
	{command = "/doorbuy", args = "", text = "купить дверь, на которую вы смотрите"},
	{command = "/doorsell", args = "", text = "продать свою дверь (половина цены)"},
	{command = "/doorlock", args = "", text = "запереть или отпереть свою дверь"},
	{command = "/class", args = "", text = "выбрать класс своей фракции"},
	{command = "/fold", args = "", text = "сложить свои устройства Альянса рядом (мэнхек, мина, турель)",
		alliance = true},
	{command = "/voices", args = "", text = "голосовые фразы: напишите фразу целиком — персонаж скажет её вслух"},
	{command = "/whitelists", args = "", text = "какие фракции вам открыты"},
	{command = "/menufactory", args = "", text = "инструкция завода: как ставить, роли, ранги"},
	-- the Alliance only (alliance = true)
	{command = "/t", args = "<текст>", kind = K.RADIO, text = "рация Гражданской Обороны", alliance = true},
	{command = "/tr", args = "<текст>", kind = K.RADIO_ALL, text = "общая рация с комбайнами", alliance = true},
	{command = "/r", args = "<текст>", kind = K.SQUAD, text = "рация отряда", alliance = true},
	{command = "/rr", args = "<текст>", kind = K.REBEL, text = "частота Сопротивления (нужна рация)", rebel = true},
	{command = "/squadcreate", args = "[название]", text = "создать отряд и вести его", alliance = true},
	{command = "/squadjoin", args = "<название>", text = "вступить в отряд своей стороны", alliance = true},
	{command = "/squadleave", args = "", text = "выйти из отряда", alliance = true},
	{command = "/squaddisband", args = "", text = "расформировать свой отряд (лидер)", alliance = true},
	{command = "/squadkick", args = "<имя>", text = "исключить юнита из отряда (лидер)", alliance = true},
	{command = "/squadsuccession", args = "", text = "преемственность лидера: вкл / выкл (лидер)", alliance = true},
	-- staff only (admin = true): nobody else sees them
	{command = "/achat", args = "<текст>", kind = K.ADMIN, text = "чат администрации", admin = true},
	{command = "/spawnadd", args = "[фракция]", text = "точка появления фракции здесь (по умолчанию — вашей)",
		admin = true},
	{command = "/spawnremove", args = "", text = "убрать ближайшую точку появления", admin = true},
	{command = "/givetokens", args = "<имя> <число>", text = "выдать токены персонажу (минус — забрать)",
		admin = true},
	{command = "/areaedit", args = "", text = "редактор зон: две точки, название, тип (ещё раз — выйти)",
		admin = true},
	{command = "/door", args = "", text = "настроить дверь, на которую вы смотрите", admin = true},
	{command = "/setfaction", args = "<имя> <фракция>", text = "перевести персонажа во фракцию (ГО, Комбайны...)",
		admin = true},
	{command = "/setname", args = "<имя> <новое имя>", text = "переименовать персонажа (сохраняется)", admin = true},
	{command = "/setmodel", args = "<имя> <модель | сброс>", text = "сменить модель персонажа поверх фракции",
		admin = true},
	{command = "/cleanup", args = "", text = "очистка предметов и трупов через 10 секунд", admin = true},
	{command = "/classedit", args = "", text = "редактор классов фракций", admin = true},
	{command = "/setclass", args = "<имя> <id | нет>", text = "назначить класс фракции игрока", admin = true},
	{command = "/setskin", args = "<имя> <номер>", text = "скин модели персонажа (сохраняется)", admin = true},
	{command = "/setbodygroup", args = "<имя> <группа> <вариант>", text = "бодигруппа модели (сохраняется)",
		admin = true},
	{command = "/bodygroups", args = "[имя]", text = "какие бодигруппы и скины есть у модели", admin = true},
	{command = "/resetlook", args = "<имя>", text = "скин и бодигруппы по умолчанию", admin = true},
	{command = "/announce", args = "", text = "новое объявление для гражданских терминалов", admin = true},
	{command = "/whitelist", args = "<имя> <фракция>", text = "открыть игроку фракцию с вайтлистом", admin = true},
	{command = "/unwhitelist", args = "<имя> <фракция>", text = "закрыть игроку фракцию", admin = true},
	{command = "/itemedit", args = "", text = "редактор предметов: свои предметы, иконки, названия", admin = true},
	{command = "/weather", args = "<ясно|пасмурно|дождь|гроза|туман|снег|авто>", text = "погода", admin = true},
	{command = "/entmodel", args = "<модель>", text = "модель энтити сервера, на которую смотрите", admin = true}
}

-- may this player use / see this hint?
function K.Allowed(entry, client)
	if (entry.alliance and !(IsValid(client) and NW.zones and NW.zones.IsAlliance(client))) then
		return false
	end

	if (entry.rebel and !(IsValid(client) and client:GetFaction() == "rebel")) then
		return false
	end

	return !entry.admin or (IsValid(client) and client:IsAdmin())
end

-- the radio side of a member of the Alliance: "cp" (blue) or "ota" (red)
function K.RadioSide(client)
	local class = NW.anim and NW.anim.GetModelClass and NW.anim.GetModelClass(string.lower(client:GetModel() or ""))

	if (client:GetFaction() == "combine" or class == "overwatch" or class == "combine_heavy") then
		return "ota"
	end

	return "cp"
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
K.typing = {"Говорит...", "Шепчет...", "Кричит...", "Пишет...", "Говорит в рацию..."}

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

-- speech is written properly: the first letter big, a full stop at the end (if there is no
-- . ! ? … already). Used for speech and the radios (sv_chat.lua).
K.polished = {[K.IC] = true, [K.WHISPER] = true, [K.YELL] = true, [K.RADIO] = true, [K.RADIO_ALL] = true,
	[K.SQUAD] = true, [K.REBEL] = true}

local function Upper(code)
	if (code >= 0x430 and code <= 0x44F) then
		return code - 0x20
	elseif (code == 0x451) then
		return 0x401
	elseif (code >= 97 and code <= 122) then
		return code - 32
	end

	return code
end

function K.Polish(text)
	text = string.Trim(text or "")

	if (text == "") then
		return text
	end

	-- the first letter (after quotes, dashes and the like)
	local out, done = {}, false

	for _, code in utf8.codes(text) do
		if (!done and Upper(code) != code) then
			code = Upper(code)
			done = true
		elseif (!done and ((code >= 0x410 and code <= 0x42F) or code == 0x401 or (code >= 65 and code <= 90) or
			(code >= 48 and code <= 57))) then
			done = true
		end

		out[#out + 1] = utf8.char(code)
	end

	text = table.concat(out)

	-- the last character (bytes: "…" and "»" are several)
	local last = string.sub(text, -1)

	if (!string.find(last, "[%.%!%?%)\"]") and string.sub(text, -3) != "…" and string.sub(text, -2) != "»") then
		text = text .. "."
	end

	return text
end
