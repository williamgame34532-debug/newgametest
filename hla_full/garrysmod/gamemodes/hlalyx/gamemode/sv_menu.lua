local M = HLA.Menu

util.AddNetworkString('hla_menu_open')
util.AddNetworkString('hla_menu_do')
util.AddNetworkString('hla_menu_closed')
util.AddNetworkString('hla_menu_error')

file.CreateDir('hla')
file.CreateDir('hla/chars')
file.CreateDir('hla/menuspot')

local function charsPath(p) return 'hla/chars/' .. p:SteamID64() .. '.json' end

function M.SaveChars(p, list)
	file.Write(charsPath(p), util.TableToJSON(list))
end

local function nextCharID()
	local n = (tonumber(file.Read('hla/charseq.txt', 'DATA') or '') or 0) + 1
	file.Write('hla/charseq.txt', tostring(n))
	return n
end

local function numbers() return util.JSONToTable(file.Read('hla/numbers.json', 'DATA') or '') or {} end
local function saveNumbers(t) file.Write('hla/numbers.json', util.TableToJSON(t)) end
function M.NumberFree(num, exceptID)
	local owner = numbers()[num]
	return owner == nil or owner == exceptID
end
local function claimNumber(num, id) local t = numbers() t[num] = id saveNumbers(t) end
local function freeNumber(num, id)
	local t = numbers()
	if t[num] == id then t[num] = nil saveNumbers(t) end
end
function M.RandomFreeNumber(extra)
	local t = numbers()
	for _ = 1, 2000 do
		local n = string.format('%03d', math.random(100, 999))
		if not t[n] and not (extra and extra[n]) then return n end
	end
	return '000'
end

local function moveFile(from, to)
	if not file.Exists(from, 'DATA') or file.Exists(to, 'DATA') then return end
	file.Write(to, file.Read(from, 'DATA') or '')
	file.Delete(from)
end

function M.LoadChars(p)
	local t = util.JSONToTable(file.Read(charsPath(p), 'DATA') or '') or {}
	local out, changed, gaveResin = {}, false, false
	for i, c in ipairs(t) do
		if istable(c) then
			if not isnumber(c.id) then
				c.id = nextCharID()
				changed = true
				moveFile('hla/inv/' .. p:SteamID64() .. '_' .. i .. '.json', 'hla/inv/char_' .. c.id .. '.json')
				if CFRework and CFRework.StoreBalance and not gaveResin then
					gaveResin = true
					CFRework.StoreBalance('c' .. c.id, CFRework.ReadBalance(p:SteamID64()))
				end
			end
			if not M.ValidNum(c.num) or not M.NumberFree(c.num, c.id) then
				c.num = M.RandomFreeNumber()
				claimNumber(c.num, c.id)
				changed = true
			end
			if not M.Class(c.model) then c.model = M.Classes[1].model changed = true end
			c.first, c.last = nil, nil
			out[#out + 1] = c
		end
	end
	if changed then M.SaveChars(p, out) end
	return out
end
local function spotPath() return 'hla/menuspot/' .. game.GetMap() .. '.json' end
function M.Spot()
	local t = util.JSONToTable(file.Read(spotPath(), 'DATA') or '')
	if t and t.pos and t.ang then return Vector(t.pos[1], t.pos[2], t.pos[3]), Angle(t.ang[1], t.ang[2], 0) end
end

local function sendOpen(p)
	local pos, ang = M.Spot()
	net.Start('hla_menu_open')
	net.WriteTable(M.LoadChars(p))
	net.WriteBool(pos ~= nil)
	if pos then net.WriteVector(pos) net.WriteAngle(ang) end
	net.Send(p)
end

function M.Enter(p)
	if HLA.Squads and HLA.Squads.Leave and HLA.Squads.Of(p) then HLA.Squads.Leave(p, true) end
	p.HLAInMenu = true
	p.HLAJoinedRound = false
	p:SetNWBool('hla_in_menu', true)
	if p.HLAOut then p.HLAOut = false p:UnSpectate() end
	p:StripWeapons()
	p:SetNoDraw(true)
	p:SetNotSolid(true)
	p:GodEnable()
	p:Lock()
	sendOpen(p)
end

function M.Play(p, c)
	p.HLAInMenu = false
	p:SetNWBool('hla_in_menu', false)
	p.HLAModel = c.model
	p.HLACharID = c.id
	p.HLAClass = M.Class(c.model)
	p:SetNWInt('hla_charid', c.id)
	p:SetNWString('hla_name', M.DisplayName(c))
	if CFRework and CFRework.ReadBalance then p:SetNWInt('cf_resin', CFRework.ReadBalance('c' .. c.id)) end
	p:UnLock()
	p:SetNoDraw(false)
	p:SetNotSolid(false)
	p:GodDisable()
	p:Spawn()
	net.Start('hla_menu_closed') net.Send(p)
	hook.Run('HLAPlayerEnteredGame', p)
end

hook.Add('PlayerInitialSpawn', 'HLAMenu', function(p)
	p.HLAInMenu = true
	p:SetNWBool('hla_in_menu', true)
end)

net.Receive('hla_menu_do', function(_, p)
	local what = net.ReadString()
	if what == 'ready' then
		if p.HLAInMenu then M.Enter(p) end
	elseif what == 'reopen' then
		if (p.HLAMenuNext or 0) > CurTime() then return end
		p.HLAMenuNext = CurTime() + 2
		M.Enter(p)
	elseif what == 'create' then
		if not p.HLAInMenu then return end
		local num, model = string.Trim(net.ReadString()), net.ReadString()
		local list = M.LoadChars(p)
		if #list >= M.MaxChars or not M.ValidNum(num) or not M.ValidModel(model) then return end
		if not M.NumberFree(num) then
			net.Start('hla_menu_error') net.WriteString('НОМЕР ' .. num .. ' УЖЕ ЗАНЯТ') net.Send(p)
			return
		end
		local id = nextCharID()
		claimNumber(num, id)
		list[#list + 1] = {id = id, num = num, model = model, created = os.time()}
		M.SaveChars(p, list)
		if CFRework and CFRework.StoreBalance and HLA.StartResin then CFRework.StoreBalance('c' .. id, HLA.StartResin:GetInt()) end
		sendOpen(p)
	elseif what == 'delete' then
		if not p.HLAInMenu then return end
		local i = net.ReadUInt(8)
		local list = M.LoadChars(p)
		if list[i] then
			freeNumber(list[i].num, list[i].id)
			table.remove(list, i)
			M.SaveChars(p, list)
		end
		sendOpen(p)
	elseif what == 'play' then
		if not p.HLAInMenu then return end
		local idx = net.ReadUInt(8)
		local c = M.LoadChars(p)[idx]
		if c and M.ValidModel(c.model) then
			if HLA.Items and HLA.Items.Save and p.HLAInv then HLA.Items.Save(p) end
			M.Play(p, c)
			if HLA.Items and HLA.Items.Load then HLA.Items.Load(p) end
		end
	end
end)

for _, c in ipairs(M.Classes) do
	player_manager.AddValidModel('hla_' .. string.lower(c.label), c.model)
	player_manager.AddValidHands('hla_' .. string.lower(c.label), 'models/weapons/c_arms_combine.mdl', 0, '00000000')
end
function GM:PlayerSetHandsModel(p, hands)
	if p.HLAClass then
		hands:SetModel('models/weapons/c_arms_combine.mdl')
		hands:SetSkin(0)
		hands:SetBodyGroups('00000000')
		return
	end
	self.BaseClass.PlayerSetHandsModel(self, p, hands)
end

function GM:PlayerSetModel(p)
	if p.HLAModel and util.IsValidModel(p.HLAModel) then
		p:SetModel(p.HLAModel)
		p:SetupHands()
		return
	end
	self.BaseClass.PlayerSetModel(self, p)
end

concommand.Add('hla_menu_spot', function(p)
	if not IsValid(p) or not p:IsAdmin() then return end
	local pos, ang = p:EyePos(), p:EyeAngles()
	file.Write(spotPath(), util.TableToJSON({pos = {pos.x, pos.y, pos.z}, ang = {math.Clamp(ang.p, -30, 30), ang.y}}))
	p:ChatPrint('[HLA] Позиция главного меню сохранена для ' .. game.GetMap())
end)
concommand.Add('hla_menu_spot_clear', function(p)
	if not IsValid(p) or not p:IsAdmin() then return end
	file.Delete(spotPath())
	p:ChatPrint('[HLA] Позиция главного меню сброшена')
end)

hook.Add('PlayerSpawn', 'HLAMenuHidden', function(p)
	if p.HLAInMenu then
		timer.Simple(0, function()
			if IsValid(p) and p.HLAInMenu then p:StripWeapons() p:SetNoDraw(true) p:SetNotSolid(true) p:GodEnable() p:Lock() end
		end)
	end
end)
hook.Add('PlayerNoClip', 'HLAMenu', function(p) if p.HLAInMenu then return false end end)
hook.Add('CanPlayerSuicide', 'HLAMenu', function(p) if p.HLAInMenu then return false end end)
hook.Add('PlayerSpawnObject', 'HLAMenu', function(p) if p.HLAInMenu then return false end end)
hook.Add('PlayerCanPickupWeapon', 'HLAMenu', function(p) if p.HLAInMenu then return false end end)
hook.Add('PlayerUse', 'HLAMenu', function(p) if p.HLAInMenu then return false end end)
