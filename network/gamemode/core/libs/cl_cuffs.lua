local cuffModel = "models/chara/simplehandcuffs/handcuffs.mdl"

hook.Add("Think", "nwCuffsVisual", function()

	if (!NETWORK.restraint.Usable(cuffModel)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		local bCuffed = client:GetNWBool("nwCuffed", false) and client:Alive()
		local prop = client.nwCuffProp

		if (bCuffed and !IsValid(prop)) then
			prop = ClientsideModel(cuffModel, RENDERGROUP_OPAQUE)

			if (IsValid(prop)) then
				prop:SetNoDraw(true)
				client.nwCuffProp = prop
			end
		elseif (!bCuffed and IsValid(prop)) then
			prop:Remove()
			client.nwCuffProp = nil
		end
	end
end)

hook.Add("PostPlayerDraw", "nwCuffsVisual", function(client)
	local prop = client.nwCuffProp

	if (!IsValid(prop)) then
		return
	end

	local bone = client:LookupBone("ValveBiped.Bip01_R_Hand")

	if (!bone) then
		return
	end

	local position, angles = client:GetBonePosition(bone)

	if (!position) then
		return
	end

	angles:RotateAroundAxis(angles:Right(), 90)

	prop:SetPos(position + angles:Forward() * -2 + angles:Up() * -1)
	prop:SetAngles(angles)
	prop:SetRenderOrigin(prop:GetPos())
	prop:SetRenderAngles(prop:GetAngles())
	prop:DrawModel()
end)
