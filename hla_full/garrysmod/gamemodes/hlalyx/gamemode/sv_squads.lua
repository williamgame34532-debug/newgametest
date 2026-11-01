-- Squads (server): kept in memory while the server runs; actions come from a terminal screen.
local SQ = HLA.Squads
util.AddNetworkString('hla_squads')
util.AddNetworkString('hla_squad_do')

local function send(to)
	net.Start('hla_squads')
	net.WriteUInt(SQ.Count(), 4)
	for id, s in pairs(SQ.list) do
		net.WriteUInt(id, 4)
		net.WriteString(s.name)
		net.WriteEntity(s.leader)
		net.WriteUInt(#s.members, 4)
		for _, m in ipairs(s.members) do net.WriteEntity(m) end
	end
	if to then net.Send(to) else net.Broadcast() end
end
SQ.Send = send

local function clean(s)
	for i = #s.members, 1, -1 do
		if not IsValid(s.members[i]) or s.members[i]:GetNWInt('hla_squad', 0) ~= s.id then table.remove(s.members, i) end
	end
	if #s.members == 0 then SQ.list[s.id] = nil return end
	if not IsValid(s.leader) or not table.HasValue(s.members, s.leader) then s.leader = s.members[1] end
end

function SQ.Leave(p, quiet)
	local s = SQ.Of(p)
	p:SetNWInt('hla_squad', 0)
	if s then
		clean(s)
		if not quiet then p:ChatPrint('Вы покинули ' .. s.name) end
		send()
	end
end

function SQ.Join(p, id)
	local s = SQ.list[id]
	if not s or #s.members >= SQ.MaxMembers then return false end
	if SQ.Of(p) == s then return true end
	SQ.Leave(p, true)
	p:SetNWInt('hla_squad', id)
	s.members[#s.members + 1] = p
	clean(s)
	-- the dispatcher announces it on the squad's channel: «Отряд: "…" — ЭХО-443 вступил в отряд», reading the number
	local name = p:GetNWString('hla_name', p:Nick())
	local num = string.match(name, '(%d+)%s*$') or ''
	local rv = HLA.RadioVoicePath
	local DIG = {['0'] = 'zero', ['1'] = 'one', ['2'] = 'two', ['3'] = 'three', ['4'] = 'four', ['5'] = 'five', ['6'] = 'six', ['7'] = 'seven', ['8'] = 'eight', ['9'] = 'nine'}
	local seq = {rv('on1'), rv('attention')}
	for d in string.gmatch(num, '%d') do seq[#seq + 1] = rv(DIG[d]) end
	seq[#seq + 1] = rv('inprogress')
	seq[#seq + 1] = rv('off4')
	local to = {}
	for _, m in ipairs(s.members) do if IsValid(m) then to[#to + 1] = m end end
	if HLA.Chat and HLA.Chat.Dispatch then
		HLA.Chat.Dispatch('Отряд: «' .. s.name .. '» — ' .. name .. ' вступил в отряд.', table.concat(seq, ';'), 'ДИСПЕТЧЕР', to)
	end
	send()
	return true
end

function SQ.Create(p, kind)
	if SQ.Count() >= SQ.Max then p:ChatPrint('Активных отрядов уже ' .. SQ.Max) return end
	local base = SQ.Kinds[kind] or SQ.Kinds[1]
	-- the lowest free number of this kind: ОТРЯД ЗАЩИТЫ 1, 2 …
	local used = {}
	for _, s in pairs(SQ.list) do
		local n = tonumber(string.match(s.name, '^' .. base .. ' (%d+)$'))
		if n then used[n] = true end
	end
	local n = 1
	while used[n] do n = n + 1 end
	local id = 1
	while SQ.list[id] do id = id + 1 end
	SQ.Leave(p, true)
	SQ.list[id] = {id = id, name = base .. ' ' .. n, leader = p, members = {}}
	SQ.Join(p, id)
	p:ChatPrint('Создан ' .. SQ.list[id].name)
end

-- only from a terminal the player stands at
net.Receive('hla_squad_do', function(_, p)
	if (p.HLASquadNext or 0) > CurTime() then return end
	p.HLASquadNext = CurTime() + 0.4
	local t = p.HLATerminal
	if not IsValid(t) or t:GetPos():DistToSqr(p:GetPos()) > 200 * 200 then return end
	local what = net.ReadString()
	if what == 'create' then SQ.Create(p, net.ReadUInt(4))
	elseif what == 'join' then if not SQ.Join(p, net.ReadUInt(4)) then p:ChatPrint('В отряде нет мест') end
	elseif what == 'leave' then SQ.Leave(p)
	elseif what == 'disband' then
		local s = SQ.Of(p)
		if s and s.leader == p then
			for _, m in ipairs(s.members) do if IsValid(m) then m:SetNWInt('hla_squad', 0) m:ChatPrint(s.name .. ' расформирован') end end
			SQ.list[s.id] = nil
			send()
		end
	end
end)

hook.Add('PlayerInitialSpawn', 'HLASquads', function(p) timer.Simple(1, function() if IsValid(p) then send(p) end end) end)
hook.Add('PlayerDisconnected', 'HLASquads', function(p)
	timer.Simple(0, function() for _, s in pairs(SQ.list) do clean(s) end send() end)
end)
