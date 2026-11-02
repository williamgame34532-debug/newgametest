AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

local L = {}
HLA.Locks = L

local function partner(door)
	if door:GetClass() ~= 'prop_door_rotating' then return end
	local kv = door:GetKeyValues() or {}
	local slave = kv.slavename
	if isstring(slave) and slave ~= '' then
		local found = ents.FindByName(slave)[1]
		if IsValid(found) and found ~= door then return found end
	end
	local name = door:GetName()
	if name ~= '' then
		for _, o in ipairs(ents.FindByClass('prop_door_rotating')) do
			local okv = o:GetKeyValues() or {}
			if o ~= door and okv.slavename == name then return o end
		end
	end
end

function ENT:GetLockPosition(door, normal)
	local index = door:LookupBone('handle')
	local position = door:GetPos()
	normal = normal or door:GetForward():Angle()
	if index and index >= 1 then position = door:GetBonePosition(index) end
	position = position + normal:Forward() * 7.2 + normal:Up() * 10 + normal:Right() * 2
	normal:RotateAroundAxis(normal:Up(), 90)
	normal:RotateAroundAxis(normal:Forward(), 180)
	normal:RotateAroundAxis(normal:Right(), 180)
	return position, normal
end

function ENT:SetDoor(door, position, angles)
	if not HLA.IsDoor(door) then return end
	local doorPartner = partner(door)
	self.door = door
	self.door:DeleteOnRemove(self)
	door.HLALock = self
	if IsValid(doorPartner) then
		self.doorPartner = doorPartner
		self.doorPartner:DeleteOnRemove(self)
		doorPartner.HLALock = self
	end
	self:SetPos(position)
	self:SetAngles(angles)
	self:SetParent(door)
end

function ENT:SpawnFunction(client, trace)
	local door = trace.Entity
	if not HLA.IsDoor(door) or IsValid(door.HLALock) then
		client:ChatPrint('[HLA] Наведитесь на дверь без замка')
		return
	end
	local normal = client:GetEyeTrace().HitNormal:Angle()
	local position, angles = self:GetLockPosition(door, normal)
	local entity = ents.Create('hla_combinelock')
	entity:SetPos(trace.HitPos)
	entity:Spawn()
	entity:Activate()
	entity:SetDoor(door, position, angles)
	L.Save()
	return entity
end

function ENT:Initialize()
	self:SetModel(self.LockModel)
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetUseType(SIMPLE_USE)
	self.nextUseTime = 0
end

function ENT:OnRemove()
	if IsValid(self) then self:SetParent(nil) end
	if IsValid(self.door) then
		self.door:Fire('unlock')
		self.door.HLALock = nil
	end
	if IsValid(self.doorPartner) then
		self.doorPartner:Fire('unlock')
		self.doorPartner.HLALock = nil
	end
	if not L.cleaning and not L.loading then timer.Simple(0, L.Save) end
end

function ENT:OnLockChanged(name, bWasLocked, bLocked)
	if not IsValid(self.door) then return end
	if bLocked then
		if not L.loading then self:EmitSound(self.SndLock) end
		self.door:Fire('lock')
		self.door:Fire('close')
		if IsValid(self.doorPartner) then
			self.doorPartner:Fire('lock')
			self.doorPartner:Fire('close')
		end
	else
		if not L.loading then self:EmitSound(self.SndUnlock[math.random(#self.SndUnlock)]) end
		self.door:Fire('unlock')
		if IsValid(self.doorPartner) then self.doorPartner:Fire('unlock') end
	end
	if not L.loading then timer.Simple(0, L.Save) end
end

function ENT:DisplayError()
	self:EmitSound(self.SndError)
	self:SetDisplayError(true)
	timer.Simple(1.2, function()
		if IsValid(self) then self:SetDisplayError(false) end
	end)
end

function ENT:Toggle(client)
	if self.nextUseTime > CurTime() then return end
	if not IsValid(client) or not client:Alive() or client.HLAInMenu or hook.Run('HLACanUseCombineLock', client) == false then
		self:DisplayError()
		self.nextUseTime = CurTime() + 2
		return
	end
	self:SetLocked(not self:GetLocked())
	self.nextUseTime = CurTime() + 2
end

function ENT:Use(client)
	self:Toggle(client)
end

local function path() return 'hla/locks/' .. game.GetMap() .. '.json' end

function L.Save()
	if L.cleaning then return end
	local out = {}
	for _, e in ipairs(ents.FindByClass('hla_combinelock')) do
		local d = e.door
		if IsValid(d) and d:MapCreationID() >= 0 then
			out[#out + 1] = {door = d:MapCreationID(), pos = d:WorldToLocal(e:GetPos()), ang = d:WorldToLocalAngles(e:GetAngles()), locked = e:GetLocked()}
		end
	end
	file.CreateDir('hla/locks')
	file.Write(path(), util.TableToJSON(out))
end

function L.Load()
	local raw = file.Read(path(), 'DATA')
	local t = raw and util.JSONToTable(raw)
	if not istable(t) then return end
	L.loading = true
	for _, r in ipairs(t) do
		local d = ents.GetMapCreatedEntity(tonumber(r.door) or -1)
		if HLA.IsDoor(d) and not IsValid(d.HLALock) and r.pos and r.ang then
			local e = ents.Create('hla_combinelock')
			e:SetPos(d:LocalToWorld(r.pos))
			e:Spawn()
			e:Activate()
			e:SetDoor(d, d:LocalToWorld(r.pos), d:LocalToWorldAngles(r.ang))
			if r.locked then e:SetLocked(true) end
		end
	end
	L.loading = false
end

hook.Add('InitPostEntity', 'HLACombineLocks', function() timer.Simple(1, L.Load) end)
hook.Add('PreCleanupMap', 'HLACombineLocks', function() L.cleaning = true end)
hook.Add('PostCleanupMap', 'HLACombineLocks', function() timer.Simple(1, function() L.cleaning = false L.Load() end) end)
hook.Add('ShutDown', 'HLACombineLocks', function() L.cleaning = true end)
