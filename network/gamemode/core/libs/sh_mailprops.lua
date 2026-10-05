properties.Add("nwMailOwner", {
	MenuLabel = "Почта: владелец (админ)",
	Order = 2,
	MenuIcon = "icon16/email.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_mailbox" and client:IsAdmin()
	end,
	Action = function(self, entity)
		Derma_StringRequest("Почтовый ящик", "Имя владельца (как имя персонажа):",
			entity:GetOwnerName(), function(text)
				self:MsgStart()
					net.WriteEntity(entity)
					net.WriteString(string.sub(text, 1, 64))
				self:MsgEnd()
			end)
	end,
	Receive = function(self, length, client)
		local entity = net.ReadEntity()
		local text = net.ReadString()

		if (!self:Filter(entity, client)) then
			return
		end

		entity:SetOwnerName(string.Trim(text))
		NETWORK.entities.Save()
	end
})

properties.Add("nwMailModel", {
	MenuLabel = "Почта: модель",
	Order = 3,
	MenuIcon = "icon16/box.png",
	Filter = function(self, entity, client)
		return IsValid(entity) and entity:GetClass() == "nw_mailbox" and client:IsAdmin()
	end,
	Action = function(self, entity)
		Derma_StringRequest("Почтовый ящик", "Путь к модели:", entity:GetModel(),
			function(text)
				self:MsgStart()
					net.WriteEntity(entity)
					net.WriteString(string.sub(text, 1, 128))
				self:MsgEnd()
			end)
	end,
	Receive = function(self, length, client)
		local entity = net.ReadEntity()
		local model = string.Trim(net.ReadString())

		if (!self:Filter(entity, client) or !util.IsValidModel(model)) then
			return
		end

		entity:SetModel(model)
		entity:PhysicsInit(SOLID_VPHYSICS)
		NETWORK.entities.Save()
	end
})
