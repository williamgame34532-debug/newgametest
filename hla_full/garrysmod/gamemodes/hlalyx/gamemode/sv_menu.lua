-- Main menu (server): characters per player, the menu spot per map, entering the game.
local M = HLA.Menu

util.AddNetworkString('hla_menu_open')
util.AddNetworkString('hla_menu_do')
util.AddNetworkString('hla_menu_closed')

file.CreateDir('hla')
file.CreateDir('hla/chars')
file.CreateDir('hla/menuspot')

local function charsPath(p) return 'hla/chars/' .. p:SteamID64() .. '.json' end

function M.LoadChars(p)
	local t = util.JSONToTable(file.Read(charsPath(p), 'DATA') or '') or {}
	local out = {}
	for _, c in ipairs(t) do
		if istable(c) and M.ValidName(c.first) and M.ValidName(c.last) and isstring(c.model) then out[#out + 1] = c end
	end
	return out
end

function M.SaveChars(p, list)
	file.Write(charsPath(p), util.TableToJSON(list))
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

-- park the player while the menu is up: invisible, locked, no damage, no weapons
function M.Enter(p)
	p.HLAInMenu = true
	p:SetNWBool('hla_in_menu', true)
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
	p:SetNWString('hla_name', c.first .. ' ' .. c.last)
	p:UnLock()
	p:SetNoDraw(false)
	p:SetNotSolid(false)
	p:GodDisable()
	p:Spawn()
	net.Start('hla_menu_closed') net.Send(p)
end

hook.Add('PlayerInitialSpawn', 'HLAMenu', function(p)
	p.HLAInMenu = true
	p:SetNWBool('hla_in_menu', true)
end)

-- the client asks for the menu once it is ready to draw (and with the hla_menu command)
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
		local first, last, model = string.Trim(net.ReadString()), string.Trim(net.ReadString()), net.ReadString()
		local list = M.LoadChars(p)
		if #list >= M.MaxChars or not M.ValidName(first) or not M.ValidName(last) or not M.ValidModel(model) then return end
		list[#list + 1] = {first = first, last = last, model = model, created = os.time()}
		M.SaveChars(p, list)
		sendOpen(p)
	elseif what == 'delete' then
		if not p.HLAInMenu then return end
		local i = net.ReadUInt(8)
		local list = M.LoadChars(p)
		if list[i] then table.remove(list, i) M.SaveChars(p, list) end
		sendOpen(p)
	elseif what == 'play' then
		if not p.HLAInMenu then return end
		local idx = net.ReadUInt(8)
		local c = M.LoadChars(p)[idx]
		if c and M.ValidModel(c.model) then
			p.HLACharIndex = idx
			M.Play(p, c)
			if HLA.Items and HLA.Items.Load then HLA.Items.Load(p) end -- this character's inventory
		end
	end
end)

-- the character's model
function GM:PlayerSetModel(p)
	if p.HLAModel and util.IsValidModel(p.HLAModel) then
		p:SetModel(p.HLAModel)
		p:SetupHands()
		return
	end
	self.BaseClass.PlayerSetModel(self, p)
end

-- admin: the menu is drawn where you stand, looking where you look
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
