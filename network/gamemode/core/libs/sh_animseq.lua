NETWORK.anim = NETWORK.anim or {}
NETWORK.anim.frames = NETWORK.anim.frames or {}
NETWORK.anim.sequenceSets = NETWORK.anim.sequenceSets or {}

NETWORK.anim.frames.metrocop = {
	normal = {

		idle = {"batonidle1", "batonidle2", "idle_baton"},
		idleRaised = {"batonangryidle1", "batonidle2"},
		walk = {"walk_hold_baton_angry", "walk_hold_pistol"},
		walkRaised = {"walk_hold_baton_angry"},
		run = {"run_hold_pistol", "run_hold_smg1"},
		runRaised = {"run_hold_pistol", "run_hold_smg1"},
		crouchIdle = {"crouch_all", "crouch_idle_pistol"},
		crouchWalk = {"cwalk_all", "cwalk_passive", "cwalk_pistol"}
	},
	pistol = {
		idle = {"pistolidle1", "pistolidle2"},
		idleRaised = {"pistolangryidle2", "pistol_aim_all", "man_gun_aim_all"},
		walk = {"walk_hold_pistol"},
		walkRaised = {"walk_aiming_pistol_all", "walkn_pistol_aim_all"},
		run = {"run_hold_pistol"},
		runRaised = {"run_aiming_pistol_all", "run_hold_pistol"},
		crouchIdle = {"crouch_idle_pistol", "crouch_all"},
		crouchWalk = {"cwalk_pistol", "cwalk_revolver", "cwalk_all"}
	},
	smg = {
		idle = {"smg1idle1", "smg1idle2"},
		idleRaised = {"smg1angryidle1", "smg1_aim_all", "man_gun_aim_all"},
		walk = {"walk_hold_smg1"},
		walkRaised = {"walk_aiming_smg1_all", "walkn_smg1_aim_all"},
		run = {"run_hold_smg1"},
		runRaised = {"run_aiming_smg1_all", "run_hold_smg1"},
		crouchIdle = {"crouch_idle_smg1", "crouch_all"},
		crouchWalk = {"cwalk_smg1", "cwalk_ar2", "cwalk_all"}
	},
	melee = {
		idle = {"batonidle1", "idle_baton"},
		idleRaised = {"batonangryidle1", "batonidle2"},
		walk = {"walk_hold_baton_angry"},
		walkRaised = {"walk_hold_baton_angry"},
		run = {"run_hold_pistol"},
		runRaised = {"run_hold_pistol"},
		crouchIdle = {"crouch_all"},
		crouchWalk = {"cwalk_melee", "cwalk_melee2", "cwalk_all"}
	}
}

NETWORK.anim.frames.metrocop.shotgun = NETWORK.anim.frames.metrocop.smg
NETWORK.anim.frames.metrocop.grenade = NETWORK.anim.frames.metrocop.normal

function NETWORK.anim.SetSequenceSet(model, set)
	NETWORK.anim.sequenceSets[string.lower(model)] = set
end

function NETWORK.anim.GetSequenceSet(model)
	if (!model) then
		return
	end

	return NETWORK.anim.sequenceSets[string.lower(model)]
end

local resolved = {}

local function Resolve(entity, model, setName, holdType)
	local key = model .. "|" .. setName .. "|" .. holdType
	local cache = resolved[key]

	if (cache != nil) then
		return cache or nil
	end

	local set = NETWORK.anim.frames[setName]
	local states = set and (set[holdType] or set.normal)

	if (!states) then
		resolved[key] = false

		return
	end

	local frames = {}
	local bAny = false

	for state, candidates in pairs(states) do
		for _, name in ipairs(candidates) do
			local sequence = entity:LookupSequence(name)

			if (sequence and sequence > 0) then
				frames[state] = name
				bAny = true

				break
			end
		end
	end

	if (!bAny) then
		resolved[key] = false

		return
	end

	resolved[key] = frames

	return frames
end

function NETWORK.anim.GetSequenceTree(client, holdType, repairedBase)
	local model = client.nwAnimModel

	if (!model) then
		return
	end

	local setName = NETWORK.anim.GetSequenceSet(model)

	if (!setName) then
		return
	end

	holdType = holdType or "normal"

	local frames = Resolve(client, string.lower(model), setName, holdType)

	if (!frames) then
		return
	end

	local base = (istable(repairedBase) and client.nwAnimClass == setName and
		repairedBase) or NETWORK.anim[setName] or {}
	local source = base[holdType] or base.normal or {}
	local tree = {}

	for key, value in pairs(source) do
		tree[key] = value
	end

	local function Put(activity, lowered, raised)
		if (!lowered and !raised) then
			return
		end

		local previous = tree[activity]

		tree[activity] = {
			lowered or raised or (previous and previous[1]),
			raised or lowered or (previous and previous[2])
		}
	end

	Put(ACT_MP_STAND_IDLE, frames.idle, frames.idleRaised)
	Put(ACT_MP_WALK, frames.walk, frames.walkRaised)
	Put(ACT_MP_RUN, frames.run, frames.runRaised)
	Put(ACT_MP_CROUCH_IDLE, frames.crouchIdle, frames.crouchIdle)
	Put(ACT_MP_CROUCHWALK, frames.crouchWalk, frames.crouchWalk)

	return tree
end

NETWORK.anim.SetSequenceSet("models/networkcp.mdl", "metrocop")

NETWORK.anim.SetSequenceSet("models/police.mdl", "metrocop")

if (CLIENT) then

	concommand.Add("network_anim_dump", function(client, command, arguments)
		local entity = LocalPlayer()

		if (arguments[1] == "look") then
			entity = LocalPlayer():GetEyeTrace().Entity
		end

		if (!IsValid(entity)) then
			NETWORK.util.PrintWarning("Не на что смотреть.")

			return
		end

		local model = entity:GetModel()
		local list = entity:GetSequenceList() or {}

		NETWORK.util.Print("Модель: " .. tostring(model))
		NETWORK.util.Print("Кадров: " .. #list)

		local markers = {"pose_standing_01", "menu_combine", "swimming_all",
			"idle_all_01", "cwalk_all", "taunt_dance"}
		local found = {}

		for _, name in ipairs(markers) do
			if ((entity:LookupSequence(name) or -1) > 0) then
				found[#found + 1] = name
			end
		end

		if (#found > 0) then
			NETWORK.util.PrintWarning("Набор игрока включён в модель: " ..
				table.concat(found, ", "))
		else
			NETWORK.util.Print("Набор игрока в модели не найден.")
		end

		local setName = NETWORK.anim.GetSequenceSet(model)

		if (setName) then
			NETWORK.util.Print("Набор кадров: " .. setName)

			local set = NETWORK.anim.frames[setName] or {}

			for holdType, states in SortedPairs(set) do
				MsgC(Color(150, 200, 255), "  " .. holdType .. "\n")

				for state, candidates in SortedPairs(states) do
					local picked

					for _, name in ipairs(candidates) do
						if ((entity:LookupSequence(name) or -1) > 0) then
							picked = name

							break
						end
					end

					MsgC(picked and Color(140, 210, 150) or Color(220, 140, 120),
						string.format("    %-12s %s\n", state,
							picked or "нет — останется кадр игрока"))
				end
			end
		end

		for index, name in ipairs(list) do
			MsgC(Color(200, 204, 208), string.format("  [%3d] %s\n", index - 1, name))
		end
	end)
end
