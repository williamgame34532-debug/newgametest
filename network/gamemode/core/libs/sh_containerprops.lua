properties.Add("nwContainerConfig", {
	MenuLabel = "Настроить контейнер",
	Order = 1,
	MenuIcon = "icon16/box.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_container" and client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenContainerConfig(entity)
	end
})

properties.Add("nwContainerType", {
	MenuLabel = "Тип контейнера",
	Order = 2,
	MenuIcon = "icon16/package.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_container" and client:IsAdmin()
	end,
	MenuOpen = function(self, option, entity)
		local submenu = option:AddSubMenu()

		for _, data in ipairs(NETWORK.container.GetAll()) do
			submenu:AddOption(data.name, function()
				self:MsgStart()
					net.WriteEntity(entity)
					net.WriteString(data.id)
				self:MsgEnd()
			end)
		end
	end,
	Action = function(self, entity)
	end,
	Receive = function(self, length, client)
		local entity = net.ReadEntity()
		local id = net.ReadString()

		if (!self:Filter(entity, client)) then
			return
		end

		entity:Rebuild(id)
	end
})

properties.Add("nwContainerLoot", {
	MenuLabel = "Настроить лут",
	Order = 3,
	MenuIcon = "icon16/basket.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_container" and client:IsAdmin()
	end,
	Action = function(self, entity)
		NETWORK.gui.OpenContainerLoot(entity)
	end
})

properties.Add("nwContainerLock", {
	MenuLabel = "Замок",
	Order = 4,
	MenuIcon = "icon16/lock.png",
	Filter = function(self, entity, client)
		return NETWORK.container.CanLock(entity) and client:IsAdmin()
	end,
	MenuOpen = function(self, option, entity)
		local submenu = option:AddSubMenu()
		local lockItem, lockCode = NETWORK.container.GetLock(entity)
		local base = lockItem != "" and NETWORK.item.Get(lockItem)

		local function Send(action, value)
			self:MsgStart()
				net.WriteEntity(entity)
				net.WriteString(action)
				net.WriteString(value or "")
			self:MsgEnd()
		end

		local state = submenu:AddOption(lockItem == "" and "Не заперто" or
			string.format("Сейчас: %s%s", base and base.name or lockItem,
			lockCode != "" and (" · " .. lockCode) or ""))

		state:SetEnabled(false)

		submenu:AddSpacer()

		submenu:AddOption("Требуемый предмет…", function()
			NETWORK.gui.OpenItemPicker("Предмет-ключ", lockItem, function(id)
				Send("item", id)
			end)
		end):SetIcon("icon16/key.png")

		submenu:AddOption("Код ключа…", function()
			Derma_StringRequest("Код ключа",
				"data.code, который должен быть у ключа (пусто — подойдёт любой):",
				lockCode, function(text)
					Send("code", text)
				end)
		end):SetIcon("icon16/textfield_key.png")

		submenu:AddOption("Выдать ключ", function()
			Send("give")
		end):SetIcon("icon16/key_add.png")

		submenu:AddOption("Снять замок", function()
			Send("clear")
		end):SetIcon("icon16/lock_open.png")
	end,
	Action = function(self, entity)
	end,
	Receive = function(self, length, client)
		local entity = net.ReadEntity()
		local action = net.ReadString()
		local value = net.ReadString()

		if (!self:Filter(entity, client)) then
			return
		end

		NETWORK.container.LockAction(client, entity, action, value)
	end
})

properties.Add("nwCacheLock", {
	MenuLabel = "Тайник: замок",
	Order = 5,
	MenuIcon = "icon16/lock_add.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_cache" and
			entity.IsOwner != nil and entity:IsOwner(client)
	end,
	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,
	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!self:Filter(entity, client) or !NETWORK.cache) then
			return
		end

		NETWORK.cache.OwnerAction(client, entity,
			NETWORK.container.IsLocked(entity) and "unlock" or "lock")
	end
})
