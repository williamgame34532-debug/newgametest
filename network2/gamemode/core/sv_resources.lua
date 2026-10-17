-- files clients download from the server (the gamemode's content folder is mounted on the
-- server; players without it get these on join)
resource.AddFile("materials/network2/emblem.png")
resource.AddFile("materials/network2/watermark.png")
resource.AddFile("materials/network2/menu/button.png")
resource.AddFile("materials/network2/menu/button_hover.png")
resource.AddFile("materials/network2/menu/vignette.png")
resource.AddFile("resource/fonts/Jura-Medium.ttf")
resource.AddFile("resource/fonts/Jura-Bold.ttf")
resource.AddFile("sound/network2/ui/hover.wav")
resource.AddFile("sound/network2/ui/click.wav")
resource.AddFile("sound/network2/ui/confirm.mp3")
for _, name in ipairs({"hover_mech", "select_mech", "press_mech", "start_mech", "open_mech", "hover_cine",
	"select_cine", "start_cine", "success_cine", "open_cine"}) do
	resource.AddFile("sound/network2/ui/alt/" .. name .. ".wav")
end

-- character menus: fonts, panel materials, icons, sounds
for _, name in ipairs({"Exo2-Regular", "Exo2-SemiBold", "Exo2-Bold", "Exo2-Italic", "Montserrat-Medium",
	"Montserrat-SemiBold", "Oswald-Light", "Oswald-Medium", "Oswald-SemiBold", "JetBrainsMono-Medium",
	"JetBrainsMono-ExtraBold"}) do
	resource.AddFile("resource/fonts/" .. name .. ".ttf")
end

for _, name in ipairs({"panel", "button", "outline", "card_shade", "chat_panel", "chat_tab", "board_sheet",
	"board_edge", "board_menu"}) do
	resource.AddFile("materials/network2/ui/" .. name .. ".png")
end

for _, name in ipairs({"male", "female", "strength", "endurance", "medicine", "engineering", "stealth", "speech",
	"plus", "trash", "play", "back", "faction", "user", "height", "skin", "check", "chat", "resize"}) do
	resource.AddFile("materials/network2/ui/icons/" .. name .. ".png")
end

for _, name in ipairs({"hls_ui_appear", "hls_ui_affirm", "textline_1", "textline_2", "textline_3", "textline_4",
	"textline_5", "textline_6", "textline_7", "textline_8", "textline_end"}) do
	resource.AddFile("sound/network2/ui/char/" .. name .. ".wav")
end

for _, name in ipairs(NW.char.logos) do
	resource.AddFile("materials/network2/factions/" .. name .. ".png")
end

resource.AddFile("sound/network2/ui/chat_receive.wav")
resource.AddFile("sound/network2/weapon_equip.wav")

-- inventory: slot / tooltip / shade materials, item icons, interface icons, sounds
for _, name in ipairs({"inv_slot", "inv_cell", "inv_tip", "inv_shade"}) do
	resource.AddFile("materials/network2/ui/" .. name .. ".png")
end

local icons = {}

for _, item in pairs(NW.items.list) do
	icons[item.icon] = true
end

for _, slot in ipairs(NW.items.slots) do
	icons[slot.icon] = true
end

for name in pairs(icons) do
	resource.AddFile("materials/network2/items/" .. name .. ".png")
end

for _, name in ipairs({"inventory", "settings", "authors", "config", "health", "hunger", "thirst", "stamina", "take",
	"interact", "drop", "close", "mic", "voice_whisper", "voice_normal", "voice_yell", "acts", "back", "act_sit",
	"act_ground", "act_wall", "act_lie", "act_injured", "act_handsup", "act_arrest", "act_lean", "act_stand",
	"act_check", "act_foldarms", "act_kneel", "act_shiver", "door", "meet", "tokens", "cid", "examine", "pulse",
	"helpup", "heal", "search", "swap", "storage", "trade", "quest", "talk", "edit", "skull", "shield"}) do
	resource.AddFile("materials/network2/ui/icons/" .. name .. ".png")
end

for _, name in ipairs({"handle_small_leather", "handle_small_leather2", "drop_leather", "cloth_belt", "cloth_belt2",
	"cloth1", "cloth2", "cloth3", "cloth4", "belt_handle1", "belt_handle2", "metal_latch", "draw_knife1",
	"inv_move1", "inv_move2", "inv_move3", "inv_bandage", "choreo_foley_jacket1", "choreo_foley_jacket2"}) do
	resource.AddFile("sound/network2/inv/" .. name .. ".wav")
end

resource.AddFile("sound/network2/inv/inv_move4.mp3")

-- using items (eating, drinking, healing) and searching (branding/make_use_sounds.py)
for _, name in ipairs({"drink_water", "drink_soda", "eat_bread", "eat_canned", "eat_ration", "pills", "medkit",
	"bandage", "search_1", "search_2", "search_3", "search_4"}) do
	resource.AddFile("sound/network2/use/" .. name .. ".wav")
end

-- music (a separate archive, ~23 MB)
resource.AddFile("sound/network2/music/menu/a1_intro_strider2.mp3")

for i = 1, 10 do
	resource.AddFile(string.format("sound/network2/music/passive/passivemusic_%02d.mp3", i))
end

for i = 1, 5 do
	resource.AddFile("sound/network2/music/combat/combinemusic_" .. i .. ".mp3")
end

-- crosshair, low-health blood
resource.AddFile("materials/network2/ui/crosshair.png")
resource.AddFile("materials/network2/ui/blood_overlay.png")

-- the voice microphone
for _, name in ipairs({"mic_frame", "mic_fill", "mic_wave"}) do
	resource.AddFile("materials/network2/ui/" .. name .. ".png")
end

-- the E key plate, the unknown mark
resource.AddFile("materials/network2/ui/key.png")
resource.AddFile("materials/network2/ui/unknown.png")

-- notifications
resource.AddFile("sound/network2/ui/hls_hint.wav")

-- death / unconscious backgrounds, the NPC windows
resource.AddFile("materials/network2/ui/death_bg.png")
resource.AddFile("materials/network2/ui/knock_bg.png")

for _, name in ipairs({"panel", "answer", "answer_hover", "card", "plate", "shade"}) do
	resource.AddFile("materials/network2/ui/npc/" .. name .. ".png")
end

-- the civic terminal: wallpaper, cursors, sounds (branding/make_terminal_assets.py)
for _, name in ipairs({"wallpaper", "cursor", "cursor_hover"}) do
	resource.AddFile("materials/network2/terminal/" .. name .. ".png")
end


for _, name in ipairs({"station_hum_loop", "station_menu_alarm", "station_menu_appear", "station_menu_disappear",
	"station_menu_hover", "station_menu_select", "station_menu_select_denied", "station_slide_open",
	"station_slide_closed"}) do
	resource.AddFile("sound/network2/terminal/civic/" .. name .. ".wav")
end

-- Civil Protection gear on the run (sv_foley.lua)
for i = 1, 6 do
	resource.AddFile("sound/network2/metrocop/metrocop_foley_step_" .. i .. ".wav")
end

-- the radio of the Alliance (cl_chat.lua; combine_tech)
for i = 1, 5 do
	resource.AddFile(string.format("sound/network2/radio/combine_radio_on_%02d.wav", i))
end

for i = 1, 6 do
	resource.AddFile(string.format("sound/network2/radio/combine_radio_off_%02d.wav", i))
end

-- the visor of the Alliance (cl_combinehud.lua)
for _, name in ipairs({"cmb_overlay", "soldier_overlay", "elite_overlay"}) do
	resource.AddSingleFile("materials/network2/overlay/" .. name .. ".vmt")
end

for _, name in ipairs({"combine_overlay", "combine_overlay_normal", "soldier_overlay", "elite_overlay"}) do
	resource.AddSingleFile("materials/network2/overlay/" .. name .. ".vtf")
end

-- the Combine font of the Alliance HUD: put Combine_Alphabet.ttf into resource/fonts of the content
-- addon (the name of the font for the HUD: nw_hud_combine_font)
for _, name in ipairs({"Combine_Alphabet.ttf", "combine_alphabet.ttf", "Combine_Alphabet.otf"}) do
	if (file.Exists("resource/fonts/" .. name, "GAME")) then
		resource.AddSingleFile("resource/fonts/" .. name)
	end
end

-- whole folders of the content addon, as they are on the disk of the server (new icons, the squads,
-- the radio, the dispatcher, the entities of the Alliance and the factory, ...): every file goes
local function Folder(path)
	local files, folders = file.Find(path .. "/*", "GAME")

	for _, name in ipairs(files or {}) do
		resource.AddSingleFile(path .. "/" .. name)
	end

	for _, name in ipairs(folders or {}) do
		Folder(path .. "/" .. name)
	end
end

for _, path in ipairs({"materials/network2/ui/icons", "materials/network2/items", "materials/network2/squad",
	"materials/network2/cmb", "materials/network2/forcefield", "materials/network2/fx", "sound/network2/squad",
	"sound/network2/radio2", "sound/network2/dispatch", "sound/network2/overwatch", "sound/network2/forcefield",
	"sound/network2/lock", "sound/network2/dispenser", "sound/network2/cmbterminal", "sound/network2/stunstick",
	"sound/network2/factory", "sound/network2/voices/male01", "sound/network2/voices/female01", "sound/network2/weather"}) do
	Folder(path)
end
