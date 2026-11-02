local CAM = {}
HLA.Cameras = CAM
local CLASSES = {npc_combine_camera = true}
local DIGIT = {[0] = 'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'}
local cvCooldown = CreateConVar('hla_camera_alert_cooldown', '45', {FCVAR_ARCHIVE}, 'Seconds between dispatcher alerts from one camera')

local used = {}
local function assign(e)
	if e:GetNWString('hla_cam_id', '') ~= '' then return end
	local seed = e:MapCreationID()
	if not seed or seed < 0 then seed = e:EntIndex() + 7919 end
	local p = e:GetPos()
	local n = (seed * 7919 + math.floor(math.abs(p.x) + math.abs(p.y) * 3 + math.abs(p.z) * 7)) % 900 + 100
	while used[n] do n = n % 999 + 1 if n < 100 then n = 100 end end
	used[n] = true
	e:SetNWString('hla_cam_id', 'КАМ-' .. n)
	e.HLACamNum = n
	if e.AddRelationship then e:AddRelationship('player D_LI 99') end
end

function CAM.ID(e) return IsValid(e) and e:GetNWString('hla_cam_id', '') or '' end

hook.Add('OnEntityCreated', 'HLACameras', function(e)
	timer.Simple(0, function()
		if IsValid(e) and CLASSES[e:GetClass()] then assign(e) end
	end)
end)
hook.Add('InitPostEntity', 'HLACameras', function()
	for cls in pairs(CLASSES) do for _, e in ipairs(ents.FindByClass(cls)) do assign(e) end end
end)
hook.Add('PostCleanupMap', 'HLACameras', function()
	used = {}
	for cls in pairs(CLASSES) do for _, e in ipairs(ents.FindByClass(cls)) do e:SetNWString('hla_cam_id', '') assign(e) end end
end)

local NECRO = {npc_zombie = true, npc_fastzombie = true, npc_poisonzombie = true, npc_zombine = true, npc_zombie_torso = true,
	npc_fastzombie_torso = true, npc_headcrab = true, npc_headcrab_fast = true, npc_headcrab_black = true, npc_headcrab_poison = true,
	npc_barnacle = true}
local function necrotic(t)
	local c = t:GetClass()
	return NECRO[c] or string.find(c, 'zomb', 1, true) or string.find(c, 'headcrab', 1, true) or string.find(c, 'necro', 1, true)
end

local FRIEND = {'combine', 'metropolice', 'cscanner', 'manhack', 'hla_npc', 'rollermine', 'turret', 'strider', 'hunter', 'helicopter', 'gunship', 'dropship', 'apc'}
local IGNORE = {'crow', 'pigeon', 'seagull', 'bird', 'citizen', 'vortigaunt'}
local IGNORE_CLASS = {npc_alyx = true, npc_barney = true, npc_kleiner = true, npc_eli = true, npc_mossman = true, npc_breen = true,
	npc_monk = true, npc_dog = true, npc_gman = true, npc_fisherman = true, npc_magnusson = true}
local function hostile(t)
	if not IsValid(t) or t:IsPlayer() then return false end
	if not (t:IsNPC() or t:IsNextBot()) then return false end
	if t:Health() <= 0 then return false end
	local c = t:GetClass()
	if CLASSES[c] then return false end
	if necrotic(t) then return true end
	for _, f in ipairs(FRIEND) do if string.find(c, f, 1, true) then return false end end
	if IGNORE_CLASS[c] then return false end
	for _, f in ipairs(IGNORE) do if string.find(c, f, 1, true) then return false end end
	if t:IsNPC() and t.Disposition then
		local p = player.GetAll()[1]
		if IsValid(p) and t:Disposition(p) ~= D_HT then return false end
	end
	return true
end

local function eye(cam)
	for _, name in ipairs({'eyes', 'light', 'lens'}) do
		local id = cam:LookupAttachment(name)
		if id and id > 0 then
			local a = cam:GetAttachment(id)
			if a then return a.Pos, a.Ang:Forward() end
		end
	end
	return cam:WorldSpaceCenter(), cam:GetForward()
end

local RANGE, CONE = 1600, math.cos(math.rad(55))
local function spot(cam)
	local en = cam.GetEnemy and cam:GetEnemy()
	if hostile(en) then return en end
	local pos, fwd = eye(cam)
	local best, bestD
	for _, t in ipairs(CAM.targets or {}) do
		if IsValid(t) then
			local c = t:WorldSpaceCenter()
			local dir = c - pos
			local d = dir:Length()
			if d > 1 and d <= RANGE and dir:GetNormalized():Dot(fwd) >= CONE and (not bestD or d < bestD) then
				local tr = util.TraceLine({start = pos, endpos = c, filter = {cam}, mask = MASK_SHOT})
				if tr.Entity == t or tr.Fraction > 0.97 then best, bestD = t, d end
			end
		end
	end
	return best
end

util.AddNetworkString('hla_cam_flash')
local function flash(cam)
	local pos = eye(cam)
	cam:EmitSound('npc/scanner/scanner_photo1.wav', 75, 100)
	net.Start('hla_cam_flash')
	net.WriteVector(pos)
	net.Broadcast()
end

local function alert(cam, target)
	local id = CAM.ID(cam)
	if id == '' then assign(cam) id = CAM.ID(cam) end
	local num = tostring(cam.HLACamNum or '')
	local necro = necrotic(target)
	local chain = {HLA.RadioVoicePath('on3'), HLA.RadioVoicePath('attention'), HLA.RadioVoicePath(necro and 'infection' or 'restrictedincursioninprogress'), HLA.RadioVoicePath('sector')}
	for d in string.gmatch(num, '%d') do chain[#chain + 1] = HLA.RadioVoicePath(DIGIT[tonumber(d)]) end
	chain[#chain + 1] = HLA.RadioVoicePath('off2')
	local zone = HLA.Story and HLA.Story.ZoneAt and HLA.Story.ZoneAt(cam:GetPos())
	local text = 'Внимание: зафиксирован ' .. (necro and 'некротик' or 'нарушитель') .. ' на камере «' .. id .. '»' .. (zone and (', зона «' .. zone .. '»') or '') .. '.'
	if HLA.Chat and HLA.Chat.Dispatch then HLA.Chat.Dispatch(text, table.concat(chain, ';'), 'ДИСПЕТЧЕР') end
	flash(cam)
	hook.Run('HLACameraSpotted', cam, target, id)
end

local lastGlobal = 0
timer.Create('HLACameraWatch', 0.5, 0, function()
	local targets = {}
	for _, t in ipairs(ents.FindByClass('npc_*')) do if hostile(t) then targets[#targets + 1] = t end end
	for _, t in ipairs(ents.GetAll()) do if t:IsNextBot() and hostile(t) then targets[#targets + 1] = t end end
	CAM.targets = targets
	for cls in pairs(CLASSES) do
		for _, cam in ipairs(ents.FindByClass(cls)) do
			local en = (cam:Health() > 0 and not cam:IsEffectActive(EF_NODRAW)) and spot(cam) or nil
			if en then
				if cam.HLASeen ~= en and CurTime() >= (cam.HLANextAlert or 0) and CurTime() >= lastGlobal then
					cam.HLASeen = en
					cam.HLANextAlert = CurTime() + cvCooldown:GetFloat()
					lastGlobal = CurTime() + 6
					alert(cam, en)
				end
			elseif not IsValid(cam.HLASeen) or (cam.HLASeenLost or 0) < CurTime() - 10 then
				cam.HLASeen = nil
			end
			if en then cam.HLASeenLost = CurTime() end
		end
	end
end)
