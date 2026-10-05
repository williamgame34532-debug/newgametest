AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Замок Альянса"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Locked")
	self:NetworkVar("Bool", 1, "Error")

	self:NetworkVar("Bool", 2, "Granted")
end

function ENT.GetLockModel()
	local model = "models/props_combine/combine_lock01.mdl"

	if (file.Exists(model, "GAME")) then
		util.PrecacheModel(model)

		return model
	end

	if (SERVER and !ENT.bWarnedModel) then
		ENT.bWarnedModel = true

		NETWORK.util.PrintWarning(
			"nw_lock: " .. model .. " не найден на сервере — " ..
			"используется запасной padlock001a. Убедитесь, что контент " ..
			"с моделью установлен и НА СЕРВЕРЕ, а не только у клиентов.")
	end

	return "models/props_c17/padlock001a.mdl"
end

function ENT.ComputeLockPosition(door, normal)
	local index = door:LookupBone("handle")
	local position = door:GetPos()

	normal = normal or door:GetForward():Angle()

	if (index and index >= 1) then
		position = door:GetBonePosition(index)
	end

	position = position + normal:Forward() * 7.2 + normal:Up() * 10 +
		normal:Right() * 2

	normal:RotateAroundAxis(normal:Up(), 90)
	normal:RotateAroundAxis(normal:Forward(), 180)
	normal:RotateAroundAxis(normal:Right(), 180)

	return position, normal
end

if (SERVER) then
	function ENT:GetLockPosition(door, normal)
		local index = door:LookupBone("handle")
		local position = door:GetPos()

		normal = normal or door:GetForward():Angle()

		if (index and index >= 1) then
			position = door:GetBonePosition(index)
		end

		position = position + normal:Forward() * 7.2 + normal:Up() * 10 + normal:Right() * 2

		normal:RotateAroundAxis(normal:Up(), 90)
		normal:RotateAroundAxis(normal:Forward(), 180)
		normal:RotateAroundAxis(normal:Right(), 180)

		return position, normal
	end

	function ENT:SpawnFunction(client, trace)
		local door = trace.Entity

		if (!NETWORK.door.IsDoor(door)) then
			return
		end

		local normal = trace.HitNormal:Angle()
		local position, angles = self:GetLockPosition(door, normal)
		local entity = ents.Create("nw_lock")

		entity:SetPos(trace.HitPos)
		entity:Spawn()
		entity:Activate()
		entity:Attach(door, position, angles)

		return entity
	end

	function ENT:Attach(door, position, angles)

		if (!IsValid(door)) then
			self:Remove()

			return false
		end

		if (IsValid(door.nwLock) and door.nwLock != self) then
			self:Remove()

			return false
		end

		self.door = door
		self.bAttached = true

		door:DeleteOnRemove(self)
		door.nwLock = self

		local partner = door.GetDoorPartner and door:GetDoorPartner()

		if (IsValid(partner)) then
			self.partner = partner

			partner:DeleteOnRemove(self)
			partner.nwLock = self
		end

		self:SetPos(position)
		self:SetAngles(angles)
		self:SetParent(door)

		return true
	end

	function ENT:EachDoor(callback)
		if (IsValid(self.door)) then
			callback(self.door)
		end

		if (IsValid(self.partner)) then
			callback(self.partner)
		end
	end

	function ENT:Allow(callback)
		self.bDriving = true

		callback()

		self.bDriving = false
	end

	function ENT:Apply(bLocked)

		if (bLocked) then
			self.nwHacked = nil
		end

		self:SetLocked(bLocked)

		if (bLocked) then
			self:EmitSound("framework/cmb/lock/lock.mp3", 70)
		else
			self:EmitSound("framework/cmb/lock/open" ..
				(math.random(2) == 2 and "2" or "") .. ".mp3", 70)
		end

		self:Allow(function()
			self:EachDoor(function(door)
				door:Fire(bLocked and "lock" or "unlock")

				if (bLocked) then
					door:Fire("close")
				end
			end)
		end)

		local data = IsValid(self.door) and NETWORK.door.GetData(self.door)

		if (data) then
			data.bLocked = bLocked and true or false

			NETWORK.door.Set(self.door, data)
		end
	end

	function ENT:Refuse(client)
		if ((self.nextRefuse or 0) > CurTime()) then
			return
		end

		self.nextRefuse = CurTime() + 1.2

		self:Fail()
	end

	function ENT:Think()

		if (!IsValid(self.door)) then
			if (CurTime() - (self.spawnTime or CurTime()) > 2) then
				self:Remove()

				return
			end

			self:NextThink(CurTime() + 0.5)

			return true
		end

		if (!self:GetLocked()) then
			self:NextThink(CurTime() + 0.5)

			return true
		end

		self:Allow(function()
			self:EachDoor(function(door)
				door:Fire("close")
				door:Fire("lock")
			end)
		end)

		self:NextThink(CurTime() + 0.4)

		return true
	end

	function ENT:Initialize()

		self:SetModel(self.GetLockModel())
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)
		self:SetLocked(true)

		self:SetMoveType(MOVETYPE_NONE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.nextUse = 0
		self.spawnTime = CurTime()

		timer.Simple(0.1, function()
			if (IsValid(self)) then
				self:Apply(true)
			end
		end)
	end

	function ENT:OnTakeDamage()
		return 0
	end

	function ENT:CanProperty()
		return false
	end

	function ENT:CanTool()
		return false
	end

	function ENT:OnRemove()
		self:EachDoor(function(door)
			door:Fire("unlock")

			door.nwLock = nil
		end)
	end

	function ENT:Fail()
		self:EmitSound("buttons/combine_button_locked.wav")
		self:SetError(true)

		timer.Simple(1.2, function()
			if (IsValid(self)) then
				self:SetError(false)
			end
		end)
	end

	function ENT:Use(client)
		if (self.nextUse > CurTime() or !IsValid(self.door)) then
			return
		end

		self.nextUse = CurTime() + 1.5

		if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
			return
		end

		if (self.nwHacked) then
			self:SetError(true)
			self:EmitSound("framework/cmb/forcefield/sparkle" ..
				math.random(4) .. ".mp3", 60, math.random(96, 108))

			timer.Simple(1, function()
				if (IsValid(self)) then
					self:SetError(false)
				end
			end)

			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("lockBroken")
			net.Send(client)

			return
		end

		local bAdminOverride = client:IsAdmin() and client:KeyDown(IN_SPEED)

		if (!NETWORK.factions.IsAlliance(client) and !bAdminOverride) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("lockNoAccess")
			net.Send(client)

			return self:Fail()
		end

		local bLocked = !self:GetLocked()

		self:Apply(bLocked)

		if (bAdminOverride) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("lockAdminOverride")
			net.Send(client)
		end

		if (!bLocked) then
			self:SetGranted(true)

			timer.Simple(1.5, function()
				if (IsValid(self)) then
					self:SetGranted(false)
				end
			end)
		end
	end
else
	local glow = Material("sprites/glow04_noz")

	function ENT:GetLightColor()
		if (self:GetError()) then
			return Color(240, 70, 60)
		end

		if (self:GetGranted()) then
			return Color(90, 230, 120)
		end

		if (self:GetLocked()) then
			return Color(70, 140, 255)
		end

		return Color(90, 230, 120)
	end

	function ENT:Draw()
		self:DrawModel()

		local color = self:GetLightColor()
		local position = self:GetPos() + self:GetUp() * -8.7 +
			self:GetForward() * -3.85 + self:GetRight() * -6
		local pulse = self:GetError() and (0.45 + math.abs(math.sin(CurTime() * 9)) * 0.55) or
			(0.82 + math.sin(CurTime() * 2.2) * 0.18)

		render.SetMaterial(glow)
		render.DrawSprite(position, 26 * pulse, 26 * pulse, ColorAlpha(color, 90 * pulse))
		render.DrawSprite(position, 9, 9, color)

		local dynamic = DynamicLight(self:EntIndex())

		if (dynamic) then
			dynamic.pos = position + self:GetForward() * -6
			dynamic.r = color.r
			dynamic.g = color.g
			dynamic.b = color.b
			dynamic.brightness = 2.4 * pulse
			dynamic.decay = 900
			dynamic.size = 110
			dynamic.dietime = CurTime() + 0.3
		end
	end
end

if (SERVER) then
	local BLOCKED = {open = true, toggle = true, unlock = true, close = false}

	hook.Add("AcceptInput", "nwLockSeal", function(entity, input, activator, caller)
		local lock = entity.nwLock

		if (!IsValid(lock) or !lock:GetLocked() or lock.bDriving) then
			return
		end

		if (BLOCKED[string.lower(input)]) then
			return true
		end
	end)
end
