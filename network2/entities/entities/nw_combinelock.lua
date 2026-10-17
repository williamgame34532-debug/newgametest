AddCSLuaFile()

-- The combine lock (after the Helix ix_combinelock). Spawned looking at a door: it sits on the door
-- by the handle and goes with it (double doors share it). E - the Alliance locks / unlocks it (the
-- door closes and locks), anyone else gets the refusal. Kept with the map (sv_persist.lua).
-- The look: the lamp of the state - a soft glow, a hot core and a little light on the door; blue -
-- locked, green - open, red blinking - refused. A change: a short flash, blue sparks, a scan line
-- over the panel and the lock sounds of the server (sound/network2/lock).

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

	function ENT:Initialize()
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

		if (!NW.zones.IsAlliance(client) and !client:IsAdmin()) then
			return self:Refuse()
		end

		self:SetState(!self:GetLocked())
	end

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
local CORE = Material("sprites/glow04_noz")
local BLUE = Color(70, 150, 255)
local GREEN = Color(80, 255, 140)
local RED = Color(255, 60, 50)

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
	local breath = 0.85 + 0.15 * math.sin(now * 2.2)

	render.SetMaterial(GLOW)
	render.DrawSprite(pos, 22 * breath * strength + flash * 30, 22 * breath * strength + flash * 30,
		ColorAlpha(color, 120 * strength))
	render.SetMaterial(CORE)
	render.DrawSprite(pos, 6 + flash * 6, 6 + flash * 6, ColorAlpha(color, 255 * strength))

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
	if (LocalPlayer():GetPos():DistToSqr(self:GetPos()) < 700 * 700) then
		local light = DynamicLight(self:EntIndex())

		if (light) then
			local color = self:GetError() and RED or (self:GetLocked() and BLUE or GREEN)

			light.pos = self:GetPos() + self:GetForward() * -8
			light.r, light.g, light.b = color.r, color.g, color.b
			light.brightness = 0.6
			light.decay = 1000
			light.size = 48
			light.dietime = CurTime() + 0.2
		end
	end
end
