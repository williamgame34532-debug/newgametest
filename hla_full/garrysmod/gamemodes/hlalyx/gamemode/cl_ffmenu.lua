-- Force field settings (admins): E with the «Настройщик силового поля», or hla_forcefield_menu while
-- looking at a field or one of its posts. Every change goes to the server at once (hla_ff_set).
local BLUE = Color(110, 200, 255)
local TEXT = Color(214, 238, 250)
local DIM = Color(70, 130, 170)
local BG = Color(8, 22, 32, 245)
local bg = Material('hla/terminal/bg')
local bar = Material('hla/terminal/bar')

surface.CreateFont('hla_ffm_t', {font = 'Play', size = 22, weight = 700, extended = true})
surface.CreateFont('hla_ffm', {font = 'Play', size = 17, weight = 700, extended = true})
surface.CreateFont('hla_ffm_s', {font = 'IBM Plex Mono', size = 15, weight = 500, extended = true})

local menu
local function send(ent, what, write)
	net.Start('hla_ff_set')
	net.WriteEntity(ent)
	net.WriteString(what)
	if write then write() end
	net.SendToServer()
end

local function field(ent)
	if IsValid(ent) and ent:GetClass() == 'hla_forcefield_post' then ent = ent:GetField() end
	if IsValid(ent) and ent:GetClass() == 'hla_forcefield' then return ent end
end

local function styleButton(b, accent)
	b:SetTextColor(TEXT)
	b:SetFont('hla_ffm')
	b.Paint = function(self, w, h)
		local hot = self:IsHovered()
		if accent or hot then
			surface.SetMaterial(bar)
			surface.SetDrawColor(255, 255, 255, hot and 255 or 170)
			surface.DrawTexturedRect(0, 0, w, h)
			self:SetTextColor(Color(8, 22, 34))
		else
			surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 28)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(DIM.r, DIM.g, DIM.b, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			self:SetTextColor(TEXT)
		end
	end
end

function HLA.OpenFieldMenu(target)
	local f = field(target)
	if not IsValid(f) then LocalPlayer():ChatPrint('Посмотрите на силовое поле или его стойку') return end
	if IsValid(menu) then menu:Remove() end
	local W, H = 440, 700
	menu = vgui.Create('DFrame')
	menu:SetSize(W, H)
	menu:SetPos(ScrW() - W - 40, ScrH() / 2 - H / 2)
	menu:SetTitle('')
	menu:ShowCloseButton(false)
	menu:MakePopup()
	menu:SetKeyboardInputEnabled(false)
	menu.Paint = function(self, w, h)
		surface.SetMaterial(bg)
		surface.SetDrawColor(255, 255, 255, 250)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetMaterial(bar)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(0, 0, w, 34)
		draw.SimpleText('СИЛОВОЕ ПОЛЕ // НАСТРОЙКА', 'hla_ffm_t', 12, 17, Color(8, 22, 34), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(DIM.r, DIM.g, DIM.b, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		if not IsValid(f) then self:Remove() end
	end
	local close = vgui.Create('DButton', menu)
	close:SetText('✕') close:SetSize(34, 34) close:SetPos(W - 34, 0)
	styleButton(close)
	close.DoClick = function() menu:Remove() end

	local scroll = vgui.Create('DScrollPanel', menu)
	scroll:Dock(FILL)
	scroll:DockMargin(8, 30, 8, 8)
	local function section(text)
		local l = scroll:Add('DLabel')
		l:SetText(text) l:SetFont('hla_ffm_s') l:SetTextColor(BLUE)
		l:Dock(TOP) l:DockMargin(4, 12, 4, 2)
	end
	local function row(h)
		local r = scroll:Add('DPanel')
		r:Dock(TOP) r:SetTall(h or 30) r:DockMargin(4, 2, 4, 2)
		r.Paint = function() end
		return r
	end
	local function buttons(parent, list)
		local n = #list
		parent.PerformLayout = function(self, w, h)
			local bw = (w - (n - 1) * 4) / n
			for i, c in ipairs(self:GetChildren()) do c:SetPos((i - 1) * (bw + 4), 0) c:SetSize(bw, h) end
		end
		for _, it in ipairs(list) do
			local b = vgui.Create('DButton', parent)
			b:SetText(it[1])
			styleButton(b, it[3])
			b.DoClick = function() surface.PlaySound('hla/ui/textline_end.wav') it[2]() end
		end
	end
	local function slider(text, mn, mx, val, dec, onSet)
		local s = scroll:Add('DNumSlider')
		s:Dock(TOP) s:DockMargin(4, 0, 4, 0) s:SetTall(32)
		s:SetText(text) s:SetMin(mn) s:SetMax(mx) s:SetDecimals(dec) s:SetValue(val)
		s.Label:SetTextColor(TEXT) s.Label:SetFont('hla_ffm')
		s:SetDark(false)
		s.OnValueChanged = function(_, v)
			timer.Create('hla_ffm_' .. text, 0.15, 1, function() if IsValid(f) then onSet(v) end end)
		end
		return s
	end

	-- state
	section('СОСТОЯНИЕ')
	buttons(row(34), {
		{'ВКЛЮЧИТЬ', function() send(f, 'on', function() net.WriteBool(true) end) end, true},
		{'ВЫКЛЮЧИТЬ', function() send(f, 'on', function() net.WriteBool(false) end) end},
	})
	-- size
	section('РАЗМЕР')
	local L = f:GetPostL()
	local postH = IsValid(L) and L:PostHeightNow() or f:GetHeight()
	slider('Высота стоек', 48, 320, postH, 0, function(v) send(f, 'height', function() net.WriteFloat(v) end) end)
	slider('Ширина поля', 16, 1000, f:GetWidth(), 0, function(v) send(f, 'width', function() net.WriteFloat(v) end) end)
	local fb, ft = f:FieldFracs()
	slider('Низ поля, %', 0, 60, fb * 100, 0, function(v) send(f, 'bottom', function() net.WriteFloat(math.max(v, 0.1) / 100) end) end)
	slider('Верх поля, %', 30, 120, ft * 100, 0, function(v) send(f, 'top', function() net.WriteFloat(v / 100) end) end)
	-- position
	section('ПОЗИЦИЯ  (шаг)')
	local step = 5
	local stepRow = row(28)
	buttons(stepRow, {{'1', function() step = 1 end}, {'5', function() step = 5 end}, {'20', function() step = 20 end}, {'50', function() step = 50 end}})
	local function mv(x, y, z) return function() send(f, 'move', function() net.WriteVector(Vector(x * step, y * step, z * step)) end) end end
	buttons(row(32), {{'ВПЕРЁД', mv(1, 0, 0)}, {'НАЗАД', mv(-1, 0, 0)}})
	buttons(row(32), {{'ВЛЕВО', mv(0, -1, 0)}, {'ВПРАВО', mv(0, 1, 0)}})
	buttons(row(32), {{'ВВЕРХ', mv(0, 0, 1)}, {'ВНИЗ', mv(0, 0, -1)}})
	-- turning
	section('ПОВОРОТ ПОЛЯ')
	local function turn(d) return function() send(f, 'turn', function() net.WriteFloat(d) end) end end
	buttons(row(32), {{'-90°', turn(-90)}, {'-15°', turn(-15)}, {'-1°', turn(-1)}, {'+1°', turn(1)}, {'+15°', turn(15)}, {'+90°', turn(90)}})
	section('ПОВОРОТ СТОЕК')
	local function tp(side, d) return function() send(f, 'turnpost', function() net.WriteInt(side, 3) net.WriteFloat(d) end) end end
	buttons(row(32), {{'Л -90°', tp(-1, -90)}, {'Л -15°', tp(-1, -15)}, {'Л +15°', tp(-1, 15)}, {'Л +90°', tp(-1, 90)}})
	buttons(row(32), {{'П -90°', tp(1, -90)}, {'П -15°', tp(1, -15)}, {'П +15°', tp(1, 15)}, {'П +90°', tp(1, 90)}})
	buttons(row(32), {{'СТОЙКИ КАК ПРИ УСТАНОВКЕ', function() send(f, 'reset') end}})
	-- looks
	section('СКИН СТОЕК')
	local function skin(mode) return function() send(f, 'skin', function() net.WriteInt(0, 3) net.WriteUInt(mode, 3) end) end end
	buttons(row(32), {{'АВТО', skin(0)}, {'ГОЛУБОЙ', skin(1)}, {'КРАСНЫЙ', skin(2)}, {'ИСХОДНЫЙ', skin(3)}})
	section('МАТЕРИАЛ ПОЛЯ')
	local function mat(i) return function() send(f, 'mat', function() net.WriteUInt(i, 3) end) end end
	buttons(row(32), {{'АВТО', mat(0)}, {'ЩИТ', mat(1)}, {'HL:A', mat(2)}, {'HL2', mat(3)}})
	-- map
	section('КАРТА')
	buttons(row(34), {
		{'СОХРАНИТЬ ВСЕ ПОЛЯ', function() send(f, 'save') end, true},
		{'УДАЛИТЬ ПОЛЕ', function() send(f, 'remove') if IsValid(menu) then menu:Remove() end end},
	})
end

concommand.Add('hla_forcefield_menu', function()
	local tr = LocalPlayer():GetEyeTrace()
	HLA.OpenFieldMenu(tr.Entity)
end)

-- E with the adjuster in hand opens the menu for what it points at
hook.Add('PlayerBindPress', 'HLAFieldMenu', function(p, bind, pressed)
	if not pressed or not string.find(bind, '+use', 1, true) then return end
	local w = p:GetActiveWeapon()
	if not IsValid(w) or w:GetClass() ~= 'hla_ff_tool' then return end
	local e = p:GetEyeTrace().Entity
	if field(e) then HLA.OpenFieldMenu(e) return true end
end)
