NETWORK.weapon = NETWORK.weapon or {}

NETWORK.weapon.raiseTime = 1.4
NETWORK.weapon.alwaysRaised = {
	gmod_tool = true,
	gmod_camera = true,
	weapon_physgun = true
}

NETWORK.weapon.hands = "weapon_nwhands"

local PLAYER = FindMetaTable("Player")

function PLAYER:IsWeaponRaised()
	local weapon = self:GetActiveWeapon()

	if (IsValid(weapon)) then
		if (NETWORK.weapon.alwaysRaised[weapon:GetClass()]) then
			return true
		end

		if (CLIENT and weapon.IsSafety and weapon:IsSafety()) then
			return false
		end
	end

	return self:GetNWBool("nwRaised", false)
end

function PLAYER:GetRaiseProgress()
	local start = self:GetNWFloat("nwRaiseStart", 0)

	if (start <= 0) then
		return 0
	end

	return math.Clamp((CurTime() - start) / NETWORK.weapon.raiseTime, 0, 1)
end
