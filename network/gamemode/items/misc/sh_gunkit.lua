ITEM.name = "Оружейный набор"
ITEM.description = "Масло, ёршики, ветошь и мелкие запчасти. Возвращает изношенному стволу состояние — пока стоишь и работаешь руками. Хватает на три чистки."
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.rarity = "special"
ITEM.weight = 1.2
ITEM.width = 2
ITEM.height = 1
ITEM.useCooldown = 60

ITEM.category = "misc"

ITEM.maxUses = 3
ITEM.repairTime = 6
ITEM.repairAmount = 50

function ITEM:OnUse(client, item)
	if (CLIENT) then
		return false
	end

	item = item or {}

	if (client.nwArmorRepair) then
		NETWORK.notice.Send(client, "armorRepairBusy", "warn")

		return false
	end

	local W = NETWORK.weaponwear
	local state = NETWORK.inventory.GetState(client)
	local target, worst

	local active = client:GetActiveWeapon()
	local held = IsValid(active) and W.FindItem(client, active)

	if (held and W.GetCondition(held) < 0.999) then
		target = held
	else
		for slot in pairs(W.slots) do
			local equipped = state.equipped[slot]

			if (equipped) then
				local condition = W.GetCondition(equipped)
				local base = NETWORK.item.Get(equipped.id)

				if (base and base.bWearWeapon and condition < 0.999 and
					(!worst or condition < worst)) then
					target = equipped
					worst = condition
				end
			end
		end
	end

	if (!target) then
		NETWORK.notice.Send(client, "gunRepairNothing", "warn")

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

	client:EmitSound("weapons/smg1/smg1_reload.wav", 55, 85)

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
			client:EmitSound("weapons/pistol/pistol_reload1.wav", 50, math.random(90, 105))
		end

		if (ticks < self.repairTime) then
			return
		end

		client.nwArmorRepair = nil

		local percent = W.Repair(client, target, self.repairAmount)

		item.uses = (item.uses or self.maxUses) - 1

		NETWORK.inventory.Sync(client)
		NETWORK.notice.Send(client, "gunRepaired", "good", base.name, percent or 100)

		if (item.uses <= 0) then
			for _, list in ipairs({state.items, state.equipped, state.storage}) do
				for key, entry in pairs(list or {}) do
					if (entry == item) then
						list[key] = nil
					end
				end
			end

			NETWORK.inventory.Sync(client)
			NETWORK.notice.Send(client, "gunKitSpent", "info")
		end
	end)

	return false
end
