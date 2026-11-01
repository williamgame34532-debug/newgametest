-- Surveillance terminal: the Combine console of the squads (hla_terminal_console) with a monitor
-- (combine_intmonitor001) over it. At the screen (E) the unit picks one of the Combine cameras of the map
-- (npc_combine_camera); what that camera sees is shown on the monitor over the terminal — to everyone near.
ENT.Type = 'anim'
ENT.Base = 'hla_terminal_console'
ENT.PrintName = 'Терминал наблюдения (камеры)'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.IsCamTerminal = true
ENT.MonitorModel = 'models/props_combine/combine_intmonitor001.mdl'
ENT.CameraClasses = {npc_combine_camera = true}

function ENT:SetupDataTables()
	self:NetworkVar('Bool', 0, 'Open')
	self:NetworkVar('Float', 0, 'OpenedAt')
	self:NetworkVar('Entity', 0, 'Monitor')
	self:NetworkVar('Int', 0, 'CamIndex')       -- the chosen camera (entity index), 0 — none
	self:NetworkVar('Vector', 0, 'CamPos')      -- where it looks from / to (it may be out of the client's view)
	self:NetworkVar('Angle', 0, 'CamAng')
end
