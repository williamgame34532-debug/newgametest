-- Network: a clean base for the new framework. Everything stock on screen is off (cl_hud.lua),
-- the camera is third person (cl_thirdperson.lua) and players can wear the build's models with
-- all their animations (sh_models.lua, sh_anims.lua, sh_animhooks.lua).
-- Derived from sandbox so the spawn menu and tools stay available while the framework grows.

DeriveGamemode("sandbox")

GM.Name = "Network"
GM.Author = "Network"
GM.Website = ""

NW = NW or {}

function NW.Warn(text)
	MsgC(Color(255, 170, 60), "[Network] ", color_white, tostring(text), "\n")
end

local folder = GM.FolderName .. "/gamemode/core/"

-- load order matters: tables before the engine, models before the menu
local FILES = {
	"sh_anims.lua",
	"sh_animhooks.lua",
	"sh_raise.lua",
	"sh_models.lua",
	"sv_movement.lua",
	"sh_menu.lua",
	"sh_notify.lua",
	"sh_character.lua",
	"sh_items.lua",
	"sh_needs.lua",
	"sh_config.lua",
	"sh_acts.lua",
	"sh_keys.lua",
	"sh_progress.lua",
	"sh_npc.lua",
	"sh_zones.lua",
	"sh_doors.lua",
	"sh_noclip.lua",
	"sh_terminal.lua",
	"sv_character.lua",
	"sv_menu.lua",
	"sv_resources.lua",
	"sh_chat.lua",
	"sv_chat.lua",
	"sv_loadout.lua",
	"sv_admin.lua",
	"sv_needs.lua",
	"sv_inventory.lua",
	"sv_social.lua",
	"sv_storage.lua",
	"sv_body.lua",
	"sv_containers.lua",
	"sv_whitelist.lua",
	"sv_npc.lua",
	"sv_spawns.lua",
	"sv_zones.lua",
	"sv_doors.lua",
	"sv_terminal.lua",
	"sv_foley.lua",
	"sv_combinehud.lua",
	"sv_music.lua",
	"sv_config.lua",
	"cl_hud.lua",
	"cl_thirdperson.lua",
	"cl_dyncam.lua",
	"cl_legs.lua",
	"cl_modelmenu.lua",
	"cl_combineidle.lua",
	"cl_animcheck.lua",
	"cl_watermark.lua",
	"cl_ui.lua",
	"cl_widgets.lua",
	"cl_menu.lua",
	"cl_charcreate.lua",
	"cl_charselect.lua",
	"cl_chat.lua",
	"cl_weaponselect.lua",
	"cl_scoreboard.lua",
	"cl_inventory.lua",
	"cl_overhead.lua",
	"cl_postfx.lua",
	"cl_carry.lua",
	"cl_music.lua",
	"cl_pausemenu.lua",
	"cl_wheel.lua",
	"cl_speech.lua",
	"cl_crosshair.lua",
	"cl_wounds.lua",
	"cl_voice.lua",
	"cl_intro.lua",
	"cl_interact.lua",
	"cl_social.lua",
	"cl_exhaust.lua",
	"cl_body.lua",
	"cl_storage.lua",
	"cl_npc.lua",
	"cl_zones.lua",
	"cl_doors.lua",
	"cl_noclip.lua",
	"cl_terminal.lua",
	"cl_combinehud.lua",
	"sh_units.lua",
	"sv_units.lua",
	"sh_squads.lua",
	"sv_squads.lua",
	"cl_squads.lua",
	"sh_squadmarks.lua",
	"sh_radio.lua",
	"sh_voices_data.lua",
	"sh_voices.lua",
	"sh_overwatch.lua",
	"sv_cmbterminal.lua",
	"cl_cmbterminal.lua",
	"sh_cameras.lua",
	"sv_persist.lua",
	"sh_skills.lua",
	"cl_skills.lua",
	"cl_status.lua",
	"sh_cwu.lua",
	"sv_cwu.lua",
	"cl_cwu.lua",
	"sh_entsettings.lua",
	"sh_requests.lua",
	"sh_business.lua",
	"sh_rebels.lua",
	"sh_schedule.lua",
	"sh_fabricator.lua",
	"sv_pain.lua",
	"sh_contraband.lua",
	"sh_cleanup.lua",
	"sh_classes.lua",
	"sv_npcrelations.lua",
	"sh_itemedit.lua",
	"cl_itemedit.lua",
	"sh_craft.lua",
	"cl_craft.lua",
	"sh_weather.lua",
	"cl_weather.lua",
	"cl_vision.lua",
	"sh_incapable.lua"
}

for _, name in ipairs(FILES) do
	local path = folder .. name
	local realm = string.sub(name, 1, 3)

	if (realm == "cl_") then
		if (SERVER) then
			AddCSLuaFile(path)
		else
			include(path)
		end
	elseif (realm == "sv_") then
		if (SERVER) then
			include(path)
		end
	else
		if (SERVER) then
			AddCSLuaFile(path)
		end

		include(path)
	end
end
