AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Тайник"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

NETWORK.cache = NETWORK.cache or {}

local C = NETWORK.cache

C.slots = 8
C.range = 110
C.placeRange = 100
C.placeTime = 3
C.pickupTime = 2
C.doorRadius = 150
C.spawnRadius = 256
C.neighbourRadius = 48
C.alertCooldown = 300
C.ownerRange = 600
C.kitItem = "cache_kit"

C.models = {
	"models/props_junk/cardboard_box003a.mdl",
	"models/props_junk/wood_crate001a.mdl",
	"models/props_c17/SuitCase001a.mdl",
	"models/props_junk/garbage_bag001a.mdl"
}

local validModels

function C.GetModels()
	if (validModels) then
		return validModels
	end

	validModels = {}

	for _, path in ipairs(C.models) do
		if (util.IsValidModel(path) or file.Exists(path, "GAME")) then
			validModels[#validModels + 1] = path
		end
	end

	if (#validModels == 0) then
		validModels[1] = NETWORK.container.fallback
	end

	return validModels
end

function C.IsValidModel(path)
	for _, model in ipairs(C.GetModels()) do
		if (model == path) then
			return true
		end
	end

	return false
end

function C.GetLimit()
	return math.max(math.Round(NETWORK.config and NETWORK.config.Get("cacheLimit") or 3), 0)
end

if (NETWORK.config and NETWORK.config.Register) then
	NETWORK.config.Register("cacheLimit", {
		name = "cfgCacheLimit",
		description = "cfgCacheLimitDesc",
		category = "inventory",
		default = 3,
		min = 0,
		max = 10,
		decimals = 0
	})
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "CacheModel")
	self:NetworkVar("String", 1, "LockItem")
	self:NetworkVar("String", 2, "LockCode")
	self:NetworkVar("Int", 0, "OwnerChar")
end

function ENT:IsOwner(client)
	local owner = self:GetOwnerChar()

	return owner > 0 and IsValid(client) and client:IsPlayer() and
		client:GetCharacterID() == owner
end

function ENT:GetContainerSlots()
	return C.slots
end

function ENT:GetContainerID()
	return ""
end

function ENT:GetContainerRefill()
	return 0
end

function ENT:GetDisplayName()
	return L("cacheName")
end

function ENT:GetDisplayDescription()
	return ""
end

if (SERVER) then
	util.AddNetworkString("nwCacheMenu")
	util.AddNetworkString("nwCacheAction")
	util.AddNetworkString("nwCacheGhost")

	C.file = "network/caches.txt"

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_cache")

		if (!IsValid(entity)) then
			return
		end

		entity:SetPos(trace.HitPos + trace.HitNormal * 4)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0))
		entity:Spawn()
		entity:Activate()

		C.Save()

		return entity
	end

	function ENT:Initialize()
		local model = self.cacheModel or self:GetCacheModel()

		if (!isstring(model) or !C.IsValidModel(model)) then
			local list = C.GetModels()

			model = list[math.random(#list)]
		end

		self:SetCacheModel(model)
		self:SetOwnerChar(math.max(tonumber(self.cacheOwner) or self:GetOwnerChar(), 0))

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.items = self.items or {}
		self.viewers = {}
		self.nextUse = 0

		self.bNoPersist = true
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter() or
			self.nextUse > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.5

		if (client:GetPos():Distance(self:GetPos()) > C.range) then
			return
		end

		if (client:KeyDown(IN_SPEED) and self:IsOwner(client)) then
			net.Start("nwCacheMenu")
				net.WriteEntity(self)
				net.WriteBool(next(self.items or {}) == nil)
			net.Send(client)

			return
		end

		NETWORK.container.Begin(client, self)
	end

	function ENT:OnRemove()
		for client in pairs(self.viewers or {}) do
			if (IsValid(client)) then
				NETWORK.container.Close(client)
			end
		end
	end

	function C.CountOwned(character)
		local count = 0

		for _, entity in ipairs(ents.FindByClass("nw_cache")) do
			if (entity:GetOwnerChar() == character) then
				count = count + 1
			end
		end

		return count
	end

	function C.FindKit(client)
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({"items", "storage"}) do
			for index, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == C.kitItem) then
					return state, list, index, item
				end
			end
		end
	end

	function C.TakeKit(client)
		local state, list, index, item = C.FindKit(client)

		if (!item) then
			return false
		end

		if ((item.amount or 1) > 1) then
			item.amount = item.amount - 1
		else
			NETWORK.inventory.Put(state, list, index, nil, nil)
		end

		NETWORK.inventory.Sync(client)

		return true
	end

	function C.GiveKit(client)
		if (!NETWORK.inventory.Give(client, C.kitItem, 1)) then
			NETWORK.item.Spawn(C.kitItem, client:GetPos() + client:GetForward() * 20 +
				Vector(0, 0, 12))
		end
	end

	local SPAWN_CLASSES = {
		"info_player_start", "info_player_deathmatch", "info_player_combine",
		"info_player_rebel", "info_player_counterterrorist", "info_player_terrorist"
	}

	function C.CheckSpot(position, filter)
		local hull = util.TraceHull({
			start = position + Vector(0, 0, 4),
			endpos = position + Vector(0, 0, 4),
			mins = Vector(-16, -16, 0),
			maxs = Vector(16, 16, 30),
			filter = filter,
			mask = MASK_SOLID
		})

		if (hull.Hit or hull.StartSolid) then
			return "cacheBlocked"
		end

		for _, entity in ipairs(ents.FindInSphere(position, C.doorRadius)) do
			if (NETWORK.door and NETWORK.door.IsDoor and NETWORK.door.IsDoor(entity)) then
				return "cacheNearDoor"
			end
		end

		for _, entity in ipairs(ents.FindInSphere(position, C.neighbourRadius)) do
			if (NETWORK.container.classes[entity:GetClass()]) then
				return "cacheBlocked"
			end
		end

		for _, class in ipairs(SPAWN_CLASSES) do
			for _, spawn in ipairs(ents.FindByClass(class)) do
				if (spawn:GetPos():Distance(position) < C.spawnRadius) then
					return "cacheNearSpawn"
				end
			end
		end
	end

	function C.FindSpot(client)
		local start = client:GetShootPos()
		local trace = util.TraceLine({
			start = start,
			endpos = start + client:GetAimVector() * C.placeRange,
			filter = client,
			mask = MASK_SOLID
		})

		if (!trace.Hit or trace.HitSky) then
			return nil, nil, "cacheBadSpot"
		end

		if (trace.HitNormal.z < 0.7 or !trace.HitWorld) then
			return nil, nil, "cacheNotGround"
		end

		local position = trace.HitPos
		local reason = C.CheckSpot(position, client)

		if (reason) then
			return nil, nil, reason
		end

		local angles = Angle(0, client:EyeAngles().y + 180 + math.random(-25, 25), 0)

		return position, angles
	end

	local function Ghost(client, task)
		net.Start("nwCacheGhost")
			net.WriteBool(task != nil)

			if (task) then
				net.WriteVector(task.position)
				net.WriteAngle(task.angles)
				net.WriteString(task.model)
			end
		net.Send(client)
	end

	local function StopProgress(client)
		net.Start("nwProgress")
			net.WriteString("")
			net.WriteFloat(0)
		net.Send(client)
	end

	function C.Cancel(client)
		if (!client.nwCachePlace) then
			return
		end

		client.nwCachePlace = nil

		StopProgress(client)
		Ghost(client, nil)
	end

	function C.Begin(client)
		if (!IsValid(client) or !client:Alive() or !client:HasCharacter() or
			client.nwCachePlace or client.nwContainerPending) then
			return
		end

		if (!C.FindKit(client)) then
			return
		end

		local limit = C.GetLimit()

		if (C.CountOwned(client:GetCharacterID()) >= limit) then
			return NETWORK.notice.Send(client, "cacheLimit", "warn", limit)
		end

		local position, angles, reason = C.FindSpot(client)

		if (!position) then
			return NETWORK.notice.Send(client, reason, "warn")
		end

		local models = C.GetModels()

		client.nwCachePlace = {
			position = position,
			angles = angles,
			model = models[math.random(#models)],
			start = client:GetPos(),
			finish = CurTime() + C.placeTime
		}

		net.Start("nwProgress")
			net.WriteString("progressCache")
			net.WriteFloat(C.placeTime)
		net.Send(client)

		Ghost(client, client.nwCachePlace)

		client:EmitSound("physics/cardboard/cardboard_box_impact_soft" ..
			math.random(1, 7) .. ".wav", 55, 100, 0.5)
	end

	function C.Place(client, task)
		local reason = C.CheckSpot(task.position, client)

		if (reason) then
			return NETWORK.notice.Send(client, reason, "warn")
		end

		if (C.CountOwned(client:GetCharacterID()) >= C.GetLimit()) then
			return NETWORK.notice.Send(client, "cacheLimit", "warn", C.GetLimit())
		end

		if (!C.TakeKit(client)) then
			return
		end

		local entity = ents.Create("nw_cache")

		if (!IsValid(entity)) then
			C.GiveKit(client)

			return
		end

		entity.cacheModel = task.model
		entity.cacheOwner = client:GetCharacterID()

		entity:SetPos(task.position)
		entity:SetAngles(task.angles)
		entity:Spawn()
		entity:Activate()

		entity:SetPos(task.position + Vector(0, 0, -entity:OBBMins().z + 0.5))

		entity:EmitSound("physics/cardboard/cardboard_box_impact_hard" ..
			math.random(1, 7) .. ".wav", 55, 100, 0.6)

		NETWORK.notice.Send(client, "cachePlaced", "good")

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("item", string.format("%s спрятал тайник",
				NETWORK.log.Name and NETWORK.log.Name(client) or client:Name()),
				entity:GetPos())
		end

		C.Save()
	end

	hook.Add("Think", "nwCachePlace", function()
		if (!NETWORK.util.Throttle("cache.place", 0.1)) then
			return
		end

		for _, client in ipairs(player.GetAll()) do
			local task = client.nwCachePlace

			if (!task) then
				continue
			end

			if (!client:Alive() or !client:HasCharacter() or
				client:GetPos():Distance(task.start) > 48 or
				client:GetPos():Distance(task.position) > C.placeRange + 40) then
				C.Cancel(client)

				continue
			end

			if (CurTime() < task.finish) then
				continue
			end

			client.nwCachePlace = nil

			Ghost(client, nil)

			local bOk, err = pcall(C.Place, client, task)

			if (!bOk) then
				ErrorNoHalt("[Network] cache: " .. tostring(err) .. "\n")
			end
		end
	end)

	hook.Add("PlayerDisconnected", "nwCachePlace", function(client)
		client.nwCachePlace = nil
	end)

	function C.OwnerAction(client, entity, action)
		if (!IsValid(entity) or entity:GetClass() != "nw_cache" or
			!entity:IsOwner(client) or
			client:GetPos():Distance(entity:GetPos()) > C.range) then
			return
		end

		if (action == "open") then
			return NETWORK.container.Begin(client, entity)
		end

		if (action == "lock") then
			if (NETWORK.container.IsLocked(entity)) then
				return NETWORK.notice.Send(client, "cacheAlreadyLocked", "info")
			end

			NETWORK.container.GiveKey(client, entity, L("cacheKeyLabel"))

			entity:EmitSound("doors/door_latch3.wav", 55)

			return NETWORK.notice.Send(client, "cacheLocked", "good")
		end

		if (action == "unlock") then
			if (!NETWORK.container.IsLocked(entity)) then
				return
			end

			NETWORK.container.SetLock(entity, "", "")

			entity:EmitSound("doors/door_latch1.wav", 55)

			return NETWORK.notice.Send(client, "cacheUnlocked", "good")
		end

		if (action == "pickup") then
			if (next(entity.items or {}) != nil) then
				return NETWORK.notice.Send(client, "cacheNotEmpty", "warn")
			end

			if (next(entity.viewers or {}) != nil or client.nwCachePickup) then
				return NETWORK.notice.Send(client, "cacheBusy", "warn")
			end

			client.nwCachePickup = entity

			net.Start("nwProgress")
				net.WriteString("progressCachePickup")
				net.WriteFloat(C.pickupTime)
			net.Send(client)

			local start = client:GetPos()

			timer.Simple(C.pickupTime, function()
				if (!IsValid(client)) then
					return
				end

				client.nwCachePickup = nil

				if (!IsValid(entity) or !client:Alive() or
					client:GetPos():Distance(start) > 48 or
					next(entity.items or {}) != nil or
					next(entity.viewers or {}) != nil) then
					StopProgress(client)

					return
				end

				entity:Remove()

				C.GiveKit(client)
				C.Save()

				NETWORK.notice.Send(client, "cachePickedUp", "good")
			end)
		end
	end

	net.Receive("nwCacheAction", function(_, client)
		local entity = net.ReadEntity()
		local action = net.ReadString()

		if ((client.nwNextCacheAction or 0) > CurTime()) then
			return
		end

		client.nwNextCacheAction = CurTime() + 0.5

		C.OwnerAction(client, entity, action)
	end)

	hook.Add("NetworkContainerOpened", "nwCache", function(client, entity)
		if (!IsValid(entity) or entity:GetClass() != "nw_cache" or entity:IsOwner(client)) then
			return
		end

		local owner = entity:GetOwnerChar()

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("item", string.format("%s открыл чужой тайник (персонаж #%d)",
				NETWORK.log.Name and NETWORK.log.Name(client) or client:Name(), owner),
				entity:GetPos())
		end

		if (owner <= 0 or (entity.nwNextAlert or 0) > CurTime()) then
			return
		end

		entity.nwNextAlert = CurTime() + C.alertCooldown

		local zoneName

		if (NETWORK.zone and NETWORK.zone.AtEntity) then
			local zone = NETWORK.zone.AtEntity(entity)

			zoneName = zone and isstring(zone.name) and zone.name != "" and zone.name
		end

		for _, target in ipairs(player.GetAll()) do
			if (target:GetCharacterID() == owner) then
				if (zoneName) then
					NETWORK.notice.Send(target, "cacheRaidedZone", "warn", zoneName)
				else
					NETWORK.notice.Send(target, "cacheRaided", "warn")
				end
			end
		end
	end)

	hook.Add("NetworkContainerClosed", "nwCache", function(client, entity)
		if (IsValid(entity) and entity:GetClass() == "nw_cache") then
			C.Save()
		end
	end)

	hook.Add("NetworkContainerLockChanged", "nwCache", function(entity)
		if (IsValid(entity) and entity:GetClass() == "nw_cache") then
			C.Save()
		end
	end)

	local function ReadFile()
		local raw = file.Read(C.file, "DATA")
		local data = raw and util.JSONToTable(raw)

		return istable(data) and data or {}
	end

	function C.Write()
		if (!C.bLoaded) then
			return
		end

		local list = {}

		for _, entity in ipairs(ents.FindByClass("nw_cache")) do
			local position = entity:GetPos()
			local angles = entity:GetAngles()
			local items = {}

			for index, item in pairs(entity.items or {}) do
				items[tostring(index)] = item
			end

			list[#list + 1] = {
				pos = {math.Round(position.x, 2), math.Round(position.y, 2),
					math.Round(position.z, 2)},
				ang = {math.Round(angles.p, 1), math.Round(angles.y, 1),
					math.Round(angles.r, 1)},
				model = entity:GetCacheModel(),
				owner = entity:GetOwnerChar(),
				lockItem = entity:GetLockItem(),
				lockCode = entity:GetLockCode(),
				items = items
			}
		end

		local data = ReadFile()

		data[game.GetMap()] = list

		file.CreateDir("network")
		file.Write(C.file, util.TableToJSON(data, true))
	end

	function C.Save()
		timer.Create("nwCacheSave", 3, 1, function()
			local bOk, err = pcall(C.Write)

			if (!bOk) then
				ErrorNoHalt("[Network] cache save: " .. tostring(err) .. "\n")
			end
		end)
	end

	function C.Load()
		local list = ReadFile()[game.GetMap()]
		local count = 0

		for _, entry in ipairs(istable(list) and list or {}) do
			if (!istable(entry) or !istable(entry.pos)) then
				continue
			end

			local entity = ents.Create("nw_cache")

			if (!IsValid(entity)) then
				continue
			end

			local items = {}

			for index, item in pairs(istable(entry.items) and entry.items or {}) do
				local slot = tonumber(index)

				if (slot and istable(item) and NETWORK.item.Get(item.id)) then
					items[slot] = item
				end
			end

			entity.cacheModel = isstring(entry.model) and entry.model or nil
			entity.cacheOwner = tonumber(entry.owner) or 0
			entity.items = items

			local ang = istable(entry.ang) and entry.ang or {}

			entity:SetPos(Vector(tonumber(entry.pos[1]) or 0, tonumber(entry.pos[2]) or 0,
				tonumber(entry.pos[3]) or 0))
			entity:SetAngles(Angle(tonumber(ang[1]) or 0, tonumber(ang[2]) or 0,
				tonumber(ang[3]) or 0))
			entity:Spawn()
			entity:Activate()

			if (isstring(entry.lockItem) and entry.lockItem != "") then
				entity:SetLockItem(entry.lockItem)
				entity:SetLockCode(tostring(entry.lockCode or ""))
			end

			count = count + 1
		end

		C.bLoaded = true

		if (count > 0) then
			NETWORK.util.Print("Восстановлено тайников: " .. count)
		end
	end

	hook.Add("InitPostEntity", "nwCache", function()
		timer.Simple(4, function()
			local bOk, err = pcall(C.Load)

			C.bLoaded = true

			if (!bOk) then
				NETWORK.util.PrintWarning("Тайники: " .. tostring(err))
			end
		end)
	end)

	timer.Create("nwCachePeriodic", 300, 0, function()
		if (C.bLoaded and #ents.FindByClass("nw_cache") > 0) then
			C.Save()
		end
	end)

	hook.Add("ShutDown", "nwCache", function()
		timer.Remove("nwCacheSave")

		pcall(C.Write)
	end)

	concommand.Add("network_cache_remove", function(client)
		if (!IsValid(client) or !client:IsAdmin()) then
			return
		end

		local entity = client:GetEyeTrace().Entity

		if (!IsValid(entity) or entity:GetClass() != "nw_cache") then
			return
		end

		entity:Remove()

		C.Save()

		NETWORK.notice.Send(client, "cacheRemoved", "good")
	end)
else
	NETWORK.interact.Register("nw_cache", {icon = "delete"})

	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (!self:IsOwner(client) or NETWORK.hud.IsHidden()) then
			return
		end

		local distance = EyePos():Distance(self:GetPos())

		if (distance > C.ownerRange) then
			return
		end

		local fade = 1 - math.Clamp((distance - C.ownerRange * 0.7) /
			(C.ownerRange * 0.3), 0, 1)
		local position = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 12)
		local direction = position - EyePos()

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			return
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local title = L("cacheOwnLabel")
		local subtitle = NETWORK.container.IsLocked(self) and L("containerLockedTag") or
			L("cacheOwnHint")

		cam.Start3D2D(position, angles, 0.14)
			surface.SetFont("nwChat")

			local titleWidth = surface.GetTextSize(title)

			surface.SetFont("nwHudSmall")

			local subWidth = surface.GetTextSize(subtitle)
			local width = math.max(titleWidth, subWidth) + 34
			local height = 48

			NETWORK.label.Frame(-width * 0.5, -height * 0.5, width, height,
				NETWORK.theme.combine, fade)

			draw.SimpleText(title, "nwChat", 0, -height * 0.5 + 14,
				ColorAlpha(NETWORK.theme.text, 250 * fade), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(subtitle, "nwHudSmall", 0, height * 0.5 - 14,
				ColorAlpha(NETWORK.theme.textDim, 240 * fade), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end

	hook.Add("PreDrawHalos", "nwCache", function()
		local client = LocalPlayer()

		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		local list = {}
		local eye = EyePos()

		for _, entity in ipairs(ents.FindByClass("nw_cache")) do
			if (entity:IsOwner(client) and eye:Distance(entity:GetPos()) <= C.ownerRange) then
				list[#list + 1] = entity
			end
		end

		if (#list > 0) then
			halo.Add(list, ColorAlpha(NETWORK.theme.combine, 200), 1, 1, 1, true, false)
		end
	end)

	local ghost

	local function RemoveGhost()
		if (IsValid(ghost)) then
			ghost:Remove()
		end

		ghost = nil
	end

	net.Receive("nwCacheGhost", function()
		RemoveGhost()

		if (!net.ReadBool()) then
			return
		end

		local position = net.ReadVector()
		local angles = net.ReadAngle()
		local model = net.ReadString()

		ghost = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)

		if (!IsValid(ghost)) then
			return
		end

		ghost:SetPos(position + Vector(0, 0, -ghost:OBBMins().z + 0.5))
		ghost:SetAngles(angles)
		ghost:SetRenderMode(RENDERMODE_TRANSALPHA)
		ghost:SetColor(Color(150, 196, 246, 110))

		timer.Create("nwCacheGhost", C.placeTime + 2, 1, RemoveGhost)
	end)

	net.Receive("nwCacheMenu", function()
		local entity = net.ReadEntity()
		local bEmpty = net.ReadBool()

		if (!IsValid(entity)) then
			return
		end

		local function Send(action)
			net.Start("nwCacheAction")
				net.WriteEntity(entity)
				net.WriteString(action)
			net.SendToServer()
		end

		local menu = vgui.Create("nwItemMenu")
		local palette = NETWORK.theme.inv

		menu:SetWidth(NETWORK.util.Scale(220))

		menu:AddOption(L("cacheMenuOpen"), function()
			Send("open")
		end, nil, "backpack")

		if (NETWORK.container.IsLocked(entity)) then
			menu:AddOption(L("cacheMenuUnlock"), function()
				Send("unlock")
			end, nil, "split")
		else
			menu:AddOption(L("cacheMenuLock"), function()
				Send("lock")
			end, nil, "cuffs")
		end

		menu:AddOption(L("cacheMenuPickup"), function()
			Send("pickup")
		end, bEmpty and nil or (palette and palette.textDim), "hand")

		menu:OpenAt(math.Round(ScrW() * 0.5) + NETWORK.util.Scale(12),
			math.Round(ScrH() * 0.5) + NETWORK.util.Scale(12))
	end)
end
