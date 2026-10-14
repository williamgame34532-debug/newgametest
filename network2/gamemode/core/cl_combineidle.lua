-- Living idle for armed Combine soldiers. The rifle / SMG idles of combine_soldier_anims are
-- frozen statues; nw_combine_anims.mdl (included by the grunt and commander models) carries
-- additive layers retargeted from CC0 motion clips: breathing, weight shifts and glances of
-- the pelvis, spine, neck, head and legs only. Played on a gesture slot over the stock idle,
-- they leave the arms, and so the weapon hold, exactly as the base animation has them.
-- Unarmed and lowered-weapon stances use full-body HL:A sequences instead (sh_act.lua /
-- sh_anims.lua); this layer only plays over the raised (aiming) stance.

NW.combineIdle = NW.combineIdle or {}

local C = NW.combineIdle

C.layers = {"nw_layer_relaxed", "nw_layer_listen"}
C.range = 1600 * 1600
C.slot = GESTURE_SLOT_VCD

-- hold types that keep the stock armed idle and get the layer on top
C.armed = {smg = true, ar2 = true, shotgun = true, rpg = true, crossbow = true, physgun = true, revolver = true}

local available = {}

local function Layers(entity)
	local model = entity:GetModel() or ""
	local list = available[model]

	if (!list) then
		list = {}

		for _, name in ipairs(C.layers) do
			local sequence = entity:LookupSequence(name)

			if (sequence and sequence > 0) then
				list[#list + 1] = sequence
			end
		end

		available[model] = list
	end

	return list
end

function C.HasLayers(entity)
	return IsValid(entity) and #Layers(entity) > 0
end

local function Still(client)
	if (!client:Alive() or !client:IsOnGround() or client:Crouching() or client:InVehicle() or
		client:GetMoveType() == MOVETYPE_NOCLIP) then
		return false
	end

	if (client:GetVelocity():Length2DSqr() > 20 * 20) then
		return false
	end

	-- own living stances (nw_*) move by themselves
	local name = client:GetSequenceName(client:GetSequence()) or ""

	if (string.sub(name, 1, 3) == "nw_") then
		return false
	end

	local weapon = client:GetActiveWeapon()

	-- lowered weapons already play the full-body HL:A idles (nw_hla_idle_smg*); the layer only
	-- livens up the stock aiming stance
	if (!IsValid(weapon) or !client:IsWeaponRaised()) then
		return false
	end

	return C.armed[weapon.HoldType or weapon:GetHoldType()] == true
end

local nextThink = 0

hook.Add("Think", "nwCombineIdle", function()
	local now = CurTime()

	if (now < nextThink) then
		return
	end

	nextThink = now + 0.1

	local eye = EyePos()

	for _, client in ipairs(player.GetAll()) do
		if (client:IsDormant() or client:GetPos():DistToSqr(eye) > C.range) then
			continue
		end

		local layers = Layers(client)

		if (#layers == 0) then
			continue
		end

		if (!Still(client)) then
			if (client.nwIdleLayerUntil) then
				client:AnimResetGestureSlot(C.slot)
				client.nwIdleLayerUntil = nil
			end

			client.nwIdleLayerNext = now + 0.8

			continue
		end

		if (now < (client.nwIdleLayerNext or 0)) then
			continue
		end

		local sequence = layers[math.random(#layers)]

		client:AddVCDSequenceToGestureSlot(C.slot, sequence, 0, true)

		local duration = client:SequenceDuration(sequence)

		client.nwIdleLayerUntil = now + duration
		client.nwIdleLayerNext = now + duration + math.Rand(0.2, 1.5)
	end
end)
