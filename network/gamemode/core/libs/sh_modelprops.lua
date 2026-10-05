local TYPES = {
	nw_breaker = {
		get = function(entity) return entity:GetBreakerModel() end,
		set = function(entity, model) entity:SetBreakerModel(model) end,
		label = "Сменить модель щитка"
	},
	nw_stash = {
		get = function(entity) return entity:GetStashModel() end,
		set = function(entity, model) entity:SetStashModel(model) end,
		label = "Сменить модель сейфа"
	},
	nw_furnitureshop = {
		get = function(entity) return entity:GetShopModel() end,
		set = function(entity, model) entity:SetShopModel(model) end,
		label = "Сменить модель склада"
	}
}

local GENERIC = {
	get = function(entity) return entity:GetModel() end,
	set = function(entity, model)
		entity:SetModel(model)

		if (entity.SetupPhysics) then
			entity:SetupPhysics()
		else
			entity:PhysicsInit(SOLID_VPHYSICS)
		end
	end
}

local function GetType(entity)
	return TYPES[entity:GetClass()] or (istable(entity.Models) and GENERIC) or nil
end

local function CanEdit(client, entity)
	return IsValid(entity) and IsValid(client) and client:IsAdmin() and
		GetType(entity) != nil
end

properties.Add("nwCycleModel", {
	MenuLabel = "Сменить модель (Network)",
	Order = 1,
	MenuIcon = "icon16/pictures.png",
	Filter = function(self, entity, client)
		return CanEdit(client, entity)
	end,
	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,
	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!self:Filter(entity, client)) then
			return
		end

		local data = GetType(entity)
		local list = entity.Models or {}
		local current = data.get(entity)
		local index = 1

		for position, path in ipairs(list) do
			if (path == current) then
				index = position

				break
			end
		end

		local total = #list

		for step = 1, total do
			local path = list[((index + step - 1) % total) + 1]

			if (util.IsValidModel(path) or file.Exists(path, "GAME")) then
				data.set(entity, path)

				if (entity.Apply) then
					entity:Apply()
				end

				if (NETWORK.entities and NETWORK.entities.Save) then
					NETWORK.entities.Save()
				end

				NETWORK.chat.Notice(client, "modelChanged")

				return
			end
		end

		NETWORK.chat.Notice(client, "modelNone")
	end
})
