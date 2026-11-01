-- Esc: the pause menu of the unit (instead of the GMod menu), in the look of the visor: the Combine symbol, the
-- unit, the squad and the zone on the left, the lines on the right: ПРОДОЛЖИТЬ, НАСТРОЙКИ (TAB), РЕДАКТОР (admins),
-- ПЕРСОНАЖИ (the main menu), МЕНЮ GMOD (the usual game menu: options, servers), ОТКЛЮЧИТЬСЯ (asks again).
-- Esc again closes it. The chat, the terminal, the main menu and the TAB menu still take Esc first.
local P = {}
HLA.Pause = P

local CYAN = Color(110, 200, 255)
local CYAN_HI = Color(170, 230, 255)
local WHITE = Color(226, 236, 244)
local GREY = Color(122, 150, 170)
local RED = Color(255, 90, 76)
local logo = Material('hla/ui/combine_logo', 'smooth')

local function sc() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local s = sc()
	surface.CreateFont('hla_ps_btn', {font = 'Exo 2', size = math.max(18, math.floor(34 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_ps_head', {font = 'Exo 2', size = math.max(14, math.floor(20 * s)), weight = 600, extended = true})
	surface.CreateFont('hla_ps_name', {font = 'Exo 2', size = math.max(22, math.floor(46 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_ps_small', {font = 'Exo 2', size = math.max(12, math.floor(17 * s)), weight = 600, extended = true})
end

local function click(kind)
	local s = kind == 'hover' and ('hla/ui/textline_' .. math.random(5, 6) .. '.wav') or 'hla/ui/textline_end.wav'
	surface.PlaySound(s)
end

function P.Close()
	if IsValid(P.frame) then P.frame:Remove() end
	P.frame = nil
end

function P.Open()
	if IsValid(P.frame) then return end
	fonts()
	local p = LocalPlayer()
	local f = vgui.Create('EditablePanel')
	P.frame = f
	f:SetSize(ScrW(), ScrH())
	f:MakePopup()
	f.born = RealTime()
	f.confirm = false
	local s = sc()
	local rows = {
		{'ПРОДОЛЖИТЬ', function() P.Close() end},
		{'НАСТРОЙКИ', function()
			P.Close()
			if HLA.Tab and HLA.Tab.Open then HLA.Tab.Open() HLA.Tab.page = 'settings' end
		end},
	}
	if HLA.CanEdit and HLA.CanEdit(p) then rows[#rows + 1] = {'РЕДАКТОР СЮЖЕТА', function() P.Close() RunConsoleCommand('hla_editor') end} end
	rows[#rows + 1] = {'ПЕРСОНАЖИ', function() P.Close() RunConsoleCommand('hla_menu') end}
	rows[#rows + 1] = {'МЕНЮ GMOD', function()
		P.Close() P.bypass = true gui.ActivateGameUI()
		timer.Simple(0.5, function() P.bypass = false end)
	end}
	rows[#rows + 1] = {'ОТКЛЮЧИТЬСЯ', function()
		if f.confirm then RunConsoleCommand('disconnect') else f.confirm = true end
	end, true}
	local bx, by = math.floor(ScrW() * 0.56), math.floor(ScrH() * 0.30)
	local bw, bh = math.floor(560 * s), math.floor(62 * s)
	for i, r in ipairs(rows) do
		local b = vgui.Create('DButton', f)
		b:SetText('')
		b:SetPos(bx, by + (i - 1) * (bh + math.floor(10 * s)))
		b:SetSize(bw, bh)
		b.Paint = function(self, w, h)
			local hot = self:IsHovered()
			if hot and not self.wasHot then click('hover') end
			self.wasHot = hot
			local k = math.Clamp((RealTime() - f.born) * 5 - i * 0.25, 0, 1)
			local danger = r[3]
			local c = danger and RED or CYAN
			if hot then
				surface.SetDrawColor(c.r, c.g, c.b, 210 * k)
				surface.DrawRect(0, 0, w, h)
			else
				surface.SetDrawColor(6, 16, 24, 170 * k)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(c.r, c.g, c.b, 220 * k)
				surface.DrawRect(0, 0, math.max(2, math.floor(4 * s)), h)
			end
			local label = r[1]
			if danger and f.confirm then label = 'ТОЧНО ОТКЛЮЧИТЬСЯ?' end
			draw.SimpleText(label, 'hla_ps_btn', math.floor(28 * s), h / 2, hot and Color(8, 20, 30, 255 * k) or Color(WHITE.r, WHITE.g, WHITE.b, 255 * k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function() click('press') r[2]() end
	end
	f.OnKeyCodePressed = function(self, code) if code == KEY_ESCAPE then P.Close() end end
	f.Paint = function(self, w, h)
		local k = math.Clamp((RealTime() - self.born) * 4, 0, 1)
		Derma_DrawBackgroundBlur(self, self.born - 0.5)
		surface.SetDrawColor(2, 8, 14, 170 * k)
		surface.DrawRect(0, 0, w, h)
		-- left: the symbol, the unit, the squad, the zone, the round
		local x, y = math.floor(ScrW() * 0.12), math.floor(ScrH() * 0.30)
		if not logo:IsError() then
			local ls = math.floor(110 * s)
			surface.SetMaterial(logo)
			surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 230 * k)
			surface.DrawTexturedRect(x, y - ls - math.floor(24 * s), ls, ls)
		end
		draw.SimpleText('ТЕРМИНАЛ ЮНИТА  ::  ПАУЗА', 'hla_ps_head', x, y, Color(CYAN.r, CYAN.g, CYAN.b, 220 * k))
		y = y + math.floor(30 * s)
		draw.SimpleText(string.upper(p:GetNWString('hla_name', p:Nick())), 'hla_ps_name', x, y, Color(CYAN_HI.r, CYAN_HI.g, CYAN_HI.b, 255 * k))
		y = y + math.floor(62 * s)
		local SQ = HLA.Squads
		local sq = SQ and SQ.Of(p)
		local zone = HLA.Story and HLA.Story.ZoneAt and HLA.Story.ZoneAt(p:GetPos())
		local info = {
			{'ОТРЯД', sq and sq.name or 'не назначен'},
			{'ЗОНА', zone or 'вне зон'},
			{'СЕТЬ', 'COMBINE NETWORK STABLE'},
		}
		local st = HLA.Story and HLA.Story.State and HLA.Story.State()
		if st == 'story' then info[#info + 1] = {'ГЛАВА', GetGlobal2String('hla_chapter_title', '')}
		elseif st == 'pvp' then info[#info + 1] = {'РАУНД', 'ПВП'} end
		for _, it in ipairs(info) do
			draw.SimpleText(it[1] .. '  ::', 'hla_ps_small', x, y, Color(GREY.r, GREY.g, GREY.b, 230 * k))
			draw.SimpleText(it[2], 'hla_ps_small', x + math.floor(110 * s), y, Color(WHITE.r, WHITE.g, WHITE.b, 240 * k))
			y = y + math.floor(26 * s)
		end
		draw.SimpleText(os.date('%H:%M:%S'), 'hla_ps_small', x, ScrH() * 0.86, Color(GREY.r, GREY.g, GREY.b, 200 * k))
		draw.SimpleText('ESC — ВЕРНУТЬСЯ', 'hla_ps_small', w - math.floor(ScrW() * 0.12), ScrH() * 0.86, Color(GREY.r, GREY.g, GREY.b, 200 * k), TEXT_ALIGN_RIGHT)
	end
	click('press')
end

-- called after the hooks of the chat / terminal / menus: only when none of them took the Esc
function GM:OnPauseMenuShow()
	if P.bypass then P.bypass = false return true end -- «МЕНЮ GMOD»: the usual menu this time
	local p = LocalPlayer()
	if not IsValid(p) or p:GetNWBool('hla_in_menu') then return true end
	if HLA.Tab and HLA.Tab.open then return true end
	if IsValid(P.frame) then P.Close() return false end
	P.Open()
	return false
end
