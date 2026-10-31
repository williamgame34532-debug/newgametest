-- Half-Life: Alyx style HUD: resin and heart health bottom-left, weapons and ammo bottom-right.
-- Size follows the screen: everything is laid out in a 1920x1080 reference space scaled by
-- min(width/1920, height/1080) * hla_hud_scale and anchored to the corners (works on 4:3 .. 32:9).
-- Low health: hearts turn red and beat, a red vignette pulses, a heartbeat plays in time.
-- Drawn through a small adapter (rect/text/size/vignette) so it can be previewed offline as well.
HLA = HLA or {}
local H = {}
HLA.Hud = H

H.AMBER = {241, 196, 61, 255}
H.RED = {236, 52, 44, 255}
H.PANEL = {8, 8, 6, 120}
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

	-- screen vignette (texture from hla_menu_content): always a soft dark edge, red when hurt or low
	if D.vignette then
		D.vignette({0, 0, 0, 95})
		if (st.hurt or 0) > 0 then D.vignette(A(H.RED, 150 * st.hurt)) end
		if low then D.vignette(A(H.RED, 40 + 120 * beat)) end
	end

	local m = 54 * s
	local x0, y0 = m, st.h - m - 236 * s

	-- RESIN
	local flash = st.resinFlash or 0
	D.rect(x0, y0, 330 * s, 64 * s, A(H.PANEL, 110 + 90 * flash))
	D.text('СМОЛА', 'hla_label', x0 + 22 * s, y0 + 32 * s, amber, 0, 1)
	D.text(tostring(st.resin or 0), 'hla_value', x0 + 306 * s, y0 + 32 * s, A(amber, 200 + 55 * flash), 2, 1)

	-- HEALTH
	local y1 = y0 + 92 * s
	D.rect(x0, y1, 330 * s, 144 * s, A(H.PANEL, 70))
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
	local wx = xr
	for i = #(st.weapons or {}), 1, -1 do
		local w = st.weapons[i]
		local font = w.glyph and 'hla_wep' or 'hla_small'
		local label = w.glyph or w.name or '?'
		local tw = D.size(label, font)
		D.text(label, font, wx, y2 + 40 * s, w.active and amber or A(amber, 90), 2, 1)
		wx = wx - tw - 22 * s
	end
	if st.showAmmo then
		local y3 = y2 + 92 * s
		D.rect(xr - 250 * s, y3, 250 * s, 144 * s, A(H.PANEL, 70))
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
