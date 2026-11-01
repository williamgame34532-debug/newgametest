AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
AddCSLuaFile('cl_hud.lua')
include('shared.lua')
include('fabricator/sv_resin.lua')
include('sv_game.lua')
include('sv_menu.lua')
include('sv_inventory.lua')
include('sv_chat.lua')
include('sv_squads.lua')
include('sv_ambient.lua')
include('sv_story.lua')

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
-- chat font (hla_chat_content)
resource.AddFile('resource/fonts/IBMPlexMono-Regular.ttf')
resource.AddFile('resource/fonts/IBMPlexMono-SemiBold.ttf')
resource.AddFile('resource/fonts/IBMPlexMono-Italic.ttf')
resource.AddFile('resource/fonts/RussoOne-Regular.ttf')
-- the Combine alphabet (top left of the visor): put combine_alphabet.ttf into garrysmod/resource/fonts
for _, f in ipairs({'resource/fonts/combine_alphabet.ttf', 'resource/fonts/Combine_Alphabet.ttf'}) do
	if file.Exists(f, 'GAME') then resource.AddFile(f) end
end
resource.AddFile('resource/fonts/Play-Regular.ttf')
resource.AddFile('resource/fonts/Play-Bold.ttf')
resource.AddFile('resource/fonts/Exo2-Bold.ttf')
-- the monitor of the surveillance terminal in a higher resolution (hla_terminal_content)
for _, f in ipairs({'combine_intmonitor001', 'combine_intmonitor001_disp', 'combine_intmonitor001_disp_off'}) do
	resource.AddFile('materials/models/props_combine/' .. f .. '.vmt')
end
resource.AddSingleFile('materials/models/props_combine/combine_intmonitor001_normal.vtf')
resource.AddFile('resource/fonts/Exo2-SemiBold.ttf')
