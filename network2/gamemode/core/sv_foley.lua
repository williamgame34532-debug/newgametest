-- Civil Protection on the run: the gear rattles (sound/network2/metrocop/metrocop_foley_step_1-6.wav)
-- on every second step while running, under the usual footsteps.

local function IsCP(client)
	local class = NW.anim and NW.anim.GetModelClass and NW.anim.GetModelClass(string.lower(client:GetModel() or ""))

	return client:GetFaction() == "cp" or class == "metrocop"
end

hook.Add("PlayerFootstep", "nwCPFoley", function(client)
	if (!client:Alive() or !client:OnGround() or client:GetMoveType() == MOVETYPE_NOCLIP or
		client:GetVelocity():Length2D() < client:GetWalkSpeed() * 1.3 or !IsCP(client)) then
		return
	end

	client.nwFoleyStep = !client.nwFoleyStep

	if (client.nwFoleyStep) then
		client:EmitSound("network2/metrocop/metrocop_foley_step_" .. math.random(1, 6) .. ".wav", 68,
			math.random(96, 104), 0.7)
	end
end)
