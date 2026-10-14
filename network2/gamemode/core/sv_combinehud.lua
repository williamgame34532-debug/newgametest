-- The Alliance HUD (cl_combinehud.lua), server side: a member of the Alliance dies - every member of
-- the Alliance gets "UNIT DOWN AT LOCATION :: <zone>" in red with the name.

util.AddNetworkString("nwUnitDown")

hook.Add("PlayerDeath", "nwUnitDown", function(victim)
	if (!IsValid(victim) or victim:GetCharacterID() == 0 or !NW.zones.IsAlliance(victim)) then
		return
	end

	local zone = NW.zones.At(NW.zones.Point(victim))
	local members = {}

	for _, member in ipairs(player.GetAll()) do
		if (member:GetCharacterID() != 0 and NW.zones.IsAlliance(member)) then
			members[#members + 1] = member
		end
	end

	net.Start("nwUnitDown")
		net.WriteString(victim:Nick())
		net.WriteString(zone and zone.name or "неизвестно")
	net.Send(members)
end)
