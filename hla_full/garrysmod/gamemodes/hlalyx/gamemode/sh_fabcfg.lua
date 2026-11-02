local C = CFRework
local F = {}
HLA.FabCfg = F
F.Path = 'hla/fabricator.json'
F.MaxCustom = 96
F.Kinds = {
	{id = 'weapon', label = 'ОРУЖИЕ'},
	{id = 'ammo', label = 'ПАТРОНЫ (В ИНВЕНТАРЬ)'},
	{id = 'health', label = 'ЗДОРОВЬЕ'},
	{id = 'armor', label = 'БРОНЯ'},
}
local KIND = {}
for _, k in ipairs(F.Kinds) do KIND[k.id] = true end

F.EngineModels = {
	weapon_pistol = 'models/weapons/w_pistol.mdl', weapon_357 = 'models/weapons/w_357.mdl',
	weapon_smg1 = 'models/weapons/w_smg1.mdl', weapon_ar2 = 'models/weapons/w_irifle.mdl',
	weapon_shotgun = 'models/weapons/w_shotgun.mdl', weapon_crossbow = 'models/weapons/w_crossbow.mdl',
	weapon_rpg = 'models/weapons/w_rocket_launcher.mdl', weapon_frag = 'models/weapons/w_grenade.mdl',
	weapon_crowbar = 'models/weapons/w_crowbar.mdl', weapon_stunstick = 'models/weapons/w_stunbaton.mdl',
	weapon_slam = 'models/weapons/w_slam.mdl', weapon_bugbait = 'models/weapons/w_bugbait.mdl',
}

F.BaseList = {}
F.Base = {}
for _, it in ipairs(C.Items) do
	F.BaseList[#F.BaseList + 1] = it
	local def = it.item and HLA.Items and HLA.Items.Defs[it.item]
	F.Base[it.id] = {cost = it.cost, amount = it.amount, off = false, text = it.text, defText = def and def.text}
end

local function withAmount(text, from, to)
	if not isstring(text) or not from or not to then return text end
	return (string.gsub(text, '([^%d])' .. from .. '([^%d])', '%1' .. to .. '%2'))
end

local function int(v, lo, hi, def)
	v = tonumber(v)
	if not v then return def end
	return math.Clamp(math.floor(v), lo, hi)
end

function F.WeaponModel(class)
	if F.EngineModels[class] then return F.EngineModels[class] end
	local w = weapons.GetStored and weapons.GetStored(class)
	if w and isstring(w.WorldModel) and w.WorldModel ~= '' then return w.WorldModel end
	return 'models/weapons/w_smg1.mdl'
end

function F.WeaponName(class)
	local w = weapons.GetStored and weapons.GetStored(class)
	if w and isstring(w.PrintName) and w.PrintName ~= '' then return w.PrintName end
	return class
end

F.Custom = {}

local function customItem(c)
	if not istable(c) or not KIND[c.kind] then return end
	local id = isstring(c.id) and string.match(c.id, '^c_[%w_]+$') and c.id
	if not id then return end
	local it = {
		id = id, custom = true, kind = c.kind, srcKind = c.kind,
		name = isstring(c.name) and string.sub(c.name, 1, 60) or id,
		category = int(c.category, 1, #C.Categories, 2),
		cost = int(c.cost, 0, 9999, 10),
		off = c.off == true,
		text = isstring(c.text) and string.sub(c.text, 1, 240) or '',
		model = isstring(c.model) and c.model ~= '' and string.sub(c.model, 1, 200) or nil,
	}
	if c.kind == 'weapon' then
		it.class = isstring(c.class) and string.match(c.class, '^[%w_%.%-]+$') or nil
		if not it.class then return end
		it.model = it.model or F.WeaponModel(it.class)
		if not isstring(c.name) or c.name == '' then it.name = F.WeaponName(it.class) end
		if it.text == '' then it.text = 'Оружие: ' .. F.WeaponName(it.class) .. '.' end
	elseif c.kind == 'ammo' then
		it.ammo = isstring(c.ammo) and string.match(c.ammo, '^[%w_%.%-]+$') or nil
		if not it.ammo then return end
		it.amount = int(c.amount, 1, 9999, 30)
		it.model = it.model or 'models/items/boxmrounds.mdl'
		if it.text == '' then it.text = 'Патроны ' .. it.ammo .. ': ' .. it.amount .. ' шт. Попадает в инвентарь.' end
		it.item = 'fab_' .. id
		it.ammoKind = true
	else
		it.amount = int(c.amount, 1, 9999, 25)
		it.model = it.model or (c.kind == 'health' and 'models/items/healthkit.mdl' or 'models/items/battery.mdl')
		if it.text == '' then it.text = (c.kind == 'health' and 'Восстанавливает ' or 'Добавляет брони: ') .. it.amount .. '.' end
	end
	return it
end

function F.Current()
	local base = {}
	for _, it in ipairs(F.BaseList) do base[it.id] = {cost = it.cost, amount = it.amount, off = it.off or false} end
	local custom = {}
	for _, it in ipairs(F.Custom) do
		custom[#custom + 1] = {id = it.id, kind = it.srcKind or it.kind, name = it.name, category = it.category, cost = it.cost, off = it.off,
			text = it.text, model = it.model, class = it.class, ammo = it.ammo, amount = it.amount}
	end
	return {base = base, custom = custom}
end

function F.Apply(t)
	if not istable(t) then return end
	local baseCfg, customCfg = t.base, t.custom
	if baseCfg == nil and customCfg == nil then baseCfg = t end
	baseCfg = istable(baseCfg) and baseCfg or {}
	local items = {}
	for _, it in ipairs(F.BaseList) do
		local base = F.Base[it.id]
		local o = baseCfg[it.id]
		it.cost, it.amount, it.off = base.cost, base.amount, false
		if istable(o) then
			it.cost = int(o.cost, 0, 9999, it.cost)
			if base.amount then it.amount = int(o.amount, 1, 9999, it.amount) end
			it.off = o.off == true
		end
		it.text = withAmount(base.text, base.amount, it.amount)
		local def = it.item and HLA.Items and HLA.Items.Defs[it.item]
		if def and def.amount and it.amount then
			def.amount = it.amount
			def.text = withAmount(base.defText, base.amount, it.amount)
		end
		items[#items + 1] = it
	end
	F.Custom = {}
	local seen = {}
	for _, c in ipairs(istable(customCfg) and customCfg or {}) do
		if #F.Custom >= F.MaxCustom then break end
		local it = customItem(c)
		if it and not seen[it.id] then
			seen[it.id] = true
			F.Custom[#F.Custom + 1] = it
			items[#items + 1] = it
			if it.ammoKind and HLA.Items then
				HLA.Items.Defs[it.item] = {name = it.name, model = it.model, text = it.text, use = 'ammo', ammo = it.ammo, amount = it.amount}
				it.kind = 'item'
			end
		end
	end
	C.Items = items
end

function F.NewID()
	return 'c_' .. os.time() .. '_' .. math.random(100, 999)
end

if SERVER then
	util.AddNetworkString('hla_fab_cfg')
	util.AddNetworkString('hla_fab_save')

	local function send(to)
		local data = util.Compress(util.TableToJSON(F.Current()))
		net.Start('hla_fab_cfg')
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)
		if to then net.Send(to) else net.Broadcast() end
	end
	F.Send = send

	function F.Load()
		local raw = file.Read(F.Path, 'DATA')
		local t = raw and util.JSONToTable(raw)
		if istable(t) then F.Apply(t) end
	end

	function F.Save()
		file.CreateDir('hla')
		file.Write(F.Path, util.TableToJSON(F.Current(), true))
	end

	hook.Add('Initialize', 'HLAFabCfg', F.Load)
	hook.Add('PlayerInitialSpawn', 'HLAFabCfg', function(p) timer.Simple(2, function() if IsValid(p) then send(p) end end) end)

	net.Receive('hla_fab_save', function(_, p)
		if not (HLA.CanEdit and HLA.CanEdit(p)) then return end
		local len = net.ReadUInt(32)
		if len <= 0 or len > 256 * 1024 then return end
		local t = util.JSONToTable(util.Decompress(net.ReadData(len)) or '')
		if not istable(t) then return end
		F.Apply(t)
		F.Save()
		send()
		p:ChatPrint('[HLA] Фабрикатор сохранён: ' .. #C.Items .. ' предметов')
	end)
else
	net.Receive('hla_fab_cfg', function()
		local len = net.ReadUInt(32)
		local t = util.JSONToTable(util.Decompress(net.ReadData(len)) or '')
		if istable(t) then F.Apply(t) end
		hook.Run('HLAFabCfgChanged')
	end)

	function F.SendEdit(t)
		local data = util.Compress(util.TableToJSON(t))
		net.Start('hla_fab_save')
		net.WriteUInt(#data, 32)
		net.WriteData(data, #data)
		net.SendToServer()
	end
end
