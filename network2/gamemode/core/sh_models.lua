-- Player models: the build's characters with their animation libraries, plus every model
-- player_manager knows. The choice lives in client convars (nw_model, nw_skin, nw_bodygroups)
-- so it survives reconnects; the server only accepts models from the lists below and applies
-- them on every spawn. Originals of patched models (WN citizens, networkcp, nemez soldiers) are
-- swapped for our copies under models/network/..., which carry the animations.

NW.models = NW.models or {}

local M = NW.models

-- {path, animation class, hands, display name}
M.list = {
	{category = "Альянс", "models/network/combine/grunt.mdl", "overwatch", "combine", "Грант"},
	{category = "Альянс", "models/network/combine/commander.mdl", "overwatch", "commander", "Командир"},
	{category = "Альянс", "models/network/combine/nemez/combine_soldier_h.mdl", "overwatch", "combine",
		"Солдат (nemez)"},
	{category = "Альянс", "models/network/combine/nemez/combine_soldier_elite_h.mdl", "overwatch", "combine",
		"Элита (nemez)"},
	{category = "Альянс", "models/synapse/combine/combine_soldier_h.mdl", "overwatch", "combine", "Солдат ОТА"},
	{category = "Гражданская оборона", "models/network/cp/networkcp.mdl", "metrocop", "cp", "Офицер ГО"}
}

for i = 1, 10 do
	local name = string.format("male%02d", i)

	M.list[#M.list + 1] = {category = "Граждане", "models/network/citizens/" .. name .. ".mdl", "citizen_male",
		"citizen", "Мужчина " .. i}
end

for _, i in ipairs({1, 2, 3, 4, 6, 7}) do
	local name = string.format("female_%02d", i)

	M.list[#M.list + 1] = {category = "Граждане", "models/network/citizens/" .. name .. ".mdl",
		"citizen_female", "citizen", "Женщина " .. i}
end

M.hands = {
	combine = {"models/weapons/c_arms_combine.mdl", 0, "00000000"},
	commander = {"models/network/combine/commander_hands.mdl", 0, "00000000"},
	cp = {"models/network/cp/networkcp_arms.mdl", 0, "00000000"},
	citizen = {"models/weapons/c_arms_citizen.mdl", 0, "00000000"}
}

-- originals -> our copies with the animations
M.remap = {
	["models/networkcp.mdl"] = "models/network/cp/networkcp.mdl",
	["models/nemez/combine_soldiers/combine_soldier_h.mdl"] = "models/network/combine/nemez/combine_soldier_h.mdl",
	["models/nemez/combine_soldiers/combine_soldier_elite_h.mdl"] =
		"models/network/combine/nemez/combine_soldier_elite_h.mdl"
}

-- the HL:A Combine of the Workshop (synapse) -> our grunt / commander with the animations
M.remap["models/synapse/hl_a/combine_grunt/npc/combine_grunt.mdl"] = "models/network/combine/grunt.mdl"
M.remap["models/synapse/combine/combine_grunt.mdl"] = "models/network/combine/grunt.mdl"
M.remap["models/synapse/hl_a/combine_commander/npc/combine_commander.mdl"] = "models/network/combine/commander.mdl"

for _, name in ipairs({"male01", "male02", "male03", "male04", "male05", "male06", "male07", "male08",
	"male09", "male10", "female_01", "female_02", "female_03", "female_04", "female_06", "female_07"}) do
	M.remap["models/willardnetworks/citizens/" .. name .. ".mdl"] = "models/network/citizens/" .. name .. ".mdl"
end

-- one sequence per class that only the build's animation libraries have
M.probe = {
	overwatch = "nw_ota_pistol_aim",
	metrocop = "nw_hla_idle_01",
	citizen_male = "nw_civ_idle",
	citizen_female = "nw_civ_idle"
}

M.byPath = {}

for _, entry in ipairs(M.list) do
	local path, class, hands, title = entry[1], entry[2], entry[3], entry[4]
	local id = "nw_" .. string.gsub(string.GetFileFromFilename(path), "%.mdl$", "")

	if (string.find(path, "nemez", 1, true)) then
		id = id .. "_nemez"
	end

	M.byPath[path] = entry
	NW.anim.SetModelClass(path, class)

	player_manager.AddValidModel(id, path)

	local hand = M.hands[hands]

	if (hand) then
		player_manager.AddValidHands(id, hand[1], hand[2], hand[3])
	end

	list.Set("PlayerOptionsModel", id, path)
	entry.id = id
	entry.title = title
end

for original, copy in pairs(M.remap) do
	local entry = M.byPath[copy]

	if (entry) then
		NW.anim.SetModelClass(original, entry[2])
	end
end

local exists = {}

local function Exists(path)
	if (exists[path] == nil) then
		exists[path] = file.Exists(path, "GAME")
	end

	return exists[path]
end

-- the model a player actually gets: our copy when the original was asked for and the copy exists
function M.Resolve(path)
	path = string.lower(string.Trim(path or ""))

	local copy = M.remap[path]

	if (copy and Exists(copy)) then
		return copy
	end

	return path
end

function M.IsAllowed(path)
	path = string.lower(path or "")

	if (M.byPath[path] or M.remap[path]) then
		return true
	end

	for _, model in pairs(player_manager.AllValidModels()) do
		if (string.lower(model) == path) then
			return true
		end
	end

	return false
end

if (CLIENT) then
	CreateClientConVar("nw_model", "models/network/citizens/male01.mdl", true, true, "Модель игрока")
	CreateClientConVar("nw_skin", "0", true, true, "Скин модели")
	CreateClientConVar("nw_bodygroups", "", true, true, "Бодигруппы модели (через запятую)")

	return
end

local DEFAULT = "models/network/citizens/male01.mdl"

local function Apply(client)
	-- a loaded character decides the model (sv_character.lua)
	local character = client.nwCharacter

	if (character) then
		-- a faction with its own model (Civil Protection, Combine) dresses everyone in it
		-- /setmodel of an admin wins over everything (sv_character.lua)
		local faction = NW.char.factions[character.faction or ""]
		local override = character.data and character.data.model

		-- the class of the character (sh_classes.lua): its model, the one picked of them
		local class = NW.classes and NW.classes.Of(client)
		local models = class and NW.classes.Models(class) or {}
		local classModel = models[character.data and character.data.classModel or 1] or models[1]

		local model = M.Resolve(override or classModel or (faction and faction.model) or character.model)

		client:SetModel(util.IsValidModel(model) and model or DEFAULT)
		client:SetSkin(math.Clamp(class and class.skin or character.skin or 0, 0, math.max(client:SkinCount() - 1, 0)))

		for index = 0, client:GetNumBodyGroups() - 1 do
			client:SetBodygroup(index, 0)
		end

		client:SetupHands()

		timer.Simple(0, function()
			if (IsValid(client)) then
				NW.anim.Refresh(client)
			end
		end)

		-- the clothes in the inventory (sv_inventory.lua)
		hook.Run("NWModelApplied", client)

		return
	end

	local wanted = client:GetInfo("nw_model")

	if (!M.IsAllowed(wanted)) then
		wanted = DEFAULT
	end

	local model = M.Resolve(wanted)

	if (!util.IsValidModel(model)) then
		model = util.IsValidModel(DEFAULT) and DEFAULT or "models/player/kleiner.mdl"
	end

	client:SetModel(model)
	client:SetSkin(math.Clamp(client:GetInfoNum("nw_skin", 0), 0, math.max(client:SkinCount() - 1, 0)))

	local groups = string.Explode(",", client:GetInfo("nw_bodygroups") or "")

	for index = 0, client:GetNumBodyGroups() - 1 do
		local value = tonumber(groups[index + 1]) or 0

		client:SetBodygroup(index, math.Clamp(value, 0, math.max(client:GetBodygroupCount(index) - 1, 0)))
	end

	client:SetupHands()

	-- tell the player when the model has no animation library of the build (not installed /
	-- an original that is not ours)
	timer.Simple(0.5, function()
		if (!IsValid(client)) then
			return
		end

		local class = NW.anim.GetModelClass(client:GetModel())
		local probe = M.probe[class]

		if (probe and (client:LookupSequence(probe) or -1) <= 0) then
			client:ChatPrint("[Network] У модели " .. client:GetModel() .. " нет анимаций сборки (" .. probe ..
				"). Установите архивы network_models и возьмите модель из меню F1.")
		end
	end)

	timer.Simple(0, function()
		if (IsValid(client)) then
			NW.anim.Refresh(client)
			hook.Run("PlayerModelChanged", client, model)
		end
	end)
end

M.Apply = Apply

function GM:PlayerSetModel(client)
	Apply(client)
end

-- change the model right away (from the menu)
concommand.Add("nw_model_apply", function(client)
	if (!IsValid(client) or !client:Alive()) then
		return
	end

	-- with characters the model belongs to the character; the free model menu is for admins
	if (client.nwCharacter and !client:IsSuperAdmin()) then
		return
	end

	if ((client.nwModelNext or 0) > CurTime()) then
		return
	end

	client.nwModelNext = CurTime() + 1

	-- the convars of the command arrive with the same packet; wait one tick
	timer.Simple(0.2, function()
		if (IsValid(client)) then
			Apply(client)
		end
	end)
end)
