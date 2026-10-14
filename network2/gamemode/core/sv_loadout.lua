-- What a player gets on spawn: the hands (nw_hands) and the weapons equipped in the inventory.
-- Superadmins also get the physics gun and the tool gun for building. No sandbox weapon pile.

function GM:PlayerLoadout(client)
	client:StripWeapons()
	client:Give("nw_hands")

	if (client:IsSuperAdmin()) then
		client:Give("weapon_physgun")
		client:Give("gmod_tool")
	end

	-- weapons that sit in the equipment slots of the inventory
	hook.Run("NWPlayerLoadout", client)

	client:SelectWeapon("nw_hands")

	return true
end
