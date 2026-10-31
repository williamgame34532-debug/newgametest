if SERVER then AddCSLuaFile('cf_rework/sh_config.lua') AddCSLuaFile('cf_rework/sh_motion.lua') end
include('cf_rework/sh_config.lua')
include('cf_rework/sh_motion.lua')
if SERVER then
 include('cf_rework/sv_resin.lua')
 local function sendFolder(path)
  local files,dirs=file.Find(path..'/*','GAME')
  for _,name in ipairs(files) do resource.AddFile(path..'/'..name) end
  for _,name in ipairs(dirs) do sendFolder(path..'/'..name) end
 end
 for _,path in ipairs({'models/cf_rework','materials/cf_rework','materials/models/cf_rework','sound/combine_fabricator'}) do sendFolder(path) end
 resource.AddFile('resource/fonts/RobotoCondensed-Regular.ttf')
 resource.AddFile('resource/fonts/RobotoCondensed-Bold.ttf')
end
