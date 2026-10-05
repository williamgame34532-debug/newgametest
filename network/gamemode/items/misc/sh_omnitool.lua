ITEM.name = "Омни-инструмент"
ITEM.description = "Служебный терминал техслужбы Альянса. Считывает и переписывает доступы: замки, удостоверения, дроны. В чужих руках бесполезен — прошивка отвечает только своим."
ITEM.model = "models/props_lab/binderblue.mdl"
ITEM.rarity = "special"
ITEM.weight = 1.2
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"
ITEM.useLabel = "itemUse"
ITEM.useCooldown = 8

ITEM.range = 110

function ITEM:OnUse(client, item)
	if (CLIENT) then
		return false
	end

	if (!NETWORK.factions.IsAlliance(client) and !client:IsAdmin()) then
		NETWORK.notice.Send(client, "omniNoAccess", "warn")

		return false
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or client:GetPos():Distance(trace.HitPos) > self.range) then
		NETWORK.notice.Send(client, "omniNoTarget", "warn")

		return false
	end

	local class = entity:GetClass()

	if (class == "npc_manhack" or class == "nw_scanner" or class == "npc_cscanner") then
		entity.nwOwner = client

		if (entity.AddEntityRelationship) then
			for _, target in ipairs(player.GetAll()) do
				entity:AddEntityRelationship(target,
					NETWORK.factions.IsAlliance(target) and D_LI or D_HT, 99)
			end
		end

		client:EmitSound("buttons/button17.wav", 60, 120)
		NETWORK.notice.Send(client, "omniDrone", "good")

		return false
	end

	if (class == "nw_lock" or (entity.GetLocked and entity.SetLocked)) then
		local bLocked = entity:GetLocked()

		entity:SetLocked(!bLocked)
		entity:EmitSound("buttons/combine_button" .. math.random(1, 3) .. ".wav", 65)

		NETWORK.notice.Send(client, bLocked and "omniUnlocked" or "omniLocked", "good")

		return false
	end

	if (NETWORK.door.IsDoor(entity)) then
		local data = NETWORK.door.GetData(entity)

		if (!data or data.type != "faction") then
			NETWORK.notice.Send(client, "omniNoData", "warn")

			return false
		end

		local state = NETWORK.inventory.GetState(client)

		for _, card in pairs((state or {}).items or {}) do
			if (istable(card) and card.id == "idcard") then
				card.data = card.data or {}
				card.data.access = table.Copy(data.factions or {})

				NETWORK.inventory.Sync(client)
				NETWORK.notice.Send(client, "omniCopied", "good")

				return false
			end
		end

		NETWORK.notice.Send(client, "omniNoCard", "warn")

		return false
	end

	NETWORK.notice.Send(client, "omniNoTarget", "warn")

	return false
end
