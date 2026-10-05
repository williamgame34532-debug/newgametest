ITEM.name = "Фильтр противогаза"
ITEM.description = "Сменный фильтрующий картридж. Ставится в надетый противогаз, ресурс — 10 минут."
ITEM.model = "models/props_junk/popcan01a.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.2
ITEM.maxStack = 5
ITEM.category = "misc"
ITEM.useLabel = "itemInstall"

function ITEM:OnUse(client, item)
	if (SERVER) then
		if (!client:GetNWBool("nwGasmask")) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("gasmaskWearFirst")
			net.Send(client)

			return false
		end

		client:SetNWFloat("nwGasmaskFilter", os.time() + 600)
		client:EmitSound("items/battery_pickup.wav", 55)
	end

	return true
end
