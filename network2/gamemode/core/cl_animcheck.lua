-- nw_anim_check: shows whether the animation libraries of the build reached a model.
-- Look at someone (or yourself in third person) and run it; without a target it checks your
-- own model. Prints the model path, its sequence count and which nw_* sequences it can find,
-- and loads each library directly to tell "library missing" from "model not patched".

local LIBS = {
	["models/network/combine/nw_combine_anims.mdl"] = {"nw_ota_port_live", "nw_ota_pistol_aim", "nw_ota_pistol_walk_aim"},
	["models/network/combine/nemez/nw_nemez_anims.mdl"] = {"nw_ota_live_1"},
	["models/network/cp/nw_cp_anims.mdl"] = {"nw_hla_idle_01", "nw_hla_sprint"},
	["models/network/citizens/nw_citizen_male.mdl"] = {"nw_civ_idle"},
	["models/network/citizens/nw_citizen_female.mdl"] = {"nw_civ_idle"}
}

concommand.Add("nw_anim_check", function()
	local client = LocalPlayer()
	local trace = client:GetEyeTrace()
	local entity = IsValid(trace.Entity) and trace.Entity.GetModel and trace.Entity or client
	local model = entity:GetModel() or "?"

	MsgC(Color(120, 210, 255), "[anim check] ", color_white, model, "  sequences: ", tostring(entity:GetSequenceCount()),
		"  class: ", NW.anim.GetModelClass(model), "\n")

	for path, names in SortedPairs(LIBS) do
		local probe = ClientsideModel(path, RENDERGROUP_OTHER)
		local own = IsValid(probe) and probe:GetSequenceCount() or 0

		if (IsValid(probe)) then
			probe:Remove()
		end

		local found = {}

		for _, name in ipairs(names) do
			found[#found + 1] = name .. "=" .. tostring(entity:LookupSequence(name))
		end

		MsgC(own > 1 and Color(120, 230, 120) or Color(255, 110, 90),
			string.format("  %s: library %s (%d seq), on this model: %s\n", path,
				own > 1 and "loads" or "MISSING", own, table.concat(found, ", ")))
	end
end)
