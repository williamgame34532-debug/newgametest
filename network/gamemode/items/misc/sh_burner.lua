ITEM.name = "Походная горелка"
ITEM.description = "Банка с горючей смесью и фитилём. Горит около десяти минут и греет не хуже костра — если не на ветру."
ITEM.model = "models/props_junk/metal_paintcan001a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.8
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"
ITEM.useLabel = "itemDeploy"

ITEM.lifetime = 600

function ITEM:OnUse(client, item)
	if (CLIENT) then
		return false
	end

	local trace = client:GetEyeTrace()

	if (client:GetPos():Distance(trace.HitPos) > 120) then
		NETWORK.notice.Send(client, "burnerNoRoom", "warn")

		return false
	end

	local fire = ents.Create("nw_campfire")

	if (!IsValid(fire)) then
		return false
	end

	fire:SetPos(trace.HitPos + trace.HitNormal * 6)
	fire:SetAngles(Angle(0, client:EyeAngles().y, 0))
	fire:Spawn()
	fire:Activate()

	fire:SetModel("models/props_junk/metal_paintcan001a.mdl")
	fire:PhysicsInit(SOLID_VPHYSICS)
	fire:SetFuel(self.lifetime)
	fire:SetLitState(true)

	timer.Simple(self.lifetime + 5, function()
		if (IsValid(fire)) then
			fire:Remove()
		end
	end)

	NETWORK.notice.Send(client, "burnerLit", "good")

	return true
end
