--[[-------------------------------------------------------------------------
	Задания (клиент): рисуются в cl_hud.lua из NWORK.HUD.Objective.
---------------------------------------------------------------------------]]

NWORK.HUD.Objective = NWORK.HUD.Objective or ( NWORK.Schema and table.Copy( NWORK.Schema.Objective or {} ) )

net.Receive( "nwork_objective", function()
	NWORK.HUD.Objective = { Title = net.ReadString(), Desc = net.ReadString() }
end )
