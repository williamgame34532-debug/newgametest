include('shared.lua')
include('cl_hud.lua')

local H = HLA.Hud
local HIDE = {CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true, CHudWeaponSelection = true}

function GM:HUDShouldDraw(name)
	if HIDE[name] then return false end
	return self.BaseClass.HUDShouldDraw(self, name)
end

-- HL:A shows pickups on its own counters, not in a pickup list
function GM:HUDDrawPickupHistory() end

-- the standard weapon list is hidden, so weapons switch instantly: wheel cycles, 1..6 pick
-- (the active one is highlighted among the icons on the right of the HUD)
local function ordered(p)
	local list = p:GetWeapons()
	table.sort(list, function(a, b)
		local sa, sb = a:GetSlot(), b:GetSlot()
		if sa ~= sb then return sa < sb end
		return a:GetSlotPos() < b:GetSlotPos()
	end)
	return list
end

hook.Add('PlayerBindPress', 'HLAWeaponSwitch', function(p, bind, pressed)
	if not pressed or (CFRework and CFRework.FocusEnt and CFRework.FocusEnt()) then return end
	local list = ordered(p)
	if #list == 0 then return end
	local cur = p:GetActiveWeapon()
	local idx = 1
	for i, w in ipairs(list) do if w == cur then idx = i end end
	local pick
	if bind == 'invnext' then pick = list[idx % #list + 1]
	elseif bind == 'invprev' then pick = list[(idx - 2) % #list + 1]
	else
		local n = tonumber(bind:match('^slot(%d)$'))
		if n then
			for _, w in ipairs(list) do if w:GetSlot() == n - 1 then pick = w break end end
			if not pick then return true end
		end
	end
	if pick then
		input.SelectWeapon(pick)
		surface.PlaySound('common/wpn_hudoff.wav')
		return true
	end
end)

-- an old standalone combine_fabricator addon draws its own resin box: not in this gamemode
hook.Add('InitPostEntity', 'HLARemoveAddonHud', function() hook.Remove('HUDPaint', 'CFReworkHints') end)
timer.Simple(5, function() hook.Remove('HUDPaint', 'CFReworkHints') end)

HLA.HudScale = CreateClientConVar('hla_hud_scale', '0.66', true, false, 'HUD size (0.4 .. 1.2)')

local function hudScale()
	return math.min(ScrW() / 1920, ScrH() / 1080) * math.Clamp(HLA.HudScale:GetFloat(), 0.4, 1.2)
end

local fontsFor
local function fonts()
	local s = hudScale()
	local key = ScrW() .. 'x' .. ScrH() .. '@' .. s
	if fontsFor == key then return end
	fontsFor = key
	surface.CreateFont('hla_label', {font = 'Roboto Condensed', size = math.max(10, math.floor(26 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_value', {font = 'Roboto Condensed', size = math.max(14, math.floor(44 * s)), weight = 300, extended = true})
	surface.CreateFont('hla_big', {font = 'Roboto Condensed', size = math.max(20, math.floor(92 * s)), weight = 300, extended = true})
	surface.CreateFont('hla_small', {font = 'Roboto Condensed', size = math.max(12, math.floor(42 * s)), weight = 300, extended = true})
	surface.CreateFont('hla_wep', {font = 'HalfLife2', size = math.max(16, math.floor(64 * s)), weight = 0, antialias = true})
end

local function col(c) return c[1], c[2], c[3], c[4] or 255 end
local XA = {[0] = TEXT_ALIGN_LEFT, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_RIGHT}
local YA = {[0] = TEXT_ALIGN_TOP, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_BOTTOM}
local edge = Material('vgui/gradient-u')
local edgeD = Material('vgui/gradient-d')
local edgeL = Material('vgui/gradient-l')
local edgeR = Material('vgui/gradient-r')
local D = {}
function D.rect(x, y, w, h, c) surface.SetDrawColor(col(c)) surface.DrawRect(x, y, w, h) end
function D.size(t, f) surface.SetFont(f) return surface.GetTextSize(t) end
function D.text(t, f, x, y, c, ax, ay) draw.SimpleText(t, f, x, y, Color(col(c)), XA[ax or 0], YA[ay or 0]) end
function D.vignette(c)
	local w, h = ScrW(), ScrH()
	local d = math.floor(h * 0.28)
	surface.SetDrawColor(col(c))
	surface.SetMaterial(edge) surface.DrawTexturedRect(0, 0, w, d)
	surface.SetMaterial(edgeD) surface.DrawTexturedRect(0, h - d, w, d)
	surface.SetMaterial(edgeL) surface.DrawTexturedRect(0, 0, d, h)
	surface.SetMaterial(edgeR) surface.DrawTexturedRect(w - d, 0, d, h)
end

local lastResin, flashAt = nil, 0
local lastHP, hurtAt = nil, 0
local lastBeat, wasLow = nil, false
local notes = {}

function GM:HUDPaint()
	self.BaseClass.HUDPaint(self)
	local p = LocalPlayer()
	if not IsValid(p) or not p:Alive() then return end
	if CFRework and CFRework.FocusState and CFRework.FocusState.blend > 0 then return end
	fonts()
	local resin = p:GetNWInt('cf_resin', 0)
	if lastResin and resin > lastResin then
		flashAt = CurTime()
		table.insert(notes, 1, {text = '+' .. (resin - lastResin) .. ' СМОЛА', t = CurTime()})
		local snd = H.Sound('resin')
		if snd then surface.PlaySound(snd) end
	end
	lastResin = resin
	local hp = p:Health()
	if lastHP and hp < lastHP then
		hurtAt = CurTime()
		local snd = H.Sound('hurt')
		if snd then surface.PlaySound(snd) end
	end
	lastHP = hp
	for i = #notes, 1, -1 do if CurTime() - notes[i].t > 2.5 then table.remove(notes, i) end end
	local shown = {}
	for i, n in ipairs(notes) do
		if i > 3 then break end
		shown[i] = {text = n.text, alpha = math.Clamp(2.5 - (CurTime() - n.t), 0, 1)}
	end

	local weps = {}
	local active = p:GetActiveWeapon()
	for _, w in ipairs(p:GetWeapons()) do
		local c = w:GetClass()
		local glyph = H.GLYPHS[c]
		weps[#weps + 1] = {glyph = glyph, name = glyph and nil or string.upper(string.sub(w:GetPrintName() or c, 1, 6)), active = w == active}
		if #weps >= 6 then break end
	end
	local st = {w = ScrW(), h = ScrH(), scale = hudScale(), t = CurTime(), resin = resin,
		resinFlash = math.Clamp(1 - (CurTime() - flashAt) / 0.6, 0, 1),
		hp = hp, maxhp = p:GetMaxHealth(), hurt = math.Clamp(1 - (CurTime() - hurtAt) / 0.35, 0, 1),
		weapons = weps, notes = shown}
	if IsValid(active) and active:GetPrimaryAmmoType() >= 0 then
		st.showAmmo = true
		st.clip = active:Clip1()
		st.reserve = p:GetAmmoCount(active:GetPrimaryAmmoType())
	end
	local beat = H.Draw(D, st)

	-- heartbeat in time with the hearts; a warning sound when health first drops low
	local low = hp > 0 and hp <= H.LOW
	if low and not wasLow then
		local snd = H.Sound('lowhealth')
		if snd then surface.PlaySound(snd) end
	end
	wasLow = low
	local idx = low and math.floor(CurTime() * H.Rate(hp) + 0.95) or nil
	if idx and idx ~= lastBeat then
		local snd = H.Sound('heartbeat')
		if snd then surface.PlaySound(snd) end
	end
	lastBeat = idx
end
