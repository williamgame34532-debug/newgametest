GM.Name = "Network: Half-Life Alyx v2"
GM.Author = "Network's Framework"
GM.Website = "https://discord.gg/network"

NETWORK = NETWORK or {}
NETWORK.name = "Network's Framework"
NETWORK.schema = "hlalyx"
NETWORK.schemaName = "Network: Half-Life Alyx v2"
NETWORK.version = "0.9.0"
NETWORK.build = "22.09"
NETWORK.discord = "https://discord.gg/network"
NETWORK.gui = NETWORK.gui or {}
NETWORK.util = NETWORK.util or {}
NETWORK.meta = NETWORK.meta or {}
NETWORK.folder = (GM and GM.FolderName) or "network"

do
	player_manager.nwTranslateModel = player_manager.nwTranslateModel or
		player_manager.TranslateToPlayerModelName

	function player_manager.TranslateToPlayerModelName(model)
		model = string.gsub(string.lower(model), "\\", "/")

		local result = player_manager.nwTranslateModel(model)

		if (result == "kleiner" and !string.find(model, "kleiner")) then
			local candidates = {
				string.gsub(model, "models/", "models/player/"),
				string.gsub(model, "models/humans", "models/player"),
				string.gsub(model, "models/zombie/", "models/player/zombie_")
			}

			for _, candidate in ipairs(candidates) do
				local translated = player_manager.nwTranslateModel(candidate)

				if (translated != "kleiner") then
					return translated
				end
			end
		end

		return result
	end
end

function NETWORK.util.Print(...)
	MsgC(Color(79, 195, 232), "[Network] ", Color(233, 239, 245), ...)
	MsgN()
end

function NETWORK.util.PrintWarning(...)
	MsgC(Color(240, 186, 74), "[Network] ", Color(233, 239, 245), ...)
	MsgN()
end

function NETWORK.util.Include(path, state)
	if (!path) then
		return
	end

	local name = string.GetFileFromFilename(path) or path

	if (state == "server" or (!state and name:sub(1, 3) == "sv_")) then
		if (SERVER) then
			include(path)
		end

		return
	end

	if (state == "client" or (!state and name:sub(1, 3) == "cl_")) then
		if (SERVER) then
			AddCSLuaFile(path)
		else
			include(path)
		end

		return
	end

	if (SERVER) then
		AddCSLuaFile(path)
	end

	include(path)
end

function NETWORK.util.IncludeDir(directory, bFromLua)
	local base = bFromLua and "" or (NETWORK.folder .. "/gamemode/")
	local files, folders = file.Find(base .. directory .. "/*", "LUA")

	for _, name in ipairs(files or {}) do
		if (name:sub(-4) == ".lua") then
			NETWORK.util.Include(base .. directory .. "/" .. name)
		end
	end

	for _, name in ipairs(folders or {}) do
		NETWORK.util.IncludeDir(directory .. "/" .. name, bFromLua)
	end
end

local libs = NETWORK.folder .. "/gamemode/core/libs/"

NETWORK.util.Include(libs .. "sh_diagwrap.lua")

NETWORK.util.Include(libs .. "sh_util.lua")
NETWORK.util.Include(libs .. "sh_lang.lua")

NETWORK.util.IncludeDir("lang")

NETWORK.util.Include(libs .. "cl_util.lua")
NETWORK.util.Include(libs .. "cl_invfilter.lua")
NETWORK.util.Include(libs .. "cl_civhud.lua")

NETWORK.util.Include(libs .. "sh_notice.lua")
NETWORK.util.Include(libs .. "sh_sound.lua")
NETWORK.util.Include(libs .. "cl_sound.lua")
NETWORK.util.Include(libs .. "cl_theme.lua")
NETWORK.util.Include(libs .. "cl_fonts.lua")
NETWORK.util.Include(libs .. "cl_uistyle.lua")
NETWORK.util.Include(libs .. "cl_postprocess.lua")
NETWORK.util.Include(libs .. "cl_postfx.lua")
NETWORK.util.Include(libs .. "cl_perf.lua")

NETWORK.util.Include(libs .. "cl_nameplate.lua")

NETWORK.util.Include(libs .. "sh_currency.lua")
NETWORK.util.Include(libs .. "sv_currency.lua")
NETWORK.util.Include(libs .. "sh_item.lua")
NETWORK.util.Include(libs .. "sh_inventory.lua")
NETWORK.util.Include(libs .. "sh_container.lua")
NETWORK.util.Include(libs .. "sv_inventory.lua")
NETWORK.util.Include(libs .. "cl_inventory.lua")
NETWORK.util.Include(libs .. "sv_container.lua")
NETWORK.util.Include(libs .. "cl_container.lua")
NETWORK.util.Include(libs .. "cl_containerlabel.lua")
NETWORK.util.Include(libs .. "sh_containerprops.lua")
NETWORK.util.Include(libs .. "sh_ration.lua")
NETWORK.util.Include(libs .. "sh_permission.lua")
NETWORK.util.Include(libs .. "sh_sandbox.lua")

NETWORK.util.Include(libs .. "sh_shopplace.lua")
NETWORK.util.Include(libs .. "sv_shopplace.lua")
NETWORK.util.Include(libs .. "cl_shopplace.lua")
NETWORK.util.Include(libs .. "sh_command.lua")
NETWORK.util.Include(libs .. "sh_recognition.lua")
NETWORK.util.Include(libs .. "sv_recognition.lua")
NETWORK.util.Include(libs .. "cl_recognition.lua")
NETWORK.util.Include(libs .. "sh_voice.lua")

NETWORK.util.IncludeDir("voicelines")
NETWORK.util.Include(libs .. "sv_vosounds.lua")
NETWORK.util.Include(libs .. "sv_visor.lua")
NETWORK.util.Include(libs .. "cl_visor.lua")
NETWORK.util.Include(libs .. "sh_nvg.lua")
NETWORK.util.Include(libs .. "sv_nvg.lua")
NETWORK.util.Include(libs .. "cl_nvg.lua")
NETWORK.util.Include(libs .. "sh_squad.lua")

NETWORK.util.Include(libs .. "sh_squadorders.lua")
NETWORK.util.Include(libs .. "sh_dispatch.lua")
NETWORK.util.Include(libs .. "sh_loyalty.lua")
NETWORK.util.Include(libs .. "sv_manhack.lua")
NETWORK.util.Include(libs .. "sv_overwatch.lua")
NETWORK.util.Include(libs .. "cl_damageflash.lua")
NETWORK.util.Include(libs .. "cl_visorcurve.lua")
NETWORK.util.Include(libs .. "cl_combinehud.lua")
NETWORK.util.Include(libs .. "sh_cmbterminal.lua")
NETWORK.util.Include(libs .. "sv_cmbterminal.lua")
NETWORK.util.Include(libs .. "sv_detain.lua")
NETWORK.util.Include(libs .. "sv_business.lua")
NETWORK.util.Include(libs .. "cl_minigames.lua")
NETWORK.util.Include(libs .. "sv_mechanic.lua")
NETWORK.util.Include(libs .. "cl_cmbterminal.lua")
NETWORK.util.Include(libs .. "sh_terminal.lua")
NETWORK.util.Include(libs .. "sv_terminal.lua")
NETWORK.util.Include(libs .. "sv_terminalpages.lua")
NETWORK.util.Include(libs .. "cl_terminal.lua")
NETWORK.util.Include(libs .. "sh_icon.lua")
NETWORK.util.Include(libs .. "sv_icon.lua")
NETWORK.util.Include(libs .. "cl_icon.lua")

NETWORK.util.Include(libs .. "sh_itemedit.lua")
NETWORK.util.Include(libs .. "sv_itemedit.lua")
NETWORK.util.Include(libs .. "cl_itemedit.lua")
NETWORK.util.Include(libs .. "sv_displabel.lua")
NETWORK.util.Include(libs .. "cl_displabel.lua")
NETWORK.util.Include(libs .. "sh_chat.lua")
NETWORK.util.Include(libs .. "sv_chat.lua")
NETWORK.util.Include(libs .. "cl_chatlayout.lua")
NETWORK.util.Include(libs .. "cl_chat.lua")
NETWORK.util.Include(libs .. "sh_movement.lua")
NETWORK.util.Include(libs .. "sh_needs.lua")
NETWORK.util.Include(libs .. "cl_viewchain.lua")
NETWORK.util.Include(libs .. "sv_ragdoll.lua")
NETWORK.util.Include(libs .. "cl_ragdoll.lua")
NETWORK.util.Include(libs .. "sh_wound.lua")
NETWORK.util.Include(libs .. "sh_pain.lua")
NETWORK.util.Include(libs .. "sh_bleed.lua")
NETWORK.util.Include(libs .. "sh_suppress.lua")
NETWORK.util.Include(libs .. "sv_wound.lua")

NETWORK.util.Include(libs .. "sh_weaponwear.lua")
NETWORK.util.Include(libs .. "sv_weaponwear.lua")
NETWORK.util.Include(libs .. "cl_wound.lua")
NETWORK.util.Include(libs .. "sv_needs.lua")

NETWORK.util.Include(libs .. "sh_spoil.lua")
NETWORK.util.Include(libs .. "sv_spoil.lua")
NETWORK.util.Include(libs .. "sh_disease.lua")
NETWORK.util.Include(libs .. "sv_disease.lua")
NETWORK.util.Include(libs .. "sh_option.lua")
NETWORK.util.Include(libs .. "sh_combat.lua")
NETWORK.util.Include(libs .. "sh_weapon.lua")
NETWORK.util.Include(libs .. "sv_weapon.lua")
NETWORK.util.Include(libs .. "cl_weapon.lua")
NETWORK.util.Include(libs .. "sh_fabricator.lua")

NETWORK.util.Include(libs .. "sh_craft.lua")
NETWORK.util.Include(libs .. "sv_craft.lua")
NETWORK.util.Include(libs .. "cl_craft.lua")
NETWORK.util.Include(libs .. "sv_fabricator.lua")
NETWORK.util.Include(libs .. "cl_fabricator.lua")
NETWORK.util.Include(libs .. "sh_jail.lua")
NETWORK.util.Include(libs .. "sv_jail.lua")
NETWORK.util.Include(libs .. "cl_jail.lua")
NETWORK.util.Include(libs .. "sh_deploy.lua")
NETWORK.util.Include(libs .. "sv_deploy.lua")
NETWORK.util.Include(libs .. "cl_deploy.lua")
NETWORK.util.Include(libs .. "sh_junk.lua")
NETWORK.util.Include(libs .. "sv_junk.lua")
NETWORK.util.Include(libs .. "cl_junk.lua")
NETWORK.util.Include(libs .. "sh_junkprops.lua")
NETWORK.util.Include(libs .. "sh_persistprops.lua")
NETWORK.util.Include(libs .. "sh_modelprops.lua")
NETWORK.util.Include(libs .. "sh_binds.lua")
NETWORK.util.Include(libs .. "cl_binds.lua")
NETWORK.util.Include(libs .. "sh_scanner.lua")
NETWORK.util.Include(libs .. "sv_scanner.lua")
NETWORK.util.Include(libs .. "cl_scanner.lua")
NETWORK.util.Include(libs .. "sv_relations.lua")
NETWORK.util.Include(libs .. "sh_restraint.lua")
NETWORK.util.Include(libs .. "sv_restraint.lua")
NETWORK.util.Include(libs .. "cl_voiceicon.lua")
NETWORK.util.Include(libs .. "cl_interact.lua")
NETWORK.util.Include(libs .. "sv_spawns.lua")
NETWORK.util.Include(libs .. "sv_search.lua")
NETWORK.util.Include(libs .. "sh_breach.lua")
NETWORK.util.Include(libs .. "sv_breach.lua")
NETWORK.util.Include(libs .. "cl_view.lua")

NETWORK.util.Include(libs .. "cl_camera.lua")

NETWORK.util.Include(libs .. "cl_cityfeel.lua")

NETWORK.util.Include(libs .. "cl_thirdperson.lua")

NETWORK.util.Include(libs .. "cl_immersive.lua")
NETWORK.util.Include(libs .. "cl_camerasway.lua")
NETWORK.util.Include(libs .. "cl_crosshair.lua")
NETWORK.util.Include(libs .. "cl_cursor.lua")
NETWORK.util.Include(libs .. "cl_hud.lua")
NETWORK.util.Include(libs .. "cl_legs.lua")
NETWORK.util.Include(libs .. "cl_weaponselect.lua")
NETWORK.util.Include(libs .. "cl_spawnitems.lua")
NETWORK.util.Include(libs .. "cl_worlditem.lua")
NETWORK.util.Include(libs .. "cl_chatbubble.lua")
NETWORK.util.Include(libs .. "cl_adminesp.lua")
NETWORK.util.Include(libs .. "sv_movement.lua")

NETWORK.util.Include(libs .. "sh_sequence.lua")
NETWORK.util.Include(libs .. "sh_anims.lua")
NETWORK.util.Include(libs .. "sh_animseq.lua")
NETWORK.util.Include(libs .. "sh_animhooks.lua")

NETWORK.util.Include(NETWORK.folder .. "/gamemode/sh_animmap.lua")
NETWORK.util.Include(libs .. "sh_factions.lua")
NETWORK.util.Include(libs .. "sh_act.lua")
NETWORK.util.Include(libs .. "sv_act.lua")

NETWORK.util.IncludeDir("faction")

NETWORK.buildTag = "2026-09-28.57"

if (CLIENT) then
	timer.Simple(2, function()
		print("[Network] Клиентская сборка геймода: " .. NETWORK.buildTag)
	end)
else
	print("[Network] Серверная сборка геймода: " .. NETWORK.buildTag)
end

NETWORK.util.Include(libs .. "sh_creation.lua")
NETWORK.util.Include(libs .. "sh_character.lua")
NETWORK.util.Include(libs .. "sh_skills.lua")
NETWORK.util.Include(libs .. "sv_skills.lua")
NETWORK.util.Include(libs .. "cl_skills.lua")
NETWORK.util.Include(libs .. "cl_skillxp.lua")
NETWORK.util.Include(libs .. "sv_character.lua")
NETWORK.util.Include(libs .. "cl_character.lua")
NETWORK.util.Include(libs .. "sv_player.lua")
NETWORK.util.Include(libs .. "sv_permission.lua")
NETWORK.util.Include(libs .. "sh_quest.lua")
NETWORK.util.Include(libs .. "sh_questlist.lua")
NETWORK.util.Include(libs .. "sv_quest.lua")
NETWORK.util.Include(libs .. "cl_quest.lua")
NETWORK.util.Include(libs .. "sh_dialogue.lua")
NETWORK.util.Include(libs .. "sv_dialogue.lua")
NETWORK.util.Include(libs .. "cl_dialogue.lua")
NETWORK.util.Include(libs .. "sv_dialoguedata.lua")
NETWORK.util.Include(libs .. "cl_dialoguedata.lua")
NETWORK.util.Include(libs .. "sh_npcprops.lua")
NETWORK.util.Include(libs .. "sh_trade.lua")
NETWORK.util.Include(libs .. "sv_trade.lua")
NETWORK.util.Include(libs .. "cl_trade.lua")
NETWORK.util.Include(libs .. "sh_traderprops.lua")
NETWORK.util.Include(libs .. "sv_mapentities.lua")
NETWORK.util.Include(libs .. "sh_recruiter.lua")
NETWORK.util.Include(libs .. "sv_recruiter.lua")
NETWORK.util.Include(libs .. "cl_recruiter.lua")
NETWORK.util.Include(libs .. "sh_recruiterprops.lua")
NETWORK.util.Include(libs .. "sh_ledprops.lua")
NETWORK.util.Include(libs .. "sh_textprops.lua")
NETWORK.util.Include(libs .. "sh_door.lua")
NETWORK.util.Include(libs .. "sv_door.lua")
NETWORK.util.Include(libs .. "cl_door.lua")
NETWORK.util.Include(libs .. "sh_barricade.lua")
NETWORK.util.Include(libs .. "sv_barricade.lua")
NETWORK.util.Include(libs .. "sv_padlock.lua")
NETWORK.util.Include(libs .. "cl_barricade.lua")
NETWORK.util.Include(libs .. "sh_lockpick.lua")
NETWORK.util.Include(libs .. "sv_lockpick.lua")
NETWORK.util.Include(libs .. "cl_lockpick.lua")
NETWORK.util.Include(libs .. "sh_zone.lua")

NETWORK.util.Include(libs .. "sh_cutscene.lua")
NETWORK.util.Include(libs .. "sv_cutscene.lua")
NETWORK.util.Include(libs .. "cl_cutscene.lua")
NETWORK.util.Include(libs .. "sv_zone.lua")
NETWORK.util.Include(libs .. "cl_zone.lua")
NETWORK.util.Include(libs .. "sh_debug.lua")
NETWORK.util.Include(libs .. "sh_extras.lua")
NETWORK.util.Include(libs .. "sv_admin.lua")
NETWORK.util.Include(libs .. "sh_class.lua")
NETWORK.util.Include(libs .. "sv_class.lua")

NETWORK.util.IncludeDir("ranks")
NETWORK.util.Include(libs .. "sh_shield.lua")
NETWORK.util.Include(libs .. "sv_shield.lua")
NETWORK.util.Include(libs .. "sv_ambientfx.lua")
NETWORK.util.Include(libs .. "cl_shield.lua")
NETWORK.util.Include(libs .. "sv_noclip.lua")
NETWORK.util.Include(libs .. "sv_props.lua")
NETWORK.util.Include(libs .. "sv_welcome.lua")
NETWORK.util.Include(libs .. "sv_entities.lua")

NETWORK.util.Include(libs .. "cl_entities.lua")

NETWORK.util.Include(libs .. "sv_database.lua")
NETWORK.util.Include(libs .. "sv_persistence.lua")
NETWORK.util.Include(libs .. "sv_bots.lua")

NETWORK.util.Include(libs .. "sh_config.lua")
NETWORK.util.Include(libs .. "sh_time.lua")
NETWORK.util.Include(libs .. "sh_weather.lua")
NETWORK.util.Include(libs .. "cl_weather.lua")
NETWORK.util.Include(libs .. "sh_climate.lua")
NETWORK.util.Include(libs .. "sv_climate.lua")
NETWORK.util.Include(libs .. "cl_climate.lua")

NETWORK.util.Include(libs .. "cl_label.lua")
NETWORK.util.Include(libs .. "sh_group.lua")
NETWORK.util.Include(libs .. "sv_group.lua")
NETWORK.util.Include(libs .. "cl_group.lua")
NETWORK.util.Include(libs .. "sv_camera.lua")
NETWORK.util.Include(libs .. "sv_menucamera.lua")
NETWORK.util.Include(libs .. "sh_startkit.lua")
NETWORK.util.Include(libs .. "sh_version.lua")
NETWORK.util.Include(libs .. "sh_log.lua")

NETWORK.util.Include(libs .. "sh_protect.lua")
NETWORK.util.Include(libs .. "sh_flag.lua")
NETWORK.util.Include(libs .. "sh_combine.lua")
NETWORK.util.Include(libs .. "sh_needsemotes.lua")
NETWORK.util.Include(libs .. "sv_pipegame.lua")
NETWORK.util.Include(libs .. "sv_polish.lua")
NETWORK.util.Include(libs .. "cl_polish.lua")
NETWORK.util.Include(libs .. "sh_schedule.lua")

NETWORK.util.Include(libs .. "sh_waypoint.lua")
NETWORK.util.Include(libs .. "sv_waypoint.lua")
NETWORK.util.Include(libs .. "cl_waypoint.lua")
NETWORK.util.Include(libs .. "sv_schedule.lua")
NETWORK.util.Include(libs .. "sv_config.lua")
NETWORK.util.Include(libs .. "cl_config.lua")

NETWORK.util.Include(libs .. "sh_trap.lua")
NETWORK.util.Include(libs .. "sv_trap.lua")
NETWORK.util.Include(libs .. "cl_trap.lua")

NETWORK.util.Include(libs .. "sh_toughness.lua")
NETWORK.util.Include(libs .. "sh_medical.lua")
NETWORK.util.Include(libs .. "sv_medical.lua")
NETWORK.util.Include(libs .. "cl_medical.lua")
NETWORK.util.Include(libs .. "sh_playermenu.lua")
NETWORK.util.Include(libs .. "sv_playermenu.lua")
NETWORK.util.Include(libs .. "sh_cid.lua")
NETWORK.util.Include(libs .. "sv_cid.lua")
NETWORK.util.Include(libs .. "sh_documents.lua")
NETWORK.util.Include(libs .. "sv_documents.lua")
NETWORK.util.Include(libs .. "sh_supply.lua")
NETWORK.util.Include(libs .. "sv_supply.lua")
NETWORK.util.Include(libs .. "sh_channels.lua")
NETWORK.util.Include(libs .. "sv_channels.lua")
NETWORK.util.Include(libs .. "sv_cmbservices.lua")
NETWORK.util.Include(libs .. "cl_cmbservices.lua")
NETWORK.util.Include(libs .. "sh_vortsweep.lua")
NETWORK.util.Include(libs .. "sh_vortpowers.lua")
NETWORK.util.Include(libs .. "sh_vortvoice.lua")
NETWORK.util.Include(libs .. "sh_vortbeamfix.lua")
NETWORK.util.Include(libs .. "cl_vortvision.lua")
NETWORK.util.Include(libs .. "cl_vortdiag.lua")
NETWORK.util.Include(libs .. "sv_vortpowers.lua")
NETWORK.util.Include(libs .. "cl_vortpowers.lua")
NETWORK.util.Include(libs .. "sh_factorywork.lua")
NETWORK.util.Include(libs .. "sv_factorywork.lua")
NETWORK.util.Include(libs .. "cl_factorywork.lua")
NETWORK.util.Include(libs .. "cl_npclook.lua")
NETWORK.util.Include(libs .. "cl_factoryui.lua")
NETWORK.util.Include(libs .. "cl_cuffs.lua")
NETWORK.util.Include(libs .. "sh_emp.lua")
NETWORK.util.Include(libs .. "cl_emp.lua")
NETWORK.util.Include(libs .. "sh_admincomp.lua")
NETWORK.util.Include(libs .. "sh_budget.lua")
NETWORK.util.Include(libs .. "sh_mail.lua")
NETWORK.util.Include(libs .. "sh_parcel.lua")
NETWORK.util.Include(libs .. "sh_decisions.lua")
NETWORK.util.Include(libs .. "sh_placer.lua")
NETWORK.util.Include(libs .. "sh_housing.lua")
NETWORK.util.Include(libs .. "sh_radio.lua")

NETWORK.util.Include(libs .. "sh_voicefx.lua")
NETWORK.util.Include(libs .. "sv_voicefx.lua")
NETWORK.util.Include(libs .. "cl_voicefx.lua")
NETWORK.util.Include(libs .. "sh_store.lua")
NETWORK.util.Include(libs .. "sh_workbench.lua")

NETWORK.dialogue.LoadDirectory()

NETWORK.util.Include(libs .. "sh_optimize.lua")

NETWORK.util.Include(libs .. "sv_diag.lua")
NETWORK.util.Include(libs .. "cl_diag.lua")

NETWORK.util.Include(libs .. "cl_netcfg.lua")

NETWORK.util.Include(libs .. "cl_promptkeys.lua")

NETWORK.util.Include(libs .. "sv_events.lua")
NETWORK.util.Include(libs .. "cl_events.lua")

NETWORK.util.Include(libs .. "sh_journal.lua")
NETWORK.util.Include(libs .. "sh_medical_db.lua")
NETWORK.util.Include(libs .. "sh_mailbox.lua")
NETWORK.util.Include(libs .. "sh_mailprops.lua")
NETWORK.util.Include(libs .. "sh_comppass.lua")
NETWORK.util.Include(libs .. "cl_armorwear.lua")
NETWORK.util.Include(libs .. "sh_trash.lua")
NETWORK.util.Include(libs .. "sh_board.lua")

NETWORK.util.Include(libs .. "sh_campfire.lua")

NETWORK.util.Include(libs .. "sv_antidupe.lua")
NETWORK.util.Include(libs .. "sv_deathloss.lua")
NETWORK.util.Include(libs .. "sv_economy2.lua")
NETWORK.util.Include(libs .. "sv_stashcode.lua")

NETWORK.util.Include(libs .. "sv_mechanics_a.lua")
NETWORK.util.Include(libs .. "sh_mechanics_b.lua")

NETWORK.util.Include(libs .. "sh_alert.lua")
NETWORK.util.Include(libs .. "sv_alert.lua")
NETWORK.util.Include(libs .. "sh_rebels.lua")
NETWORK.util.Include(libs .. "sv_rebels.lua")
NETWORK.util.Include(libs .. "cl_rebels.lua")

NETWORK.util.Include(libs .. "sh_xenwatch.lua")
NETWORK.util.Include(libs .. "sv_xenwatch.lua")
NETWORK.util.Include(libs .. "sv_cpmarks.lua")
NETWORK.util.Include(libs .. "sv_loyaltyreq.lua")

NETWORK.util.Include(libs .. "sv_toolcharge.lua")
NETWORK.util.Include(libs .. "sh_issued.lua")
NETWORK.util.Include(libs .. "sv_onewaydoor.lua")
NETWORK.util.Include(libs .. "sv_blogextras.lua")

NETWORK.util.Include(libs .. "sh_credits.lua")

NETWORK.util.Include(libs .. "sh_lootprops.lua")
NETWORK.util.Include(libs .. "sv_lootprops.lua")
NETWORK.util.Include(libs .. "sv_discord.lua")

NETWORK.util.Include(libs .. "sh_build.lua")

NETWORK.util.Include(libs .. "cl_status.lua")

NETWORK.util.Include(libs .. "cl_disease.lua")

NETWORK.util.Include(libs .. "cl_propshover.lua")

NETWORK.util.Include(libs .. "cl_chgen.lua")

NETWORK.util.Include(libs .. "sh_pvp.lua")
NETWORK.util.Include(libs .. "sv_pvp.lua")
NETWORK.util.Include(libs .. "cl_pvp.lua")

NETWORK.util.Include(libs .. "sv_uptime.lua")

NETWORK.util.Include(libs .. "sh_spawnmenu.lua")
NETWORK.util.Include(libs .. "sh_player_requests.lua")
NETWORK.util.Include(libs .. "sh_cityupdate.lua")
NETWORK.util.Include(libs .. "sv_cityupdate.lua")
NETWORK.util.IncludeDir("core/city_assets")
NETWORK.util.Include(libs .. "cl_cityassets.lua")

NETWORK.util.Include(libs .. "cl_cityupdate.lua")

-- Purchasable apartments (tax + registered residence).
NETWORK.util.Include(libs .. "sh_apartments.lua")
NETWORK.util.Include(libs .. "sv_apartments.lua")

-- Client downloads for gamemode/content (compiled models, materials).
NETWORK.util.Include(libs .. "sv_content.lua")
NETWORK.util.IncludeDir("core/derma")

NETWORK.util.Include(libs .. "sh_plugin.lua")

function GM:Initialize()
	NETWORK.util.Print("==========================================")
	NETWORK.util.Print("  СБОРКА: " .. NETWORK.version .. "  ОТ " .. NETWORK.build)
	NETWORK.util.Print("==========================================")

	NETWORK.util.Print(string.format("%s %s (%s) загружен.", NETWORK.name, NETWORK.version,
		SERVER and "server" or "client"))
end
