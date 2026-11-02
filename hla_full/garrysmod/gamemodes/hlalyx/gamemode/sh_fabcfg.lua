local C = CFRework
local F = {}
HLA.FabCfg = F
F.Path = 'hla/fabricator.json'

F.Base = {}
for _, it in ipairs(C.Items) do
	local def = it.item and HLA.Items and HLA.Items.Defs[it.item]
	F.Base[it.id] = {cost = it.cost, amount = it.amount, off = false, text = it.text, defText = def and def.text}
end
local function withAmount(text, from, to)
	if not isstring(text) or not from or not to then return text end
	return (string.gsub(text, '([^%d])' .. from .. '([^%d])', '%1' .. to .. '%2'))
end

function F.Current()
	local out = {}
	for _, it in ipairs(C.Items) do out[it.id] = {cost = it.cost, amount = it.amount, off = it.off or false} end
	return out
end

function F.Apply(t)
	if not istable(t) then return end
	for _, it in ipairs(C.Items) do
		local base = F.Base[it.id]
		local o = t[it.id]
		if base then
			it.cost, it.amount, it.off = base.cost, base.amount, false
			if istable(o) then
				if tonumber(o.cost) then it.cost = math.Clamp(math.floor(tonumber(o.cost)), 0, 9999) end
				if base.amount and tonumber(o.amount) then it.amount = math.Clamp(math.floor(tonumber(o.amount)), 1, 9999) end
				it.off = o.off == true
			end
			it.text = withAmount(base.text, base.amount, it.amount)
			local def = it.item and HLA.Items and HLA.Items.Defs[it.item]
			if def and def.amount and it.amount then
				def.amount = it.amount
				def.text = withAmount(base.defText, base.amount, it.amount)
			end
		end
	end
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
		p:ChatPrint('[HLA] Настройки фабрикатора сохранены')
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
