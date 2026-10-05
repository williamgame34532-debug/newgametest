NETWORK.chgen = NETWORK.chgen or {}

local enabled = CreateClientConVar("network_chgen", "1", true, false,
	"Руки в первом лице от модели персонажа")
local longArms = CreateClientConVar("network_chgen_long", "0", true, false,
	"Руки от ключиц (1), а не от плеч (0)")

local handsRootLong = {
	["ValveBiped.Bip01_R_Clavicle"] = true,
	["ValveBiped.Bip01_L_Clavicle"] = true
}

local handsRoot = {
	["ValveBiped.Bip01_R_UpperArm"] = true,
	["ValveBiped.Bip01_L_UpperArm"] = true
}

local state = {
	model = "",
	skin = 0,
	bodygroups = {},
	time = CurTime(),
	bBoneDraw = false,
	bForceReload = false,
	rootBones = {},
	handBones = {}
}

local function GetAllChildBones(entity, bone)
	local result = {}
	local bones = entity:GetChildBones(bone)
	local lastBranch = bone

	for i = 1, #bones do
		local child = bones[i]
		local lastBone = child

		result[entity:GetBoneName(child)] = true

		for j = 0, entity:GetBoneCount() - 1 do
			local parent = entity:GetBoneParent(j)

			if (parent == lastBone or parent == lastBranch or
				result[entity:GetBoneName(parent)]) then
				local tree = entity:GetChildBones(j)

				result[entity:GetBoneName(j)] = true
				lastBone = j

				if (tree and #tree > 1) then
					lastBranch = j
				end
			end
		end
	end

	return result
end

local function GetDefaultHands(client)
	local modelName = player_manager.TranslateToPlayerModelName(client:GetModel())
	local data = player_manager.TranslatePlayerHands(modelName)

	if (!istable(data)) then
		return
	end

	return {
		model = tostring(data.model or "models/weapons/c_arms_citizen.mdl"),
		skin = tonumber(data.skin) or 0,
		body = tostring(data.body or "0000000")
	}
end

function NETWORK.chgen.Reload()
	state.bForceReload = true
end

function NETWORK.chgen.Draw(hands)
	local client = LocalPlayer()

	if (!IsValid(client) or !IsValid(hands)) then
		return
	end

	if (state.time != CurTime()) then
		hands:SetModel(hands:GetModel())
	end

	local skin = client:GetSkin()
	local bSkinChanged = state.skin != skin
	local bGroupsChanged = false

	for i = 0, client:GetNumBodyGroups() - 1 do
		if (state.bodygroups[i] != client:GetBodygroup(i)) then
			bGroupsChanged = true

			break
		end
	end

	if (state.bForceReload or state.model != hands:GetModel() or bSkinChanged or bGroupsChanged) then
		state.bForceReload = false
		state.bBoneDraw = false
		state.rootBones = longArms:GetBool() and handsRootLong or handsRoot
		state.handBones = {}

		hands:SetModel(client:GetModel())
		hands:SetSkin(skin)

		if (client.GetPlayerColor) then
			local color = client:GetPlayerColor()

			if (isvector(color)) then
				hands:SetColor(color:ToColor())
			end
		end

		for i = 0, client:GetNumBodyGroups() - 1 do
			if (hands:GetBodygroupCount(i) > 0) then
				hands:SetBodygroup(i, client:GetBodygroup(i))
			end
		end

		local bHasRoot = false

		for i = 0, hands:GetBoneCount() - 1 do
			if (state.rootBones[hands:GetBoneName(i)]) then
				bHasRoot = true

				break
			end
		end

		if (!bHasRoot) then

			local default = GetDefaultHands(client)

			if (default) then
				hands:SetModel(default.model)
				hands:SetSkin(default.skin)
				hands:SetBodyGroups(default.body)
			end
		else
			for i = 0, hands:GetBoneCount() - 1 do
				local name = hands:GetBoneName(i)

				if (state.rootBones[name]) then
					state.handBones[name] = true

					table.Merge(state.handBones, GetAllChildBones(hands, i))
				end
			end

			state.bBoneDraw = true
		end

		state.model = hands:GetModel()
		state.skin = skin

		for i = 0, client:GetNumBodyGroups() - 1 do
			state.bodygroups[i] = client:GetBodygroup(i)
		end
	end

	if (state.bBoneDraw) then
		local nan = 0 / 0
		local hidden = Vector(nan, nan, nan)

		for i = 0, hands:GetBoneCount() - 1 do
			if (!state.handBones[hands:GetBoneName(i)]) then
				hands:ManipulateBoneScale(i, hidden)
			else
				hands:ManipulateBoneScale(i, Vector(1, 1, 1))
			end
		end

		hands:DrawModel()

		state.time = CurTime()
	else
		hands:DrawModel()
	end
end

hook.Add("PreDrawPlayerHands", "nwChgen", function(hands, viewModel, client, weapon)
	state.calls = (state.calls or 0) + 1

	if (!enabled:GetBool() or !IsValid(client) or !client:HasCharacter()) then
		return
	end

	NETWORK.chgen.Draw(hands)

	return true
end)

concommand.Add("network_chgen_status", function()
	local client = LocalPlayer()
	local hands = IsValid(client) and client:GetHands()

	print("[Network] chgen: включён " .. tostring(enabled:GetBool()) ..
		", вызовов PreDrawPlayerHands " .. tostring(state.calls or 0))
	print("[Network] chgen: руки " .. (IsValid(hands) and hands:GetModel() or "нет сущности") ..
		", модель игрока " .. (IsValid(client) and client:GetModel() or "?"))
	print("[Network] chgen: по костям " .. tostring(state.bBoneDraw) .. ", костей рук " ..
		tostring(table.Count(state.handBones or {})))
end)

hook.Add("NetworkInventoryUpdated", "nwChgen", function()
	NETWORK.chgen.Reload()
end)

cvars.AddChangeCallback("network_chgen_long", function()
	NETWORK.chgen.Reload()
end, "nwChgen")

cvars.AddChangeCallback("network_chgen", function(_, _, value)
	local client = LocalPlayer()
	local hands = IsValid(client) and client:GetHands()

	if (IsValid(hands) and tobool(value) == false) then
		local default = GetDefaultHands(client)

		if (default) then
			hands:SetModel(default.model)
			hands:SetSkin(default.skin)
			hands:SetBodyGroups(default.body)
		end

		for i = 0, hands:GetBoneCount() - 1 do
			hands:ManipulateBoneScale(i, Vector(1, 1, 1))
		end
	end

	NETWORK.chgen.Reload()
end, "nwChgenToggle")

NETWORK.option.Register("chgen", {
	name = "settingChgen",
	description = "settingChgenDesc",
	category = "view",
	type = "bool",
	convar = "network_chgen",
	default = true
})
