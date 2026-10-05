NETWORK.blogextras = NETWORK.blogextras or {}

local B = NETWORK.blogextras

hook.Add("OnNPCKilled", "nwNoNpcWeapons", function(npc)
	if (!IsValid(npc)) then
		return
	end

	timer.Simple(0, function()
		if (!IsValid(npc)) then
			return
		end

		for _, weapon in ipairs(npc:GetWeapons() or {}) do
			if (IsValid(weapon)) then
				weapon:Remove()
			end
		end
	end)

	local position = npc:GetPos()

	timer.Simple(0.1, function()
		for _, entity in ipairs(ents.FindInSphere(position, 96)) do
			if (IsValid(entity) and entity:IsWeapon() and
				!IsValid(entity:GetOwner())) then
				entity:Remove()
			end
		end
	end)
end)

hook.Add("NetworkItemConsumed", "nwUseCooldown", function(client, base)
	if (!istable(base) or !base.useCooldown) then
		return
	end

	client.nwItemCooldown = client.nwItemCooldown or {}
	client.nwItemCooldown[base.id] = CurTime() + base.useCooldown
end)

function B.OnCooldown(client, id)
	local until_ = (client.nwItemCooldown or {})[id]

	return until_ != nil and until_ > CurTime() and math.ceil(until_ - CurTime())
end

NETWORK.config.Register("armourSteps", {
	name = "cfgArmourSteps",
	description = "cfgArmourStepsDesc",
	category = "world",
	type = "bool",
	default = false
})

B.stepSounds = {
	medium = {
		"physics/cardboard/cardboard_box_scrape_smooth_loop1.wav",
		"physics/body/body_medium_impact_soft1.wav"
	},
	heavy = {
		"physics/body/body_medium_impact_soft3.wav",
		"physics/body/body_medium_impact_soft6.wav"
	}
}

function B.ArmourClass(client)
	local state = NETWORK.inventory.GetState(client)
	local best = "light"

	for _, item in pairs((state or {}).equipped or {}) do
		local base = istable(item) and NETWORK.item.Get(item.id)

		if (!base) then
			continue
		end

		local kind = base.armourClass

		if (!kind) then
			if (base.category == "armour" or base.category == "armor") then
				kind = (base.weight or 0) >= 4 and "heavy" or "medium"
			end
		end

		if (kind == "heavy") then
			return "heavy"
		elseif (kind == "medium") then
			best = "medium"
		end
	end

	if (client:GetCharacterFaction() == "combine" or
		client:GetCharacterFaction() == "cmb") then
		return "heavy"
	end

	return best
end

hook.Add("PlayerFootstep", "nwArmourSteps", function(client, position, foot,
	soundName, volume)

	if (NETWORK.config.Get("armourSteps") != true) then
		return
	end

	if (!client:HasCharacter() or !client:Alive()) then
		return
	end

	local kind = B.ArmourClass(client)

	if (kind == "light") then
		return
	end

	local speed = client:GetVelocity():Length2D()

	if (speed < NETWORK.movement.runSpeed * 0.7) then
		return
	end

	local list = B.stepSounds[kind]

	client:EmitSound(list[math.random(#list)], kind == "heavy" and 62 or 55,
		math.random(92, 100), kind == "heavy" and 0.35 or 0.22, CHAN_AUTO)
end)
