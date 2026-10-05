NETWORK.trap = NETWORK.trap or {}

NETWORK.rebels = NETWORK.rebels or {}
NETWORK.rebels.Is = NETWORK.rebels.Is or function(client)
	return IsValid(client) and client:IsPlayer() and
		client:GetNWString("nwClass", "") == "rebel"
end

function NETWORK.trap.IsRebel(client)
	return IsValid(client) and client:IsPlayer() and client:HasCharacter() and
		NETWORK.rebels.Is(client) == true
end

NETWORK.trap.classes = {
	nw_tripwire = true,
	nw_beartrap = true,
	nw_ied = true,
	nw_lasermine = true
}

NETWORK.trap.rebelClasses = {
	nw_tripwire = true,
	nw_beartrap = true,
	nw_ied = true
}

NETWORK.trap.highlightRange = 300
NETWORK.trap.useRange = 110
NETWORK.trap.defuseTime = 4
NETWORK.trap.freeTime = 3
NETWORK.trap.hackTime = 8
NETWORK.trap.rootTime = 20
NETWORK.trap.struggleChance = 0.12
NETWORK.trap.turretHealth = 150

NETWORK.config.Register("trapLimit", {
	name = "cfgTrapLimit",
	description = "cfgTrapLimitDesc",
	category = "world",
	default = 4,
	min = 0,
	max = 20,
	decimals = 0
})

NETWORK.config.Register("trapLifetime", {
	name = "cfgTrapLifetime",
	description = "cfgTrapLifetimeDesc",
	category = "world",
	default = 45,
	min = 0,
	max = 240,
	decimals = 0
})

function NETWORK.trap.IsRooted(client)
	return IsValid(client) and client:GetNWFloat("nwTrapRoot", 0) > CurTime()
end

hook.Add("StartCommand", "nwTrapRoot", function(client, cmd)
	if (!NETWORK.trap.IsRooted(client)) then
		return
	end

	cmd:ClearMovement()
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_SPEED)
end)

hook.Add("NetworkMovementSpeed", "zzzTrapRoot", function(client, walk, run)
	if (NETWORK.trap.IsRooted(client)) then
		return 1, 1
	end
end)

local function CanPlace(client, data)
	if (NETWORK.trap.CanPlace) then
		return NETWORK.trap.CanPlace(client, data)
	end

	return true
end

local function RebelOnly(client)
	return NETWORK.trap.IsRebel(client)
end

NETWORK.deploy.Register("tripwire", {
	item = "tripwire_kit",
	class = "nw_tripwire",
	models = {
		"models/weapons/w_grenade.mdl",
		"models/items/grenadeammo.mdl",
		"models/props_junk/garbage_metalcan001a.mdl"
	},
	model = "models/props_junk/popcan01a.mdl",
	mount = "any",
	bTwoPoint = true,
	wireLength = 250,
	wireMin = 32,
	spacing = 24,
	time = 5,
	offset = 2,
	name = "deployTripwire",
	hint = "trapHintAnchor",
	hint2 = "trapHintWire",
	noAccess = "trapNoAccess",
	placeSound = "weapons/slam/mine_mode.wav",
	bNoMenu = true,
	bHidden = true,
	bLimited = true,
	CanUse = RebelOnly,
	CanPlace = CanPlace
})

NETWORK.deploy.Register("beartrap", {
	item = "beartrap",
	class = "nw_beartrap",
	models = {
		"models/props_junk/sawblade001a.mdl",
		"models/props_c17/trappropeller_blade.mdl"
	},
	model = "models/props_junk/popcan01a.mdl",
	mount = "floor",
	hullSize = 10,
	hullHeight = 12,
	spacing = 32,
	time = 4,
	offset = 1,
	name = "deployBeartrap",
	noAccess = "trapNoAccess",
	placeSound = "physics/metal/metal_box_impact_soft2.wav",
	bNoMenu = true,
	bHidden = true,
	bLimited = true,
	CanUse = RebelOnly,
	CanPlace = CanPlace
})

NETWORK.deploy.Register("ied", {
	item = "ied",
	class = "nw_ied",
	models = {

		"models/props_combine/combine_mine01.mdl",
		"models/props_junk/metal_paintcan001a.mdl",
		"models/props_junk/garbage_metalcan001a.mdl",
		"models/props_junk/popcan01a.mdl"
	},
	model = "models/props_junk/popcan01a.mdl",
	mount = "floor",
	hullSize = 14,
	hullHeight = 16,
	spacing = 40,
	time = 5,
	offset = 0,
	name = "deployIED",
	noAccess = "trapNoAccess",
	placeSound = "physics/metal/metal_canister_impact_soft1.wav",
	bNoMenu = true,
	bHidden = true,
	bLimited = true,
	CanUse = RebelOnly,
	CanPlace = CanPlace
})

NETWORK.deploy.Register("lasermine", {
	item = "lasermine",
	class = "nw_lasermine",
	models = {
		"models/props_combine/combinebutton.mdl",
		"models/props_combine/combine_mine01.mdl"
	},
	model = "models/props_combine/combine_mine01.mdl",
	mount = "wall",
	spacing = 24,
	time = 3,
	pickupTime = 2,
	offset = 1,
	name = "deployLasermine",
	placeSound = "buttons/combine_button1.wav",
	bHidden = true,
	bLimited = true,
	CanPlace = CanPlace
})

NETWORK.deploy.Register("hackedturret", {
	item = "hacked_turret_kit",
	class = "npc_turret_floor",
	model = "models/combine_turrets/floor_turret.mdl",
	time = 6,
	pickupTime = 4,
	offset = 0,
	name = "deployHackedTurret",
	noAccess = "trapNoAccess",
	labelForeign = "deployHackedForeign",
	bLimited = true,
	CanUse = RebelOnly,
	CanPlace = CanPlace,
	CanControl = function(client, entity)
		return client:IsAdmin() or NETWORK.trap.IsRebel(client)
	end,
	OnDeployed = function(entity, client)
		if (NETWORK.trap.MakeHacked) then
			NETWORK.trap.MakeHacked(entity, client, true)
		end
	end
})
