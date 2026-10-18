AddCSLuaFile()

-- The ration dispenser (after the Helix ix_rationdispenser): models/props_combine/combine_dispenser.mdl
-- on the wall. A citizen with a CID card presses E: ВСТАВЬТЕ CID → ПРОВЕРКА → (the time of the last
-- ration of this character: once in nw_ration_interval seconds) ПОДГОТОВКА → ВЫДАЧА: the machine
-- plays dispense_package and the ration (item "ration") drops out. The stock: nw_ration_stock
-- rations (-1 - endless); empty - ПУСТО (the sound of the empty stock). The Alliance turns it on and
-- off with E (ОТКЛЮЧЁН). Kept with the map with its state (sv_persist.lua).

ENT.Type = "anim"
ENT.PrintName = "Раздатчик рационов"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.Displays = {
	[1] = {"ВСТАВЬТЕ CID", Color(230, 236, 240), true},
	[2] = {"ПРОВЕРКА", Color(255, 200, 0)},
	[3] = {"ВЫДАЧА", Color(0, 255, 90)},
	[4] = {"ЛИМИТ", Color(255, 50, 40)},
	[5] = {"ЖДИТЕ", Color(255, 200, 0)},
	[6] = {"ОТКЛЮЧЁН", Color(255, 50, 40), true},
	[7] = {"НЕТ CID", Color(255, 50, 40)},
	[8] = {"ПОДГОТОВКА", Color(0, 255, 90)},
	[9] = {"ПУСТО", Color(255, 120, 40), true},
	[10] = {"КОМЕНДАНТСКИЙ ЧАС", Color(255, 50, 40)}
}

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Display")
	self:NetworkVar("Int", 1, "Stock")
	self:NetworkVar("Bool", 0, "Enabled")
end

if (SERVER) then
	local interval = CreateConVar("nw_ration_interval", "3600", FCVAR_ARCHIVE, "Как часто персонаж получает рацион (секунды)")
	local stockDefault = CreateConVar("nw_ration_stock", "-1", FCVAR_ARCHIVE,
		"Сколько рационов в новом раздатчике (-1 — бесконечно)")

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_dispenser")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(trace.HitNormal:Angle())
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_junk/watermelon01.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:DrawShadow(false)
		self:SetUseType(SIMPLE_USE)
		self:SetDisplay(1)
		self:SetEnabled(true)
		self:SetStock(stockDefault:GetInt())

		self.machine = ents.Create("prop_dynamic")
		self.machine:SetModel("models/props_combine/combine_dispenser.mdl")
		self.machine:SetPos(self:GetPos())
		self.machine:SetAngles(self:GetAngles())
		self.machine:SetParent(self)
		self.machine:Spawn()
		self.machine:Activate()
		self.machine:SetSolid(SOLID_NONE)
		self:DeleteOnRemove(self.machine)

		-- the package in the slot while it comes out
		self.dummy = ents.Create("prop_dynamic")
		self.dummy:SetModel("models/weapons/w_package.mdl")
		self.dummy:SetPos(self:GetPos())
		self.dummy:SetAngles(self:GetAngles())
		self.dummy:SetParent(self.machine, 1)
		self.dummy:SetNoDraw(true)
		self.dummy:Spawn()
		self:DeleteOnRemove(self.dummy)

		-- E goes here: the machine model is not solid, this box around it is (and draws only the screen)
		self:PhysicsInitBox(Vector(-6, -16, -26), Vector(10, 16, 26))
		self:SetCollisionBounds(Vector(-6, -16, -26), Vector(10, 16, 26))
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end

		self.ready = true
	end

	function ENT:Show(display, length)
		self:SetDisplay(display)

		if (length) then
			timer.Simple(length, function()
				if (IsValid(self)) then
					self:SetDisplay(self:GetStock() == 0 and 9 or 1)
					self.ready = true
				end
			end)
		end
	end

	function ENT:Refuse(display)
		self.ready = false
		self:EmitSound("buttons/combine_button_locked.wav", 65)
		self:Show(display, 2)
	end

	function ENT:Dispense(client)
		self:SetDisplay(3)
		self.machine:Fire("SetAnimation", "dispense_package")
		self:EmitSound("ambient/machines/combine_terminal_idle4.wav", 65)
		self.dummy:SetNoDraw(false)

		timer.Simple(1.2, function()
			if (!IsValid(self)) then
				return
			end

			self.dummy:SetNoDraw(true)

			local item = ents.Create("nw_item")

			if (IsValid(item)) then
				item:SetItem("ration", {})
				item:SetPos(self.dummy:GetPos())
				item:SetAngles(self.dummy:GetAngles())
				item:Spawn()
			end

			if (self:GetStock() > 0) then
				self:SetStock(self:GetStock() - 1)
				NW.persist.Save("nw_dispenser")
			end

			self:Show(5)

			timer.Simple(4, function()
				if (IsValid(self)) then
					self:Show(self:GetStock() == 0 and 9 or 1)
					self.ready = true
				end
			end)
		end)
	end

	function ENT:Use(client)
		if (!self.ready or !IsValid(client) or !client:IsPlayer() or client:GetCharacterID() == 0) then
			return
		end

		-- the Alliance: on / off
		if (NW.zones.IsAlliance(client)) then
			self:SetEnabled(!self:GetEnabled())
			self:SetDisplay(self:GetEnabled() and 1 or 6)
			self:EmitSound(self:GetEnabled() and "buttons/combine_button1.wav" or "buttons/combine_button2.wav", 65)
			self.ready = false

			timer.Simple(1.5, function()
				if (IsValid(self)) then
					self.ready = true
				end
			end)

			NW.persist.Save("nw_dispenser")

			return
		end

		if (!self:GetEnabled()) then
			return self:Refuse(6)
		end

		if (self:GetStock() == 0) then
			self.ready = false
			self:EmitSound("network2/dispenser/empty_stock.mp3", 65)
			self:Show(9, 2)

			return
		end

		if (!NW.inventory.Has(client, "cid")) then
			return self:Refuse(7)
		end

		-- the curfew: no rations (sh_schedule.lua)
		if (NW.schedule and !NW.schedule.Allows("rations")) then
			NW.Notify(client, "Раздача закрыта: комендантский час")

			return self:Refuse(10)
		end

		self.ready = false
		self:SetDisplay(2)
		self:EmitSound("ambient/machines/combine_terminal_idle2.wav", 65)

		timer.Simple(math.Rand(1.8, 2.2), function()
			if (!IsValid(self) or !IsValid(client)) then
				if (IsValid(self)) then
					self:Show(1)
					self.ready = true
				end

				return
			end

			local character = client.nwCharacter
			local data = character and character.data or {}

			if ((data.nextRation or 0) > os.time()) then
				return self:Refuse(4)
			end

			data.nextRation = os.time() + interval:GetInt()
			NW.char.SaveData(client)

			self:SetDisplay(8)
			self:EmitSound("ambient/machines/combine_terminal_idle3.wav", 65)

			timer.Simple(3, function()
				if (IsValid(self)) then
					self:Dispense(client)
				end
			end)
		end)
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_dispenser", {
			Save = function(entity)
				return {enabled = entity:GetEnabled(), stock = entity:GetStock()}
			end,
			Load = function(entity, data)
				entity:SetEnabled(data.enabled != false)
				entity:SetStock(tonumber(data.stock) or -1)
				entity:SetDisplay(!entity:GetEnabled() and 6 or (entity:GetStock() == 0 and 9 or 1))
			end
		})
	end)

	-- admins: the stock of the dispenser looked at
	concommand.Add("nw_dispenser_stock", function(client, _, arguments)
		if (!IsValid(client) or !client:IsAdmin()) then
			return
		end

		local entity = client:GetEyeTrace().Entity

		if (IsValid(entity) and entity:GetClass() != "nw_dispenser" and IsValid(entity:GetParent())) then
			entity = entity:GetParent()
		end

		if (!IsValid(entity) or entity:GetClass() != "nw_dispenser") then
			return NW.Notify(client, "Посмотрите на раздатчик")
		end

		entity:SetStock(math.floor(tonumber(arguments[1]) or -1))
		entity:SetDisplay(entity:GetStock() == 0 and 9 or 1)
		NW.persist.Save("nw_dispenser")
		NW.Notify(client, "Запас раздатчика: " .. (entity:GetStock() < 0 and "бесконечно" or entity:GetStock()))
	end)

	return
end

-- ------------------------------------------------------------------ client --
surface.CreateFont("nwDispenser", {font = "JetBrains Mono ExtraBold", size = 30, weight = 800, extended = true,
	antialias = false})
surface.CreateFont("nwDispenserSmall", {font = "JetBrains Mono Medium", size = 16, weight = 500, extended = true,
	antialias = false})

function ENT:Draw()
	local position, angles = self:GetPos(), self:GetAngles()
	local display = self:GetEnabled() and self.Displays[self:GetDisplay()] or self.Displays[6]

	angles:RotateAroundAxis(angles:Forward(), 90)
	angles:RotateAroundAxis(angles:Right(), 270)

	if (LocalPlayer():GetPos():DistToSqr(position) > 600 * 600) then
		return
	end

	cam.Start3D2D(position + self:GetForward() * 7.6 + self:GetRight() * 8.5 + self:GetUp() * 3, angles, 0.1)
		render.PushFilterMin(TEXFILTER.NONE)
		render.PushFilterMag(TEXFILTER.NONE)

		surface.SetDrawColor(4, 8, 10, 255)
		surface.DrawRect(10, 16, 153, 40)
		surface.SetDrawColor(60, 70, 74)
		surface.DrawOutlinedRect(9, 16, 155, 40)

		local alpha = display[3] and 255 or math.abs(math.cos(RealTime() * 2) * 255)

		draw.SimpleText(display[1], "nwDispenser", 86, 36, ColorAlpha(display[2], alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		if (self:GetStock() >= 0) then
			draw.SimpleText("ЗАПАС " .. self:GetStock(), "nwDispenserSmall", 86, 64, Color(120, 140, 150),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		render.PopFilterMin()
		render.PopFilterMag()
	cam.End3D2D()
end
