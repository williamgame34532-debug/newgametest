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
CFRework.FabClass = 'hla_fabricator'
CFRework.ResinClass = 'hla_resin'
CFRework.HintHook = 'HLAFabricatorHints'
for _, f in ipairs(HLA.FabFiles.client) do
	if SERVER then AddCSLuaFile('fabricator/' .. f) else include('fabricator/' .. f) end
end

if SERVER then AddCSLuaFile('sh_menu.lua') AddCSLuaFile('sh_movement.lua') AddCSLuaFile('cl_menu.lua') end
include('sh_menu.lua')
if SERVER then AddCSLuaFile('sh_items.lua') AddCSLuaFile('cl_tabmenu.lua') AddCSLuaFile('cl_world.lua') end
include('sh_items.lua')
if SERVER then AddCSLuaFile('sh_fabcfg.lua') end
include('sh_fabcfg.lua')
include('sh_movement.lua')
if SERVER then AddCSLuaFile('sh_anims.lua') AddCSLuaFile('sh_chat.lua') AddCSLuaFile('cl_chat.lua') AddCSLuaFile('cl_view.lua') end
include('sh_anims.lua')
include('sh_chat.lua')
if SERVER then AddCSLuaFile('sh_voice.lua') AddCSLuaFile('sh_voicelines_data.lua') end
include('sh_voice.lua')
if SERVER then AddCSLuaFile('sh_squads.lua') AddCSLuaFile('cl_squads.lua') AddCSLuaFile('cl_hudcurve.lua') AddCSLuaFile('cl_ffmenu.lua') AddCSLuaFile('cl_ambient.lua') end
include('sh_squads.lua')
if SERVER then AddCSLuaFile('sh_dispatch.lua') AddCSLuaFile('sh_story.lua') AddCSLuaFile('cl_story.lua') AddCSLuaFile('cl_editor.lua') AddCSLuaFile('cl_voice.lua') AddCSLuaFile('cl_thirdperson.lua') AddCSLuaFile('cl_effects.lua') AddCSLuaFile('cl_pause.lua') AddCSLuaFile('cl_scoreboard.lua') AddCSLuaFile('cl_dropship.lua') AddCSLuaFile('cl_intro.lua') end
include('sh_dispatch.lua')
if SERVER then AddCSLuaFile('sh_radiovoice.lua') end
include('sh_radiovoice.lua')
include('sh_story.lua')
if SERVER then AddCSLuaFile('sh_markers.lua') end
include('sh_markers.lua')

HLA.DropChance = CreateConVar('hla_resin_drop_chance', '0.6', {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, 'Chance an NPC drops resin')
HLA.StartResin = CreateConVar('hla_start_resin', '10', {FCVAR_ARCHIVE, FCVAR_NOTIFY}, 'Resin a new player starts with')
