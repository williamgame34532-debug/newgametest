-- Background sounds of the city (hla_ambient_content: sound/hla/ambient/*). The server picks the next
-- sound and when it plays; every player hears the same sound at the same moment (net hla_amb).
-- hla_ambient 0 = off; hla_ambient_play <name or group> plays one now (admins).
util.AddNetworkString('hla_amb')
local cv = CreateConVar('hla_ambient', '1', {FCVAR_ARCHIVE}, 'City background sounds for everyone at once (0/1)')
local cvGap = CreateConVar('hla_ambient_gap', '35 90', {FCVAR_ARCHIVE}, 'Seconds between the background sounds: min max')

local function list(prefix, n, first)
	local t = {}
	for i = first or 1, n do t[#t + 1] = string.format(prefix, i) end
	return t
end
-- groups: files, weight, volume (0..1), length (s)
local GROUPS = {
	strider = {list('amb_c17_strider_distant_%02d.mp3', 16), 40, 0.75, 7},
	dropship = {{'amb_dropship_1.mp3', 'amb_dropship_2.mp3', 'amb_dropship_3.mp3'}, 16, 0.7, 18},
	alarm = {{'amb_c17_distant_alarm_01_l.mp3', 'amb_combine_alarm_distant_01.mp3', 'amb_combine_alarm_01.mp3', 'amb_basement_alarm.mp3'}, 10, 0.55, 7},
	cymbal = {list('amb_cymbal_high_%02d.mp3', 8), 12, 0.6, 13},
	chimes = {list('ambient_chimes_%d.mp3', 22), 14, 0.55, 19},
	manhack = {{'amb_manhack_alert.wav'}, 5, 0.6, 4},
}

local last
local function pick(group)
	local g = GROUPS[group]
	if not g then
		local total = 0
		for k, v in pairs(GROUPS) do if k ~= last then total = total + v[2] end end
		local r = math.random() * total
		for k, v in pairs(GROUPS) do
			if k ~= last then
				r = r - v[2]
				if r <= 0 then group, g = k, v break end
			end
		end
	end
	last = group
	return 'hla/ambient/' .. g[1][math.random(#g[1])], g[3], g[4]
end

local function play(group, to)
	local path, vol, len = pick(group)
	net.Start('hla_amb')
	net.WriteString(path)
	net.WriteFloat(vol)
	if to then net.Send(to) else net.Broadcast() end
	return len
end

local nextAt = CurTime() + 20
timer.Create('HLAAmbient', 1, 0, function()
	if not cv:GetBool() or #player.GetAll() == 0 or CurTime() < nextAt then return end
	local len = play()
	local mn, mx = string.match(cvGap:GetString(), '(%d+)%s+(%d+)')
	mn, mx = tonumber(mn) or 35, tonumber(mx) or 90
	nextAt = CurTime() + len + math.random(mn, math.max(mn, mx))
end)

concommand.Add('hla_ambient_play', function(p, _, args)
	if IsValid(p) and not p:IsAdmin() then return end
	local a = args[1]
	if a and not GROUPS[a] then
		net.Start('hla_amb') net.WriteString('hla/ambient/' .. a) net.WriteFloat(0.7) net.Broadcast()
	else
		play(a)
	end
end)
