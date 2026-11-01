-- Chat: only people nearby hear you. Modes by the first word:
--   text            говорит   (normal voice)
--   /w или /ш text  шепчет    (very close)
--   /y или /к text  кричит    (far)
--   /me или /я text действие  (* ЮНИТ 457 поправляет ремень)
--   /it или /о text окружение (* звенит стекло ... — описание происходящего рядом)
-- Those a little further than the range only catch that someone speaks («неразборчиво»).
HLA = HLA or {}
local CH = {}
HLA.Chat = CH

CH.MaxLen = 600 -- letters (sent by net, not by the «say» command with its short limit)
CH.Modes = {
	say = {id = 1, range = 400, verb = 'говорит', label = 'ГОВОРИТЬ'},
	w = {id = 2, range = 120, verb = 'шепчет', label = 'ШЁПОТ', cmds = {'/w', '/ш'}},
	y = {id = 3, range = 1000, verb = 'кричит', label = 'КРИК', cmds = {'/y', '/к'}},
	me = {id = 4, range = 400, action = true, label = 'ДЕЙСТВИЕ', cmds = {'/me', '/я'}},
	it = {id = 5, range = 400, env = true, label = 'ОКРУЖЕНИЕ', cmds = {'/it', '/о'}},
}
CH.ByID = {}
for key, m in pairs(CH.Modes) do m.key = key CH.ByID[m.id] = m end
CH.DISPATCH = 6 -- message id of the city dispatcher (not a chat mode)
CH.Muffle = 1.45 -- up to range * Muffle: heard, but not the words

-- 'mode key', 'text without the command'
function CH.Parse(text)
	text = string.Trim(text or '')
	local first, rest = string.match(text, '^(%S+)%s*(.*)$')
	if first then
		local low = string.lower(first)
		for key, m in pairs(CH.Modes) do
			for _, c in ipairs(m.cmds or {}) do
				if low == c then return key, string.Trim(rest) end
			end
		end
	end
	return 'say', text
end

-- range in metres for the hint in the input line (1 m ~ 52 units)
function CH.Metres(m) return math.floor(m.range / 52 + 0.5) end

-- atmosphere: short lines about what is heard around, now and then, to each player on their own
CH.AmbientEvery = {240, 480} -- seconds, random in between
CH.Ambient = {
	'Где-то над кварталом проходит патрульный дрон — гул затихает за крышами.',
	'Из громкоговорителя доносится обрывок объявления Надзора и тонет в помехах.',
	'Вдалеке воет сирена и обрывается на полуслове.',
	'Под ногами мелко дрожит асфальт: где-то идёт тяжёлая техника Альянса.',
	'В рации на секунду проступает чужой канал: щелчки, номер сектора, тишина.',
	'Ветер гонит по улице обрывки листовок. Пахнет озоном и ржавчиной.',
	'Где-то хлопает железная дверь, эхо уходит по пустым дворам.',
	'Над городом медленно поворачивается прожектор Цитадели.',
	'С крыши срывается и разбивается о землю кусок шифера.',
	'Издалека слышен короткий треск выстрелов, затем снова тишина.',
	'Лампы на столбах моргают — по сети проходит скачок напряжения.',
	'На канале отряда — сухой щелчок проверки связи.',
}
