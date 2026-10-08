--[[-------------------------------------------------------------------------
	N-work — фракции.

	Models по полу — из них собирается «Внешность» в создании персонажа.
	Icon — материал для неймплейта и инвентаря (если nil, рисуются
	инициалы фракции).
---------------------------------------------------------------------------]]

NWORK.Factions = NWORK.Factions or {}

NWORK.Factions["citizen"] = {
	Name     = "Гражданское население",
	Initials = "ГН",
	Icon     = "nwork/fac_citizen.png",

	Models = {
		male = {
			"models/player/group01/male_01.mdl",
			"models/player/group01/male_02.mdl",
			"models/player/group01/male_03.mdl",
			"models/player/group01/male_04.mdl",
			"models/player/group01/male_05.mdl",
			"models/player/group01/male_06.mdl",
			"models/player/group01/male_07.mdl",
			"models/player/group01/male_08.mdl",
			"models/player/group01/male_09.mdl",
		},
		female = {
			"models/player/group01/female_01.mdl",
			"models/player/group01/female_02.mdl",
			"models/player/group01/female_03.mdl",
			"models/player/group01/female_04.mdl",
			"models/player/group01/female_05.mdl",
			"models/player/group01/female_06.mdl",
		},
	},
}

NWORK.Factions["cp"] = {
	Name     = "Гражданская Оборона",
	Initials = "ГО",
	Icon     = nil, -- своя иконка появится позже

	Models = {
		male = { "models/player/police.mdl" },
	},
}

function NWORK.FactionHasModel( faction, mdl )
	local f = NWORK.Factions[ faction ]
	if not f then return false end

	for _, list in pairs( f.Models ) do
		for _, m in ipairs( list ) do
			if m == mdl then return true end
		end
	end

	return false
end
