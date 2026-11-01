AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')
util.AddNetworkString('hla_term')

local STARTUP = {'hla/terminal/combine_tech_startup_01.wav', 'hla/terminal/combine_tech_startup_02.wav', 'hla/terminal/combine_tech_startup_03.wav'}

-- turn the entity (around its up axis) so that its screen faces «dir»
local function faceScreen(e, dir)
	local _, _, _, normal = e:Screen()
	if not normal then return end
	local have = math.deg(math.atan2(normal.y, normal.x))
	local want = math.deg(math.atan2(dir.y, dir.x))
	local a = e:GetAngles()
	a:RotateAroundAxis(Vector(0, 0, 1), math.AngleDifference(want, have))
	e:SetAngles(a)
end

-- how far the model reaches behind its origin, against the screen direction (to sit on a wall)
local function backDepth(e, normal)
	local mn, mx = e:OBBMins(), e:OBBMaxs()
	local back = 0
	for _, x in ipairs({mn.x, mx.x}) do for _, y in ipairs({mn.y, mx.y}) do for _, z in ipairs({mn.z, mx.z}) do
		local d = e:LocalToWorld(Vector(x, y, z)) - e:GetPos()
		back = math.min(back, d:Dot(normal))
	end end end
	return -back
end

function ENT:SpawnFunction(p, tr, cls)
	if not tr.Hit then return end
	local e = ents.Create(cls)
	e:SetPos(tr.HitPos)
	e:SetAngles(Angle(0, (p:GetPos() - tr.HitPos):Angle().y, 0))
	e:Spawn()
	e:Activate()
	local wall = math.abs(tr.HitNormal.z) < 0.5
	if e.WallMount and wall then
		-- on the wall: the screen out of the wall, the back against it, the screen at eye height
		local n = Vector(tr.HitNormal.x, tr.HitNormal.y, 0):GetNormalized()
		faceScreen(e, n)
		e:SetPos(tr.HitPos + n * (backDepth(e, n) + 0.5))
	else
		-- on the floor: facing the player, standing on its lowest point
		local toPlayer = Vector(p:GetPos().x - tr.HitPos.x, p:GetPos().y - tr.HitPos.y, 0):GetNormalized()
		faceScreen(e, toPlayer)
		e:SetPos(tr.HitPos + Vector(0, 0, -e:OBBMins().z + (e.WallMount and 48 or 0)))
	end
	local ph = e:GetPhysicsObject()
	if IsValid(ph) then ph:EnableMotion(false) ph:Sleep() end
	return e
end

function ENT:Initialize()
	self:SetModel(self:PickModel())
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:EnableMotion(false) end
	if self.Powered then
		self:SetOpen(false)
		self:Play(self.Anim.closeIdle)
	else
		-- no power: the monitor stays out, its screen red
		self:SetOpen(true)
		self:Play(self.Anim.openIdle or self.Anim.closeIdle)
	end
end

function ENT:Play(name)
	if not name then return end
	local seq = self:LookupSequence(name)
	if seq and seq >= 0 then self:ResetSequence(seq) self:SetCycle(0) self:SetPlaybackRate(1) end
end

-- opens (screen out, start-up sound) when someone comes close, folds back when nobody is around
function ENT:Think()
	if not self.Powered then return end
	local near = false
	for _, p in ipairs(player.GetAll()) do
		if p:Alive() and p:GetPos():DistToSqr(self:GetPos()) < self.OpenRange * self.OpenRange then near = true break end
	end
	if near ~= self:GetOpen() then
		self:SetOpen(near)
		self:SetOpenedAt(CurTime())
		if near then
			if not self.Static then self:Play(self.Anim.open) end
			self:EmitSound(STARTUP[math.random(#STARTUP)], 60)
		elseif not self.Static then
			self:Play(self.Anim.close)
		end
	end
	-- hold the last pose once an animation is done
	if not self.Static and self:GetCycle() >= 1 then
		local idle = self:GetOpen() and self.Anim.openIdle or self.Anim.closeIdle
		if idle and self:GetSequenceName(self:GetSequence()) ~= idle then self:Play(idle) end
	end
	self:NextThink(CurTime())
	return true
end

local function focus(p, e)
	p.HLATerminal = e
	net.Start('hla_term') net.WriteEntity(e or NULL) net.Send(p)
	if IsValid(e) then hook.Run('HLATerminalFocus', p, e) end
end

function ENT:Use(p)
	if not self.Powered or not IsValid(p) or not p:IsPlayer() or p.HLAInMenu then return end
	if p.HLATerminal == self then focus(p, nil) else focus(p, self) end
end

net.Receive('hla_term', function(_, p) focus(p, nil) end) -- «ЗАКРЫТЬ ТЕРМИНАЛ» / Esc

hook.Add('PlayerTick', 'HLATerminal', function(p)
	local t = p.HLATerminal
	if t == nil then return end
	if not IsValid(t) or not p:Alive() or t:GetPos():DistToSqr(p:GetPos()) > 170 * 170 then focus(p, nil) end
end)

-- terminals placed by admins are remembered per map (all kinds)
local KINDS = {'hla_terminal', 'hla_terminal_medium', 'hla_terminal_small', 'hla_terminal_console', 'hla_terminal_cams'}
local function path() return 'hlalyx/terminals_' .. game.GetMap() .. '.txt' end
local function load()
	for _, s in ipairs(util.JSONToTable(file.Read(path(), 'DATA') or '') or {}) do
		local e = ents.Create(s[7] or 'hla_terminal')
		if IsValid(e) then
			e:SetPos(Vector(s[1], s[2], s[3])) e:SetAngles(Angle(s[4], s[5], s[6])) e:Spawn() e:Activate()
			local ph = e:GetPhysicsObject()
			if IsValid(ph) then ph:EnableMotion(false) end
		end
	end
end
hook.Add('InitPostEntity', 'HLATerminals', load)
hook.Add('PostCleanupMap', 'HLATerminals', load)
concommand.Add('hla_save_terminals', function(p)
	if IsValid(p) and not p:IsAdmin() then return end
	local list = {}
	for _, cls in ipairs(KINDS) do
		for _, e in ipairs(ents.FindByClass(cls)) do
			local pos, a = e:GetPos(), e:GetAngles()
			list[#list + 1] = {pos.x, pos.y, pos.z, a.p, a.y, a.r, cls}
		end
	end
	file.CreateDir('hlalyx')
	file.Write(path(), util.TableToJSON(list))
	local msg = 'Сохранено терминалов: ' .. #list
	if IsValid(p) then p:ChatPrint(msg) else print(msg) end
end)
