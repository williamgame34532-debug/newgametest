--[[-------------------------------------------------------------------------
	N-work — предметы (общее).

	Регистрация предметов: имя, описание, модель (из неё же строится
	иконка в инвентаре). UseName — подпись действия «использовать»,
	сама логика Use определена только на сервере.
---------------------------------------------------------------------------]]

NWORK.Items = NWORK.Items or {}

function NWORK.RegisterItem( id, t )
	t.id = id
	NWORK.Items[ id ] = t
end

NWORK.RegisterItem( "scrap", {
	Name  = "Металлолом",
	Desc  = "Кусок ржавого металла. Основной компонент для крафта и починки.",
	Model = "models/props_junk/garbage_metalcan001a.mdl",
} )

NWORK.RegisterItem( "battery", {
	Name  = "Батарея",
	Desc  = "Универсальная энергоячейка. Мягкий, но ёмкий источник питания — ценится всеми, у кого есть хоть какая-то техника.",
	Model = "models/items/battery.mdl",
} )

NWORK.RegisterItem( "cola", {
	Name    = "Жестянка газировки",
	Desc    = "Тёплая и выдохшаяся, но всё ещё сладкая. Немного поднимает настроение.",
	Model   = "models/props_junk/popcan01a.mdl",
	UseName = "Выпить",
	Use     = SERVER and function( ply )
		ply:SetHealth( math.min( ply:Health() + 5, ply:GetMaxHealth() ) )
		ply:EmitSound( "npc/barnacle/barnacle_gulp2.wav", 60 )
		return true -- расходуется
	end or nil,
} )

NWORK.RegisterItem( "medkit", {
	Name    = "Аптечка",
	Desc    = "Полевая аптечка Сопротивления. Бинты, антисептик и пара ампул — хватит, чтобы встать на ноги.",
	Model   = "models/items/healthkit.mdl",
	UseName = "Использовать",
	Use     = SERVER and function( ply )
		if ply:Health() >= ply:GetMaxHealth() then return false end
		ply:SetHealth( math.min( ply:Health() + 25, ply:GetMaxHealth() ) )
		ply:EmitSound( "items/smallmedkit1.wav", 60 )
		return true
	end or nil,
} )
