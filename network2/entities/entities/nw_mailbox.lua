AddCSLuaFile()

-- The mailbox of a house: the keys of its apartments are taken here (sv_doors.lua). E - the keys of
-- the apartments of this house where you live and whose key you do not carry (a lock changed after a
-- move: a new key). The house: the doors of the kind "Квартира" within the radius of the mailbox.
-- Admins: Alt + E - the editor: the name of the house, the model (your own), the radius; the number
-- of apartments it serves is shown. Kept with the map (sv_persist.lua).

ENT.Type = "anim"
ENT.PrintName = "Почтовый ящик"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.DefaultModel = "models/props_lab/filecabinet02.mdl"

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "HouseName")
	self:NetworkVar("Int", 0, "Radius")
end

-- the apartment doors it serves (one of each pair)
function ENT:Doors()
	local out, seen = {}, {}
	local radius = math.max(64, self:GetRadius())

	for _, door in ipairs(ents.FindInSphere(self:GetPos(), radius)) do
		if (NW.doors.IsDoor(door) and !seen[door] and door:GetNW2String("nwDoorKind", "") == "apartment") then
			out[#out + 1] = door

			if (SERVER) then
				for _, member in ipairs(NW.doors.Group(door)) do
					seen[member] = true
				end
			else
				seen[door] = true
			end
		end
	end

	return out
end

if (SERVER) then
	util.AddNetworkString("nwMailboxEdit")
	util.AddNetworkString("nwMailboxSave")

	function ENT:SpawnFunction(client, trace)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0

		local entity = ents.Create("nw_mailbox")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		if (self:GetRadius() == 0) then
			self:SetRadius(1500)
		end

		self:ApplyModel()
		self:SetUseType(SIMPLE_USE)
	end

	function ENT:ApplyModel()
		local model = self.nwModel or self.DefaultModel

		self:SetModel(util.IsValidModel(model) and model or self.DefaultModel)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer() or client:GetCharacterID() == 0 or (self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.8

		if (client:IsAdmin() and client:KeyDown(IN_WALK)) then
			net.Start("nwMailboxEdit")
				net.WriteEntity(self)
				net.WriteString(self.nwModel or "")
				net.WriteUInt(#self:Doors(), 10)
			net.Send(client)

			return
		end

		local given = 0

		for _, door in ipairs(self:Doors()) do
			if (NW.doors.IsOwner(client, door) and !NW.doors.HasKey(client, door)) then
				local label = door:GetNW2String("nwDoorName", "")

				if (label == "") then
					label = "квартира"
				end

				if (self:GetHouseName() != "") then
					label = label .. ", " .. self:GetHouseName()
				end

				local data = {door = door:MapCreationID(), epoch = door:GetNW2Int("nwDoorEpoch", 0), label = label}

				if (!NW.inventory.Add(client, "key", data)) then
					NW.inventory.SpawnWorldItem(client, {id = "key", data = data})
				end

				given = given + 1
			end
		end

		if (given > 0) then
			NW.inventory.Changed(client)
			self:EmitSound("doors/door_metal_thin_open1.wav", 60, 115)
			client:EmitSound("network2/inv/metal_latch.wav", 55)
			NW.SayMe(client, "достаёт из почтового ящика ключи")
			NW.Notify(client, given == 1 and "Вы забрали ключ" or ("Вы забрали ключи: " .. given))
		else
			self:EmitSound("doors/door_metal_thin_close2.wav", 55, 120)
			NW.Notify(client, "Для вас здесь ничего нет")
		end
	end

	net.Receive("nwMailboxSave", function(_, client)
		local entity = net.ReadEntity()
		local name = string.sub(string.Trim(net.ReadString() or ""), 1, 48)
		local model = string.Trim(net.ReadString() or "")
		local radius = math.Clamp(net.ReadUInt(14), 64, 8000)

		if (!client:IsAdmin() or !IsValid(entity) or entity:GetClass() != "nw_mailbox") then
			return
		end

		entity:SetHouseName(name)
		entity:SetRadius(radius)
		entity.nwModel = (model != "" and util.IsValidModel(model)) and model or nil
		entity:ApplyModel()
		NW.persist.Save("nw_mailbox")
		NW.Notify(client, "Почтовый ящик сохранён: квартир в доме — " .. #entity:Doors())
	end)

	timer.Simple(0, function()
		NW.persist.Register("nw_mailbox", {
			Save = function(entity)
				return {name = entity:GetHouseName(), radius = entity:GetRadius(), model = entity.nwModel}
			end,
			Load = function(entity, data)
				entity:SetHouseName(data.name or "")
				entity:SetRadius(tonumber(data.radius) or 1500)
				entity.nwModel = data.model
				entity:ApplyModel()
			end
		})
	end)

	return
end

-- ------------------------------------------------------------------ client --
surface.CreateFont("nwMailboxTitle", {font = "Montserrat SemiBold", size = 40, weight = 600, extended = true,
	antialias = true})

function ENT:Draw()
	self:DrawModel()

	local distance = EyePos():DistToSqr(self:GetPos())

	if (distance > 300 * 300) then
		return
	end

	local alpha = math.Clamp((300 - math.sqrt(distance)) / 80, 0, 1)
	local top = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 10))

	cam.Start3D2D(top, Angle(0, EyeAngles().y - 90, 90), 0.07)
		local name = self:GetHouseName() != "" and ("Почта · " .. self:GetHouseName()) or "Почтовый ящик"

		draw.SimpleTextOutlined(name, "nwMailboxTitle", 0, 0, Color(236, 238, 242, 255 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 180 * alpha))
	cam.End3D2D()
end

net.Receive("nwMailboxEdit", function()
	local entity = net.ReadEntity()
	local model = net.ReadString()
	local doors = net.ReadUInt(10)

	if (!IsValid(entity)) then
		return
	end

	local W = NW.widgets
	local sh = ScrH()
	local w, h = math.Round(sh * 0.5), math.Round(sh * 0.42)
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(w, h)
	frame:Center()
	frame:MakePopup()
	frame.Paint = function(_, pw, ph)
		draw.RoundedBox(10, 0, 0, pw, ph, Color(15, 17, 21, 242))
		draw.RoundedBox(2, 0, 0, pw, 3, Color(232, 196, 72))
		draw.SimpleText("Почтовый ящик", "nwWidget", sh * 0.025, sh * 0.03, NW.ui.color.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText("Квартир в радиусе: " .. doors .. " (двери вида «Квартира»)", "nwWidget", sh * 0.025,
			ph - sh * 0.1, Color(150, 154, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local pad = math.Round(sh * 0.025)
	local fh = math.Round(sh * 0.038)
	local y = sh * 0.065

	W.Label(frame, "Название дома (на ключах)", pad, y)

	local name = W.Entry(frame, entity:GetHouseName())

	name:SetPos(pad, y + sh * 0.022)
	name:SetSize(w - pad * 2, fh)
	y = y + sh * 0.075

	W.Label(frame, "Модель (пусто — шкафчик по умолчанию)", pad, y)

	local path = W.Entry(frame, model)

	path:SetPos(pad, y + sh * 0.022)
	path:SetSize(w - pad * 2, fh)
	y = y + sh * 0.075

	W.Label(frame, "Радиус дома, юниты", pad, y)

	local radius = W.Number(frame, entity:GetRadius(), 64, 8000)

	radius:SetPos(pad, y + sh * 0.022)
	radius:SetSize(w * 0.3, fh)

	local save = W.Button(frame, "Сохранить", function()
		net.Start("nwMailboxSave")
			net.WriteEntity(entity)
			net.WriteString(name:GetValue())
			net.WriteString(path:GetValue())
			net.WriteUInt(radius:GetNumber(), 14)
		net.SendToServer()
		frame:Remove()
	end, true)

	save:SetPos(w - pad - w * 0.3, h - pad - fh)
	save:SetSize(w * 0.3, fh)

	local close = W.Button(frame, "Отмена", function()
		frame:Remove()
	end)

	close:SetPos(pad, h - pad - fh)
	close:SetSize(w * 0.3, fh)
end)
