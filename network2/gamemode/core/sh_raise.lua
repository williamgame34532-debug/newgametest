-- Safety. Every weapon is on safety when it is taken out: the model carries it (lowered
-- stance, living idles, the pistol in a two-handed low ready) and it does not fire. Holding R
-- for a moment takes the safety off - the weapon comes up into the normal armed stance - and
-- holding R again puts it back on. Short R presses still reload. (The key: sh_keys.lua.)
-- Tools, the physics gun, the camera and SWEPs with SWEP.IsAlwaysRaised have no safety. SWEP.HasSafety
-- forces it on or off (the hands, nw_hands, have it: lowered they only carry and knock, raised
-- they punch). The change is animated: the old stance fades into the new one, the view model
-- comes up or is lowered (always seen). nw_safety 0 turns the whole system off (everything always up).

local meta = FindMetaTable("Player")

local safety = CreateConVar("nw_safety", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED},
	"Предохранитель: оружие достаётся на предохранителе, зажатая R снимает его")

local ALWAYS = {
	gmod_tool = true,
	weapon_physgun = true,
	weapon_physcannon = true,
	gmod_camera = true,
	weapon_medkit = true
}

-- TFA weapons (tfa_*) have a safety of their own (Shift + E + R): ours stays out of their way, and
-- with the TFA safety on the model carries the weapon lowered (the view model stays as TFA draws it)
local function IsTFA(weapon)
	return IsValid(weapon) and (weapon.IsTFAWeapon == true or string.sub(weapon:GetClass(), 1, 4) == "tfa_")
end

local function TFASafety(weapon)
	if (isfunction(weapon.IsSafety)) then
		return weapon:IsSafety() == true
	elseif (isfunction(weapon.GetSafety)) then
		return weapon:GetSafety() == true
	end

	return false
end

NW.IsTFA = IsTFA

local function HasSafety(weapon)
	if (!IsValid(weapon) or ALWAYS[weapon:GetClass()] or weapon.IsAlwaysRaised or IsTFA(weapon)) then
		return false
	end

	if (weapon.HasSafety != nil) then
		return weapon.HasSafety == true
	end

	local hold = weapon.HoldType or weapon:GetHoldType()

	return hold != "normal" and hold != "fist" and hold != ""
end

NW.HasSafety = HasSafety

function meta:IsWeaponRaised()
	local weapon = self:GetActiveWeapon()

	if (!IsValid(weapon)) then
		return false
	end

	if (IsTFA(weapon)) then
		return !TFASafety(weapon)
	end

	if (!safety:GetBool() or !HasSafety(weapon)) then
		local hold = weapon.HoldType or weapon:GetHoldType()

		-- empty hands stay relaxed
		return hold != "normal" and hold != "fist" and hold != ""
	end

	return self:GetNW2Bool("nwRaised", false)
end

function meta:IsSafetyOn()
	return safety:GetBool() and HasSafety(self:GetActiveWeapon()) and !self:GetNW2Bool("nwRaised", false)
end

if (SERVER) then
	function meta:SetWeaponRaised(bRaised)
		bRaised = tobool(bRaised)

		if (self:GetNW2Bool("nwRaised", false) == bRaised) then
			return
		end

		self:SetNW2Bool("nwRaised", bRaised)
		self.nwRaiseBlock = CurTime() + 0.35

		local weapon = self:GetActiveWeapon()

		if (HasSafety(weapon)) then
			-- the view model comes up; going on safety it is only lowered (cl_thirdperson.lua), never put away
			local action = bRaised and (weapon.RaiseActivity or ACT_VM_DRAW) or weapon.LowerActivity

			if (action) then
				weapon:SendWeaponAnim(action)
			end
		end

		if (HasSafety(weapon) and !weapon.SafetySilent) then
			self:EmitSound(bRaised and "weapons/smg1/switch_single.wav" or "weapons/smg1/switch_burst.wav", 55,
				bRaised and 105 or 95, 0.6)
		end

		hook.Run("NWWeaponRaised", self, bRaised)
	end

	function meta:ToggleWeaponRaised()
		self:SetWeaponRaised(!self:GetNW2Bool("nwRaised", false))
	end

	concommand.Add("nw_safety_toggle", function(client)
		if (IsValid(client)) then
			client:ToggleWeaponRaised()
		end
	end)

	-- a weapon always comes out on safety, with the equip sound
	hook.Add("PlayerSwitchWeapon", "nwSafety", function(client, old, new)
		client:SetNW2Bool("nwRaised", false)

		if (IsValid(new) and new != old and HasSafety(new) and !new.SafetySilent) then
			-- gear being handled (Kenney RPG Audio, CC0)
			client:EmitSound("network2/inv/belt_handle" .. math.random(1, 2) .. ".wav", 60, math.random(96, 104), 0.75)
		end
	end)

	hook.Add("PlayerSpawn", "nwSafety", function(client)
		client:SetNW2Bool("nwRaised", false)
	end)

	-- hold R
	hook.Add("PlayerButtonDown", "nwSafety", function(client, button)
		if (button != NW.keys.Get("safety", client) or !HasSafety(client:GetActiveWeapon())) then
			return
		end

		client.nwSafetyHeld = true

		timer.Create("nwSafety" .. client:EntIndex(), 0.45, 1, function()
			if (IsValid(client) and client.nwSafetyHeld) then
				client:ToggleWeaponRaised()
			end
		end)
	end)

	hook.Add("PlayerButtonUp", "nwSafety", function(client, button)
		if (button == NW.keys.Get("safety", client)) then
			client.nwSafetyHeld = false
		end
	end)
end

-- on safety the weapon does not fire (or reload); right after the switch neither, so the
-- R hold or a held trigger does not go off by itself
hook.Add("StartCommand", "nwSafety", function(client, command)
	if (client:IsSafetyOn()) then
		local weapon = client:GetActiveWeapon()

		-- lowered hands still carry, throw what they hold and knock
		if (weapon.FireWhenLowered) then
			if (!client:GetNW2Bool("nwHoldingObject", false)) then
				command:RemoveKey(IN_ATTACK)
			end
		else
			command:RemoveKey(IN_ATTACK)
			command:RemoveKey(IN_ATTACK2)
		end

		return
	end

	if ((client.nwRaiseBlock or 0) > CurTime()) then
		command:RemoveKey(IN_ATTACK)
		command:RemoveKey(IN_ATTACK2)
		command:RemoveKey(IN_RELOAD)
	end
end)

-- a weapon on safety stays in the view model, lowered and turned aside (cl_thirdperson.lua,
-- GM:CalcViewModelView): the hands and the weapon are always seen in first person
