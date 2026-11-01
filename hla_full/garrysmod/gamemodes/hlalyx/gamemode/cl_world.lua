-- World-facing client bits: no hover hints, names over players, the hold-E pickup ring.
local I = HLA.Items

-- nothing pops up when looking at things (sandbox target id and its hints)
function GM:HUDDrawTargetID() end
hook.Add('HUDShouldDraw', 'HLANoHints', function(name)
	if name == 'CHudHintDisplay' then return false end
end)

---------------------------------------------------------------------------------------------------
-- unit name over the player you look at: well above the helmet, Exo 2 (hla_chat_content, OFL), the Combine
-- symbol on its left in the same colour (hla/ui/combine_logo, from HL:A — shown once it is installed)
surface.CreateFont('hla_name3d', {font = 'Exo 2', size = 52, weight = 700, extended = true, antialias = true})
local AMBER = HLA.Hud.AMBER_C -- blue HUD colour
local lookAt, lookAlpha = nil, 0
local logo = Material('hla/ui/combine_logo', 'smooth')

-- a name tag in the world: pos is the point over the head, col its colour, a 0..1
function HLA.NameTag(pos, text, col, a, scale)
	local hasLogo = not logo:IsError()
	cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), scale or 0.055)
		surface.SetFont('hla_name3d')
		local tw, th = surface.GetTextSize(text)
		local icon = hasLogo and th * 0.95 or 0
		local gap = hasLogo and 12 or 0
		local x0 = -(tw + icon + gap) / 2
		if hasLogo then
			surface.SetMaterial(logo)
			surface.SetDrawColor(col.r, col.g, col.b, 255 * a)
			surface.DrawTexturedRect(x0, -icon / 2, icon, icon)
		end
		draw.SimpleTextOutlined(text, 'hla_name3d', x0 + icon + gap, 0, Color(col.r, col.g, col.b, 255 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 2, Color(0, 6, 12, 170 * a))
	cam.End3D2D()
end

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

-- the point for name tags: over the helmet (the eyes + a head and a little more)
function HLA.TagPos(e)
	local base = (HLA.ChatBox and HLA.ChatBox.HeadPos) and HLA.ChatBox.HeadPos(e) or e:EyePos() + Vector(0, 0, 11)
	return base + Vector(0, 0, 12)
end

hook.Add('PostDrawTranslucentRenderables', 'HLANames', function(depth, sky)
	if sky or not IsValid(lookAt) or lookAlpha <= 0 then return end
	-- squad mates have their own tag (cl_squads.lua)
	local SQ = HLA.Squads
	if SQ and SQ.Of(LocalPlayer()) and SQ.Of(LocalPlayer()) == SQ.Of(lookAt) then return end
	HLA.NameTag(HLA.TagPos(lookAt), string.upper(lookAt:GetNWString('hla_name')), AMBER, lookAlpha)
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
