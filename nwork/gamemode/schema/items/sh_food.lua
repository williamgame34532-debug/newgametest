--[[-------------------------------------------------------------------------
	Еда и вода. Нужды (модуль needs) восстанавливаются, если он включён.
---------------------------------------------------------------------------]]

local function Restore( ply, need, amount )
	if NWORK.Needs then NWORK.Needs.Add( ply, need, amount ) end
end

NWORK.Item.Register( "water", {
	Name     = "Вода Брина",
	Desc     = "Синяя жестянка с водой из городских запасов. Странный привкус, но жажду утоляет.",
	Model    = "models/props_junk/popcan01a.mdl",
	Category = "Еда",
	Stack    = 5,
	Actions  = {
		use = { Name = "Выпить", Order = 1, Run = function( ply )
			Restore( ply, "thirst", 40 )
			ply:EmitSound( "npc/barnacle/barnacle_gulp2.wav", 60 )
			return true
		end },
	},
} )

NWORK.Item.Register( "cola", {
	Name     = "Жестянка газировки",
	Desc     = "Тёплая и выдохшаяся, но всё ещё сладкая. Немного поднимает настроение.",
	Model    = "models/props_junk/popcan01a.mdl",
	Category = "Еда",
	Stack    = 5,
	Actions  = {
		use = { Name = "Выпить", Order = 1, Run = function( ply )
			Restore( ply, "thirst", 25 )
			Restore( ply, "rest", 10 )
			ply:SetHealth( math.min( ply:Health() + 5, ply:GetMaxHealth() ) )
			ply:EmitSound( "npc/barnacle/barnacle_gulp2.wav", 60 )
			return true
		end },
	},
} )

NWORK.Item.Register( "bread", {
	Name     = "Пайковый хлеб",
	Desc     = "Плотный серый брусок из гражданского пайка. Сытно и безвкусно.",
	Model    = "models/props_junk/garbage_bag001a.mdl",
	Category = "Еда",
	Stack    = 5,
	Actions  = {
		use = { Name = "Съесть", Order = 1, Run = function( ply )
			Restore( ply, "hunger", 45 )
			ply:EmitSound( "npc/barnacle/barnacle_crunch2.wav", 60 )
			return true
		end },
	},
} )
