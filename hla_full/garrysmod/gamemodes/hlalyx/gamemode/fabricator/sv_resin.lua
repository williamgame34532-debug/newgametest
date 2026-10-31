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
	for _, e in ipairs(ents.FindByClass(C.FabClass)) do
		if e:GetOperator() == p then e:EndSession(true) end
	end
end)

---------------------------------------------------------------------------------------------------
-- Focus mode: pressing E on a display puts the player's camera in front of it (client side);
-- the mouse drives a cursor on the screen, LMB clicks, E feeds resin, «ЗАВЕРШИТЬ» leaves.
util.AddNetworkString('cf_rework_focus')
util.AddNetworkString('cf_rework_press')

function C.SetFocus(p, e)
	if not IsValid(p) then return end
	e = IsValid(e) and e or nil
	if p.CFFocus == e then return end
	if not e then p.CFNoFireUntil = CurTime() + 0.35 end
	p.CFFocus = e
	net.Start('cf_rework_focus')
	net.WriteEntity(e or NULL)
	net.Send(p)
end

function C.Focused(p, e) return IsValid(p) and p.CFFocus ~= nil and p.CFFocus == e end

-- What a player is aiming at on a nearby fabricator: screen pixel or a physical part
local function target(p)
	for _, e in ipairs(ents.FindInSphere(p:EyePos(), C.UseRange + 60)) do
		if e.IsCombineFabricator then
			local x, y = C.HitScreen(e, p)
			if x then return e, x, y end
			local part = C.HitPart(e, p)
			if part then return e, nil, nil, part end
		end
	end
end

-- no shooting while at a screen and for a moment after leaving it
hook.Add('StartCommand', 'CFReworkFocus', function(p, cmd)
	if IsValid(p.CFFocus) or (p.CFNoFireUntil or 0) > CurTime() then
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(bit.bor(IN_ATTACK, IN_ATTACK2))))
	end
end)

hook.Add('KeyPress', 'CFReworkUse', function(p, key)
	if key ~= IN_USE or not p:Alive() or (p.CFReworkNextUse or 0) > CurTime() then return end
	-- at the screen E does nothing: resin goes into the cells by hand, after «ЗАВЕРШИТЬ»
	if IsValid(p.CFFocus) then return end
	-- a folded fabricator opens when E is pressed on its hull
	local tr = p:GetEyeTrace()
	local hull = tr.Entity
	if IsValid(hull) and hull.IsCombineFabricator and not hull.Awake and tr.HitPos:DistToSqr(p:EyePos()) < (C.UseRange + 40) ^ 2 then
		p.CFReworkNextUse = CurTime() + 0.5
		hull.LastNearby = CurTime()
		hull:WakeUp()
		return
	end
	local e, x, y, part = target(p)
	if not e then return end
	p.CFReworkNextUse = CurTime() + 0.2
	if x then
		e:RequestFocus(p)
	else
		e:Interact(p, nil, nil, part)
	end
end)

net.Receive('cf_rework_press', function(_, p)
	local x, y = net.ReadFloat(), net.ReadFloat()
	local e = p.CFFocus
	if not IsValid(e) or not p:Alive() or (p.CFReworkNextUse or 0) > CurTime() then return end
	if p:GetPos():DistToSqr(e:GetPos()) > C.LeaveRadius * C.LeaveRadius then C.SetFocus(p, nil) return end
	if x < 0 or y < 0 or x > C.Layout.W or y > C.Layout.H then return end
	p.CFReworkNextUse = CurTime() + 0.15
	e:Interact(p, x, y, nil)
end)

net.Receive('cf_rework_focus', function(_, p)
	-- client asks to leave focus (e.g. pressed Esc-like key); entering is server-driven only
	if net.ReadBool() == false then C.SetFocus(p, nil) end
end)

hook.Add('PlayerDeath', 'CFReworkFocus', function(p) C.SetFocus(p, nil) end)

function C.AimedPart(e, p)
	if C.Focused(p, e) then return nil end
	return C.HitPart(e, p)
end

concommand.Add('cf_resin_give', function(p, _, args)
	if not IsValid(p) then print('Run this from an admin player console.') return end
	if not p:IsAdmin() then return end
	C.ChangeBalance(p, math.Clamp(math.floor(tonumber(args[1]) or 20), 1, 1000))
end)
