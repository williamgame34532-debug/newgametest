AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')
util.AddNetworkString('hla_cams')       -- server -> the unit at the screen: the cameras of the map
util.AddNetworkString('hla_cam_pick')   -- client -> server: show this camera (0 — off)

local function cameras(self)
	local out = {}
	for _, e in ipairs(ents.GetAll()) do
		if self.CameraClasses[e:GetClass()] then out[#out + 1] = e end
	end
	table.sort(out, function(a, b) return a:EntIndex() < b:EntIndex() end)
	return out
end

-- the eye of a camera: its «eyes» / «light» attachment, or its centre looking where it faces
local function eye(cam)
	for _, name in ipairs({'eyes', 'light', 'lens'}) do
		local id = cam:LookupAttachment(name)
		if id and id > 0 then
			local a = cam:GetAttachment(id)
			if a then return a.Pos + a.Ang:Forward() * 4, a.Ang end
		end
	end
	return cam:WorldSpaceCenter() + cam:GetForward() * 10, cam:GetAngles()
end

function ENT:Initialize()
	self.BaseClass.Initialize(self)
	-- the monitor stands on the terminal, its screen the same way as the terminal's
	if util.IsValidModel(self.MonitorModel) then
		local m = ents.Create('prop_dynamic')
		m:SetModel(self.MonitorModel)
		m:SetPos(self:GetPos())
		m:SetAngles(self:GetAngles())
		m:Spawn()
		local _, _, _, normal = self:Screen()
		local yaw = normal and normal:Angle().y or self:GetAngles().y
		m:SetAngles(Angle(0, yaw, 0))
		local top = self:GetPos().z + self:OBBMaxs().z
		m:SetPos(Vector(self:GetPos().x, self:GetPos().y, top + 4 - m:OBBMins().z) - (normal or self:GetForward()) * 4)
		m:SetParent(self)
		m:SetSolid(SOLID_VPHYSICS)
		self:DeleteOnRemove(m)
		self:SetMonitor(m)
	end
end

function ENT:Think()
	local r = self.BaseClass.Think(self)
	local cam = Entity(self:GetCamIndex())
	if self:GetCamIndex() > 0 and IsValid(cam) then
		local pos, ang = eye(cam)
		self:SetCamPos(pos)
		self:SetCamAng(ang)
	elseif self:GetCamIndex() > 0 then
		self:SetCamIndex(0) -- the camera is gone
	end
	self:NextThink(CurTime() + 0.05)
	return true
end

-- the list goes to the unit that steps up to the screen
hook.Add('HLATerminalFocus', 'HLACamTerminal', function(p, e)
	if not e.IsCamTerminal then return end
	local list = cameras(e)
	net.Start('hla_cams')
	net.WriteEntity(e)
	net.WriteUInt(#list, 8)
	for _, c in ipairs(list) do
		net.WriteUInt(c:EntIndex(), 16)
		net.WriteVector(c:GetPos())
		local zone = HLA.Story and HLA.Story.ZoneAt and HLA.Story.ZoneAt(c:GetPos()) or ''
		net.WriteString(zone or '')
	end
	net.Send(p)
end)

net.Receive('hla_cam_pick', function(_, p)
	local t = net.ReadEntity()
	local idx = net.ReadUInt(16)
	if not IsValid(t) or not t.IsCamTerminal or p.HLATerminal ~= t then return end
	if idx == 0 then t:SetCamIndex(0) return end
	local cam = Entity(idx)
	if not IsValid(cam) or not t.CameraClasses[cam:GetClass()] then return end
	t:SetCamIndex(idx)
	local pos, ang = eye(cam)
	t:SetCamPos(pos) t:SetCamAng(ang)
	t:EmitSound('hla/terminal/combine_tech_click_0' .. math.random(1, 5) .. '.wav', 55)
end)

-- what the camera sees is sent to the players near a terminal showing it (also when it is far away)
hook.Add('SetupPlayerVisibility', 'HLACamTerminal', function(p)
	for _, t in ipairs(ents.FindByClass('hla_terminal_cams')) do
		if t:GetCamIndex() > 0 and t:GetPos():DistToSqr(p:GetPos()) < 1200 * 1200 then AddOriginToPVS(t:GetCamPos()) end
	end
end)
