-- Half-Life: Alyx gamemode for Garry's Mod: HL:A HUD, resin economy and the Combine fabricator.
GM.Name = 'Half-Life: Alyx'
GM.Author = 'newgametest'
GM.IsHLA = true
DeriveGamemode('sandbox')

HLA = HLA or {}
HLA.FabFiles = {
	shared = {'sh_math.lua', 'sh_config.lua', 'sh_layout.lua', 'sh_geometry.lua', 'sh_rig.lua', 'sh_station.lua'},
	client = {'cl_partmap.lua', 'cl_ui.lua', 'cl_parts.lua', 'cl_focus.lua'},
}
for _, f in ipairs(HLA.FabFiles.shared) do
	if SERVER then AddCSLuaFile('fabricator/' .. f) end
	include('fabricator/' .. f)
end
-- own class names, so a separately installed combine_fabricator addon can never replace them
CFRework.FabClass = 'hla_fabricator'
CFRework.ResinClass = 'hla_resin'
for _, f in ipairs(HLA.FabFiles.client) do
	if SERVER then AddCSLuaFile('fabricator/' .. f) else include('fabricator/' .. f) end
end

HLA.DropChance = CreateConVar('hla_resin_drop_chance', '0.6', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Chance an NPC drops resin')
HLA.StartResin = CreateConVar('hla_start_resin', '10', {FCVAR_ARCHIVE, FCVAR_NOTIFY}, 'Resin a new player starts with')
