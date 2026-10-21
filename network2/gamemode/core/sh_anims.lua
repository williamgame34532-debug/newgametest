-- Animation classes: per hold type, per movement state {safety on, safety off}. An action is an
-- activity (number), a sequence name (string), a list of sequence names (each player gets one
-- of them, changing over time; missing names are skipped, none left -> the stock activity) or a
-- list of activities (the first one the model has).
NW.anim = NW.anim or {}

-- living idles of the build (models/network/citizens/nw_citizen_male|female.mdl, own per gender)
NW.anim.civIdle = {"nw_civ_idle", "nw_civ_live_1", "nw_civ_live_2", "nw_civ_subtle", "nw_civ_foldarms",
	"nw_civ_listen"}
-- HL:A motion capture of Civil Protection (models/network/cp/nw_cp_anims.mdl):
-- with empty hands only the unarmed idles; with the stunstick its own idles and the sprint
NW.anim.cpIdle = {"nw_hla_idle_unarmed_1", "nw_hla_idle_unarmed_2"}
NW.anim.cpStickIdle = {"nw_hla_idle_01", "nw_hla_idle_02", "nw_hla_idle_03", "nw_hla_idle_04"}
NW.anim.cpSmgIdle = {"nw_hla_idle_smg", "nw_hla_idle_smg_onehand", "nw_hla_idle_smg_twohand"}

NW.anim.citizen_male = {
	normal = {
		-- the plain HL2 standing idle
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_ANGRY_SMG1},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_COVER_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_AIM_RIFLE_STIMULATED},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN_AIM_RIFLE_STIMULATED},
		[ACT_LAND] = {ACT_RESET, ACT_RESET}
	},
	pistol = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_RANGE_ATTACK_PISTOL},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_RANGE_ATTACK_PISTOL_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_AIM_RIFLE_STIMULATED},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN_AIM_RIFLE_STIMULATED},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_PISTOL,
		reload = ACT_RELOAD_PISTOL
	},
	smg = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE_SMG1_RELAXED, ACT_IDLE_ANGRY_SMG1},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_RANGE_AIM_SMG1_LOW},
		[ACT_MP_WALK] = {ACT_WALK_RIFLE_RELAXED, ACT_WALK_AIM_RIFLE_STIMULATED},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_AIM_RIFLE},
		[ACT_MP_RUN] = {ACT_RUN_RIFLE_RELAXED, ACT_RUN_AIM_RIFLE_STIMULATED},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_SMG1,
		reload = ACT_GESTURE_RELOAD_SMG1
	},
	shotgun = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE_SHOTGUN_RELAXED, ACT_IDLE_ANGRY_SMG1},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_RANGE_AIM_SMG1_LOW},
		[ACT_MP_WALK] = {ACT_WALK_RIFLE_RELAXED, ACT_WALK_AIM_RIFLE_STIMULATED},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_RIFLE},
		[ACT_MP_RUN] = {ACT_RUN_RIFLE_RELAXED, ACT_RUN_AIM_RIFLE_STIMULATED},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_SHOTGUN
	},
	grenade = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_MANNEDGUN},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_RANGE_AIM_SMG1_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_AIM_RIFLE_STIMULATED},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN_RIFLE_STIMULATED},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_RANGE_ATTACK_THROW
	},
	melee = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_ANGRY_MELEE},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_COVER_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_AIM_RIFLE},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_MELEE_ATTACK_SWING
	},
	glide = ACT_GLIDE,
	vehicle = {
		["prop_vehicle_prisoner_pod"] = {"podpose", Vector(-3, 0, 0)},
		["prop_vehicle_jeep"] = {ACT_BUSY_SIT_CHAIR, Vector(14, 0, -14)},
		["prop_vehicle_airboat"] = {ACT_BUSY_SIT_CHAIR, Vector(8, 0, -20)},
		chair = {ACT_BUSY_SIT_CHAIR, Vector(1, 0, -23)}
	}
}

NW.anim.citizen_female = {
	normal = NW.anim.citizen_male.normal,
	pistol = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE_PISTOL, ACT_IDLE_ANGRY_PISTOL},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_RANGE_AIM_SMG1_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_AIM_PISTOL},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN_AIM_PISTOL},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_PISTOL,
		reload = ACT_RELOAD_PISTOL
	},
	smg = NW.anim.citizen_male.smg,
	shotgun = NW.anim.citizen_male.shotgun,
	grenade = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_MANNEDGUN},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_RANGE_AIM_SMG1_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_AIM_PISTOL},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN_AIM_PISTOL},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_RANGE_ATTACK_THROW
	},
	melee = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_MANNEDGUN},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_LOW, ACT_COVER_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_AIM_RIFLE},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_MELEE_ATTACK_SWING
	},
	glide = ACT_GLIDE,
	vehicle = NW.anim.citizen_male.vehicle
}

-- nw_hla_* idles: HL:A motion capture (models/network/cp/nw_cp_anims.mdl on networkcp); other
-- CP models do not have them and fall back to the stock activity (RepairSet).
NW.anim.metrocop = {
	-- empty hands: the plain walk and run of the metrocop in both states (no rifle aim with nothing in
	-- the hands)
	normal = {
		[ACT_MP_STAND_IDLE] = {NW.anim.cpIdle, ACT_IDLE},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_PISTOL_LOW, ACT_COVER_PISTOL_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET}
	},
	pistol = {
		[ACT_MP_STAND_IDLE] = {{"nw_hla_idle_pistol"}, ACT_IDLE_ANGRY_PISTOL},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_PISTOL_LOW, ACT_COVER_PISTOL_LOW},
		[ACT_MP_WALK] = {ACT_WALK_PISTOL, ACT_WALK_AIM_PISTOL},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		[ACT_MP_RUN] = {ACT_RUN_PISTOL, ACT_RUN_AIM_PISTOL},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_PISTOL,
		reload = ACT_GESTURE_RELOAD_PISTOL
	},
	smg = {
		[ACT_MP_STAND_IDLE] = {NW.anim.cpSmgIdle, ACT_IDLE_ANGRY_SMG1},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_SMG1_LOW, ACT_COVER_SMG1_LOW},
		[ACT_MP_WALK] = {ACT_WALK_RIFLE, ACT_WALK_AIM_RIFLE},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		[ACT_MP_RUN] = {ACT_RUN_RIFLE, ACT_RUN_AIM_RIFLE},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_SMG1,
		reload = ACT_GESTURE_RELOAD_SMG1
	},
	shotgun = {
		[ACT_MP_STAND_IDLE] = {NW.anim.cpSmgIdle, ACT_IDLE_ANGRY_SMG1},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_SMG1_LOW, ACT_COVER_SMG1_LOW},
		[ACT_MP_WALK] = {ACT_WALK_RIFLE, ACT_WALK_AIM_RIFLE},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		[ACT_MP_RUN] = {ACT_RUN_RIFLE, ACT_RUN_AIM_RIFLE},
		[ACT_LAND] = {ACT_RESET, ACT_RESET}
	},
	grenade = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_ANGRY_MELEE},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_PISTOL_LOW, ACT_COVER_PISTOL_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_ANGRY},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_COMBINE_THROW_GRENADE
	},
	melee = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_ANGRY_MELEE},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_PISTOL_LOW, ACT_COVER_PISTOL_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_ANGRY},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_MELEE_ATTACK_SWING_GESTURE
	},
	-- the stunstick (nw_stunstick, NW.anim.weaponHold): HL:A idles with the baton and the sprint with
	-- it; raised fists keep the plain melee set above
	stunstick = {
		[ACT_MP_STAND_IDLE] = {NW.anim.cpStickIdle, ACT_IDLE_ANGRY_MELEE},
		[ACT_MP_CROUCH_IDLE] = {ACT_COVER_PISTOL_LOW, ACT_COVER_PISTOL_LOW},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK_ANGRY},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH, ACT_WALK_CROUCH},
		-- the run with the baton in the hand: the HL:A sprint, on a model without it the run of the
		-- metrocop with the stick, never the empty-handed walk
		[ACT_MP_RUN] = {{"nw_hla_sprint", ACT_RUN}, {"nw_hla_sprint", ACT_RUN}},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_MELEE_ATTACK_SWING_GESTURE
	},

	glide = ACT_GLIDE,
	vehicle = {
		chair = {ACT_COVER_PISTOL_LOW, Vector(5, 0, -5)},
		["prop_vehicle_airboat"] = {ACT_COVER_PISTOL_LOW, Vector(10, 0, 0)},
		["prop_vehicle_jeep"] = {ACT_COVER_PISTOL_LOW, Vector(18, -2, 4)},
		["prop_vehicle_prisoner_pod"] = {ACT_IDLE, Vector(-4, -0.5, 0)}
	}
}

NW.anim.overwatch = {

	bLayered = true,

	reload = {
		"act_reload_low",
		"act_reload_low_alt01",
		"act_reload_low_alt02"
	},
	reloadFull = {
		"act_gesture_reload_shotgun",
		"act_gesture_reload_shotgun_alt01",
		"act_gesture_reload_shotgun_alt02"
	},
	reloadSMG = {
		"act_gesture_reload_smg1",
		"act_gesture_reload_smg1_alt01",
		"act_gesture_reload_smg1_alt02"
	},
	reloadLow = {
		"act_reload_low",
		"act_reload_low_alt01",
		"act_reload_low_alt02"
	},

	jump = "jump_shotgun_jump",
	shieldUp = "shield_equip",
	shieldDown = "shield_unequip",

	death = {"death_01", "death_02", "death_03"},

	normal = {
		-- own Overwatch set (nw_combine_anims.mdl); a list rotates per soldier (sh_animhooks)
		-- nw_ota_live_*: living 20 s stances (weight shifts, looks, radio, neck, shoulders)
		[ACT_MP_STAND_IDLE] = {{"nw_ota_live_1", "nw_ota_live_atease", "nw_ota_live_belt", "nw_ota_live_2", "nw_idle_relaxed",
			"nw_ota_scan", "nw_idle_foldarms"}, ACT_IDLE_ANGRY},
		[ACT_MP_CROUCH_IDLE] = {ACT_CROUCHIDLE, ACT_CROUCHIDLE},
		[ACT_MP_WALK] = {{"walkunarmed_all"}, ACT_WALK_RIFLE},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_RIFLE},
		[ACT_MP_RUN] = {ACT_RUN_AIM_RIFLE, ACT_RUN_AIM_RIFLE},
		[ACT_LAND] = {ACT_RESET, ACT_RESET}
	},
	pistol = {
		-- both hands on the pistol in every state (nw_combine_anims): safety on - low ready,
		-- safety off - aimed; walks in four directions (_b / _l / _r, picked by sh_animhooks)
		[ACT_MP_STAND_IDLE] = {{"nw_ota_pistol_live"}, {{"nw_ota_pistol_aim"}, ACT_IDLE_ANGRY}},
		[ACT_MP_CROUCH_IDLE] = {ACT_CROUCHIDLE, ACT_CROUCHIDLE},
		[ACT_MP_WALK] = {"nw_ota_pistol_walk", "nw_ota_pistol_walk_aim"},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_RIFLE},
		[ACT_MP_RUN] = {"nw_ota_pistol_run", "nw_ota_pistol_run_aim"},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_PISTOL,
		reload = ACT_GESTURE_RELOAD_PISTOL
	},
	smg = {
		-- safety on: weapon up across the chest, alive (nw_ota_port_live); safety off: the stock
		-- HL2 combat idle
		[ACT_MP_STAND_IDLE] = {{{"nw_ota_port_live"}, ACT_IDLE_SMG1}, ACT_IDLE_ANGRY_SMG1},
		[ACT_MP_CROUCH_IDLE] = {ACT_CROUCHIDLE, ACT_RANGE_AIM_SMG1_LOW},
		[ACT_MP_WALK] = {ACT_WALK_RIFLE, ACT_WALK_AIM_RIFLE},
		[ACT_MP_CROUCHWALK] = {ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_AIM_RIFLE},
		[ACT_MP_RUN] = {{ACT_RUN_RIFLE, ACT_RUN_AIM_RIFLE}, ACT_RUN_AIM_RIFLE},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_SMG1,
		reload = ACT_GESTURE_RELOAD_SMG1
	},
	glide = ACT_GLIDE,
	vehicle = {
		chair = {ACT_COVER_PISTOL_LOW, Vector(5, 0, -5)}
	}
}

NW.anim.overwatch.shotgun = NW.anim.overwatch.smg

-- the pistol walks exist for four directions
NW.anim.directional = NW.anim.directional or {}
NW.anim.directional.nw_ota_pistol_walk = true
NW.anim.directional.nw_ota_pistol_walk_aim = true

-- own walk / run sequences have no ground speed of their own: units per second they were made
-- for, so the playback follows the player's real speed (sh_animhooks, GM:UpdateAnimation)
NW.anim.groundSpeed = {
	nw_ota_pistol_walk = 30, nw_ota_pistol_walk_aim = 30,
	nw_ota_pistol_walk_b = 45, nw_ota_pistol_walk_aim_b = 45,
	nw_ota_pistol_walk_l = 33.5, nw_ota_pistol_walk_aim_l = 33.5,
	nw_ota_pistol_walk_r = 34.5, nw_ota_pistol_walk_aim_r = 34.5,
	nw_ota_pistol_run = 82.5, nw_ota_pistol_run_aim = 82.5,
	-- the CP sprint with the stunstick (HL:A capture, no root motion): one cycle per 240 units, so at
	-- the run speed (200) it plays a little slower than its own pace instead of the engine's 2x
	nw_hla_sprint = 240
}
NW.anim.overwatch.grenade = NW.anim.overwatch.normal
NW.anim.overwatch.melee = NW.anim.overwatch.normal

NW.anim.combine_heavy = {
	normal = {
		[ACT_MP_STAND_IDLE] = {"idle_unarmed", "idle_unarmed_angry"},
		[ACT_MP_CROUCH_IDLE] = {"crouch_unarmed", "crouch_unarmed"},
		[ACT_MP_WALK] = {"walkunarmed_all", "walkunarmed_all"},
		[ACT_MP_CROUCHWALK] = {"crouchwalk_unarmed", "crouchwalk_unarmed"},
		[ACT_MP_RUN] = {"run_unarmed", "run_unarmed"},
		[ACT_LAND] = {ACT_RESET, ACT_RESET}
	},
	smg = {
		[ACT_MP_STAND_IDLE] = {"idle_holster_smg", "idle_shotgun"},
		[ACT_MP_CROUCH_IDLE] = {"crouch_unarmed", "crouch_idle_shotgun"},
		[ACT_MP_WALK] = {"walk_holster", "walk_aimrifle"},
		[ACT_MP_CROUCHWALK] = {"crouchwalk_unarmed", "crouchwalk_unarmed"},
		[ACT_MP_RUN] = {"run_holster", "run_shotgun_rifle"},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_SMG1,
		reload = {"act_gesture_reload_smg1", "act_gesture_reload_smg1_alt01",
			"act_gesture_reload_smg1_alt02"},
		reloadLow = {"act_reload_low", "act_reload_low_alt01", "act_reload_low_alt02"}
	},
	shotgun = {
		[ACT_MP_STAND_IDLE] = {"idle_holster", "idle_shotgun"},
		[ACT_MP_CROUCH_IDLE] = {"crouch_unarmed", "crouch_idle_shotgun"},
		[ACT_MP_WALK] = {"walk_holster", "walk_aimrifle"},
		[ACT_MP_CROUCHWALK] = {"crouchwalk_unarmed", "crouchwalk_unarmed"},
		[ACT_MP_RUN] = {"run_holster", "run_shotgun_rifle"},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK_SHOTGUN,
		reload = {"act_gesture_reload_shotgun", "act_gesture_reload_shotgun_alt01",
			"act_gesture_reload_shotgun_alt02"},
		reloadLow = {"act_reload_low", "act_reload_low_alt01", "act_reload_low_alt02"}
	},
	glide = ACT_GLIDE,
	vehicle = {
		chair = {ACT_COVER_PISTOL_LOW, Vector(5, 0, -5)}
	}
}

NW.anim.combine_heavy.pistol = NW.anim.combine_heavy.smg
NW.anim.combine_heavy.grenade = NW.anim.combine_heavy.normal
NW.anim.combine_heavy.melee = NW.anim.combine_heavy.normal

NW.anim.combine_heavy.shield = {
	[ACT_MP_STAND_IDLE] = {"idle_shield", "idle_shield"},
	[ACT_MP_CROUCH_IDLE] = {"crouch_unarmed", "crouch_unarmed"},
	[ACT_MP_WALK] = {"shield_all", "shield_all"},
	[ACT_MP_CROUCHWALK] = {"crouchwalk_unarmed", "crouchwalk_unarmed"},
	[ACT_MP_RUN] = {"shield_all", "shield_all"},
	[ACT_LAND] = {ACT_RESET, ACT_RESET},
	glide = "jump_shield"
}

NW.anim.player = {
	normal = {
		[ACT_MP_STAND_IDLE] = ACT_HL2MP_IDLE,
		[ACT_MP_CROUCH_IDLE] = ACT_HL2MP_IDLE_CROUCH,
		[ACT_MP_WALK] = ACT_HL2MP_WALK,
		[ACT_MP_RUN] = ACT_HL2MP_RUN,
		[ACT_LAND] = {ACT_RESET, ACT_RESET}
	},
	passive = {
		[ACT_MP_STAND_IDLE] = ACT_HL2MP_IDLE_PASSIVE,
		[ACT_MP_WALK] = ACT_HL2MP_WALK_PASSIVE,
		[ACT_MP_CROUCHWALK] = ACT_HL2MP_WALK_CROUCH_PASSIVE,
		[ACT_MP_RUN] = ACT_HL2MP_RUN_PASSIVE,
		[ACT_LAND] = {ACT_RESET, ACT_RESET}
	}
}

NW.anim.vortigaunt = {
	normal = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_ANGRY},
		[ACT_MP_CROUCH_IDLE] = {"crouchidle", "crouchidle"},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_CROUCHWALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_MELEE_ATTACK1
	},

	broom = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, "sweep_idle"},
		[ACT_MP_CROUCH_IDLE] = {"crouchidle", "crouchidle"},
		[ACT_MP_WALK] = {"Walk_all_HoldBroom", "Walk_all_HoldBroom"},
		[ACT_MP_CROUCHWALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = "sweep"
	},

	beam = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_ANGRY},
		[ACT_MP_CROUCH_IDLE] = {"crouchidle", "crouchidle"},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_CROUCHWALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_GESTURE_RANGE_ATTACK1,
		reload = ACT_IDLE,
		glide = {ACT_RUN, ACT_RUN}
	},

	heal = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE},
		[ACT_MP_CROUCH_IDLE] = {"crouchidle", "crouchidle"},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_CROUCHWALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN},
		[ACT_LAND] = {ACT_RESET, ACT_RESET}
	},

	gun = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, "TCidlecombat"},
		[ACT_MP_CROUCH_IDLE] = {"crouchidle", "crouchidle"},
		[ACT_MP_WALK] = {ACT_WALK, "Walk_all_TC"},
		[ACT_MP_CROUCHWALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_RUN] = {ACT_RUN, "run_all_TC"},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		reload = ACT_IDLE
	},

	melee = {
		[ACT_MP_STAND_IDLE] = {ACT_IDLE, ACT_IDLE_ANGRY},
		[ACT_MP_CROUCH_IDLE] = {"crouchidle", "crouchidle"},
		[ACT_MP_WALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_CROUCHWALK] = {ACT_WALK, ACT_WALK},
		[ACT_MP_RUN] = {ACT_RUN, ACT_RUN_AIM},
		[ACT_LAND] = {ACT_RESET, ACT_RESET},
		attack = ACT_MELEE_ATTACK1
	},

	glide = ACT_GLIDE,
	vehicle = {
		chair = {"crouchidle", Vector(5, 0, -5)}
	}
}

local V = NW.anim.vortigaunt

for _, hold in ipairs({"pistol", "revolver", "smg", "ar2", "shotgun",
	"rpg", "crossbow", "duel", "physgun", "camera", "magic"}) do
	V[hold] = V.gun
end

for _, hold in ipairs({"melee2", "knife", "slam"}) do
	V[hold] = V.melee
end

for _, hold in ipairs({"grenade", "fist", "passive"}) do
	V[hold] = V.normal
end

setmetatable(V, {
	__index = function(self, key)
		if (isstring(key)) then
			return rawget(self, "normal")
		end
	end
})

NW.anim.weaponHold = {
	weapon_cbroom = "broom",
	swep_vortigaunt_sweep = "broom",
	swep_vortigaunt_beam = "beam",
	swep_vortigaunt_beam_edit = "beam",
	swep_vortigaunt_heal = "heal",
	nw_stunstick = "stunstick",
	weapon_stunstick = "stunstick"
}

local translations = {}

function NW.anim.SetModelClass(model, class)
	if (!NW.anim[class]) then
		NW.Warn("Нет класса анимаций: " .. tostring(class))

		return
	end

	translations[string.lower(model)] = class
end

local patterns = {
	{"metropolice", "metrocop"},
	{"/police", "metrocop"},
	{"combine_soldier", "overwatch"},
	{"combine_super", "overwatch"},
	{"overwatch", "overwatch"}
}

function NW.anim.SetModelPattern(pattern, class)
	if (!NW.anim[class]) then
		NW.Warn("Нет класса анимаций: " .. tostring(class))

		return
	end

	table.insert(patterns, 1, {string.lower(pattern), class})
end

function NW.anim.GetModelClass(model)
	model = string.lower(model)

	local class = translations[model]

	if (!class and string.find(model, "/player")) then
		return "player"
	end

	if (!class) then
		for _, entry in ipairs(patterns) do
			if (string.find(model, entry[1], 1, true)) then
				class = entry[2]

				break
			end
		end
	end

	class = class or "citizen_male"

	if (class == "citizen_male" and (string.find(model, "female") or
		string.find(model, "alyx") or string.find(model, "mossman"))) then
		class = "citizen_female"
	end

	return class
end

for _, model in ipairs({
	"models/vortigaunt.mdl",
	"models/vortigaunt_slave.mdl",
	"models/vortigaunt_blue.mdl",
	"models/vortigaunt_doctor.mdl"
}) do
	NW.anim.SetModelClass(model, "vortigaunt")
end

NW.anim.SetModelPattern("vortigaunt", "vortigaunt")

NW.anim.SetModelClass("models/police.mdl", "metrocop")
NW.anim.SetModelClass("models/networkcp.mdl", "metrocop")
NW.anim.SetModelClass("models/policetrench.mdl", "metrocop")
NW.anim.SetModelClass("models/leet_police2.mdl", "metrocop")

for _, model in ipairs({
	"models/wn7new/metropolice/male_07.mdl",
	"models/wn7new/metropolice/male_08.mdl",
	"models/wn7new/metropolice/male_09.mdl"
}) do
	NW.anim.SetModelClass(model, "metrocop")
end
NW.anim.SetModelClass("models/player/combine_heavy.mdl", "combine_heavy")
NW.anim.SetModelClass("models/combine_soldier.mdl", "overwatch")
NW.anim.SetModelClass("models/combine_soldier_prisonguard.mdl", "overwatch")
NW.anim.SetModelClass("models/combine_super_soldier.mdl", "overwatch")

NW.anim.SetModelClass(
	"models/synapse/hl_a/combine_commander/npc/combine_commander.mdl",
	"overwatch")
NW.anim.SetModelClass("models/synapse/combine/combine_supressor.mdl",
	"overwatch")

NW.anim.SetModelClass("models/synapse/combine/combine_grunt.mdl",
	"overwatch")

NW.anim.SetModelPattern("models/synapse/combine/", "overwatch")
NW.anim.SetModelPattern("models/network/combine/", "overwatch")

NW.anim.SetModelPattern("models/synapse/hl_a/combine", "overwatch")

for _, model in ipairs({
	"models/willardnetworks/citizens/female_01.mdl",
	"models/willardnetworks/citizens/female_02.mdl",
	"models/willardnetworks/citizens/female_03.mdl",
	"models/willardnetworks/citizens/female_04.mdl",
	"models/willardnetworks/citizens/female_06.mdl"
}) do
	NW.anim.SetModelClass(model, "citizen_female")
end

for _, model in ipairs({
	"models/willardnetworks/citizens/male01.mdl",
	"models/willardnetworks/citizens/male02.mdl",
	"models/willardnetworks/citizens/male03.mdl",
	"models/willardnetworks/citizens/male04.mdl",
	"models/willardnetworks/citizens/male05.mdl",
	"models/willardnetworks/citizens/male06.mdl",
	"models/willardnetworks/citizens/male07.mdl",
	"models/willardnetworks/citizens/male08.mdl"
}) do
	NW.anim.SetModelClass(model, "citizen_male")
end
