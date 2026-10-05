AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Раздатчик пайков"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.Displays = {
	[1] = {"dispenseInsert", Color(226, 236, 248), true},
	[2] = {"dispenseChecking", Color(240, 200, 90)},
	[3] = {"dispenseGiving", Color(120, 220, 140)},
	[4] = {"dispenseNoTicket", Color(232, 92, 92)},
	[5] = {"dispenseWait", Color(240, 200, 90)},
	[6] = {"dispenseOffline", Color(232, 92, 92), true},
	[7] = {"dispenseNoStock", Color(232, 92, 92)},
	[8] = {"dispenseLoaded", Color(120, 220, 140)},
	[9] = {"dispenseNoCard", Color(232, 92, 92)},
	[10] = {"dispenseLimit", Color(232, 92, 92)},

	[11] = {"rebelSysError", Color(232, 92, 92)}
}

ENT.Tickets = {
	{ticket = "ticket_premium", ration = "ration_premium", level = 3},
	{ticket = "ticket_standard", ration = "ration_standard", level = 2},
	{ticket = "ticket_basic", ration = "ration_basic", level = 1}
}

ENT.RationLevels = {
	ration_basic = 1,
	ration_standard = 2,
	ration_premium = 3
}

ENT.MaxStock = 24
ENT.MaxTotal = 25

ENT.bRequireTicket = false
ENT.bUseSchedule = true

function ENT.GetDispenserModel()
	local model = "models/props_combine/combine_dispenser.mdl"

	if (file.Exists(model, "GAME")) then
		util.PrecacheModel(model)

		return model
	end

	return "models/props_interiors/VendingMachineSoda01a.mdl"
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Display")
	self:NetworkVar("Int", 1, "StockBasic")
	self:NetworkVar("Int", 2, "StockStandard")
	self:NetworkVar("Int", 3, "StockPremium")
	self:NetworkVar("Bool", 0, "Enabled")
end

function ENT:GetStock(level)
	if (level == 3) then
		return self:GetStockPremium()
	end

	if (level == 2) then
		return self:GetStockStandard()
	end

	return self:GetStockBasic()
end

if (SERVER) then

	function ENT:PlaceAt(trace, client)
		local normal = trace.HitNormal
		local bWall = math.abs(normal.z) <= 0.7
		local angles

		if (bWall) then

			angles = normal:Angle()
			angles.p = 0
			angles.r = 0
		else
			angles = Angle(0, IsValid(client) and
				(client:EyeAngles().y + 180) or 0, 0)
			normal = Vector(0, 0, 1)
		end

		self:SetAngles(angles)

		local mins = self.collisionMins or self:OBBMins()
		local position = trace.HitPos

		if (bWall) then

			local floor = util.TraceLine({
				start = position,
				endpos = position - Vector(0, 0, 1024),
				filter = self,
				mask = MASK_SOLID
			})

			if (floor.Hit and floor.HitPos.z > position.z + mins.z) then
				position.z = floor.HitPos.z - mins.z
			end
		else

			local floor = util.TraceLine({
				start = position + Vector(0, 0, 8),
				endpos = position - Vector(0, 0, 1024),
				filter = self,
				mask = MASK_SOLID
			})

			if (floor.Hit) then
				position.z = floor.HitPos.z - mins.z
			end
		end

		self:SetPos(position)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_dispenser")

		if (!IsValid(entity)) then
			return
		end

		entity:SetPos(trace.HitPos)
		entity:Spawn()
		entity:Activate()
		entity:PlaceAt(trace, client)

		if (NETWORK.entities and NETWORK.entities.Save) then
			NETWORK.entities.Save()
		end

		return entity
	end

	function ENT:Initialize()
		local model = self.GetDispenserModel()

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)

		local mins, maxs = self:OBBMins(), self:OBBMaxs()
		local inset = Vector(0, 3, 2)

		mins = Vector(math.min(mins.x * 0.15, -1), mins.y + inset.y,
			mins.z + inset.z)
		maxs = Vector(maxs.x, maxs.y - inset.y, maxs.z - inset.z)

		self.collisionMins = mins
		self.collisionMaxs = maxs

		self:PhysicsInitBox(mins, maxs)
		self:SetCollisionBounds(mins, maxs)
		self:SetSolid(SOLID_BBOX)
		self:SetNotSolid(false)
		self:SetCollisionGroup(COLLISION_GROUP_NONE)
		self:CollisionRulesChanged()

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.AutomaticFrameAdvance = true

		local idle = self:LookupSequence("idle")

		if (idle and idle > 0) then
			self:ResetSequence(idle)
		end

		self:SetPlaybackRate(1)
		self:SetDisplay(1)
		self:SetEnabled(true)

		if (self:GetStockBasic() <= 0 and self:GetStockStandard() <= 0 and
			self:GetStockPremium() <= 0) then
			self:SetStockBasic(8)
			self:SetStockStandard(4)
			self:SetStockPremium(2)
		end

		self.bReady = true
		self.nextUse = 0
	end

	function ENT:Think()
		self:NextThink(CurTime())

		if ((self.nextAbsorb or 0) < CurTime()) then
			self.nextAbsorb = CurTime() + 0.3

			self:AbsorbNearbyRations()
		end

		return true
	end

	function ENT:GetAbsorbBounds()
		local mins, maxs = self:OBBMins(), self:OBBMaxs()
		local low = Vector(math.huge, math.huge, math.huge)
		local high = Vector(-math.huge, -math.huge, -math.huge)

		for _, x in ipairs({mins.x, maxs.x}) do
			for _, y in ipairs({mins.y, maxs.y}) do
				for _, z in ipairs({mins.z, maxs.z}) do
					local corner = self:LocalToWorld(Vector(x, y, z))

					low.x, low.y, low.z = math.min(low.x, corner.x),
						math.min(low.y, corner.y), math.min(low.z, corner.z)
					high.x, high.y, high.z = math.max(high.x, corner.x),
						math.max(high.y, corner.y), math.max(high.z, corner.z)
				end
			end
		end

		local margin = Vector(14, 14, 14)

		return low - margin, high + margin
	end

	function ENT:AbsorbNearbyRations()
		if (!self:GetEnabled() or self:TotalStock() >= self.MaxTotal) then
			return
		end

		local low, high = self:GetAbsorbBounds()

		for _, entity in ipairs(ents.FindInBox(low, high)) do
			if (!IsValid(entity) or entity:GetClass() != "nw_item") then
				continue
			end

			if ((entity.nwNoAbsorb or 0) > CurTime()) then
				continue
			end

			local level = self.RationLevels[entity:GetItemID()]

			if (!level) then
				continue
			end

			local space = math.min(self.MaxStock - self:GetStock(level),
				self.MaxTotal - self:TotalStock())

			if (space <= 0) then
				continue
			end

			local amount = math.max(entity:GetItemAmount(), 1)
			local taken = math.min(amount, space)

			self:AddStock(level, taken)
			self:EmitSound("items/ammocrate_close.wav", 60)

			if (taken >= amount) then
				entity:Remove()
			else
				entity:SetItemAmount(amount - taken)
			end

			break
		end
	end

	function ENT:SetStock(level, value)
		value = math.Clamp(math.Round(tonumber(value) or 0), 0, self.MaxStock)

		if (level == 3) then
			self:SetStockPremium(value)
		elseif (level == 2) then
			self:SetStockStandard(value)
		else
			self:SetStockBasic(value)
		end
	end

	function ENT:TotalStock()
		return self:GetStockBasic() + self:GetStockStandard() +
			self:GetStockPremium()
	end

	function ENT:AddStock(level, amount)
		level = math.Clamp(math.Round(tonumber(level) or 1), 1, 3)

		self:SetStock(level, self:GetStock(level) + (tonumber(amount) or 0))
		self:SetDisplay(8)
		self:EmitSound("ambient/machines/combine_terminal_idle3.wav", 70, 105)

		timer.Simple(2, function()
			if (IsValid(self) and self.bReady) then
				self:SetDisplay(1)
			end
		end)
	end

	function ENT:Notify(client, key)
		if (IsValid(client)) then
			NETWORK.chat.Notice(client, key)
		end
	end

	function ENT:Fail(id, length)
		self:SetDisplay(id or 6)
		self:EmitSound("buttons/combine_button_locked.wav")

		self.bReady = false

		timer.Simple(length or 2, function()
			if (IsValid(self)) then
				self:SetDisplay(1)

				self.bReady = true
			end
		end)
	end

	function ENT:HasCard(client)
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({"items", "storage", "equipped"}) do
			for _, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == "idcard") then
					return true
				end
			end
		end

		return false
	end

	function ENT:FindTicket(client)
		local state = NETWORK.inventory.GetState(client)
		local held

		for _, entry in ipairs(self.Tickets) do
			for _, list in ipairs({"items", "storage"}) do
				for index, item in pairs(state[list] or {}) do
					if (!istable(item) or item.id != entry.ticket) then
						continue
					end

					if (self:GetStock(entry.level) > 0) then
						return entry, list, index
					end

					held = held or entry
				end
			end
		end

		return nil, nil, nil, held
	end

	function ENT:GetFactionLevel(client)
		if (NETWORK.factions.IsAlliance(client)) then
			return 3
		end

		if (NETWORK.factions.IsCWU(client)) then
			return 2
		end

		return 1
	end

	function ENT:FindFreeRation(client)
		local allowed = self:GetFactionLevel(client)

		for level = allowed, 1, -1 do
			for _, entry in ipairs(self.Tickets) do
				if (entry.level == level and self:GetStock(level) > 0) then
					return {ration = entry.ration, level = level}
				end
			end
		end
	end

	function ENT:GetTrayPosition()
		local attachment = self:LookupAttachment("package")

		if (attachment and attachment > 0) then
			local data = self:GetAttachment(attachment)

			if (data and data.Pos) then
				return data.Pos, data.Ang or self:GetAngles()
			end
		end

		return self:GetPos() +
			self:GetForward() * (self:OBBMaxs().x + 14) +
			Vector(0, 0, 20), self:GetAngles()
	end

	function ENT:SpawnRation(id, releaseDelay)
		releaseDelay = releaseDelay or 1.2

		local sequence = self:LookupSequence("dispense_package")

		if (sequence and sequence > 0) then
			self:ResetSequence(sequence)
			self:SetCycle(0)
			self:SetPlaybackRate(1)
		end

		self:EmitSound("ambient/machines/combine_terminal_idle4.wav")

		timer.Simple(releaseDelay, function()
			if (!IsValid(self)) then
				return
			end

			local position, angles = self:GetTrayPosition()
			local ration = NETWORK.item.Spawn(id, position, angles)

			if (IsValid(ration)) then
				ration.nwNoAbsorb = CurTime() + 30
			end

			self:EmitSound("items/ammocrate_open.wav", 60)

			self:SetDisplay(5)

			timer.Simple(4, function()
				if (IsValid(self)) then
					local idle = self:LookupSequence("idle")

					if (idle and idle > 0) then
						self:ResetSequence(idle)
					end

					self:SetDisplay(1)

					self.bReady = true
				end
			end)
		end)
	end

	function ENT:StartDispense(entry)
		self:SetStock(entry.level, self:GetStock(entry.level) - 1)
		self:SetDisplay(3)
		self:SpawnRation(entry.ration)
	end

	function ENT:Refill(client)
		if (self:TotalStock() >= self.MaxTotal) then
			return false
		end

		local list = {
			{id = "ration_basic", level = 1},
			{id = "ration_standard", level = 2},
			{id = "ration_premium", level = 3}
		}

		for _, entry in ipairs(list) do
			if (NETWORK.inventory.Take(client, entry.id, 1)) then
				NETWORK.inventory.Sync(client)
				self:AddStock(entry.level, 1)
				self:EmitSound("items/ammocrate_close.wav", 60)
				self:Notify(client, "dispenseLoaded")

				if (NETWORK.ration and NETWORK.ration.ClearWaypoint) then
					NETWORK.ration.ClearWaypoint(client)
				end

				return true
			end
		end

		return false
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.4

		if (self:GetNWBool("nwSabotaged", false)) then
			self:EmitSound("buttons/combine_button_locked.wav")
			self:Notify(client, "rebelSysErrorNotice")

			return
		end

		local bStaff = NETWORK.factions.IsAlliance(client) or
			NETWORK.factions.IsCWU(client)

		if (client:KeyDown(IN_SPEED)) then
			if (!NETWORK.factions.IsOverwatch(client) and !client:IsAdmin()) then
				return self:Fail(6, 1.5)
			end

			self:SetEnabled(!self:GetEnabled())
			self:SetDisplay(self:GetEnabled() and 1 or 6)
			self:EmitSound(self:GetEnabled() and "buttons/combine_button1.wav" or
				"buttons/combine_button2.wav")
			self:Notify(client, self:GetEnabled() and "dispenseOn" or "dispenseOff")

			self.bReady = true

			if (NETWORK.entities and NETWORK.entities.Save) then
				NETWORK.entities.Save()
			end

			return
		end

		if (bStaff and self:Refill(client)) then
			return
		end

		if (!self.bReady) then
			return
		end

		if (!self:GetEnabled()) then
			return self:Fail(6)
		end

		if (!self:HasCard(client)) then
			self:Notify(client, "dispenseNoCard")

			return self:Fail(9, 2)
		end

		if (self.bUseSchedule and NETWORK.schedule and
			NETWORK.schedule.IsRationTime and
			!NETWORK.schedule.IsRationTime()) then
			self:Notify(client, "dispenseClosed")

			return self:Fail(5, 2)
		end

		local character = client:GetCharacter()

		if (!character) then
			return
		end

		local charID = tostring(character:GetID())

		NETWORK.dispenser = NETWORK.dispenser or {}
		NETWORK.dispenser.taken = NETWORK.dispenser.taken or {}

		if (NETWORK.dispenser.taken[charID] == NETWORK.dispenser.window) then
			self:Notify(client, "dispenseFreqLimit")

			return self:Fail(10, 2)
		end

		local entry, list, index, held = self:FindTicket(client)

		if (!entry and !self.bRequireTicket) then
			entry = self:FindFreeRation(client)

			if (!entry) then
				self:Notify(client, "dispenseNoStock")

				return self:Fail(7, 2.5)
			end
		elseif (!entry) then
			self:Notify(client, held and "dispenseEmptyLevel" or "dispenseNeedTicket")

			return self:Fail(held and 7 or 4, 2.5)
		end

		self.bReady = false

		self:SetDisplay(2)
		self:EmitSound("ambient/machines/combine_terminal_idle2.wav")

		timer.Simple(math.Rand(1.8, 2.2), function()
			if (!IsValid(self)) then
				return
			end

			if (!IsValid(client) or !client:HasCharacter() or
				client:GetPos():Distance(self:GetPos()) > 150) then
				self.bReady = true

				self:SetDisplay(1)

				return
			end

			if (self:GetStock(entry.level) <= 0) then
				return self:Fail(7, 2)
			end

			if (entry.ticket) then
				local state = NETWORK.inventory.GetState(client)
				local current = NETWORK.inventory.At(state, list, index)

				if (!current or current.id != entry.ticket) then
					return self:Fail(7, 2)
				end

				if ((current.amount or 1) > 1) then
					current.amount = current.amount - 1

					NETWORK.inventory.Sync(client)
				else
					NETWORK.inventory.Put(state, list, index, nil, nil)
				end
			end

			NETWORK.dispenser.taken[charID] = NETWORK.dispenser.window

			self:SetDisplay(8)
			self:EmitSound("ambient/machines/combine_terminal_idle3.wav")

			timer.Simple(10.2, function()
				if (!IsValid(self)) then
					return
				end

				self:StartDispense(entry)
			end)
		end)
	end

	NETWORK.dispenser = NETWORK.dispenser or {}
	NETWORK.dispenser.taken = NETWORK.dispenser.taken or {}
	NETWORK.dispenser.window = NETWORK.dispenser.window or 1

	timer.Create("nwDispenserWindow", 5, 0, function()
		local bOpen = NETWORK.schedule and NETWORK.schedule.IsRationTime and
			NETWORK.schedule.IsRationTime()

		if (bOpen == NETWORK.dispenser.bWindowOpen) then
			return
		end

		NETWORK.dispenser.bWindowOpen = bOpen

		if (!bOpen) then
			return
		end

		NETWORK.dispenser.window = NETWORK.dispenser.window + 1
		NETWORK.dispenser.taken = {}

		for _, entity in ipairs(ents.FindByClass("nw_dispenser")) do
			if (entity:GetEnabled()) then
				entity:SetDisplay(1)

				entity.bReady = true
			end
		end
	end)

	function NETWORK.dispenser.StartPlacing(client, entity)
		if (!IsValid(client) or !IsValid(entity)) then
			return
		end

		client.nwPlacing = entity

		entity:SetNotSolid(true)
		entity:SetRenderMode(RENDERMODE_TRANSALPHA)
		entity:SetColor(Color(255, 255, 255, 130))

		NETWORK.chat.Notice(client, "dispensePlaceOn")
	end

	function NETWORK.dispenser.StopPlacing(client, bQuiet)
		local entity = client.nwPlacing

		client.nwPlacing = nil

		if (IsValid(entity)) then
			entity:SetNotSolid(false)
			entity:SetRenderMode(RENDERMODE_NORMAL)
			entity:SetColor(Color(255, 255, 255, 255))
			entity:CollisionRulesChanged()

			if (NETWORK.entities and NETWORK.entities.Save) then
				NETWORK.entities.Save()
			end
		end

		if (!bQuiet) then
			NETWORK.chat.Notice(client, "dispensePlaceOff")
		end
	end

	timer.Create("nwDispenserPlace", 0.05, 0, function()
		for _, client in ipairs(player.GetAll()) do
			local entity = client.nwPlacing

			if (!IsValid(entity)) then
				client.nwPlacing = nil

				continue
			end

			if (!client:Alive() or !client:IsAdmin()) then
				NETWORK.dispenser.StopPlacing(client, true)

				continue
			end

			local trace = util.TraceLine({
				start = client:EyePos(),
				endpos = client:EyePos() + client:GetAimVector() * 300,
				filter = {client, entity},
				mask = MASK_SOLID
			})

			if (trace.Hit) then
				entity:PlaceAt(trace, client)
			end
		end
	end)

	hook.Add("KeyPress", "nwDispenserPlace", function(client, key)
		if (key != IN_USE or !IsValid(client.nwPlacing)) then
			return
		end

		NETWORK.dispenser.StopPlacing(client)
	end)

	hook.Add("PlayerDisconnected", "nwDispenserPlace", function(client)
		if (IsValid(client.nwPlacing)) then
			NETWORK.dispenser.StopPlacing(client, true)
		end
	end)

	local function FindDispenser(client)
		if (IsValid(client.nwPlacing)) then
			return client.nwPlacing
		end

		local trace = client:GetEyeTrace()

		if (IsValid(trace.Entity) and trace.Entity:GetClass() == "nw_dispenser") then
			return trace.Entity
		end

		local best, distance

		for _, entity in ipairs(ents.FindByClass("nw_dispenser")) do
			local length = entity:GetPos():Distance(trace.HitPos)

			if (length < 128 and (!distance or length < distance)) then
				best, distance = entity, length
			end
		end

		return best
	end

	local function SaveEntities()
		if (NETWORK.entities and NETWORK.entities.Save) then
			NETWORK.entities.Save()
		end
	end

	NETWORK.command.Register("dispensermove", {
		description = "cmdDispensermove",
		usage = "/dispensermove",
		adminOnly = true,
		OnRun = function(command, client)

			if (IsValid(client.nwPlacing)) then
				return NETWORK.dispenser.StopPlacing(client)
			end

			local entity = FindDispenser(client)

			if (!IsValid(entity)) then
				return NETWORK.chat.Notice(client, "dispenseMoveNone")
			end

			NETWORK.dispenser.StartPlacing(client, entity)
		end
	})

	NETWORK.command.Register("dispenserturn", {
		description = "cmdDispenserturn",
		usage = "/dispenserturn [градусы]",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local entity = FindDispenser(client)

			if (!IsValid(entity)) then
				return NETWORK.chat.Notice(client, "dispenseMoveNone")
			end

			local angles = entity:GetAngles()

			entity:SetAngles(Angle(0, angles.y + (tonumber(arguments[1]) or 90), 0))
			SaveEntities()
			NETWORK.chat.Notice(client, "dispenseTurned")
		end
	})

	NETWORK.command.Register("dispensernudge", {
		description = "cmdDispensernudge",
		usage = "/dispensernudge <вперёд> <вбок> <вверх>",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local entity = FindDispenser(client)

			if (!IsValid(entity)) then
				return NETWORK.chat.Notice(client, "dispenseMoveNone")
			end

			entity:SetPos(entity:GetPos() +
				entity:GetForward() * (tonumber(arguments[1]) or 0) +
				entity:GetRight() * (tonumber(arguments[2]) or 0) +
				Vector(0, 0, tonumber(arguments[3]) or 0))
			SaveEntities()
			NETWORK.chat.Notice(client, "dispenseNudged")
		end
	})
else

	function ENT:FixMaterials()
		if (self.bMaterialsChecked) then
			return
		end

		self.bMaterialsChecked = true

		if (!util.IsValidModel(self:GetModel() or "")) then
			self.fallbackModel = ClientsideModel("models/props_interiors/VendingMachineSoda01a.mdl")

			if (IsValid(self.fallbackModel)) then
				self.fallbackModel:SetNoDraw(true)
			end

			return
		end

		for index, path in ipairs(self:GetMaterials() or {}) do
			local material = Material(path)

			if (!material or material:IsError()) then
				self:SetSubMaterial(index - 1, "models/props_combine/metal_combinebridge001")
			end
		end
	end

	function ENT:OnRemove()
		if (IsValid(self.fallbackModel)) then
			self.fallbackModel:Remove()
		end
	end

	function ENT:Draw()
		self:FixMaterials()

		if (IsValid(self.fallbackModel)) then
			self.fallbackModel:SetPos(self:GetPos())
			self.fallbackModel:SetAngles(self:GetAngles())
			self.fallbackModel:DrawModel()

			return
		end

		self:DrawModel()

		local data = self:GetEnabled() and self.Displays[self:GetDisplay()] or
			self.Displays[6]

		if (self:GetNWBool("nwSabotaged", false)) then
			data = self.Displays[11]
		end

		if (!data) then
			return
		end

		local client = LocalPlayer()

		if (IsValid(client) and
			client:GetPos():Distance(self:GetPos()) > 500) then
			return
		end

		local alpha = data[3] and 255 or math.abs(math.cos(RealTime() * 2) * 255)
		local bDispenserModel = string.find(self:GetModel() or "",
			"combine_dispenser", 1, true) != nil

		if (bDispenserModel) then
			local angles = self:GetAngles()

			angles:RotateAroundAxis(angles:Forward(), 90)
			angles:RotateAroundAxis(angles:Right(), 270)

			local forward = math.max(7.6, self:OBBMaxs().x + 0.6)

			cam.Start3D2D(self:GetPos() + self:GetForward() * forward +
				self:GetRight() * 8.5 + self:GetUp() * 3, angles, 0.1)
				surface.SetDrawColor(6, 9, 14, 235)
				surface.DrawRect(10, 14, 153, 54)

				surface.SetDrawColor(data[2].r, data[2].g, data[2].b, alpha)
				surface.DrawRect(10, 14, 3, 54)

				draw.SimpleText(NETWORK.util.Upper(L(data[1])), "nwChat", 86, 32,
					ColorAlpha(data[2], alpha), TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)

				draw.SimpleText("I:" .. self:GetStockBasic() .. "   II:" ..
					self:GetStockStandard() .. "   III:" .. self:GetStockPremium(),
					"nwHudSmall", 86, 56, Color(180, 200, 215, 220),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()

			return
		end

		local mins, maxs = self:OBBMins(), self:OBBMaxs()
		local position = self:LocalToWorld(Vector(maxs.x + 0.4, 0,
			maxs.z - (maxs.z - mins.z) * 0.22))
		local angles = self:GetAngles()

		angles:RotateAroundAxis(angles:Up(), 90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(position, angles, 0.1)
			NETWORK.label.Frame(-92, -30, 184, 60, data[2], alpha / 255)

			draw.SimpleText(NETWORK.util.Upper(L(data[1])), "nwChat", 0, -10,
				ColorAlpha(data[2], alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			surface.SetDrawColor(data[2].r, data[2].g, data[2].b, 55)
			surface.DrawRect(-72, 2, 144, 1)

			draw.SimpleText("I:" .. self:GetStockBasic() .. "   II:" ..
				self:GetStockStandard() .. "   III:" .. self:GetStockPremium(),
				"nwHudSmall", 0, 14, Color(180, 200, 215, 220), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
