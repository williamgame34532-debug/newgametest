-- Combine Fabricator loader
local shared = {'sh_math.lua', 'sh_config.lua', 'sh_layout.lua', 'sh_geometry.lua', 'sh_rig.lua', 'sh_station.lua'}
local client = {'cl_partmap.lua', 'cl_ui.lua', 'cl_parts.lua'}

for _, f in ipairs(shared) do
	if SERVER then AddCSLuaFile('cf_rework/' .. f) end
	include('cf_rework/' .. f)
end
for _, f in ipairs(client) do
	if SERVER then AddCSLuaFile('cf_rework/' .. f) else include('cf_rework/' .. f) end
end

if SERVER then
	include('cf_rework/sv_resin.lua')
	local function sendFolder(path)
		local files, dirs = file.Find(path .. '/*', 'GAME')
		for _, name in ipairs(files or {}) do resource.AddFile(path .. '/' .. name) end
		for _, name in ipairs(dirs or {}) do sendFolder(path .. '/' .. name) end
	end
	for _, path in ipairs({'models/cf_rework', 'materials/cf_rework', 'materials/models/cf_rework', 'sound/combine_fabricator'}) do
		sendFolder(path)
	end
	resource.AddFile('resource/fonts/RobotoCondensed-Regular.ttf')
	resource.AddFile('resource/fonts/RobotoCondensed-Bold.ttf')
end
