local L = {}
HLA.Loot = L
local I = HLA.Items

L.Models = {
	{label = 'ЯЩИК СНАБЖЕНИЯ', model = 'models/items/item_item_crate.mdl'},
	{label = 'ДЕРЕВЯННЫЙ ЯЩИК', model = 'models/props_junk/wood_crate001a.mdl'},
	{label = 'БОЛЬШОЙ ЯЩИК', model = 'models/props_junk/wood_crate002a.mdl'},
	{label = 'ШКАФЧИК', model = 'models/props_c17/lockers001a.mdl'},
	{label = 'КАРТОТЕКА', model = 'models/props_lab/filecabinet02.mdl'},
	{label = 'ХОЛОДИЛЬНИК', model = 'models/props_c17/furniturefridge001a.mdl'},
	{label = 'КОМОД', model = 'models/props_c17/furnituredrawer001a.mdl'},
	{label = 'КОНТЕЙНЕР АЛЬЯНСА', model = 'models/props_combine/combine_dispenser.mdl'},
}
L.ModelOK = {}
for _, m in ipairs(L.Models) do L.ModelOK[m.model] = true end
L.MaxSlots = 16

L.Default = {
	default = {
		{id = 'pills', chance = 60, min = 1, max = 2},
		{id = 'medkit', chance = 25, min = 1, max = 1},
		{id = 'battery', chance = 30, min = 1, max = 2},
		{id = 'ammo_service', chance = 50, min = 1, max = 2},
		{id = 'ammo_pistol', chance = 35, min = 1, max = 2},
		{id = 'health_vial', chance = 10, min = 1, max = 1},
	},
}

if SERVER then
	util.AddNetworkString('hla_cont')
	util.AddNetworkString('hla_cont_do')
	util.AddNetworkString('hla_loot_tables')
	util.AddNetworkString('hla_loot_save')
	util.AddNetworkString('hla_cont_cfg')

	L.Tables = table.Copy(L.Default)

	local function sanitize(t)
		local out = {}
		for name, list in pairs(istable(t) and t or {}) do
			if isstring(name) and #name > 0 and #name <= 32 and istable(list) then
				local entries = {}
				for _, e in ipairs(list) do
					if istable(e) and isstring(e.id) and I.Defs[e.id] and #entries < 32 then
						local mn = math.Clamp(math.floor(tonumber(e.min) or 1), 1, 99)
						entries[#entries + 1] = {id = e.id, chance = math.Clamp(math.floor(tonumber(e.chance) or 50), 1, 100),
							min = mn, max = math.Clamp(math.floor(tonumber(e.max) or mn), mn, 99)}
					end
				end
				out[name] = entries
			end
		end
		if not out.default then out.default = table.Copy(L.Default.default) end
		return out
	end

	function L.LoadTables()
		local t = util.JSONToTable(file.Read('hla/loot.json', 'DATA') or '')
		if istable(t) then L.Tables = sanitize(t) end
	end
	function L.SaveTables()
		file.CreateDir('hla')
		file.Write('hla/loot.json', util.TableToJSON(L.Tables, true))
	end

	function L.Roll(name, slots)
		local list = L.Tables[name] or L.Tables.default or {}
		local items = {}
		local pos = 1
		for _, e in ipairs(list) do
			if pos > slots then break end
			if math.random(1, 100) <= e.chance then
				local n = math.random(e.min, e.max)
				local max = I.Stack(e.id)
				while n > 0 and pos <= slots do
					local put = math.min(n, max)
					items[pos] = {id = e.id, n = put}
					pos = pos + 1
					n = n - put
				end
			end
		end
		return items
	end

	local function filled(e)
		local n = 0
		for i = 1, e:GetSlots() do if e.items[i] then n = n + 1 end end
		e:SetFilled(n)
	end

	function L.Refill(e)
		e.items = L.Roll(e.cfg.table, e.cfg.slots)
		e.nextRefill = CurTime() + math.max(1, e.cfg.respawn) * 60
		filled(e)
		L.SendTo(e)
	end

	local function viewers(e)
		local out = {}
		for _, p in ipairs(player.GetAll()) do
			if p.HLACont == e then
				if p:Alive() and p:GetPos():DistToSqr(e:GetPos()) < 160 * 160 then out[#out + 1] = p else p.HLACont = nil end
			end
		end
		return out
	end

	local function write(e)
		net.WriteEntity(e)
		net.WriteString(e:GetTitle())
		net.WriteUInt(e:GetSlots(), 5)
		for i = 1, e:GetSlots() do
			local it = e.items[i]
			net.WriteString(it and it.id or '')
			net.WriteUInt(it and it.n or 0, 8)
		end
	end

	function L.SendTo(e, only)
		local to = only and {only} or viewers(e)
		if #to == 0 then return end
		net.Start('hla_cont')
		net.WriteBool(true)
		write(e)
		net.Send(to)
	end

	function L.Open(p, e)
		p.HLACont = e
		e:EmitSound('items/ammocrate_open.wav', 60, 100, 0.6)
		L.SendTo(e, p)
		I.Send(p)
	end

	net.Receive('hla_cont_do', function(_, p)
		if (p.HLAContNext or 0) > CurTime() then return end
		p.HLAContNext = CurTime() + 0.08
		local what = net.ReadString()
		local e = p.HLACont
		if what == 'close' then p.HLACont = nil return end
		if not IsValid(e) or not e.IsHLAContainer or not p:Alive() or p:GetPos():DistToSqr(e:GetPos()) > 160 * 160 then
			p.HLACont = nil
			net.Start('hla_cont') net.WriteBool(false) net.Send(p)
			return
		end
		local function takeSlot(i)
			local it = e.items[i]
			if not it then return false end
			local room = math.min(it.n, I.Room(p, it.id))
			if room < 1 then return false end
			I.Add(p, it.id, room)
			it.n = it.n - room
			if it.n <= 0 then e.items[i] = nil end
			return true
		end
		if what == 'take' then
			local i = net.ReadUInt(5)
			if takeSlot(i) then p:EmitSound(I.MoveSound(), 50) else p:ChatPrint('Инвентарь заполнен') end
		elseif what == 'takeall' then
			local any = false
			for i = 1, e:GetSlots() do if takeSlot(i) then any = true end end
			if any then p:EmitSound(I.MoveSound(), 50) end
		elseif what == 'put' then
			local s = net.ReadUInt(5)
			local inv = I.Inv(p)
			local id = inv[s]
			if not id then return end
			local n = I.N(p, s)
			local max = I.Stack(id)
			for i = 1, e:GetSlots() do
				if n <= 0 then break end
				local it = e.items[i]
				if it and it.id == id and it.n < max then
					local put = math.min(n, max - it.n)
					it.n = it.n + put
					n = n - put
				end
			end
			for i = 1, e:GetSlots() do
				if n <= 0 then break end
				if not e.items[i] then
					local put = math.min(n, max)
					e.items[i] = {id = id, n = put}
					n = n - put
				end
			end
			local moved = I.N(p, s) - n
			if moved > 0 then I.Take(p, s, moved) p:EmitSound(I.MoveSound(), 50) else p:ChatPrint('Контейнер заполнен') end
		end
		filled(e)
		L.SendTo(e)
	end)

	timer.Create('HLALootRefill', 10, 0, function()
		for _, e in ipairs(ents.FindByClass('hla_container')) do
			if e.cfg and e.nextRefill and CurTime() >= e.nextRefill and #viewers(e) == 0 then L.Refill(e) end
		end
	end)

	local function mapPath() return 'hla/containers/' .. game.GetMap() .. '.json' end

	function L.SaveMap()
		if L.loading or L.cleaning then return end
		local out = {}
		for _, e in ipairs(ents.FindByClass('hla_container')) do
			if e.cfg then out[#out + 1] = {pos = e:GetPos(), ang = e:GetAngles(), cfg = e.cfg} end
		end
		file.CreateDir('hla/containers')
		file.Write(mapPath(), util.TableToJSON(out))
	end

	local function cleanCfg(c)
		c = istable(c) and c or {}
		return {
			model = L.ModelOK[c.model] and c.model or L.Models[1].model,
			title = isstring(c.title) and string.sub(c.title, 1, 40) or 'ЯЩИК СНАБЖЕНИЯ',
			table = isstring(c.table) and L.Tables[c.table] and c.table or 'default',
			slots = math.Clamp(math.floor(tonumber(c.slots) or 8), 1, L.MaxSlots),
			respawn = math.Clamp(math.floor(tonumber(c.respawn) or 10), 1, 600),
		}
	end

	function L.LoadMap()
		local t = util.JSONToTable(file.Read(mapPath(), 'DATA') or '')
		if not istable(t) then return end
		L.loading = true
		for _, r in ipairs(t) do
			if r.pos then
				local e = ents.Create('hla_container')
				e.cfg = cleanCfg(r.cfg)
				e:SetPos(r.pos)
				e:SetAngles(r.ang or angle_zero)
				e:Spawn()
				e:Activate()
				L.Refill(e)
			end
		end
		L.loading = false
	end

	function L.SendTables(p)
		local data = util.Compress(util.TableToJSON(L.Tables))
		net.Start('hla_loot_tables')
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)
		net.Send(p)
	end

	net.Receive('hla_loot_save', function(_, p)
		if not (HLA.CanEdit and HLA.CanEdit(p)) then return end
		local len = net.ReadUInt(32)
		if len <= 0 or len > 128 * 1024 then return end
		local t = util.JSONToTable(util.Decompress(net.ReadData(len)) or '')
		if not istable(t) then return end
		L.Tables = sanitize(t)
		L.SaveTables()
		L.SendTables(p)
		p:ChatPrint('[HLA] Таблицы лута сохранены')
	end)

	net.Receive('hla_cont_cfg', function(_, p)
		if not (HLA.CanEdit and HLA.CanEdit(p)) then return end
		local e = net.ReadEntity()
		local what = net.ReadString()
		if what == 'tables' then L.SendTables(p) return end
		if not IsValid(e) or not e.IsHLAContainer then return end
		if what == 'get' then
			net.Start('hla_cont_cfg') net.WriteEntity(e) net.WriteString(util.TableToJSON(e.cfg)) net.Send(p)
			L.SendTables(p)
		elseif what == 'set' then
			local c = cleanCfg(util.JSONToTable(net.ReadString()) or {})
			local modelChanged = c.model ~= e.cfg.model
			e.cfg = c
			e:SetTitle(c.title)
			e:SetSlots(c.slots)
			if modelChanged then
				e:SetModel(c.model)
				e:PhysicsInit(SOLID_VPHYSICS)
				local phys = e:GetPhysicsObject()
				if IsValid(phys) then phys:EnableMotion(false) end
			end
			for i = c.slots + 1, L.MaxSlots do e.items[i] = nil end
			L.SaveMap()
			p:ChatPrint('[HLA] Контейнер сохранён')
		elseif what == 'refill' then
			L.Refill(e)
		end
	end)

	hook.Add('Initialize', 'HLALoot', L.LoadTables)
	hook.Add('InitPostEntity', 'HLALoot', function() timer.Simple(1, L.LoadMap) end)
	hook.Add('PreCleanupMap', 'HLALoot', function() L.cleaning = true end)
	hook.Add('PostCleanupMap', 'HLALoot', function() timer.Simple(1, function() L.cleaning = false L.LoadMap() end) end)
	hook.Add('ShutDown', 'HLALoot', function() L.cleaning = true end)
	hook.Add('PhysgunDrop', 'HLALoot', function(_, e) if IsValid(e) and e.IsHLAContainer then timer.Simple(0, L.SaveMap) end end)
end
