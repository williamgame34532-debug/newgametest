-- Half-Life: Alyx gamemode: loadout, resin economy, fabricator placement that persists per map.
local C = CFRework

-- loadout: hands and the weapon of the unit's model
function GM:PlayerLoadout(p)
	p:StripWeapons()
	if p.HLAInMenu then return true end -- nothing in hand while choosing a character
	p:Give('hla_hands')
	local cls = p.HLAClass
	local w = cls and weapons.GetStored(cls.weapon) and p:Give(cls.weapon)
	if IsValid(w) then
		local ammo = w:GetPrimaryAmmoType()
		if ammo >= 0 then p:GiveAmmo(math.max(w:GetMaxClip1(), 10) * 4, game.GetAmmoName(ammo), true) end
		p:SelectWeapon(cls.weapon)
	else
		if cls then print('[HLA] weapon not installed: ' .. cls.weapon .. ' (model ' .. cls.model .. ')') end
		p:Give('weapon_pistol')
		p:GiveAmmo(36, 'Pistol', true)
		p:SelectWeapon('weapon_pistol')
	end
	return true
end

-- start resin is given to each new character when it is created (sv_menu.lua)

local function dropResin(pos, n)
	for i = 1, n do
		local e = ents.Create(C.ResinClass)
		if not IsValid(e) then return end
		e:SetPos(pos + Vector(math.Rand(-8, 8), math.Rand(-8, 8), 16 + i * 4))
		e:Spawn()
		local ph = e:GetPhysicsObject()
		if IsValid(ph) then ph:SetVelocity(VectorRand() * 60 + Vector(0, 0, 120)) end
	end
end

hook.Add('OnNPCKilled', 'HLAResinDrop', function(npc, attacker)
	if not IsValid(npc) or not IsValid(attacker) or not attacker:IsPlayer() then return end
	if math.random() < HLA.DropChance:GetFloat() then dropResin(npc:WorldSpaceCenter(), math.random(1, 2)) end
end)

hook.Add('PropBreak', 'HLAResinCrates', function(_, prop)
	if not IsValid(prop) then return end
	local m = string.lower(prop:GetModel() or '')
	if (m:find('crate') or m:find('box')) and math.random() < 0.5 then dropResin(prop:WorldSpaceCenter(), 1) end
end)

-- fabricators placed by admins are remembered per map
local function savePath() return 'hlalyx/stations_' .. game.GetMap() .. '.txt' end

local function saveStations()
	local list = {}
	for _, e in ipairs(ents.FindByClass(C.FabClass)) do
		local p, a = e:GetPos(), e:GetAngles()
		list[#list + 1] = {p.x, p.y, p.z, a.p, a.y, a.r}
	end
	file.CreateDir('hlalyx')
	file.Write(savePath(), util.TableToJSON(list))
	return #list
end

local function loadStations()
	local data = util.JSONToTable(file.Read(savePath(), 'DATA') or '') or {}
	for _, s in ipairs(data) do
		local e = ents.Create(C.FabClass)
		if IsValid(e) then
			e:SetPos(Vector(s[1], s[2], s[3])) e:SetAngles(Angle(s[4], s[5], s[6]))
			e:Spawn() e:Activate()
			e.HLAPlaced = true
		end
	end
end
hook.Add('InitPostEntity', 'HLALoadStations', loadStations)
hook.Add('PostCleanupMap', 'HLALoadStations', loadStations)

concommand.Add('hla_save_stations', function(p)
	if IsValid(p) and not p:IsAdmin() then return end
	local n = saveStations()
	local msg = 'Сохранено фабрикаторов: ' .. n
	if IsValid(p) then p:ChatPrint(msg) else print(msg) end
end)

concommand.Add('hla_clear_stations', function(p)
	if IsValid(p) and not p:IsAdmin() then return end
	file.Delete(savePath())
	if IsValid(p) then p:ChatPrint('Сохранённые фабрикаторы для карты удалены') end
end)

---------------------------------------------------------------------------------------------------
-- bodies are real (server) ragdolls, so they can be carried with the hands: NPCs through
-- ai_serverragdolls, players through their own ragdoll made here; the oldest go after a limit
local MAX_BODIES = 16
local BODY_LIFE = 300
local bodies = {}

hook.Add('Initialize', 'HLAServerRagdolls', function() RunConsoleCommand('ai_serverragdolls', '1') end)

local function track(rag)
	bodies[#bodies + 1] = rag
	while #bodies > MAX_BODIES do
		local old = table.remove(bodies, 1)
		if IsValid(old) and not IsValid(old.HLAHeldBy) then old:Remove() end
	end
	timer.Simple(BODY_LIFE, function()
		if IsValid(rag) and not IsValid(rag.HLAHeldBy) then rag:Remove() end
	end)
end
hook.Add('CreateEntityRagdoll', 'HLABodies', function(owner, rag) if IsValid(rag) then track(rag) end end)

function GM:DoPlayerDeath(p, attacker, dmg)
	p:AddDeaths(1)
	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= p then attacker:AddFrags(1) end
	local rag = ents.Create('prop_ragdoll')
	if not IsValid(rag) then p:CreateRagdoll() return end
	rag:SetModel(p:GetModel())
	rag:SetPos(p:GetPos())
	rag:SetAngles(Angle(0, p:GetAngles().y, 0))
	rag:SetSkin(p:GetSkin())
	for i = 0, p:GetNumBodyGroups() - 1 do rag:SetBodygroup(i, p:GetBodygroup(i)) end
	rag:Spawn()
	rag:Activate()
	-- pose of the body at the moment of death
	local vel = p:GetVelocity() + (dmg and dmg:GetDamageForce() * 0.02 or vector_origin)
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local ph = rag:GetPhysicsObjectNum(i)
		local bone = rag:TranslatePhysBoneToBone(i)
		local pos, ang = p:GetBonePosition(bone)
		if IsValid(ph) and pos then
			ph:SetPos(pos)
			ph:SetAngles(ang)
			ph:SetVelocity(vel)
		end
	end
	rag:SetCollisionGroup(COLLISION_GROUP_WEAPON) -- does not block the living, hands still reach it
	rag:SetNWString('hla_name', p:GetNWString('hla_name', ''))
	track(rag)
end

---------------------------------------------------------------------------------------------------
-- eye height of the unit models: the view (and where shots come from) is put at the «eyes» of the
-- model, standing and crouched, so the camera does not sink below or float above the head
local eyeCache = {}
hook.Add('PlayerSpawn', 'HLAEyeHeight', function(p)
	timer.Simple(0.3, function()
		if not IsValid(p) or not p:Alive() or p.HLAInMenu or not (HLA.IsUnit and HLA.IsUnit(p)) then return end
		local mdl = p:GetModel()
		local z = eyeCache[mdl]
		if not z then
			local id = p:LookupAttachment('eyes')
			local a = id and id > 0 and p:GetAttachment(id)
			if not a then return end
			z = a.Pos.z - p:GetPos().z
			if z < 48 or z > 84 then return end
			eyeCache[mdl] = z
		end
		p:SetViewOffset(Vector(0, 0, z))
		p:SetViewOffsetDucked(Vector(0, 0, math.Round(z * 28 / 64, 1)))
	end)
end)
