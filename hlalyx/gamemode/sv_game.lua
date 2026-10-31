-- Half-Life: Alyx gamemode: loadout, resin economy, fabricator placement that persists per map.
local C = CFRework

function GM:PlayerLoadout(p)
	p:StripWeapons()
	p:Give('weapon_physcannon') -- gravity gloves stand-in
	p:Give('weapon_pistol')
	p:GiveAmmo(36, 'Pistol', true)
	p:SelectWeapon('weapon_pistol')
	return true
end

-- a brand-new player (no saved balance) starts with some resin
hook.Add('PlayerInitialSpawn', 'HLAStartResin', function(p)
	timer.Simple(0.2, function()
		if not IsValid(p) then return end
		if not file.Exists('cf_rework/balances/' .. p:SteamID64() .. '.txt', 'DATA') then
			C.ChangeBalance(p, HLA.StartResin:GetInt())
		end
	end)
end)

local function dropResin(pos, n)
	for i = 1, n do
		local e = ents.Create('sent_cf_resin')
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
	for _, e in ipairs(ents.FindByClass('sent_combine_fabricator')) do
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
		local e = ents.Create('sent_combine_fabricator')
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
