DIALOGUE.name = "Работница"
DIALOGUE.start = "greeting"

DIALOGUE.nodes = {
	greeting = {
		text = "Я не думала, что такие важные люди тоже едут в Сектор 2.",
		replies = {
			{text = "Зачем вам в Сектор 2?", to = "question1"},
			{text = "Вы видели старого мужчину в костюме?", to = "question2"},
			{text = "Мне нужна работа.", to = "work"},
			{text = "До свидания.", exit = true}
		}
	},
	question1 = {
		text = "Мои родственники живут там. Я возвращаюсь к ним после того, как работала в Европе.",
		replies = {
			{text = "Понятно.", to = "greeting"},
			{text = "Удачи вам.", exit = true}
		}
	},
	question2 = {
		text = "Да, я видела пару людей в костюмах как у вас. Они общались с командиром таможни.",
		replies = {
			{text = "Спасибо.", to = "greeting"},
			{text = "Мне пора.", exit = true}
		}
	},
	work = {
		text = "Работа есть всегда. Собери мне пять кусков металлолома — заплачу пайками.",
		replies = {
			{text = "Я возьмусь.", to = "workTaken", quest = "garbage"},
			{
				text = "Я собрал мусор, который только смог найти.",
				to = "workDone",
				complete = "garbage"
			},
			{text = "Не сейчас.", to = "greeting"}
		}
	},
	workTaken = {
		text = "Отлично. Ищи на путях и в подворотнях, там всегда что-то валяется.",
		replies = {
			{text = "Понял.", exit = true}
		}
	},
	workDone = {
		text = "Неплохо, такие работники мне нравятся! Вот твоя награда.",
		replies = {
			{text = "Благодарю.", exit = true}
		}
	}
}
