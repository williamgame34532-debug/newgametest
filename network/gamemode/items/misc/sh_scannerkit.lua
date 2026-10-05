ITEM.name = "Переносной сканер"
ITEM.description = "Сложенный разведывательный дрон Альянса. Разворачивается на месте и висит над кварталом, подсвечивая всё живое для того, кто его выпустил. Заряда хватает на несколько минут."
ITEM.model = "models/props_combine/combine_intmonitor001.mdl"
ITEM.rarity = "special"
ITEM.weight = 2
ITEM.width = 2
ITEM.height = 1
ITEM.category = "misc"
ITEM.useLabel = "itemDeploy"
ITEM.useCooldown = 120

ITEM.lifetime = 240

function ITEM:OnUse(client, item)
	if (CLIENT) then
		return false
	end

	if (!NETWORK.factions.IsAlliance(client) and !client:IsAdmin()) then
		NETWORK.notice.Send(client, "scannerNoAccess", "warn")

		return false
	end

	local forward = client:GetAimVector()

	forward.z = 0
	forward:Normalize()

	local scanner = ents.Create("nw_scanner")

	if (!IsValid(scanner)) then
		return false
	end

	scanner:SetPos(client:GetPos() + forward * 70 + Vector(0, 0, 70))
	scanner:SetAngles(Angle(0, client:EyeAngles().y, 0))
	scanner:Spawn()
	scanner:Activate()

	scanner.nwOwner = client
	scanner.nwPortable = true

	client:EmitSound("npc/scanner/scanner_photo1.wav", 60, 110)
	NETWORK.notice.Send(client, "scannerDeployed", "good",
		math.Round(self.lifetime / 60))

	timer.Simple(self.lifetime, function()
		if (IsValid(scanner)) then
			scanner:EmitSound("npc/scanner/combat_scan4.wav", 55, 90)
			scanner:Remove()
		end
	end)

	return true
end
