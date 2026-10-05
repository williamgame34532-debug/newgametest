ITEM.name = "Противогаз (тест)"
ITEM.description = "Гражданский фильтрующий противогаз. Использовать — надеть/снять; защищает от токсичного газа, пока жив фильтр (10 минут на фильтр)."
ITEM.model = "models/props_junk/metalgascan.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.7
ITEM.maxStack = 1
ITEM.category = "misc"
ITEM.useLabel = "itemWear"
ITEM.bConsumeOnUse = false

ITEM.bodygroups = {[1] = 1}

function ITEM:OnUse(client, item)
	if (SERVER) then
		local bWear = !client:GetNWBool("nwGasmask")

		client:SetNWBool("nwGasmask", bWear)
		client:EmitSound(bWear and "npc/combine_soldier/gear5.wav" or
			"npc/combine_soldier/gear3.wav", 60)

		NETWORK.inventory.RefreshAppearance(client)

		if (bWear and client:GetNWFloat("nwGasmaskFilter", 0) <= os.time()) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("gasmaskNoFilter")
			net.Send(client)
		end
	end

	return false
end
