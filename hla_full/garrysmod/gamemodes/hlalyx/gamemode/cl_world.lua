local I = HLA.Items

function GM:HUDDrawTargetID() end
hook.Add('HUDShouldDraw', 'HLANoHints', function(name)
	if name == 'CHudHintDisplay' then return false end
end)

surface.CreateFont('hla_tag_name', {font = 'Roboto Condensed', size = 44, weight = 700, italic = true, extended = true, antialias = true})
surface.CreateFont('hla_tag_line', {font = 'Roboto Condensed', size = 32, weight = 700, italic = true, extended = true, antialias = true})
surface.CreateFont('hla_name3d', {font = 'Roboto Condensed', size = 52, weight = 700, italic = true, extended = true, antialias = true})
local AMBER = HLA.Hud.AMBER_C
local lookAt, lookAlpha = nil, 0
local logo = Material('hla/ui/combine_logo', 'smooth')
local TAG_WHITE = Color(232, 240, 246)
local TAG_GREY = Color(170, 196, 214)
local TAG_GREEN = Color(110, 236, 150)
local TAG_RED = Color(255, 84, 72)

local function tagLines(e, text)
	local cls = HLA.Menu and HLA.Menu.ModelLabel and HLA.Menu.ModelLabel(e:GetModel()) or ''
	local sq = HLA.Squads and HLA.Squads.Of and HLA.Squads.Of(e)
	local second = string.upper((cls ~= '' and cls ~= '?') and cls or 'ЮНИТ ГО') .. (sq and ('  ::  ' .. string.upper(sq.name)) or '')
	local hp = e:Health()
	local third = hp > 30 and 'СТАТУС: В НОРМЕ' or 'СТАТУС: КРИТИЧЕСКИЙ'
	return {{text, 'hla_tag_name', TAG_WHITE}, {second, 'hla_tag_line', TAG_GREY}, {third, 'hla_tag_line', hp > 30 and TAG_GREEN or TAG_RED}}
end

function HLA.NameTag(pos, text, col, a, scale, ent)
	local hasLogo = not logo:IsError()
	if IsValid(ent) then
		local right = EyeAngles():Right()
		cam.Start3D2D(pos + right * 10, Angle(0, EyeAngles().y - 90, 90), scale or 0.05)
			local lines = tagLines(ent, text)
			local icon = 72
			local x = hasLogo and (icon + 16) or 0
			local h = 44 + 34 + 34
			local y = -h / 2
			if hasLogo then
				surface.SetMaterial(logo)
				surface.SetDrawColor(TAG_WHITE.r, TAG_WHITE.g, TAG_WHITE.b, 245 * a)
				surface.DrawTexturedRect(0, -icon / 2, icon, icon)
			end
			for i, l in ipairs(lines) do
				draw.SimpleTextOutlined(l[1], l[2], x, y, Color(l[3].r, l[3].g, l[3].b, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2, Color(0, 6, 12, 150 * a))
				y = y + (i == 1 and 44 or 34)
			end
		cam.End3D2D()
		return
	end
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

function HLA.TagPos(e)
	local base = (HLA.ChatBox and HLA.ChatBox.HeadPos) and HLA.ChatBox.HeadPos(e) or e:EyePos() + Vector(0, 0, 11)
	return base - Vector(0, 0, 4)
end

hook.Add('PostDrawTranslucentRenderables', 'HLANames', function(depth, sky)
	if sky or not IsValid(lookAt) or lookAlpha <= 0 then return end
	local SQ = HLA.Squads
	if SQ and SQ.Of(LocalPlayer()) and SQ.Of(LocalPlayer()) == SQ.Of(lookAt) then return end
	HLA.NameTag(HLA.TagPos(lookAt), string.upper(lookAt:GetNWString('hla_name')), AMBER, lookAlpha, 0.045, lookAt)
end)

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
