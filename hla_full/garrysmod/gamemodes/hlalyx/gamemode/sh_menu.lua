-- Main menu in the style of the Half-Life: Alyx menu (golden panels), shared settings.
-- The menu is shown in the world (3D2D) at a spot an admin picks per map (hla_menu_spot),
-- the camera stands in front of it. Play > choose a character or create one > spawn.
HLA = HLA or {}
HLA.Menu = HLA.Menu or {}
local M = HLA.Menu

M.CommunityURL = 'https://steamcommunity.com/' -- button «СООБЩЕСТВО»
M.MaxChars = 4
M.NameMin, M.NameMax = 2, 24

-- player models a character can use (models missing on a client are skipped there)
M.Models = {}
for i = 1, 9 do M.Models[#M.Models + 1] = string.format('models/player/Group03/male_%02d.mdl', i) end
for i = 1, 7 do M.Models[#M.Models + 1] = string.format('models/player/Group03/female_%02d.mdl', i) end

function M.ModelLabel(path)
	local sex, n = string.match(path or '', '(%a+)_(%d+)%.mdl$')
	if not sex then return '?' end
	return (sex == 'female' and 'ЖЕНЩИНА ' or 'МУЖЧИНА ') .. n
end

function M.ValidModel(path)
	for _, m in ipairs(M.Models) do if m == path then return file.Exists(path, 'GAME') end end
	return false
end

-- letters (Latin and Cyrillic), hyphen and apostrophe; UTF-8 aware length
function M.ValidName(s)
	if not isstring(s) then return false end
	s = string.Trim(s)
	local n = utf8.len(s)
	if not n or n < M.NameMin or n > M.NameMax then return false end
	for _, code in utf8.codes(s) do
		local ok = (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 45 or code == 39
			or (code >= 0x410 and code <= 0x44F) or code == 0x401 or code == 0x451
		if not ok then return false end
	end
	return true
end

-- movement and stamina
M.Move = {walk = 150, run = 245, slow = 90, crouch = 0.45, jump = 190}
M.Stamina = {max = 100, drain = 17, regen = 14, regenDelay = 1.1, jump = 14, recover = 25}
