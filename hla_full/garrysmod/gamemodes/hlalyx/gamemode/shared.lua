-- Half-Life: Alyx gamemode for Garry's Mod: HL:A HUD, resin economy and the Combine fabricator.
GM.Name = 'Half-Life: Alyx'
GM.Author = 'newgametest'
GM.IsHLA = true
DeriveGamemode('sandbox')

HLA = HLA or {}
HLA.FabFiles = {
	shared = {'sh_math.lua', 'sh_config.lua', 'sh_layout.lua', 'sh_station.lua'},
	client = {'cl_ui.lua', 'cl_focus.lua', 'cl_monitor.lua'},
}
for _, f in ipairs(HLA.FabFiles.shared) do
	if SERVER then AddCSLuaFile('fabricator/' .. f) end
	include('fabricator/' .. f)
end
-- own class names, so a separately installed combine_fabricator addon can never replace them
CFRework.FabClass = 'hla_fabricator'
CFRework.ResinClass = 'hla_resin'
CFRework.HintHook = 'HLAFabricatorHints'
for _, f in ipairs(HLA.FabFiles.client) do
	if SERVER then AddCSLuaFile('fabricator/' .. f) else include('fabricator/' .. f) end
end

-- main menu (characters) and movement with stamina
if SERVER then AddCSLuaFile('sh_menu.lua') AddCSLuaFile('sh_movement.lua') AddCSLuaFile('cl_menu.lua') end
include('sh_menu.lua')
if SERVER then AddCSLuaFile('sh_items.lua') AddCSLuaFile('cl_tabmenu.lua') AddCSLuaFile('cl_world.lua') end
include('sh_items.lua')
include('sh_movement.lua')
-- unit animations, chat, first person body view
if SERVER then AddCSLuaFile('sh_anims.lua') AddCSLuaFile('sh_chat.lua') AddCSLuaFile('cl_chat.lua') AddCSLuaFile('cl_view.lua') end
include('sh_anims.lua')
include('sh_chat.lua')
if SERVER then AddCSLuaFile('sh_voice.lua') AddCSLuaFile('sh_voicelines_data.lua') end
include('sh_voice.lua')
if SERVER then AddCSLuaFile('sh_squads.lua') AddCSLuaFile('cl_squads.lua') AddCSLuaFile('cl_hudcurve.lua') AddCSLuaFile('cl_ffmenu.lua') AddCSLuaFile('cl_ambient.lua') end
include('sh_squads.lua')

HLA.DropChance = CreateConVar('hla_resin_drop_chance', '0.6', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Chance an NPC drops resin')
HLA.StartResin = CreateConVar('hla_start_resin', '10', {FCVAR_ARCHIVE, FCVAR_NOTIFY}, 'Resin a new player starts with')
