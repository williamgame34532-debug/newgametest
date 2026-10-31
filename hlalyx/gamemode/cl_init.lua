include('shared.lua')
include('cl_hud.lua')

local H = HLA.Hud
local HIDE = {CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true}

function GM:HUDShouldDraw(name)
	if HIDE[name] then return false end
	return self.BaseClass.HUDShouldDraw(self, name)
end

-- HL:A shows pickups on its own counters, not in a pickup list
function GM:HUDDrawPickupHistory() end

local fontsFor
local function fonts()
	local s = ScrH() / 1080
	if fontsFor == ScrH() then return end
	fontsFor = ScrH()
	surface.CreateFont('hla_label', {font = 'Roboto Condensed', size = math.floor(24 * s), weight = 700, extended = true})
	surface.CreateFont('hla_value', {font = 'Roboto Condensed', size = math.floor(40 * s), weight = 300, extended = true})
	surface.CreateFont('hla_big', {font = 'Roboto Condensed', size = math.floor(86 * s), weight = 300, extended = true})
	surface.CreateFont('hla_small', {font = 'Roboto Condensed', size = math.floor(40 * s), weight = 300, extended = true})
	surface.CreateFont('hla_wep', {font = 'HalfLife2', size = math.floor(64 * s), weight = 0, additive = false, antialias = true})
end

local function col(c) return c[1], c[2], c[3], c[4] or 255 end
local XA = {[0] = TEXT_ALIGN_LEFT, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_RIGHT}
local YA = {[0] = TEXT_ALIGN_TOP, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_BOTTOM}
local D = {}
function D.rect(x, y, w, h, c) surface.SetDrawColor(col(c)) surface.DrawRect(x, y, w, h) end
function D.size(t, f) surface.SetFont(f) return surface.GetTextSize(t) end
function D.text(t, f, x, y, c, ax, ay) draw.SimpleText(t, f, x, y, Color(col(c)), XA[ax or 0], YA[ay or 0]) end

local lastResin, flashAt = nil, 0
local notes = {}

function GM:HUDPaint()
	self.BaseClass.HUDPaint(self)
	local p = LocalPlayer()
	if not IsValid(p) or not p:Alive() then return end
	fonts()
	local resin = p:GetNWInt('cf_resin', 0)
	if lastResin and resin > lastResin then
		flashAt = CurTime()
		table.insert(notes, 1, {text = '+' .. (resin - lastResin) .. ' СМОЛА', t = CurTime()})
	end
	lastResin = resin
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
		weps[#weps + 1] = {glyph = H.GLYPHS[c], name = H.GLYPHS[c] and nil or string.upper(string.sub(w:GetPrintName() or c, 1, 6)), active = w == active}
		if #weps >= 6 then break end
	end
	local st = {w = ScrW(), h = ScrH(), resin = resin, resinFlash = math.Clamp(1 - (CurTime() - flashAt) / 0.6, 0, 1),
		hp = p:Health(), maxhp = p:GetMaxHealth(), weapons = weps, notes = shown}
	if IsValid(active) and active:GetPrimaryAmmoType() >= 0 then
		st.showAmmo = true
		st.clip = active:Clip1()
		st.reserve = p:GetAmmoCount(active:GetPrimaryAmmoType())
	end
	H.Draw(D, st)
end
