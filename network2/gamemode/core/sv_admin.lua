-- Small staff actions from the TAB menu (superadmins only): go to a player (go), bring a player,
-- slay. nw_admin <action> <user id>.

local ACTIONS = {}

local function Behind(client, target)
	local pos = target:GetPos() - target:GetForward() * 48 + Vector(0, 0, 4)
	local trace = util.TraceHull({start = target:GetPos() + Vector(0, 0, 4), endpos = pos,
		mins = client:OBBMins(), maxs = client:OBBMaxs(), filter = {client, target}})

	return trace.HitPos
end

function ACTIONS.go(client, target)
	client:SetPos(Behind(client, target))
	client:SetEyeAngles((target:EyePos() - client:EyePos()):Angle())
end

function ACTIONS.bring(client, target)
	target:SetPos(Behind(target, client))
	target:SetEyeAngles((client:EyePos() - target:EyePos()):Angle())
end

function ACTIONS.slay(client, target)
	target:Kill()
end

concommand.Add("nw_admin", function(client, _, arguments)
	if (!IsValid(client) or !client:IsSuperAdmin()) then
		return
	end

	local action = ACTIONS[arguments[1] or ""]
	local target = Player(tonumber(arguments[2] or "") or -1)

	if (!action or !IsValid(target) or !target:Alive() or (!client:Alive() and arguments[1] != "slay")) then
		return
	end

	action(client, target)
	MsgN(string.format("[nw_admin] %s: %s -> %s", client:SteamName(), arguments[1], target:SteamName()))
end)

