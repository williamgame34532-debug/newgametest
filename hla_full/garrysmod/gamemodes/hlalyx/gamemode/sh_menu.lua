-- Main menu in the style of the Half-Life: Alyx menu (golden panels), shared settings.
-- The menu is shown in the world (3D2D) at a spot an admin picks per map (hla_menu_spot),
-- the camera stands in front of it. Play > choose a character or create one (number + model) > spawn.
HLA = HLA or {}
HLA.Menu = HLA.Menu or {}
local M = HLA.Menu

M.CommunityURL = 'https://steamcommunity.com/' -- button «СООБЩЕСТВО»
M.MaxChars = 4

-- Characters are Combine units: a three-digit number instead of a name, one of three models,
-- each with its own weapon. Every character has a permanent ID (saves are keyed by it).
M.NamePrefix = 'ЮНИТ '
M.Classes = {
	{model = 'models/cultist/hl_a/combine_grunt/combine_grunt.mdl', label = 'ГРАНТ', weapon = 'tfa_osips'},
	{model = 'models/nemez/combine_soldiers/combine_soldier_recon_h.mdl', label = 'РАЗВЕДЧИК', weapon = 'weapon_csniper_tfa2'},
	{model = 'models/nemez/combine_soldiers/combine_soldier_coordinator_h.mdl', label = 'КООРДИНАТОР', weapon = 'tfa_ocipr'},
	-- HL:A Ordinal: shown in character creation once its model is installed; change the path / weapon here
	{model = 'models/cultist/hl_a/combine_ordinal/combine_ordinal.mdl', label = 'ОРДИНАЛ', weapon = 'tfa_ocipr'},
}
M.Models = {}
for i, c in ipairs(M.Classes) do M.Models[i] = c.model end

function M.Class(path)
	path = string.lower(path or '')
	for _, c in ipairs(M.Classes) do if c.model == path then return c end end
end

function M.ModelLabel(path)
	local c = M.Class(path)
	return c and c.label or '?'
end

function M.ValidModel(path)
	return M.Class(path) ~= nil and file.Exists(path, 'GAME')
end

-- exactly three digits
function M.ValidNum(s)
	return isstring(s) and string.match(s, '^%d%d%d$') ~= nil
end

function M.DisplayName(c)
	return M.NamePrefix .. (c.num or '???')
end

-- movement and stamina
-- realistic pace for an armed unit in gear (1 m ~ 52 units): walk ~2.4 m/s = 125, run ~4.4 m/s = 230,
-- slow walk (Alt) ~1.4 m/s = 75, crouch 45% of it, jump 180 (about 45 cm up)
M.Move = {walk = 125, run = 230, slow = 75, crouch = 0.45, jump = 180,
	accel = 6,       -- sv_accelerate: speeds up and stops over ~0.25 s, not instantly (GMod: 10)
	airaccel = 2,    -- sv_airaccelerate: almost no steering in the air (GMod: 10)
	airMax = 1.0}    -- in a jump not faster than the speed it started with (no jump boost / bunny hop)
-- stamina: ~11 s of running from full, back to full in ~6 s after a short pause
M.Stamina = {max = 100, drain = 9, regen = 18, regenDelay = 0.8, jump = 9, recover = 15}
