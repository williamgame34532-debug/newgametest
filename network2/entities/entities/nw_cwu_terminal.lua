AddCSLuaFile()

-- The terminal of the Civil Workers' Union: the same machine as the Alliance terminal (skin 1), its
-- own screen (cl_cmbterminal.lua, kind "cwu"): the breakdowns of the district, the jobs, the factory.
-- Used by the CWU and the Alliance (sv_cwu.lua).

ENT.Base = "nw_cmb_terminal"
ENT.Type = "anim"
ENT.PrintName = "Терминал ГСР"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.TerminalSkin = 1
ENT.TerminalKind = "cwu"

function ENT:CanUse(client)
	-- the city administration too: the state orders (sh_exports.lua)
	return client:GetFaction() == "cwu" or NW.zones.IsAlliance(client) or client:GetNW2Bool("nwCityAdmin", false) or
		client:IsAdmin()
end
