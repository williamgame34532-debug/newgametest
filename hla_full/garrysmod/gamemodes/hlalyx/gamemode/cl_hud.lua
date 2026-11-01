-- Half-Life: Alyx style HUD: resin and heart health bottom-left, weapons and ammo bottom-right.
-- Size follows the screen: everything is laid out in a 1920x1080 reference space scaled by
-- min(width/1920, height/1080) * hla_hud_scale and anchored to the corners (works on 4:3 .. 32:9).
-- Low health: hearts turn red and beat, a red vignette pulses, a heartbeat plays in time.
-- Drawn through a small adapter (rect/text/size/vignette) so it can be previewed offline as well.
HLA = HLA or {}
local H = {}
HLA.Hud = H

-- the whole on-screen HUD is blue (the name AMBER is kept for the code that uses it)
H.AMBER = {110, 200, 255, 255}
H.AMBER_C = Color(110, 200, 255)
H.RED = {236, 52, 44, 255}
H.PANEL = {4, 10, 16, 120}
-- backing panels: barely there — seen when you look for them. On the curved visor the HUD is added
-- onto the picture, so the panel is a faint blue glow; drawn flat it is a faint dark plate.
local function panel(D, x, y, w, h, k)
	k = k or 1
	local add = HLA.HudCurve and HLA.HudCurve.Additive and HLA.HudCurve.Additive()
	if add then
		local a = math.min(255, 255 * k)
		D.rect(x, y, w, h, {6 * k, 14 * k, 20 * k, a})
		D.rect(x, y, w, math.max(1, h * 0.012), {18 * k, 40 * k, 54 * k, a}) -- a hairline on top
	else
		D.rect(x, y, w, h, {4, 12, 20, math.min(255, 45 * k)})
		D.rect(x, y, w, math.max(1, h * 0.012), {110, 200, 255, math.min(255, 26 * k)})
	end
end
H.Panel = panel
H.LOW = 100 / 3 -- one heart left -> low health state

local HEART = {
	'.XX...XX.',
	'XXXX.XXXX',
	'XXXXXXXXX',
	'XXXXXXXXX',
	'.XXXXXXX.',
	'..XXXXX..',
	'...XXX...',
	'....X....',
}

local function A(c, a) return {c[1], c[2], c[3], a} end
local function mix(a, b, t) return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] or 255} end

-- pixel heart; `grow` scales it around its centre (beat), fill = 0..1 lit columns
local function heart(D, cx, cy, px, fill, col, dim)
	local cut = math.floor(fill * 9 + 0.5)
	local x0, y0 = cx - px * 4.5, cy - px * 4
	for row, line in ipairs(HEART) do
		for c = 1, 9 do
			if line:sub(c, c) == 'X' then
				D.rect(x0 + (c - 1) * px, y0 + (row - 1) * px, math.max(1, px - 1), math.max(1, px - 1), c <= cut and col or dim)
			end
		end
	end
end

-- heart rate (beats per second) at low health, 0 otherwise
function H.Rate(hp)
	if hp <= 0 or hp > H.LOW then return 0 end
	return 1.1 + (1 - hp / H.LOW) * 0.9
end

-- beat curve for a time t and rate (Hz): sharp double pulse like a heart
function H.Beat(t, rate)
	local ph = (t * rate) % 1
	local a = math.max(0, 1 - math.abs(ph - 0.05) / 0.08)
	local b = math.max(0, 1 - math.abs(ph - 0.28) / 0.08) * 0.6
	return math.max(a, b)
end

-- screen vignette (texture from hla_menu_content): always a soft dark edge, red when hurt or low.
-- Drawn on its own, outside the curved visor HUD.
function H.Vignette(D, st)
	if not D.vignette then return end
	local hp = st.hp or 0
	local low = hp > 0 and hp <= H.LOW
	local beat = low and H.Beat(st.t or 0, H.Rate(hp)) or 0
	D.vignette({0, 0, 0, 95})
	if (st.hurt or 0) > 0 then D.vignette(A(H.RED, 150 * st.hurt)) end
	if low then D.vignette(A(H.RED, 40 + 120 * beat)) end
end

-- st: {w, h, scale, t, resin, resinFlash, hp, maxhp, hurt (0..1 recent damage flash),
--      weapons = {{glyph, name, active}}, clip, reserve, showAmmo, notes}
function H.Draw(D, st)
	local s = st.scale or math.min(st.w / 1920, st.h / 1080) * 0.66
	local amber = H.AMBER
	local t = st.t or 0
	local hp, maxhp = st.hp or 0, st.maxhp or 100
	local low = hp > 0 and hp <= H.LOW
	local rate = H.Rate(hp)
	local beat = low and H.Beat(t, rate) or 0

	local m = 54 * s
	local x0, y0 = m, st.h - m - 236 * s

	-- RESIN
	local flash = st.resinFlash or 0
	panel(D, x0, y0, 330 * s, 64 * s, 1 + 1.5 * flash)
	D.text('СМОЛА', 'hla_label', x0 + 22 * s, y0 + 32 * s, amber, 0, 1)
	D.text(tostring(st.resin or 0), 'hla_value', x0 + 306 * s, y0 + 32 * s, A(amber, 200 + 55 * flash), 2, 1)

	-- HEALTH
	local y1 = y0 + 92 * s
	panel(D, x0, y1, 330 * s, 144 * s)
	local hcol = low and mix(amber, H.RED, 1) or amber
	if (st.hurt or 0) > 0 then hcol = mix(hcol, {255, 255, 255, 255}, st.hurt * 0.7) end
	D.text('ЗДОРОВЬЕ', 'hla_label', x0 + 22 * s, y1 + 14 * s, low and H.RED or amber, 0, 0)
	local per = 100 / 3
	local hearts = math.max(3, math.ceil(maxhp / per))
	local px = math.max(2, math.floor(8 * s + 0.5))
	local step = px * 9 + 22 * s
	for i = 1, hearts do
		local f = math.Clamp((hp - (i - 1) * per) / per, 0, 1)
		local grow = (low and f > 0) and math.floor(px * (1 + 0.28 * beat) + 0.5) or px
		heart(D, x0 + 22 * s + px * 4.5 + (i - 1) * step, y1 + 92 * s, grow, f, hcol, A(low and H.RED or amber, 55))
	end

	-- STAMINA: a thin bar under the hearts, shown while it is not full
	if st.stamina and (st.staminaShow or 0) > 0 then
		local f = math.Clamp(st.stamina / (st.staminaMax or 100), 0, 1)
		local bw, bh = 286 * s, math.max(2, 7 * s)
		local by = y1 + 128 * s
		local va = st.staminaShow
		D.rect(x0 + 22 * s, by, bw, bh, A(amber, 45 * va))
		D.rect(x0 + 22 * s, by, bw * f, bh, A(st.tired and H.RED or amber, 230 * va))
	end

	-- WEAPONS + AMMO
	local xr = st.w - m
	local y2 = st.h - m - 236 * s
	-- one weapon per row, upward from over the ammo box: slot, name; the active one lit with a bar
	local rh = 34 * s
	local wy = y2 + 62 * s
	for i = #(st.weapons or {}), 1, -1 do
		local w = st.weapons[i]
		local c = w.active and amber or A(amber, 110)
		if w.active then
			D.rect(xr - 6 * s, wy - rh / 2 + 4 * s, 4 * s, rh - 8 * s, amber)
			panel(D, xr - 330 * s, wy - rh / 2 + 2 * s, 320 * s, rh - 4 * s, 0.8)
		end
		D.text(string.upper(w.name or '?'), 'hla_wname', xr - 18 * s, wy, c, 2, 1)
		D.text(tostring(w.slot or i), 'hla_wslot', xr - 340 * s, wy, A(amber, w.active and 220 or 90), 0, 1)
		wy = wy - rh
	end
	if st.showAmmo then
		local y3 = y2 + 92 * s
		panel(D, xr - 250 * s, y3, 250 * s, 144 * s)
		D.text('БОЕЗАПАС', 'hla_label', xr - 228 * s, y3 + 14 * s, amber, 0, 0)
		if st.clip and st.clip >= 0 then
			local rs = '/' .. tostring(st.reserve or 0)
			local rw = D.size(rs, 'hla_small')
			D.text(rs, 'hla_small', xr - 20 * s, y3 + 122 * s, amber, 2, 2)
			D.text(tostring(st.clip), 'hla_big', xr - 24 * s - rw, y3 + 132 * s, amber, 2, 2)
		else
			D.text(tostring(st.reserve or 0), 'hla_big', xr - 20 * s, y3 + 132 * s, amber, 2, 2)
		end
	end

	for i, n in ipairs(st.notes or {}) do
		D.text(n.text, 'hla_label', x0 + 350 * s, y0 + 32 * s - (i - 1) * 30 * s, A(amber, 255 * n.alpha), 0, 1)
	end
	return beat
end

H.GLYPHS = {
	weapon_pistol = 'd', weapon_357 = 'e', weapon_smg1 = 'a', weapon_ar2 = 'l', weapon_shotgun = 'b',
	weapon_crossbow = 'g', weapon_rpg = 'i', weapon_frag = 'k', weapon_crowbar = 'c', weapon_stunstick = 'n',
	weapon_physcannon = 'm', weapon_bugbait = 'j', weapon_slam = 'o',
}

-- HUD sounds: your own Half-Life: Alyx files are used when present (see README), otherwise HL2 ones
H.SOUNDS = {
	heartbeat = {'hla_hud/heartbeat.wav', 'player/heartbeat1.wav'},
	lowhealth = {'hla_hud/low_health.wav'},
	resin = {'hla_hud/resin_pickup.wav'},
	hurt = {'hla_hud/damage.wav'},
}
function H.Sound(name)
	for _, path in ipairs(H.SOUNDS[name] or {}) do
		if file.Exists('sound/' .. path, 'GAME') then return path end
	end
end
