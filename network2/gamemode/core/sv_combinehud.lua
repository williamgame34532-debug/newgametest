-- The Alliance HUD (cl_combinehud.lua), server side: a member of the Alliance dies - every member of
-- the Alliance gets "ПОТЕРЯ БИО-СИГНАЛА :: <зона>" in red with the name.

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

	local where = zone and zone.name or "неизвестно"

	net.Start("nwUnitDown")
		net.WriteString(victim:Nick())
		net.WriteString(where)
	net.Send(members)

	-- the dispatcher, to the Alliance only
	NW.Dispatch("[ПАТРУЛЬ] Потеря био-сигнала юнита: " .. victim:Nick() .. ", в зоне: " .. where, members)

	-- the Overwatch voice: "lost biosignal for unit" and the callsign, if the unit has one
	local data = victim.nwCharacter and victim.nwCharacter.data
	local side = NW.units.Side(victim:GetFaction())
	local voice = {"npc/overwatch/radiovoice/lostbiosignalforunit.wav"}

	if (data and data.callsignSide == side) then
		table.Add(voice, NW.units.VoiceFor(side, data.callsign))
	end

	NW.units.Voice(members, voice)
end)
