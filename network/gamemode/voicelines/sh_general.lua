local PATH = "framework/vo/cit/"
local PATH_FEMALE = "framework/vo/citfemale/"

NETWORK.voice.RegisterCategory("answer", "voiceAnswers")
NETWORK.voice.RegisterCategory("alert", "voiceAlert")
NETWORK.voice.RegisterCategory("combine", "voiceCombine")
NETWORK.voice.RegisterCategory("combat", "voiceCombat")
NETWORK.voice.RegisterCategory("mood", "voiceMood")
NETWORK.voice.RegisterCategory("misc", "voiceMisc")

local lines = {
	{"не думай", "Не думай об этом.", "answer04.wav", "answer"},
	{"позже", "Поговорим об этом позже!", "answer05.wav", "answer"},
	{"понятно", "Понятно.", "answer07.wav", "answer"},
	{"страшно", "Даже подумать страшно.", "answer12.wav", "answer"},
	{"и ты", "И ты — и я!", "answer14.wav", "answer"},
	{"пошляк", "Ты пошлейший тип!", "answer20.wav", "answer"},
	{"спорим", "Хах, спорим?", "answer27.wav", "answer"},
	{"что делать", "Ну и что мне с этим делать?", "answer29.wav", "answer"},
	{"сзади", "Сзади!", "behindyou01.wav", "alert"},
	{"сзади2", "Сзаади!", "behindyou02.wav", "alert"},
	{"не вовремя", "Эх, как не вовремя.", "busy02.wav", "alert"},
	{"берегись", "Берегиись!", "headsup02.wav", "alert"},
	{"ложись", "Ложииись!", "getdown02.wav", "alert"},
	{"убирайся", "Убирайся отсюда к чёрту!", "gethellout.wav", "alert"},
	{"спасайся", "Спасайся!", "runforyourlife01.wav", "alert"},
	{"смотри", "Смотри что делаешь!", "watchwhat.wav", "alert"},
	{"го", "Гражданская Оборона!", "civilprotection01.wav", "combine"},
	{"альянс", "Альянс!", "combine01.wav", "combine"},
	{"гошники", "Г.Ошники!", "cps01.wav", "combine"},
	{"прикрой", "Прикрой, перезаряжу.", "coverwhilereload01.wav", "combat"},
	{"зарядить", "Нужно зарядить.", "gottareload01.wav", "combat"},
	{"готов один", "Ха-а, один готов!", "gotone01.wav", "combat"},
	{"хэки", "Вот и хэки!", "herecomehacks01.wav", "combat"},
	{"вот они", "А вот и они!", "herecomehacks02.wav", "combat"},
	{"аптечку", "Возьми аптечку.", "health01.wav", "combat"},
	{"аптечку2", "Возьми аптечку!", "health02.wav", "combat"},
	{"остаюсь", "Я остаюсь!", "imstickinghere01.wav", "combat"},
	{"готов", "Окей, я готов.", "doingsomething.wav", "mood"},
	{"потрясающе", "Потрясающе.", "fantastic01.wav", "mood"},
	{"наконец", "Наконец.", "fantastic02.wav", "mood"},
	{"всё шло хорошо", "А ведь всё шло так хорошо!", "gordead_ans01.wav", "mood"},
	{"о нет", "О нет...", "gordead_ans05.wav", "mood"},
	{"не помог", "Я знал, даже он не смог бы помочь.", "gordead_ans09.wav", "mood"},
	{"нет", "Нет! Нееет!", "no01.wav", "mood"},
	{"нет2", "О нет..", "no02.wav", "mood"},
	{"окей", "Окей!", "ok01.wav", "mood"},
	{"окей2", "Окей.", "ok02.wav", "mood"},
	{"хай", "Хай.", "hi01.wav", "mood"},
	{"голодный", "Я голодный, как собака.", "question09.wav", "misc"},
	{"не в планах", "Ручаюсь, что в планах этого не было.", "question11.wav", "misc"},
	{"извини док", "Извини, док.", "sorrydoc01.wav", "misc"},
	{"живот", "А.. живот!", nil, "misc"},
	{"заслужил", "Чем же я это заслужил?", nil, "misc"},
}

for _, data in ipairs(lines) do
	NETWORK.voice.Register(data[1], {
		text = data[2],
		sound = data[3] and (PATH .. data[3]) or nil,
		soundFemale = data[3] and (PATH_FEMALE .. data[3]) or nil,
		category = data[4],
		faction = "citizen"
	})
end
