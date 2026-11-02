local M = HLA.Menu
local SQ = HLA.Squads
local B = {nums = {}}
HLA.Bots = B

local function wipeFiles(p)
	local id = -p:EntIndex()
	file.Delete('hla/inv/char_' .. id .. '.json')
	file.Delete('cf_rework/balances/c' .. id .. '.txt')
end

local function makeUnit(p)
	if not IsValid(p) or not p:IsBot() or not p.HLAInMenu then return end
	wipeFiles(p)
	local num = M.RandomFreeNumber(B.nums)
	B.nums[num] = p
	local cls = M.Classes[math.random(#M.Classes)]
	local c = {id = -p:EntIndex(), num = num, model = cls.model, bot = true}
	p.HLABotNum = num
	M.Play(p, c)
end

hook.Add('PlayerInitialSpawn', 'HLABots', function(p)
	if not p:IsBot() then return end
	timer.Simple(1, function() makeUnit(p) end)
end)

hook.Add('PlayerDisconnected', 'HLABots', function(p)
	if p.HLABotNum then B.nums[p.HLABotNum] = nil end
	if p:IsBot() then wipeFiles(p) end
end)

local function humanSquad()
	local best
	for id, s in pairs(SQ.list or {}) do
		if #s.members < SQ.MaxMembers then
			for _, m in ipairs(s.members) do
				if IsValid(m) and not m:IsBot() then
					if not best or #s.members < #SQ.list[best].members then best = id end
					break
				end
			end
		end
	end
	return best
end

timer.Create('HLABotSquads', 3, 0, function()
	for _, p in ipairs(player.GetBots()) do
		if p.HLAInMenu then makeUnit(p)
		elseif not SQ.Of(p) and not (p.HLABotSquad and SQ.list[p.HLABotSquad]) then
			local id = humanSquad()
			if id and SQ.Join(p, id) then p.HLABotSquad = id end
		end
	end
end)
