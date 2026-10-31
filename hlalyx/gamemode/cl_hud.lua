-- Half-Life: Alyx style HUD: resin and heart health bottom-left, weapons and ammo bottom-right.
-- Drawn through a small adapter (rect/text/size) so it can be previewed offline as well.
HLA = HLA or {}
local H = {}
HLA.Hud = H

H.AMBER = {241, 196, 61, 255}
H.DIM = {241, 196, 61, 60}
H.PANEL = {8, 8, 6, 120}

-- pixel heart, 9 x 8 dot matrix like the reference
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

local function heart(D, x, y, px, fill, col, dim)
	local cols = 9
	local cut = math.floor(fill * cols + 0.5)
	for row, line in ipairs(HEART) do
		for c = 1, cols do
			if line:sub(c, c) == 'X' then
				D.rect(x + (c - 1) * px, y + (row - 1) * px, px - 1, px - 1, c <= cut and col or dim)
			end
		end
	end
end

local function A(c, a) return {c[1], c[2], c[3], a} end

-- st: {w, h, resin, resinFlash (0..1), hp, maxhp, weapons = {{glyph=, name=, active=}}, clip, reserve, showAmmo}
function H.Draw(D, st)
	local s = st.h / 1080
	local amber = H.AMBER
	local x0, y0 = 60 * s, st.h - 312 * s

	-- RESIN
	local flash = st.resinFlash or 0
	D.rect(x0, y0, 330 * s, 64 * s, A(H.PANEL, 110 + 90 * flash))
	D.text('СМОЛА', 'hla_label', x0 + 22 * s, y0 + 32 * s, amber, 0, 1)
	D.text(tostring(st.resin or 0), 'hla_value', x0 + 300 * s, y0 + 32 * s, A(amber, 200 + 55 * flash), 2, 1)

	-- HEALTH: one heart per 33 hp, partially filled
	local y1 = y0 + 92 * s
	D.rect(x0, y1, 330 * s, 140 * s, A(H.PANEL, 70))
	D.text('ЗДОРОВЬЕ', 'hla_label', x0 + 22 * s, y1 + 14 * s, amber, 0, 0)
	local per = 100 / 3
	local hearts = math.max(3, math.ceil((st.maxhp or 100) / per))
	local px = math.max(2, math.floor(8 * s))
	for i = 1, hearts do
		local f = math.Clamp(((st.hp or 0) - (i - 1) * per) / per, 0, 1)
		heart(D, x0 + 22 * s + (i - 1) * (px * 9 + 20 * s), y1 + 58 * s, px, f, amber, H.DIM)
	end

	-- WEAPONS + AMMO
	local xr = st.w - 140 * s
	local y2 = st.h - 312 * s
	local wx = xr
	for i = #(st.weapons or {}), 1, -1 do
		local w = st.weapons[i]
		local font = w.glyph and 'hla_wep' or 'hla_small'
		local label = w.glyph or w.name
		local tw = D.size(label, font)
		D.text(label, font, wx, y2 + 40 * s, w.active and amber or A(amber, 90), 2, 1)
		wx = wx - tw - 22 * s
	end
	if st.showAmmo then
		local y3 = y2 + 92 * s
		D.rect(xr - 220 * s, y3, 240 * s, 140 * s, A(H.PANEL, 70))
		D.text('БОЕЗАПАС', 'hla_label', xr - 200 * s, y3 + 14 * s, amber, 0, 0)
		if st.clip and st.clip >= 0 then
			local rs = '/' .. tostring(st.reserve or 0)
			local rw = D.size(rs, 'hla_small')
			D.text(rs, 'hla_small', xr, y3 + 118 * s, amber, 2, 2)
			D.text(tostring(st.clip), 'hla_big', xr - 4 * s - rw, y3 + 128 * s, amber, 2, 2)
		else
			D.text(tostring(st.reserve or 0), 'hla_big', xr, y3 + 128 * s, amber, 2, 2)
		end
	end

	-- pickup notes
	for i, n in ipairs(st.notes or {}) do
		D.text(n.text, 'hla_label', x0 + 350 * s, y0 + 32 * s - (i - 1) * 30 * s, A(amber, 255 * n.alpha), 0, 1)
	end
end

-- HL2 weapon glyphs of the HalfLife2 font (used by the engine's own weapon icons)
H.GLYPHS = {
	weapon_pistol = 'd', weapon_357 = 'e', weapon_smg1 = 'a', weapon_ar2 = 'l', weapon_shotgun = 'b',
	weapon_crossbow = 'g', weapon_rpg = 'i', weapon_frag = 'k', weapon_crowbar = 'c', weapon_stunstick = 'n',
	weapon_physcannon = 'm', weapon_bugbait = 'j', weapon_slam = 'o',
}
