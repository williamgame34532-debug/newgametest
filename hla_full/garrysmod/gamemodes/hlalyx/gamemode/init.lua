AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
AddCSLuaFile('cl_hud.lua')
include('shared.lua')
include('fabricator/sv_resin.lua')
include('sv_game.lua')
include('sv_menu.lua')
include('sv_inventory.lua')

-- clients download the fabricator content (models, materials, sounds, font) from the server
local function sendFolder(path)
	local files, dirs = file.Find(path .. '/*', 'GAME')
	for _, name in ipairs(files or {}) do resource.AddFile(path .. '/' .. name) end
	for _, name in ipairs(dirs or {}) do sendFolder(path .. '/' .. name) end
end
for _, path in ipairs({'models/cf_rework', 'materials/cf_rework', 'materials/models/cf_rework', 'sound/combine_fabricator', 'materials/hla', 'sound/hla'}) do
	sendFolder(path)
end
-- the ported HL:A monitor shader (only our file, not the game's own shaders)
if file.Exists('shaders/fxc/hla_monitor_ps30.vcs', 'GAME') then resource.AddSingleFile('shaders/fxc/hla_monitor_ps30.vcs') end
resource.AddFile('resource/fonts/RobotoCondensed-Regular.ttf')
resource.AddFile('resource/fonts/RobotoCondensed-Bold.ttf')
