NWORK.Item.Register( "scrap", {
	Name     = "Металлолом",
	Desc     = "Кусок ржавого металла. Основной компонент для крафта и починки.",
	Model    = "models/props_junk/garbage_metalcan001a.mdl",
	Category = "Разное",
	Stack    = 20,
} )

NWORK.Item.Register( "battery", {
	Name     = "Батарея",
	Desc     = "Универсальная энергоячейка. Мягкий, но ёмкий источник питания — ценится всеми, у кого есть хоть какая-то техника.",
	Model    = "models/items/battery.mdl",
	Category = "Энергия",
	Stack    = 5,
} )

NWORK.Item.Register( "radio", {
	Name     = "Рация",
	Desc     = "Самодельный приёмопередатчик. Позволяет говорить по рации: /r <сообщение>.",
	Model    = "models/props_lab/citizenradio.mdl",
	Category = "Энергия",
	Stack    = 1,
} )

NWORK.Item.Register( "cid", {
	Name     = "Гражданский ID",
	Desc     = "Карточка гражданина Города 24. Без неё не выдают паёк и не пускают дальше КПП.",
	Model    = "models/gibs/metal_gib4.mdl",
	Category = "Документы",
	Stack    = 1,
	Actions  = {
		show = { Name = "Показать", Order = 1, Run = function( ply )
			local f = ply:GetFactionTable()
			NWORK.Chat.Send( ply, "it", ( "%s показывает документ: «%s, #%05d, %s»" ):format(
				ply:GetCharName(), ply:GetCharName(), ply:GetCharID(), f and f.Name or "—" ) )
			return false
		end },
	},
} )
