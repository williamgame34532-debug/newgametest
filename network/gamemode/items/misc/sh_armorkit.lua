ITEM.name = "Ремкомплект брони"
ITEM.description = "Запасные пластины, кевларовые вставки и заклёпки. Восстанавливает изношенный шлем или бронежилет — пока стоишь и работаешь руками. Хватает на три ремонта."
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.rarity = "special"
ITEM.weight = 1.6
ITEM.width = 2
ITEM.height = 1

ITEM.useCooldown = 120

ITEM.category = "misc"

ITEM.maxUses = 3
ITEM.repairTime = 8
ITEM.repairAmount = 40

function ITEM:OnUse(client, item)
	if (CLIENT) then
		return false
	end

	item = item or {}

	if (client.nwArmorRepair) then
		NETWORK.notice.Send(client, "armorRepairBusy", "warn")

		return false
	end

	local state = NETWORK.inventory.GetState(client)
	local target, worst

	for _, slot in ipairs({"helmet", "armour"}) do
		local equipped = state.equipped[slot]
		local base = equipped and NETWORK.item.Get(equipped.id)

		if (base and base.maxUses and base.maxUses > 1) then
			local condition = (equipped.uses or base.maxUses) / base.maxUses

			if (condition < 0.999 and (!worst or condition < worst)) then
				target = equipped
				worst = condition
			end
		end
	end

	if (!target) then
		NETWORK.notice.Send(client, "armorRepairNothing", "warn")

		return false
	end

	local base = NETWORK.item.Get(target.id)
	local start = client:GetPos()
	local health = client:Health()

	client.nwArmorRepair = target

	net.Start("nwArmorRepair")
		net.WriteFloat(self.repairTime)
		net.WriteString(base.name)
	net.Send(client)

	client:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60, 90)

	local ticks = 0

	timer.Create("nwArmorRepair" .. client:EntIndex(), 1, self.repairTime, function()
		if (!IsValid(client) or client.nwArmorRepair != target) then
			return
		end

		ticks = ticks + 1

		local bMoved = client:GetPos():DistToSqr(start) > 24 * 24
		local bHurt = client:Health() < health or !client:Alive() or client:IsDowned()

		if (bMoved or bHurt) then
			client.nwArmorRepair = nil

			timer.Remove("nwArmorRepair" .. client:EntIndex())

			net.Start("nwArmorRepair")
				net.WriteFloat(0)
				net.WriteString("")
			net.Send(client)

			NETWORK.notice.Send(client, "armorRepairStopped", "warn")

			return
		end

		if (ticks % 2 == 0) then
			client:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav",
				55, math.random(95, 110))
		end

		if (ticks < self.repairTime) then
			return
		end

		client.nwArmorRepair = nil

		target.uses = math.min(base.maxUses, (target.uses or base.maxUses) + self.repairAmount)

		item.uses = (item.uses or self.maxUses) - 1

		NETWORK.inventory.Sync(client)
		NETWORK.notice.Send(client, "armorRepaired", "good", base.name,
			math.Round(target.uses / base.maxUses * 100))

		if (item.uses <= 0) then

			for _, list in ipairs({state.items, state.equipped, state.storage}) do
				for key, entry in pairs(list or {}) do
					if (entry == item) then
						list[key] = nil
					end
				end
			end

			NETWORK.inventory.Sync(client)
			NETWORK.notice.Send(client, "armorKitSpent", "info")
		end
	end)

	return false
end
