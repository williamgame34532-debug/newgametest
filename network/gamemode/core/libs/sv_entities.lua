NETWORK.entities = NETWORK.entities or {}

local TABLE_NAME = "network_entities"

local SAVED = {
	nw_crafttable = function(entity)
		return {
			name = entity:GetTableName(),
			model = entity:GetTableModel(),
			recipes = entity.recipes
		}
	end,

	nw_npc = function(entity)
		return NETWORK.entities.CollectBody(entity, {
			name = entity:GetNPCName(),
			model = entity:GetNPCModel(),
			sequence = entity:GetNPCSequence(),
			dialogue = entity:GetDialogue(),
			factions = entity.GetFactions and entity:GetFactions() or ""
		})
	end,
	nw_trader = function(entity)
		return NETWORK.entities.CollectBody(entity, {
			name = entity:GetNPCName(),
			model = entity:GetNPCModel(),
			sequence = entity:GetNPCSequence(),
			dialogue = entity:GetDialogue(),
			description = entity:GetTraderDescription(),
			traderID = entity:GetTraderID(),
			offers = entity.offers,
			restock = entity:GetRestock(),
			restockAmount = entity:GetRestockAmount(),
			factions = entity:GetFactions(),
			unlockItem = entity:GetUnlockItem(),
			unlockAmount = entity:GetUnlockAmount()
		})
	end,

	nw_recruiter = function(entity)
		return NETWORK.entities.CollectBody(entity, {
			name = entity:GetNPCName(),
			model = entity:GetNPCModel(),
			sequence = entity:GetNPCSequence(),
			configID = entity:GetConfigID()
		})
	end,
	nw_container = function(entity)
		return {
			containerType = entity:GetContainerID(),
			items = entity.items
		}
	end,
	nw_led = function(entity)
		return {
			text = entity:GetText(),
			subtext = entity:GetSubtext(),
			style = entity:GetStyle(),
			scale = entity:GetTextScale()
		}
	end,
	nw_forcefield = function(entity)
		return {mode = entity:GetMode()}
	end,
	nw_dispenser = function(entity)
		return {
			bEnabled = entity:GetEnabled(),
			basic = entity:GetStockBasic(),
			standard = entity:GetStockStandard(),
			premium = entity:GetStockPremium()
		}
	end,
	nw_vending = function(entity)
		return {}
	end,

	nw_junk = function(entity)
		return {
			model = entity:GetJunkModel(),
			minItems = entity:GetMinItems(),
			maxItems = entity:GetMaxItems(),
			refill = entity:GetRefill(),
			loot = entity.loot
		}
	end,
	nw_breaker = function(entity)
		return {
			bBroken = entity:GetNWBool("nwBroken", false),
			model = entity:GetBreakerModel()
		}
	end,

	nw_stash = function(entity)
		return {model = entity:GetStashModel(), group = entity.nwGroup}
	end,
	nw_furnitureshop = function(entity)
		return {model = entity:GetShopModel()}
	end,

	prop_physics = function(entity)
		return NETWORK.entities.CollectProp(entity)
	end,
	prop_dynamic = function(entity)
		return NETWORK.entities.CollectProp(entity)
	end,
	prop_physics_multiplayer = function(entity)
		return NETWORK.entities.CollectProp(entity)
	end
}

SAVED.nw_campfire = function(entity)
	return {
		model = entity:GetModel(),
		fuel = entity:GetFuel(),
		lit = entity:GetLit()
	}
end

SAVED.nw_board = function(entity)
	local color = entity:GetColor()

	return {
		model = entity:GetModel(),
		notices = istable(entity.notices) and entity.notices or {},
		material = entity:GetMaterial() or "",
		color = {color.r, color.g, color.b, color.a}
	}
end

SAVED.npc_turret_floor = function(entity)
	return {
		deploy = entity:GetNWString("nwDeploy", ""),
		faction = entity.nwOwnerFaction or "",
		hostile = entity.nwHostile
	}
end

local function RestoreDeploy(entity, data)
	entity.nwDeployID = data.deploy != "" and data.deploy or nil
	entity.nwOwnerFaction = data.faction != "" and data.faction or nil
	entity.nwNoSalvage = true

	if (istable(data.hostile)) then
		entity.nwHostile = {}

		for id, value in pairs(data.hostile) do
			if (NETWORK.factions.Get(id)) then
				entity.nwHostile[id] = value == true
			end
		end
	end

	entity:SetNWString("nwDeploy", data.deploy or "")

	if (NETWORK.deploy and NETWORK.deploy.ApplyRelations) then
		NETWORK.deploy.ApplyRelations(entity)
	end
end

local GENERIC_UPGRADE = {
	nw_recruiter = true
}

local FILTER = {
	prop_physics = function(entity)
		return entity.nwPersist == true
	end,
	prop_dynamic = function(entity)
		return entity.nwPersist == true
	end,
	prop_physics_multiplayer = function(entity)
		return entity.nwPersist == true
	end
}

function NETWORK.entities.CollectBody(entity, data)
	data = istable(data) and data or {}

	local groups = {}

	for _, group in pairs(entity:GetBodyGroups() or {}) do
		local value = entity:GetBodygroup(group.id)

		if (value and value > 0) then
			groups[tostring(group.id)] = value
		end
	end

	data.skin = entity:GetSkin() or 0
	data.bodygroups = groups

	return data
end

function NETWORK.entities.ApplyBody(entity, data)
	if (!IsValid(entity) or !istable(data)) then
		return
	end

	local skins = math.max(entity:SkinCount() or 1, 1)

	entity:SetSkin(math.Clamp(math.Round(tonumber(data.skin) or 0), 0, skins - 1))

	if (!istable(data.bodygroups)) then
		return
	end

	for index, value in pairs(data.bodygroups) do
		local id = math.Round(tonumber(index) or -1)

		if (id < 0) then
			continue
		end

		local count = entity:GetBodygroupCount(id) or 0

		if (count > 0) then
			entity:SetBodygroup(id, math.Clamp(math.Round(tonumber(value) or 0), 0, count - 1))
		end
	end
end

function NETWORK.entities.RestoreBody(entity, data)
	if (!istable(data) or (data.skin == nil and !istable(data.bodygroups))) then
		return
	end

	NETWORK.entities.ApplyBody(entity, data)

	local model = entity:GetModel()

	timer.Simple(1, function()
		if (IsValid(entity) and entity:GetModel() == model) then
			NETWORK.entities.ApplyBody(entity, data)
		end
	end)
end

function NETWORK.entities.CollectProp(entity)
	local groups = {}

	for _, data in pairs(entity:GetBodyGroups() or {}) do
		local value = entity:GetBodygroup(data.id)

		if (value and value > 0) then
			groups[tostring(data.id)] = value
		end
	end

	local color = entity:GetColor()
	local physics = entity:GetPhysicsObject()

	return {
		model = entity:GetModel(),
		skin = entity:GetSkin(),
		bodygroups = groups,
		material = entity:GetMaterial() or "",
		color = {color.r, color.g, color.b, color.a},
		bFrozen = !IsValid(physics) or !physics:IsMotionEnabled(),
		bDynamic = entity:GetClass() == "prop_dynamic"
	}
end

function NETWORK.entities.RestoreProp(entity, data)
	if (isstring(data.model) and util.IsValidModel(data.model)) then
		entity:SetModel(data.model)
	end

	entity:SetSkin(math.max(math.Round(tonumber(data.skin) or 0), 0))
	entity:SetMaterial(isstring(data.material) and data.material or "")

	for index, value in pairs(data.bodygroups or {}) do
		entity:SetBodygroup(tonumber(index) or 0, math.Round(tonumber(value) or 0))
	end

	local color = data.color

	if (istable(color) and #color >= 4) then
		entity:SetColor(Color(color[1], color[2], color[3], color[4]))

		if (color[4] < 255) then
			entity:SetRenderMode(RENDERMODE_TRANSALPHA)
		end
	end

	entity.nwPersist = true

	local physics = entity:GetPhysicsObject()

	if (IsValid(physics)) then
		if (data.bFrozen != false) then
			physics:EnableMotion(false)
			physics:Sleep()
		else
			physics:Wake()
		end
	end
end

local RESTORE = {

	nw_crafttable = function() end,
	npc_turret_floor = function(entity, data)
		RestoreDeploy(entity, data)
	end,
	nw_npc = function(entity, data)
		entity:SetNPCName(data.name or "")
		entity:SetNPCModel(data.model or "")
		entity:SetNPCSequence(data.sequence or "")
		entity:SetDialogue(data.dialogue or "")

		if (isstring(data.factions) and entity.SetFactions) then
			entity:SetFactions(data.factions)
		end

		entity:Apply()

		NETWORK.entities.RestoreBody(entity, data)
	end,
	nw_trader = function(entity, data)
		entity:SetNPCName(data.name or "")
		entity:SetNPCModel(data.model or "")
		entity:SetNPCSequence(data.sequence or "")
		entity:SetDialogue(data.dialogue or "")
		entity:SetTraderDescription(data.description or "")
		entity:SetTraderID(data.traderID or "")
		entity.offers = istable(data.offers) and data.offers or {}

		entity:SetRestock(math.Clamp(math.Round(tonumber(data.restock) or 0),
			-1, 86400))
		entity:SetRestockAmount(math.max(
			math.Round(tonumber(data.restockAmount) or 1), 1))

		if (isstring(data.factions)) then
			entity:SetFactions(data.factions)
		end

		if (isstring(data.unlockItem)) then
			entity:SetUnlockItem(data.unlockItem)
			entity:SetUnlockAmount(math.max(math.Round(tonumber(data.unlockAmount) or 0), 0))
		end

		entity:Apply()

		NETWORK.entities.RestoreBody(entity, data)
	end,

	nw_recruiter = function(entity, data)
		local vars = istable(data.vars) and data.vars or {}
		local model = data.model

		if (data.bGeneric) then
			model = vars.NPCModel or model
		end

		entity:SetNPCName(data.name or vars.NPCName or "")
		entity:SetNPCModel(isstring(model) and model or "")
		entity:SetNPCSequence(data.sequence or vars.NPCSequence or "")

		local config = data.configID or vars.ConfigID

		entity:SetConfigID(isstring(config) and config != "" and config or "default")

		entity:Apply()

		NETWORK.entities.RestoreBody(entity, data)
	end,
	nw_container = function(entity, data)
		if (data.containerType and data.containerType != "") then
			entity:Rebuild(data.containerType)
		end

		if (istable(data.items)) then
			entity.items = {}

			for index, item in pairs(data.items) do
				entity.items[tonumber(index)] = item
			end
		end
	end,
	nw_led = function(entity, data)
		entity:SetText(data.text or "")
		entity:SetSubtext(data.subtext or "")
		entity:SetStyle(data.style or 0)
		entity:SetTextScale(data.scale or 1)
	end,
	nw_forcefield = function(entity, data)
		entity:SetMode(data.mode or 1)
	end,
	nw_dispenser = function(entity, data)
		entity:SetEnabled(data.bEnabled != false)

		if (data.basic != nil) then
			entity:SetStockBasic(math.Clamp(tonumber(data.basic) or 0, 0, entity.MaxStock))
			entity:SetStockStandard(math.Clamp(tonumber(data.standard) or 0, 0, entity.MaxStock))
			entity:SetStockPremium(math.Clamp(tonumber(data.premium) or 0, 0, entity.MaxStock))
		end
	end,
	nw_vending = function() end,
	nw_junk = function(entity, data)
		if (isstring(data.model) and data.model != "") then
			entity:SetJunkModel(data.model)
			entity:Apply()
		end

		entity:SetMinItems(math.Clamp(math.Round(tonumber(data.minItems) or 1), 1, 10))
		entity:SetMaxItems(math.Clamp(math.Round(tonumber(data.maxItems) or 2),
			entity:GetMinItems(), 10))

		entity:SetRefill(math.Clamp(math.Round(tonumber(data.refill) or 0),
			-1, 86400))

		if (istable(data.loot)) then
			entity.loot = data.loot
		end
	end,
	nw_breaker = function(entity, data)
		entity:SetNWBool("nwBroken", data.bBroken == true)

		if (isstring(data.model) and data.model != "") then
			entity:SetBreakerModel(data.model)
			entity:Apply()
		end
	end,
	nw_stash = function(entity, data)
		if (isstring(data.model) and data.model != "") then
			entity:SetStashModel(data.model)
			entity:Apply()
		end

		entity.nwGroup = isstring(data.group) and data.group or nil
	end,
	nw_furnitureshop = function(entity, data)
		if (isstring(data.model) and data.model != "") then
			entity:SetShopModel(data.model)
			entity:Apply()
		end
	end,
	nw_furniture = function(entity, data)
		entity.nwOwner = data.owner

		entity:SetLocked(data.bLocked == true)

		if (data.bLocked) then
			local physics = entity:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:EnableMotion(false)
				physics:Sleep()
			end
		end
	end,
	prop_physics = function(entity, data)
		NETWORK.entities.RestoreProp(entity, data)
	end,
	prop_dynamic = function(entity, data)
		NETWORK.entities.RestoreProp(entity, data)
	end,
	prop_physics_multiplayer = function(entity, data)
		NETWORK.entities.RestoreProp(entity, data)
	end
}

sql.Query([[
	CREATE TABLE IF NOT EXISTS ]] .. TABLE_NAME .. [[ (
		map TEXT NOT NULL,
		data TEXT NOT NULL
	)
]])

util.AddNetworkString("nwEntitySave")

net.Receive("nwEntitySave", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then
		return
	end

	local entity = net.ReadEntity()

	if (IsValid(entity) and NETWORK.entities.IsProp and
		NETWORK.entities.IsProp(entity)) then
		entity.nwPersist = true
		entity:SetNWBool("nwPersist", true)

		local physics = entity:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	NETWORK.entities.Save()

	NETWORK.chat.Notice(client, IsValid(entity) and
		NETWORK.entities.IsProp(entity) and "entityPersisted" or
		"entitiesSaved")
end)

NETWORK.entities.propClasses = {
	prop_physics = true,
	prop_dynamic = true,
	prop_physics_multiplayer = true
}

function NETWORK.entities.IsProp(entity)
	return IsValid(entity) and
		NETWORK.entities.propClasses[entity:GetClass()] == true
end

NETWORK.entities.noSave = {
	nw_item = true,
	nw_ragdoll = true,
	nw_letter = true,

	nw_furniture = true
}

function NETWORK.entities.CollectGeneric(entity)
	local data = NETWORK.entities.CollectProp(entity)

	data.bGeneric = true

	if (entity.GetNetworkVars) then
		data.vars = entity:GetNetworkVars() or {}
	end

	return data
end

RESTORE.nw_campfire = function(entity, data)
	if (isstring(data.model) and (util.IsValidModel(data.model) or
		file.Exists(data.model, "GAME"))) then
		util.PrecacheModel(data.model)
		entity:SetModel(data.model)
		entity:PhysicsInit(SOLID_VPHYSICS)
	end

	entity:SetFuel(math.Clamp(tonumber(data.fuel) or 0, 0, entity.fuelMax))

	if (data.lit and entity:GetFuel() > 0) then
		entity:SetLitState(true)
	end
end

RESTORE.nw_board = function(entity, data)
	if (isstring(data.model) and (util.IsValidModel(data.model) or file.Exists(data.model, "GAME"))) then
		util.PrecacheModel(data.model)
		entity:SetModel(data.model)

		if (entity.SetupPhysics) then
			entity:SetupPhysics()
		else
			entity:PhysicsInit(SOLID_VPHYSICS)
		end
	end

	entity.notices = istable(data.notices) and data.notices or {}
	entity:SetCount(#entity.notices)
end

function NETWORK.entities.CollectLook(entity, data)
	if (!istable(data)) then
		return data
	end

	if (data.material == nil) then
		data.material = entity:GetMaterial() or ""
	end

	if (data.color == nil) then
		local color = entity:GetColor()

		data.color = {color.r, color.g, color.b, color.a}
	end

	return data
end

function NETWORK.entities.ApplyLook(entity, data)
	if (!IsValid(entity) or !istable(data)) then
		return
	end

	if (isstring(data.material) and data.material != "") then
		entity:SetMaterial(data.material)
	end

	local color = data.color

	if (istable(color) and #color >= 4) then
		entity:SetColor(Color(color[1], color[2], color[3], color[4]))

		if (color[4] < 255) then
			entity:SetRenderMode(RENDERMODE_TRANSALPHA)
		end
	end
end

function NETWORK.entities.RestoreGeneric(entity, data)
	NETWORK.entities.RestoreProp(entity, data)

	if (istable(data.vars)) then
		for key, value in pairs(data.vars) do
			if (!isstring(key)) then
				continue
			end

			if (isnumber(value) and (string.find(key, "End$") or string.find(key, "At$") or
				string.find(key, "Time$") or string.find(key, "Until$") or
				string.find(key, "Next$") or string.find(key, "Start$"))) then
				continue
			end

			local setter = entity["Set" .. key]

			if (isfunction(setter)) then
				local bOk, err = pcall(setter, entity, value)

				if (!bOk) then
					NETWORK.util.PrintWarning("Восстановление " .. entity:GetClass() .. "." ..
						key .. ": " .. tostring(err))
				end
			end
		end
	end
end

function NETWORK.entities.Save()
	local list = {}

	for _, entity in ipairs(ents.GetAll()) do
		if (!IsValid(entity)) then
			continue
		end

		local class = entity:GetClass()

		if (string.sub(class, 1, 3) != "nw_" or SAVED[class]) then
			continue
		end

		if (NETWORK.entities.noSave[class] or entity.bNoPersist) then
			continue
		end

		local owner = entity:GetOwner()

		if (IsValid(owner) and owner:IsPlayer()) then
			continue
		end

		local position = entity:GetPos()
		local angles = entity:GetAngles()

		list[#list + 1] = {
			class = class,
			position = {position.x, position.y, position.z},
			angles = {angles.p, angles.y, angles.r},
			data = NETWORK.entities.CollectGeneric(entity)
		}
	end

	for class, collect in pairs(SAVED) do
		local filter = FILTER[class]

		for _, entity in ipairs(ents.FindByClass(class)) do
			if (!IsValid(entity)) then
				continue
			end

			if (filter and !filter(entity)) then
				continue
			end

			local position = entity:GetPos()

			local angles = entity.baseAngles or entity:GetAngles()

			list[#list + 1] = {
				class = class,
				position = {position.x, position.y, position.z},
				angles = {angles.p, angles.y, angles.r},
				data = NETWORK.entities.CollectLook(entity, collect(entity))
			}
		end
	end

	local encoded = util.TableToJSON(list)

	if (!encoded) then
		NETWORK.util.PrintWarning("Не удалось упаковать сущности.")

		return false
	end

	sql.Query("DELETE FROM " .. TABLE_NAME .. " WHERE map = " ..
		sql.SQLStr(game.GetMap()))
	sql.Query(string.format("INSERT INTO %s (map, data) VALUES (%s, %s)", TABLE_NAME,
		sql.SQLStr(game.GetMap()), sql.SQLStr(encoded)))

	NETWORK.util.Print("Сохранено сущностей: " .. #list)

	return true
end

NETWORK.entities.loaders = NETWORK.entities.loaders or {}

NETWORK.entities.loaders.nw_crafttable = function(entity, data)
	entity:SetTableName(data.name or "")
	entity:SetTableModel(data.model or "")

	entity.recipes = istable(data.recipes) and data.recipes or {}

	entity:Apply()
end

function NETWORK.entities.Load()
	local rows = sql.Query("SELECT data FROM " .. TABLE_NAME .. " WHERE map = " ..
		sql.SQLStr(game.GetMap()))

	if (!istable(rows) or !rows[1]) then
		return
	end

	local list = util.JSONToTable(rows[1].data or "")

	if (!istable(list)) then
		return
	end

	local count = 0

	local function AlreadyThere(class, position)
		for _, other in ipairs(ents.FindInSphere(position, 8)) do
			if (IsValid(other) and other:GetClass() == class and
				other:GetPos():DistToSqr(position) <= 8 * 8) then
				return true
			end
		end

		return false
	end

	for _, entry in ipairs(list) do
		local restore = RESTORE[entry.class]
		local bGeneric = istable(entry.data) and entry.data.bGeneric == true

		if (istable(entry.position) and AlreadyThere(entry.class,
			Vector(entry.position[1], entry.position[2], entry.position[3]))) then
			continue
		end

		if (!restore and !bGeneric) then
			continue
		end

		if (bGeneric and !(restore and GENERIC_UPGRADE[entry.class])) then
			restore = NETWORK.entities.RestoreGeneric
		end

		local entity = ents.Create(entry.class)

		if (!IsValid(entity)) then
			continue
		end

		entity:SetPos(Vector(entry.position[1], entry.position[2], entry.position[3]))
		entity:SetAngles(Angle(entry.angles[1], entry.angles[2], entry.angles[3]))

		local data = entry.data or {}

		if (string.sub(entry.class, 1, 5) == "prop_" and
			isstring(data.model) and util.IsValidModel(data.model)) then
			entity:SetModel(data.model)
		end

		local loader = NETWORK.entities.loaders and
			NETWORK.entities.loaders[entry.class]

		if (loader) then
			entity:Spawn()
			entity:Activate()

			loader(entity, data)

			continue
		end

		if (entry.class == "nw_furniture" and isstring(data.id)) then
			entity:SetFurnitureID(data.id)
		end

		entity:Spawn()
		entity:Activate()

		local bOk, err = pcall(restore, entity, data or entry.data or {})

		if (!bOk) then
			NETWORK.util.PrintWarning("Восстановление " .. entry.class .. ": " ..
				tostring(err))
		end

		if (string.sub(entry.class, 1, 5) != "prop_") then
			NETWORK.entities.ApplyLook(entity, data or entry.data)
		end

		count = count + 1
	end

	NETWORK.util.Print("Восстановлено сущностей: " .. count)
end

hook.Add("InitPostEntity", "nwEntities", function()
	timer.Simple(2, function()
		NETWORK.entities.Load()
	end)
end)

hook.Add("ShutDown", "nwEntities", function()
	NETWORK.entities.Save()
end)

timer.Create("nwEntities", 120, 0, function()
	NETWORK.entities.Save()
end)

NETWORK.command.Register("saveall", {
	adminOnly = true,
	description = "cmdSaveAll",
	OnRun = function(command, client)
		local marked = 0

		for _, entity in ipairs(ents.GetAll()) do
			if (!NETWORK.entities.IsProp(entity)) then
				continue
			end

			if (entity:MapCreationID() > 0 or entity:IsPlayerHolding()) then
				continue
			end

			entity.nwPersist = true
			entity:SetNWBool("nwPersist", true)

			local physics = entity:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:EnableMotion(false)
				physics:Sleep()
			end

			marked = marked + 1
		end

		local bOk = NETWORK.entities.Save()

		NETWORK.notice.Send(client, bOk and "saveAllDone" or "saveAllFailed",
			bOk and "good" or "bad", marked)
	end
})

concommand.Add("network_entities_save", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	NETWORK.entities.Save()
end)

concommand.Add("network_entities_clear", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	sql.Query("DELETE FROM " .. TABLE_NAME .. " WHERE map = " ..
		sql.SQLStr(game.GetMap()))

	NETWORK.util.Print("Сохранение сущностей очищено.")
end)

SAVED.nw_ration_bin = SAVED.nw_container
RESTORE.nw_ration_bin = RESTORE.nw_container
