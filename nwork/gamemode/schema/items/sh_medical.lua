NWORK.Item.Register( "medkit", {
	Name     = "Аптечка",
	Desc     = "Полевая аптечка Сопротивления. Бинты, антисептик и пара ампул — хватит, чтобы встать на ноги.",
	Model    = "models/items/healthkit.mdl",
	Category = "Медицина",
	Stack    = 3,
	Actions  = {
		use = { Name = "Использовать", Order = 1, Run = function( ply )
			if ply:Health() >= ply:GetMaxHealth() then
				NWORK.Notify( ply, "Вы не ранены.", "info" )
				return false
			end
			ply:SetHealth( math.min( ply:Health() + 25, ply:GetMaxHealth() ) )
			ply:EmitSound( "items/smallmedkit1.wav", 60 )
			return true
		end },
	},
} )

NWORK.Item.Register( "bandage", {
	Name     = "Бинт",
	Desc     = "Не слишком чистый, но лучше, чем ничего. Останавливает кровь.",
	Model    = "models/props_junk/garbage_newspaper001a.mdl",
	Category = "Медицина",
	Stack    = 5,
	Actions  = {
		use = { Name = "Перевязать", Order = 1, Run = function( ply )
			if ply:Health() >= ply:GetMaxHealth() then return false end
			ply:SetHealth( math.min( ply:Health() + 10, ply:GetMaxHealth() ) )
			ply:EmitSound( "items/medshot4.wav", 55 )
			return true
		end },
	},
} )
