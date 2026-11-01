-- World-facing client bits: no hover hints, names over players, the hold-E pickup ring.
local I = HLA.Items

-- nothing pops up when looking at things (sandbox target id and its hints)
function GM:HUDDrawTargetID() end
hook.Add('HUDShouldDraw', 'HLANoHints', function(name)
	if name == 'CHudHintDisplay' then return false end
end)

---------------------------------------------------------------------------------------------------
-- unit name over the player you look at
surface.CreateFont('hla_name3d', {font = 'Roboto Condensed', size = 46, weight = 700, extended = true, antialias = true})
local AMBER = HLA.Hud.AMBER_C -- blue HUD colour
local lookAt, lookAlpha = nil, 0

hook.Add('Think', 'HLANameTarget', function()
	local p = LocalPlayer()
	if not IsValid(p) then return end
	local tr = util.TraceLine({start = p:EyePos(), endpos = p:EyePos() + p:GetAimVector() * 350, filter = p, mask = MASK_SHOT})
	local e = tr.Entity
	if IsValid(e) and e:IsPlayer() and e:Alive() and e:GetNWString('hla_name', '') ~= '' then
		lookAt = e
		lookAlpha = math.min(1, lookAlpha + FrameTime() * 6)
	else
		lookAlpha = math.max(0, lookAlpha - FrameTime() * 4)
		if lookAlpha <= 0 then lookAt = nil end
	end
end)

hook.Add('PostDrawTranslucentRenderables', 'HLANames', function(depth, sky)
	if sky or not IsValid(lookAt) or lookAlpha <= 0 then return end
	local bone = lookAt:LookupBone('ValveBiped.Bip01_Head1')
	local pos = bone and lookAt:GetBonePosition(bone) or lookAt:EyePos()
	pos = pos + Vector(0, 0, 13)
	cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), 0.06)
		draw.SimpleTextOutlined(string.upper(lookAt:GetNWString('hla_name')), 'hla_name3d', 0, 0,
			Color(AMBER.r, AMBER.g, AMBER.b, 255 * lookAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 160 * lookAlpha))
	cam.End3D2D()
end)

---------------------------------------------------------------------------------------------------
-- pickup ring at the crosshair while E is held on an item
hook.Add('HUDPaint', 'HLAPickupRing', function()
	local p = LocalPlayer()
	if not IsValid(p) then return end
	local e = p:GetNW2Entity('hla_pick')
	if not IsValid(e) then return end
	local f = math.Clamp((CurTime() - p:GetNW2Float('hla_pick_t')) / I.PickupTime, 0, 1)
	local cx, cy = ScrW() / 2, ScrH() / 2
	local r = math.floor(math.min(ScrW(), ScrH()) * 0.022)
	draw.NoTexture()
	local seg = 40
	for i = 0, seg - 1 do
		local a0, a1 = i / seg, (i + 1) / seg
		local lit = a1 <= f
		surface.SetDrawColor(AMBER.r, AMBER.g, AMBER.b, lit and 240 or 50)
		local t0, t1 = -math.pi / 2 + a0 * 2 * math.pi, -math.pi / 2 + a1 * 2 * math.pi
		surface.DrawPoly({
			{x = cx + math.cos(t0) * r, y = cy + math.sin(t0) * r},
			{x = cx + math.cos(t1) * r, y = cy + math.sin(t1) * r},
			{x = cx + math.cos(t1) * (r - 4), y = cy + math.sin(t1) * (r - 4)},
			{x = cx + math.cos(t0) * (r - 4), y = cy + math.sin(t0) * (r - 4)},
		})
	end
	local d = I.Get(e:GetItemID())
	if d then draw.SimpleText(string.upper(d.name), 'hla_label', cx, cy + r + 18, AMBER, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP) end
end)
