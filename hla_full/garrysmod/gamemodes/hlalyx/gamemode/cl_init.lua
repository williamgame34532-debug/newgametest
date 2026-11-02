include('shared.lua')
include('cl_hud.lua')
include('cl_hudcurve.lua')
include('cl_world.lua')
include('cl_tabmenu.lua')
include('cl_menu.lua')
include('cl_chat.lua')
include('cl_view.lua')
include('cl_squads.lua')
include('cl_ambient.lua')
include('cl_ffmenu.lua')
include('cl_story.lua')
include('cl_editor.lua')
include('cl_voice.lua')
include('cl_thirdperson.lua')
include('cl_effects.lua')
include('cl_pause.lua')
include('cl_scoreboard.lua')
include('cl_dropship.lua')
include('cl_intro.lua')
include('cl_fabeditor.lua')

local H = HLA.Hud
local HIDE = {CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true, CHudWeaponSelection = true}

function GM:HUDShouldDraw(name)
	if HIDE[name] then return false end
	return self.BaseClass.HUDShouldDraw(self, name)
end

function GM:HUDDrawPickupHistory() end

function GM:AddDeathNotice() end
function GM:DrawDeathNotice() end

local function ordered(p)
	local list = p:GetWeapons()
	table.sort(list, function(a, b)
		local sa, sb = a:GetSlot(), b:GetSlot()
		if sa ~= sb then return sa < sb end
		return a:GetSlotPos() < b:GetSlotPos()
	end)
	return list
end

local SW = {
	hands = {'hla/weapon/cloth_1.wav', 'hla/weapon/cloth_2.wav', 'hla/weapon/cloth_3.wav'},
	pistol = {'hla/weapon/draw_pistol.wav'},
	rifle = {'hla/weapon/grab_rifle.wav', 'hla/weapon/grab_polymer.wav'},
}
local PISTOL = {pistol = true, revolver = true, ['357'] = true}
function HLA.SwitchSound(w)
	local kind = 'rifle'
	if not IsValid(w) or w:GetClass() == 'hla_hands' or w:GetClass() == 'weapon_physcannon' then kind = 'hands'
	elseif w.GetHoldType and PISTOL[w:GetHoldType()] then kind = 'pistol' end
	local list = SW[kind]
	local first = list[math.random(#list)]
	if not file.Exists('sound/' .. first, 'GAME') then surface.PlaySound('common/wpn_hudoff.wav') return end
	surface.PlaySound(first)
	if kind == 'rifle' and file.Exists('sound/hla/weapon/raise.wav', 'GAME') then
		timer.Simple(0.18, function() surface.PlaySound('hla/weapon/raise.wav') end)
	end
end

hook.Add('PlayerBindPress', 'HLAWeaponSwitch', function(p, bind, pressed)
	if not pressed or (CFRework and CFRework.FocusEnt and CFRework.FocusEnt()) then return end
	if HLA.Story and HLA.Story.VoteKey and HLA.Story.VoteKey(bind) then return true end
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
		HLA.SwitchSound(pick)
		return true
	end
end)

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
	surface.CreateFont('hla_label', {font = 'Play', size = math.max(11, math.floor(28 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_value', {font = 'Play', size = math.max(15, math.floor(48 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_big', {font = 'Play', size = math.max(22, math.floor(100 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_small', {font = 'Play', size = math.max(13, math.floor(44 * s)), weight = 400, extended = true})
	surface.CreateFont('hla_wname', {font = 'Play', size = math.max(12, math.floor(26 * s)), weight = 700, extended = true})
	surface.CreateFont('hla_wslot', {font = 'Play', size = math.max(10, math.floor(20 * s)), weight = 400, extended = true})
	surface.CreateFont('hla_wep', {font = 'HalfLife2', size = math.max(16, math.floor(64 * s)), weight = 0, antialias = true})
end

local function col(c) return c[1], c[2], c[3], c[4] or 255 end
local XA = {[0] = TEXT_ALIGN_LEFT, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_RIGHT}
local YA = {[0] = TEXT_ALIGN_TOP, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_BOTTOM}
local D = {}
function D.rect(x, y, w, h, c) surface.SetDrawColor(col(c)) surface.DrawRect(x, y, w, h) end
function D.size(t, f) surface.SetFont(f) return surface.GetTextSize(t) end
function D.text(t, f, x, y, c, ax, ay) draw.SimpleText(t, f, x, y, Color(col(c)), XA[ax or 0], YA[ay or 0]) end
local vignette = Material('hla/ui/vignette')
function D.vignette(c)
	surface.SetDrawColor(col(c))
	surface.SetMaterial(vignette)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end

local lastResin, flashAt = nil, 0
local staminaSeen, wasTiredAt
local lastHP, hurtAt = nil, 0
local lastBeat, wasLow = nil, false
local hbSound, hbPath
local notes = {}

function GM:HUDPaint()
	self.BaseClass.HUDPaint(self)
	local p = LocalPlayer()
	if not IsValid(p) or not p:Alive() then
		if hbSound and hbSound:IsPlaying() then hbSound:Stop() end
		return
	end
	if CFRework and CFRework.FocusState and CFRework.FocusState.blend > 0 then return end
	if HLA.Tab and HLA.Tab.fade > 0 then return end
	if HLA.Binoculars and HLA.Binoculars.k > 0.2 then return end
	if p:GetNWBool('hla_in_menu') or (HLA.Menu.State and HLA.Menu.State.fade > 0) then return end
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
	for _, w in ipairs(ordered(p)) do
		local c = w:GetClass()
		local name = language.GetPhrase(w:GetPrintName() or c)
		if (utf8.len(name) or 0) > 22 then name = string.sub(name, 1, (utf8.offset(name, 22) or 23) - 1) .. '…' end
		weps[#weps + 1] = {glyph = H.GLYPHS[c], name = utf8.force and utf8.force(name) or name, slot = w:GetSlot() + 1, active = w == active}
		if #weps >= 6 then break end
	end
	local st = {w = ScrW(), h = ScrH(), scale = hudScale(), t = CurTime(), resin = resin,
		resinFlash = math.Clamp(1 - (CurTime() - flashAt) / 0.6, 0, 1),
		hp = hp, maxhp = p:GetMaxHealth(), hurt = math.Clamp(1 - (CurTime() - hurtAt) / 0.35, 0, 1),
		weapons = weps, notes = shown}
	local stam = HLA.Stamina and HLA.Stamina(p) or HLA.Menu.Stamina.max
	if stam < HLA.Menu.Stamina.max - 0.5 then staminaSeen = CurTime() end
	st.stamina, st.staminaMax = stam, HLA.Menu.Stamina.max
	st.staminaShow = math.Clamp(1.5 - (CurTime() - (staminaSeen or -10)), 0, 1)
	st.tired = stam < HLA.Menu.Stamina.recover and (wasTiredAt or 0) > 0
	if stam <= 0.5 then wasTiredAt = CurTime() elseif stam >= HLA.Menu.Stamina.recover then wasTiredAt = 0 end
	if IsValid(active) and active:GetPrimaryAmmoType() >= 0 then
		st.showAmmo = true
		st.clip = active:Clip1()
		st.reserve = p:GetAmmoCount(active:GetPrimaryAmmoType())
		st.safe = HLA.IsSafe and HLA.IsSafe(p)
	end
	H.Vignette(D, st)
	local beat
	HLA.HudCurve.Paint(function()
		beat = H.Draw(D, st)
		hook.Run('HLAHUDPaint')
	end)
	beat = beat or 0

	local low = hp > 0 and hp <= H.LOW
	if low and not wasLow then
		local snd = H.Sound('lowhealth')
		if snd then surface.PlaySound(snd) end
	end
	wasLow = low
	local snd = H.Sound('heartbeat')
	if low and snd then
		if not hbSound or hbPath ~= snd then
			if hbSound then hbSound:Stop() end
			hbSound, hbPath = CreateSound(p, snd), snd
		end
		local idx = math.floor(CurTime() * H.Rate(hp) + 0.95)
		if snd == 'player/heartbeat1.wav' then
			if not hbSound:IsPlaying() then hbSound:PlayEx(0.7, 100) end
			hbSound:ChangePitch(math.Clamp(85 + H.Rate(hp) * 18, 90, 130), 0.2)
		elseif idx ~= lastBeat then
			hbSound:Stop() hbSound:PlayEx(0.8, 100)
		end
		lastBeat = idx
	elseif hbSound and hbSound:IsPlaying() then
		hbSound:FadeOut(0.4)
		lastBeat = nil
	end
end
