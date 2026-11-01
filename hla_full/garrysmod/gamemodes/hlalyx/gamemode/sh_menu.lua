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
-- calm, weighty movement (units per second; a person walks ~1.4 m/s = ~75, runs ~3.5 m/s = ~185):
-- walk 105, run 185, slow walk (Alt) 70, crouch 40% of it, jump 170 (about 40 cm up)
M.Move = {walk = 105, run = 185, slow = 70, crouch = 0.4, jump = 170,
	accel = 5,       -- sv_accelerate: speeds up and stops over ~0.3 s, not instantly (GMod: 10)
	airaccel = 2,    -- sv_airaccelerate: almost no steering in the air (GMod: 10)
	airMax = 1.0}    -- in a jump not faster than the speed it started with (no jump boost / bunny hop)
M.Stamina = {max = 100, drain = 17, regen = 14, regenDelay = 1.1, jump = 14, recover = 25}
