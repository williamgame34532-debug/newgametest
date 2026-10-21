AddCSLuaFile()

-- The combine lock (after the Helix ix_combinelock). Spawned looking at a door: it sits on the door
-- by the handle and goes with it (double doors share it). E - the Alliance locks / unlocks it (the
-- door closes and locks), anyone else gets the refusal. Kept with the map (sv_persist.lua).
-- The look: the lamp of the state - a soft glow, a hot core and a little light on the door; blue -
-- locked, green - open, red blinking - refused. A change: a short flash, blue sparks, a scan line
-- over the panel and the lock sounds of the server (sound/network2/lock). The lamp is small and soft:
-- seen up close, not across the street, and not through walls.
-- Shift + E (the Alliance): the settings - who may open it (the Alliance / with the CWU / Civil
-- Protection only / the Overwatch only) and the self-locking (off, 5, 10, 30, 60 s after opening).

ENT.Type = "anim"
ENT.PrintName = "Замок Альянса"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Locked")
	self:NetworkVar("Bool", 1, "Error")
	self:NetworkVar("Float", 0, "Changed")
	self:NetworkVar("Entity", 0, "Door")
	self:NetworkVar("Int", 0, "Access")
	self:NetworkVar("Int", 1, "AutoLock")
end

ENT.Accesses = {
	{name = "Весь Альянс", Allow = function(client)
		return NW.zones.IsAlliance(client)
	end},
	{name = "Альянс и ГСР", Allow = function(client)
		return NW.zones.IsAlliance(client) or client:GetFaction() == "cwu"
	end},
	{name = "Только ГО", Allow = function(client)
		return client:GetFaction() == "cp"
	end},
	{name = "Только ОТА", Allow = function(client)
		return client:GetFaction() == "combine"
	end}
}
ENT.AutoLocks = {0, 5, 10, 30, 60}

function ENT:CanOperate(client)
	local access = self.Accesses[math.Clamp(self:GetAccess(), 1, #self.Accesses)]

	return client:IsAdmin() or access.Allow(client)
end

if (SERVER) then
	local function Partner(door)
		local partners = NW.doors and NW.doors.Group and NW.doors.Group(door) or {door}
		local out = {}

		for _, member in ipairs(partners) do
			if (member != door) then
				out[#out + 1] = member
			end
		end

		return out
	end

	-- where on the door: by the handle, on the side the player looks from
	function ENT:Place(door, normal)
		local index = door:LookupBone("handle")
		local position = door:GetPos()

		normal = normal or door:GetForward():Angle()

		if (index and index >= 1) then
			position = door:GetBonePosition(index)
		end

		position = position + normal:Forward() * 7.2 + normal:Up() * 10 + normal:Right() * 2

		local angles = Angle(normal.p, normal.y, normal.r)

		angles:RotateAroundAxis(angles:Up(), 90)
		angles:RotateAroundAxis(angles:Forward(), 180)
		angles:RotateAroundAxis(angles:Right(), 180)

		return position, angles
	end

	function ENT:Attach(door, position, angles)
		if (!NW.doors.IsDoor(door)) then
			return
		end

		self:SetDoor(door)
		self:SetPos(position)
		self:SetAngles(angles)
		self:SetParent(door)
		door:DeleteOnRemove(self)
		door.nwCombineLock = self

		for _, partner in ipairs(Partner(door)) do
			partner.nwCombineLock = self
		end
	end

	function ENT:SpawnFunction(client, trace)
		local door = trace.Entity

		if (!NW.doors.IsDoor(door) or IsValid(door.nwCombineLock)) then
			NW.Notify(client, "Посмотрите на дверь без замка")

			return
		end

		local entity = ents.Create("nw_combinelock")

		entity:SetPos(trace.HitPos)
		entity:Spawn()
		entity:Activate()
		entity:Attach(door, entity:Place(door, trace.HitNormal:Angle()))

		return entity
	end

	util.AddNetworkString("nwLockMenu")
	util.AddNetworkString("nwLockSet")
	util.AddNetworkString("nwLockToggle")

	function ENT:Initialize()
		self:SetAccess(math.max(1, self:GetAccess()))
		self:SetModel("models/props_combine/combine_lock01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)
		self.nextUse = 0
	end

	function ENT:Doors()
		local door = self:GetDoor()

		if (!IsValid(door)) then
			return {}
		end

		local out = {door}

		for _, partner in ipairs(Partner(door)) do
			out[#out + 1] = partner
		end

		return out
	end

	function ENT:Spark()
		local effect = EffectData()

		effect:SetOrigin(self:GetPos() + self:GetForward() * -3 + self:GetUp() * -8)
		effect:SetNormal(-self:GetForward())
		effect:SetMagnitude(1)
		effect:SetScale(1)
		effect:SetRadius(2)
		util.Effect("ElectricSpark", effect, true, true)
	end

	function ENT:SetState(bLocked)
		self:SetLocked(bLocked)
		self:SetChanged(CurTime())

		for _, door in ipairs(self:Doors()) do
			if (bLocked) then
				door:Fire("Close")
				door:Fire("Lock")
			else
				door:Fire("Unlock")
			end

			door.nwLocked = bLocked
		end

		self:EmitSound(bLocked and "network2/lock/combine_lock.mp3" or
			("network2/lock/combine_locker_open" .. math.random(1, 3) .. ".mp3"), 65)
		self:Spark()
		NW.persist.Save("nw_combinelock")
	end

	function ENT:Refuse()
		self:EmitSound("buttons/combine_button_locked.wav", 65)
		self:SetError(true)

		timer.Simple(1.2, function()
			if (IsValid(self)) then
				self:SetError(false)
			end
		end)
	end

	function ENT:Use(client)
		if (self.nextUse > CurTime() or !IsValid(client) or !client:IsPlayer()) then
			return
		end

		self.nextUse = CurTime() + 1.2

		-- Shift + E: the settings (the Alliance)
		if (client:KeyDown(IN_SPEED) and (NW.zones.IsAlliance(client) or client:IsAdmin())) then
			net.Start("nwLockMenu")
				net.WriteEntity(self)
			net.Send(client)

			return
		end

		self:Operate(client)
	end

	-- open / lock (E on the lock, or the menu of the lock and the wheel of the door)
	function ENT:Operate(client)
		if (!self:CanOperate(client)) then
			return self:Refuse()
		end

		self:SetState(!self:GetLocked())

		-- opened: locks itself again after a while
		local wait = self:GetAutoLock()

		if (!self:GetLocked() and wait > 0) then
			local mark = self:GetChanged()

			timer.Simple(wait, function()
				if (IsValid(self) and !self:GetLocked() and self:GetChanged() == mark) then
					self:SetState(true)
				end
			end)
		end
	end

	net.Receive("nwLockToggle", function(_, client)
		local lock = net.ReadEntity()

		if (!IsValid(lock) or lock:GetClass() != "nw_combinelock" or (lock.nextUse or 0) > CurTime() or
			client:GetPos():DistToSqr(lock:GetPos()) > 200 * 200) then
			return
		end

		lock.nextUse = CurTime() + 1.2
		lock:Operate(client)
	end)

	net.Receive("nwLockSet", function(_, client)
		local lock = net.ReadEntity()
		local key = net.ReadString()
		local value = net.ReadUInt(8)

		if (!IsValid(lock) or lock:GetClass() != "nw_combinelock" or
			!(NW.zones.IsAlliance(client) or client:IsAdmin()) or client:GetPos():DistToSqr(lock:GetPos()) > 200 * 200) then
			return
		end

		if (key == "access" and lock.Accesses[value]) then
			lock:SetAccess(value)
			NW.Notify(client, "Доступ: " .. lock.Accesses[value].name)
		elseif (key == "autolock" and table.HasValue(lock.AutoLocks, value)) then
			lock:SetAutoLock(value)
			NW.Notify(client, value > 0 and ("Самозапирание через " .. value .. " с") or "Самозапирание выключено")
		else
			return
		end

		lock:EmitSound("buttons/combine_button" .. math.random(1, 3) .. ".wav", 55)
		NW.persist.Save("nw_combinelock")
	end)

	function ENT:OnRemove()
		for _, door in ipairs(self:Doors()) do
			door:Fire("Unlock")
			door.nwCombineLock = nil
			door.nwLocked = false
		end
	end

	-- kept on the door of the map (by its map id)
	timer.Simple(0, function()
		NW.persist.Register("nw_combinelock", {
			Save = function(entity)
				local door = entity:GetDoor()

				return {door = IsValid(door) and door:MapCreationID() or -1, locked = entity:GetLocked(),
					access = entity:GetAccess(), autolock = entity:GetAutoLock(),
					local_pos = IsValid(door) and door:WorldToLocal(entity:GetPos()) or nil,
					local_ang = IsValid(door) and door:WorldToLocalAngles(entity:GetAngles()) or nil}
			end,
			Create = function(data)
				local door = ents.GetMapCreatedEntity(tonumber(data.door) or -1)

				if (!NW.doors.IsDoor(door) or IsValid(door.nwCombineLock)) then
					return
				end

				local entity = ents.Create("nw_combinelock")

				entity:Spawn()
				entity:Activate()

				local pos = istable(data.local_pos) and Vector(data.local_pos[1], data.local_pos[2], data.local_pos[3])
				local ang = istable(data.local_ang) and Angle(data.local_ang[1], data.local_ang[2], data.local_ang[3])

				if (isvector(data.local_pos)) then
					pos = data.local_pos
				end

				if (isangle(data.local_ang)) then
					ang = data.local_ang
				end

				if (pos and ang) then
					entity:Attach(door, door:LocalToWorld(pos), door:LocalToWorldAngles(ang))
				else
					entity:Attach(door, entity:Place(door))
				end

				return entity
			end,
			Load = function(entity, data)
				entity:SetAccess(math.Clamp(tonumber(data.access) or 1, 1, #entity.Accesses))
				entity:SetAutoLock(tonumber(data.autolock) or 0)

				if (data.locked) then
					timer.Simple(0.5, function()
						if (IsValid(entity)) then
							entity:SetState(true)
						end
					end)
				end
			end
		})
	end)

	return
end

-- ------------------------------------------------------------------ client --
local GLOW = Material("sprites/light_glow02_add")
local BLUE = Color(90, 150, 230)
local GREEN = Color(110, 220, 150)
local RED = Color(235, 80, 70)

function NW.LockToggle(lock)
	net.Start("nwLockToggle")
		net.WriteEntity(lock)
	net.SendToServer()
end

-- the settings: from the wheel of the door (hold E on the door → «Режим замка», cl_social.lua) or Shift + E
function NW.LockMenu(lock)
	if (!IsValid(lock)) then
		return
	end

	local function Set(key, value)
		net.Start("nwLockSet")
			net.WriteEntity(lock)
			net.WriteString(key)
			net.WriteUInt(value, 8)
		net.SendToServer()
	end

	local menu = DermaMenu()

	-- the cursor while the menu is open
	gui.EnableScreenClicker(true)
	menu.OnRemove = function()
		gui.EnableScreenClicker(false)
	end

	if (lock:CanOperate(LocalPlayer())) then
		menu:AddOption(lock:GetLocked() and "Открыть дверь" or "Запереть дверь", function()
			NW.LockToggle(lock)
		end):SetIcon(lock:GetLocked() and "icon16/lock_open.png" or "icon16/lock.png")
		menu:AddSpacer()
	end
	local access = menu:AddSubMenu("Кто открывает")

	for index, entry in ipairs(lock.Accesses) do
		local option = access:AddOption(entry.name, function()
			Set("access", index)
		end)

		option:SetChecked(lock:GetAccess() == index)
	end

	local auto = menu:AddSubMenu("Самозапирание")

	for _, seconds in ipairs(lock.AutoLocks) do
		local option = auto:AddOption(seconds > 0 and ("Через " .. seconds .. " с") or "Выключено", function()
			Set("autolock", seconds)
		end)

		option:SetChecked(lock:GetAutoLock() == seconds)
	end

	menu:AddSpacer()
	menu:AddOption("Закрыть"):SetIcon("icon16/cross.png")
	menu:Open()
	menu:Center()
end

-- the lock on this door (or nil)
function NW.LockOf(door)
	for _, lock in ipairs(ents.FindByClass("nw_combinelock")) do
		if (lock:GetDoor() == door) then
			return lock
		end
	end

	-- the other half of a double door
	for _, lock in ipairs(ents.FindByClass("nw_combinelock")) do
		local other = lock:GetDoor()

		if (IsValid(other) and other:GetPos():DistToSqr(door:GetPos()) < 140 * 140 and
			other:GetClass() == door:GetClass()) then
			return lock
		end
	end
end

net.Receive("nwLockMenu", function()
	NW.LockMenu(net.ReadEntity())
end)

function ENT:Draw()
	self:DrawModel()

	local now = CurTime()
	local color = self:GetLocked() and BLUE or GREEN
	local strength = 1

	if (self:GetError()) then
		color = RED
		strength = math.floor(now * 8) % 2 == 0 and 1 or 0.25
	end

	-- the flash of a change
	local since = now - self:GetChanged()
	local flash = since < 0.5 and (1 - since / 0.5) or 0
	local pos = self:GetPos() + self:GetUp() * -8.7 + self:GetForward() * -3.85 + self:GetRight() * -6
	local breath = 0.9 + 0.1 * math.sin(now * 2.2)

	-- small and soft: the colour is read up close, it does not shine across the street
	local near = math.Clamp(1 - EyePos():Distance(pos) / 600, 0.25, 1)

	render.SetMaterial(GLOW)
	render.DrawSprite(pos, 9 * breath * strength + flash * 14, 9 * breath * strength + flash * 14,
		ColorAlpha(color, 55 * strength * near))
	render.DrawSprite(pos, 3 + flash * 3, 3 + flash * 3, ColorAlpha(color, 170 * strength * near))

	-- the scan line over the panel after a change
	if (since < 0.8) then
		local t = since / 0.8
		local line = self:GetPos() + self:GetForward() * -4 + self:GetUp() * (2 - t * 14)

		render.SetMaterial(GLOW)
		render.DrawSprite(line, 10, 2, ColorAlpha(color, 200 * (1 - t)))
	end
end

function ENT:Think()
	-- a little light on the door
	if (LocalPlayer():GetPos():DistToSqr(self:GetPos()) < 400 * 400) then
		local light = DynamicLight(self:EntIndex())

		if (light) then
			local color = self:GetError() and RED or (self:GetLocked() and BLUE or GREEN)

			light.pos = self:GetPos() + self:GetForward() * -8
			light.r, light.g, light.b = color.r, color.g, color.b
			light.brightness = 0.18
			light.decay = 1000
			light.size = 26
			light.dietime = CurTime() + 0.2
		end
	end
end
