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

local function hostile(t)
	if not IsValid(t) then return false end
	if t:IsPlayer() then return false end
	return t:IsNPC() or t:IsNextBot()
end

local function alert(cam, target)
	local id = CAM.ID(cam)
	if id == '' then assign(cam) id = CAM.ID(cam) end
	local num = tostring(cam.HLACamNum or '')
	local chain = {HLA.RadioVoicePath('attention'), HLA.RadioVoicePath('infection'), HLA.RadioVoicePath('sector')}
	for d in string.gmatch(num, '%d') do chain[#chain + 1] = HLA.RadioVoicePath(DIGIT[tonumber(d)]) end
	local zone = HLA.Story and HLA.Story.ZoneAt and HLA.Story.ZoneAt(cam:GetPos())
	local text = 'Внимание: зафиксирован некротик на камере «' .. id .. '»' .. (zone and (', зона «' .. zone .. '»') or '') .. '.'
	if HLA.Chat and HLA.Chat.Dispatch then HLA.Chat.Dispatch(text, table.concat(chain, ';'), 'ДИСПЕТЧЕР') end
	hook.Run('HLACameraSpotted', cam, target, id)
end

local lastGlobal = 0
timer.Create('HLACameraWatch', 0.5, 0, function()
	for cls in pairs(CLASSES) do
		for _, cam in ipairs(ents.FindByClass(cls)) do
			local en = cam.GetEnemy and cam:GetEnemy()
			if hostile(en) then
				if cam.HLASeen ~= en then
					cam.HLASeen = en
					if CurTime() >= (cam.HLANextAlert or 0) and CurTime() >= lastGlobal then
						cam.HLANextAlert = CurTime() + cvCooldown:GetFloat()
						lastGlobal = CurTime() + 6
						alert(cam, en)
					end
				end
			else
				cam.HLASeen = nil
			end
		end
	end
end)
