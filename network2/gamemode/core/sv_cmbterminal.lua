-- The terminal of the Alliance, server (entities/entities/nw_cmb_terminal.lua, cl_cmbterminal.lua):
-- what its screen asks for. The squads go through nwSquadAction (sv_squads.lua).
--   close        the user leaves the terminal
--   resolve <n>  close the call of the civic terminal n (sv_terminal.lua)
--   cam_view <n> the combine camera n is watched from this terminal (sh_cameras.lua)

util.AddNetworkString("nwCmbTerminalOpen")
util.AddNetworkString("nwCmbTerminalLean")
util.AddNetworkString("nwCmbTerminal")

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
