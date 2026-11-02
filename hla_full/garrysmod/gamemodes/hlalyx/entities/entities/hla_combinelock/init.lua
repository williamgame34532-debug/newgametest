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

function ENT:LockPlacement(door, normal)
	local pos = door:GetPos()
	local bone = door:LookupBone('handle')
	if bone and bone >= 1 then pos = door:GetBonePosition(bone) or pos end
	normal = normal or door:GetForward():Angle()
	pos = pos + normal:Forward() * 7.2 + normal:Up() * 10 + normal:Right() * 2
	normal:RotateAroundAxis(normal:Up(), 90)
	normal:RotateAroundAxis(normal:Forward(), 180)
	normal:RotateAroundAxis(normal:Right(), 180)
	return pos, normal
end

function ENT:SetDoor(door, pos, ang)
	if not HLA.IsDoor(door) then return end
	self.door = door
	door.HLALock = self
	door:DeleteOnRemove(self)
	local p = partner(door)
	if IsValid(p) then
		self.doorPartner = p
		p.HLALock = self
		p:DeleteOnRemove(self)
	end
	self:SetPos(pos)
	self:SetAngles(ang)
	self:SetParent(door)
	door:CallOnRemove('HLALockDoor', function(d) d.HLARemoving = true end)
	local was = door:GetInternalVariable('m_bLocked')
	if was == true then
		self.mapLocked = true
		local prev = L.loading
		L.loading = true
		self:SetLocked(true)
		L.loading = prev
	end
end

function ENT:SpawnFunction(p, tr)
	local door = tr.Entity
	if not HLA.IsDoor(door) then p:ChatPrint('[HLA] Наведитесь на дверь') return end
	if IsValid(door.HLALock) then p:ChatPrint('[HLA] На этой двери уже есть замок') return end
	local e = ents.Create('hla_combinelock')
	e:SetPos(tr.HitPos)
	e:Spawn()
	e:Activate()
	local _, ang = e:LockPlacement(door, tr.HitNormal:Angle())
	e:SetAngles(ang)
	e:SetPos(tr.HitPos)
	local n = tr.HitNormal
	local mn, mx = e:OBBMins(), e:OBBMaxs()
	local back = math.huge
	for _, x in ipairs({mn.x, mx.x}) do for _, y in ipairs({mn.y, mx.y}) do for _, z in ipairs({mn.z, mx.z}) do
		back = math.min(back, (e:LocalToWorld(Vector(x, y, z)) - tr.HitPos):Dot(n))
	end end end
	local c = (e:LocalToWorld(e:OBBCenter()) - tr.HitPos)
	local side = c - n * c:Dot(n)
	local pos = tr.HitPos - side - n * (back - 0.3)
	e:SetDoor(door, pos, ang)
	L.Save()
	return e
end

function ENT:Initialize()
	self:SetModel(self.LockModel)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetUseType(SIMPLE_USE)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
	self.nextUse = 0
end

function ENT:OnRemove()
	for _, d in ipairs({self.door, self.doorPartner}) do
		if IsValid(d) then
			if not self.mapLocked then d:Fire('Unlock') end
			d.HLALock = nil
		end
	end
	if not L.loading and not L.cleaning and IsValid(self.door) and not self.door.HLARemoving and not self.door:IsMarkedForDeletion() then timer.Simple(0, L.Save) end
end

function ENT:OnLockChanged(_, was, now)
	if was == now then return end
	for _, d in ipairs({self.door, self.doorPartner}) do
		if IsValid(d) then
			if now then d:Fire('Close') d:Fire('Lock') elseif not self.mapLocked then d:Fire('Unlock') end
		end
	end
	if L.loading then return end
	if now then self:EmitSound(self.SndLock, 65) else self:EmitSound(self.SndUnlock[math.random(#self.SndUnlock)], 65) end
	timer.Simple(0, L.Save)
end

function ENT:ShowError()
	if self:GetDisplayError() then return end
	self:EmitSound(self.SndError, 65)
	self:SetDisplayError(true)
	timer.Simple(1.2, function() if IsValid(self) then self:SetDisplayError(false) end end)
end

function L.CanUse(p)
	if not IsValid(p) or not p:Alive() or p.HLAInMenu then return false end
	return hook.Run('HLACanUseCombineLock', p) ~= false
end

function ENT:Use(p)
	if self.nextUse > CurTime() then return end
	self.nextUse = CurTime() + 1.5
	if not L.CanUse(p) or (self.mapLocked and not (HLA.CanEdit and HLA.CanEdit(p))) then self:ShowError() return end
	if self.mapLocked then self.mapLocked = nil self.adminUnlocked = true end
	self:SetLocked(not self:GetLocked())
end

hook.Add('PlayerUse', 'HLACombineLock', function(p, e)
	local lock = IsValid(e) and e.HLALock
	if IsValid(lock) and lock:GetLocked() then
		if (p.HLALockMsg or 0) < CurTime() then
			p.HLALockMsg = CurTime() + 1.5
			lock:ShowError()
		end
	end
end)

local function path() return 'hla/locks/' .. game.GetMap() .. '.json' end

function L.Save()
	if L.cleaning then return end
	local out = {}
	for _, e in ipairs(ents.FindByClass('hla_combinelock')) do
		local d = e.door
		if IsValid(d) and d:MapCreationID() >= 0 then
			out[#out + 1] = {door = d:MapCreationID(), pos = d:WorldToLocal(e:GetPos()), ang = d:WorldToLocalAngles(e:GetAngles()), locked = e:GetLocked(), unlocked = e.adminUnlocked or nil}
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
			if r.unlocked and e.mapLocked then
				e.mapLocked = nil
				e.adminUnlocked = true
				e:SetLocked(false)
			end
			if r.locked then e:SetLocked(true) end
		end
	end
	L.loading = false
end

hook.Add('InitPostEntity', 'HLACombineLocks', function() timer.Simple(1, L.Load) end)
hook.Add('PreCleanupMap', 'HLACombineLocks', function() L.cleaning = true end)
hook.Add('PostCleanupMap', 'HLACombineLocks', function() timer.Simple(1, function() L.cleaning = false L.Load() end) end)
hook.Add('ShutDown', 'HLACombineLocks', function() L.cleaning = true end)
