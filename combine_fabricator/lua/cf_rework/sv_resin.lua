-- Resin balance (server) and the E / left-click input for fabricators.
local C = CFRework

file.CreateDir('cf_rework')
file.CreateDir('cf_rework/balances')

local function validID(id) return isstring(id) and id:match('^%d+$') end

function C.ReadBalance(id)
	if not validID(id) then return 0 end
	return math.Clamp(math.floor(tonumber(file.Read('cf_rework/balances/' .. id .. '.txt', 'DATA')) or 0), 0, C.MaxResin)
end

function C.StoreBalance(id, n)
	if not validID(id) then return false end
	file.Write('cf_rework/balances/' .. id .. '.txt', tostring(math.Clamp(math.floor(n), 0, C.MaxResin)))
	return true
end

function C.Balance(p) return p:GetNWInt('cf_resin', 0) end

function C.ChangeBalance(p, delta)
	if not IsValid(p) then return false end
	local n = C.Balance(p) + delta
	if n < 0 or n > C.MaxResin then return false end
	p:SetNWInt('cf_resin', n)
	C.StoreBalance(p:SteamID64(), n)
	return true
end

-- refund by SteamID64, also when the player already left
function C.Refund(id, amount)
	if not amount or amount <= 0 then return end
	for _, p in ipairs(player.GetAll()) do
		if p:SteamID64() == id then C.ChangeBalance(p, amount) return end
	end
	C.StoreBalance(id, C.ReadBalance(id) + amount)
end

hook.Add('PlayerInitialSpawn', 'CFReworkLoadBalance', function(p)
	timer.Simple(0, function()
		if IsValid(p) then p:SetNWInt('cf_resin', C.ReadBalance(p:SteamID64())) end
	end)
end)

hook.Add('PlayerDisconnected', 'CFReworkDisconnect', function(p)
	for _, e in ipairs(ents.FindByClass('sent_combine_fabricator')) do
		if e:GetOperator() == p then e:EndSession(true) end
	end
end)

-- What a player is aiming at on a nearby fabricator: screen pixel or a physical part
local function target(p)
	for _, e in ipairs(ents.FindInSphere(p:EyePos(), C.UseRange + 60)) do
		if e:GetClass() == 'sent_combine_fabricator' then
			local pose = C.PoseOf(e)
			local x, y = C.HitScreen(e, p, pose)
			if x then return e, x, y end
			local part = C.HitPart(e, p, pose)
			if part then return e, nil, nil, part end
		end
	end
end

hook.Add('KeyPress', 'CFReworkUse', function(p, key)
	if key ~= IN_USE or not p:Alive() or (p.CFReworkNextUse or 0) > CurTime() then return end
	local e, x, y, part = target(p)
	if not e then return end
	p.CFReworkNextUse = CurTime() + 0.2
	e:Interact(p, x, y, part)
end)

-- left click on the display (sent by the client only when the crosshair is on a screen;
-- the server recomputes the aim itself)
util.AddNetworkString('cf_rework_click')
net.Receive('cf_rework_click', function(_, p)
	if not IsValid(p) or not p:Alive() or (p.CFReworkNextUse or 0) > CurTime() then return end
	local e, x, y = target(p)
	if not e or not x then return end
	p.CFReworkNextUse = CurTime() + 0.2
	e:Interact(p, x, y, nil)
end)

function C.AimedPart(e, p)
	return C.HitPart(e, p, C.PoseOf(e))
end

concommand.Add('cf_resin_give', function(p, _, args)
	if not IsValid(p) then print('Run this from an admin player console.') return end
	if not p:IsAdmin() then return end
	C.ChangeBalance(p, math.Clamp(math.floor(tonumber(args[1]) or 20), 1, 1000))
end)
