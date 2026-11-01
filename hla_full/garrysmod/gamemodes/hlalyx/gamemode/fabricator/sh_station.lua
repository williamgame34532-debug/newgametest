-- Shared station helpers for the Half-Life: Alyx fabricator model (models/cf_rework/hla_station.mdl).
-- Everything that moves is the model's own skeleton and sequences; the code only reads attachments:
--   main_panel_fill  display surface (21.42 x 12.05), x right, y up, z toward the viewer
--   resin_attach_00..09  resin troughs of the tray carousel
--   item_attach      where the printed item rests inside the rib bay
CFRework = CFRework or {}
local C = CFRework

C.PANEL_W, C.PANEL_H = 21.42, 12.05

local function att(ent, name)
	local id = ent:LookupAttachment(name)
	if not id or id <= 0 then return end
	local a = ent:GetAttachment(id)
	if a then return a.Pos, a.Ang end
end
C.Attachment = att

-- the station is folded out and the screen can be used
-- (an old separately installed combine_fabricator addon calls this with its own entity, which has no
-- GetDeployed: such a station is simply never ready instead of an error)
function C.Ready(ent) return IsValid(ent) and ent.GetDeployed ~= nil and ent:GetDeployed() end

-- world-space display frame: top-left origin, right, down, normal, 3D2D angle and scale.
-- The 1024 x 512 canvas fills the panel width and is centred on its height.
function C.ScreenWorld(ent)
	local pos, ang = att(ent, 'main_panel_fill')
	if not pos then return end
	local right, up, normal = ang:Forward(), -ang:Right(), ang:Up()
	local scale = C.PANEL_W / C.Layout.W
	local margin = (C.PANEL_H - C.Layout.H * scale) * 0.5
	local origin = pos + up * (C.PANEL_H - margin)
	return origin, right, -up, normal, ang, scale, pos
end

-- canvas pixel under the player's crosshair, or nil
function C.HitScreen(ent, ply)
	if not IsValid(ply) or not C.Ready(ent) then return end
	local origin, right, down, normal, _, scale = C.ScreenWorld(ent)
	if not origin then return end
	local eye, dir = ply:EyePos(), ply:GetAimVector()
	if eye:DistToSqr(origin) > C.UseRange * C.UseRange then return end
	if dir:Dot(normal) >= -0.05 or (eye - origin):Dot(normal) <= 0 then return end
	local hit = util.IntersectRayWithPlane(eye, dir, origin, normal)
	if not hit then return end
	local rel = hit - origin
	local x, y = rel:Dot(right) / scale, rel:Dot(down) / scale
	if x < 0 or y < 0 or x > C.Layout.W or y > C.Layout.H then return end
	return x, y, hit
end

local function raySphere(eye, dir, center, radius)
	local oc = center - eye
	local t = oc:Dot(dir)
	if t < 0 then return end
	if oc:LengthSqr() - t * t > radius * radius then return end
	return t
end

-- centre of the resin tray (average of the ten trough attachments)
function C.CellsCenter(ent)
	local sum, n = Vector(0, 0, 0), 0
	for i = 0, 9 do
		local p = att(ent, string.format('resin_attach_%02d', i))
		if p then sum = sum + p n = n + 1 end
	end
	if n > 0 then return sum / n end
end

function C.ItemPoint(ent)
	local p, a = att(ent, 'item_attach')
	return p or ent:WorldSpaceCenter(), a or ent:GetAngles()
end

-- resin can be loaded only while an order waits for it and the tray is fully presented
function C.CellsOpen(ent)
	return ent:GetStage() == C.State.DEPOSIT and ent:GetTrayReady()
end

-- which physical part the player aims at: 'cells' (resin tray) or 'chamber' (rib bay)
function C.HitPart(ent, ply)
	if not IsValid(ply) then return end
	local eye, dir = ply:EyePos(), ply:GetAimVector()
	local best, bestT
	local function try(name, center, radius)
		if not center then return end
		local t = raySphere(eye, dir, center, radius)
		if t and t < C.UseRange and (not bestT or t < bestT) then best, bestT = name, t end
	end
	if C.CellsOpen(ent) then try('cells', C.CellsCenter(ent), 9) end
	if ent:GetStage() == C.State.DONE and ent:GetBayOpen() then try('chamber', (C.ItemPoint(ent)), 10) end
	return best
end
