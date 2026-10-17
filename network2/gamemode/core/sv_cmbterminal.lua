-- The terminal of the Alliance, server (entities/entities/nw_cmb_terminal.lua, cl_cmbterminal.lua):
-- what its screen asks for. The squads go through nwSquadAction (sv_squads.lua).
--   close        the user leaves the terminal
--   resolve <n>  close the call of the civic terminal n (sv_terminal.lua)
--   broadcast    an announcement of the Overwatch to the whole city (sh_overwatch.lua), once in
--                nw_cmbterminal_broadcast seconds for everyone

util.AddNetworkString("nwCmbTerminalOpen")
util.AddNetworkString("nwCmbTerminalLean")
util.AddNetworkString("nwCmbTerminal")

local cooldown = CreateConVar("nw_cmbterminal_broadcast", "120", FCVAR_ARCHIVE,
	"Как часто терминал Альянса может давать оповещение городу (секунды)")

local nextBroadcast = 0

local ACTIONS = {}

function ACTIONS.close(client, terminal)
	if (terminal:GetUser() == client) then
		terminal:SetUser(NULL)
	end
end

function ACTIONS.resolve(client, terminal, arg)
	local civic = Entity(tonumber(arg) or 0)

	if (IsValid(civic) and civic:GetClass() == NW.terminal.class and NW.terminal.Resolve) then
		NW.terminal.Resolve(civic, client)
	end
end

function ACTIONS.broadcast(client, terminal, arg)
	if (CurTime() < nextBroadcast) then
		return NW.Notify(client, "Канал оповещения занят ещё " .. math.ceil(nextBroadcast - CurTime()) .. " с")
	end

	if (NW.overwatch.City(arg)) then
		nextBroadcast = CurTime() + cooldown:GetFloat()
		MsgN(string.format("[CMB TERMINAL] %s (%s): оповещение %s", client:Nick(), client:SteamName(), arg))
	end
end

-- other screens add their own (the CWU: sv_cwu.lua)
NW.cmbTerminalActions = ACTIONS

net.Receive("nwCmbTerminal", function(_, client)
	local terminal = net.ReadEntity()
	local action = net.ReadString()
	local arg = net.ReadString()

	if ((client.nwCmbNext or 0) > CurTime()) then
		return
	end

	client.nwCmbNext = CurTime() + 0.3

	if (!IsValid(terminal) or !terminal.CanUse or !ACTIONS[action] or terminal:GetUser() != client or
		client:GetPos():DistToSqr(terminal:GetPos()) > 200 * 200 or !terminal:CanUse(client)) then
		return
	end

	ACTIONS[action](client, terminal, arg)
end)
