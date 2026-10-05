NETWORK.sound = NETWORK.sound or {}

NETWORK.sound.paths = {
	click = "framework/buttons/click.wav",
	clickAlt = "framework/buttons/click2.ogg",
	hover1 = "framework/buttons/textline_1.wav",
	hover2 = "framework/buttons/textline_2.wav",
	hover3 = "framework/buttons/textline_3.wav"
}

NETWORK.sound.menu = {
	hover = {},
	press = {},
	load = {}
}

for i = 1, 6 do
	NETWORK.sound.menu.hover[i] = "menus/mainmenu/selectsound_" .. i .. ".wav"
end

for i = 1, 3 do
	NETWORK.sound.menu.press[i] = "menus/mainmenu/pressound_" .. i .. ".wav"
	NETWORK.sound.menu.load[i] = "menus/mainmenu/load/loading" .. i .. ".wav"
end

NETWORK.sound.menu.createSelect = {}
NETWORK.sound.menu.createPress = {}

for i = 1, 2 do
	NETWORK.sound.menu.createSelect[i] = "menus/mainmenu/create/select" .. i .. ".wav"
	NETWORK.sound.menu.createPress[i] = "menus/mainmenu/create/press" .. i .. ".wav"
end

NETWORK.sound.menu.tabSelect = {"menus/ui/select_tab.mp3"}
NETWORK.sound.menu.hint = {"menus/ui/hint.wav"}
NETWORK.sound.menu.chatOpen = {"menus/ui/chat_open.wav"}
NETWORK.sound.menu.tabPress = {"menus/ui/click_tab.mp3"}

NETWORK.sound.menu.invMove = {}
NETWORK.sound.menu.invSelect = {}
NETWORK.sound.menu.invStack = {"menus/ui/inv_stack.wav"}

for i = 1, 3 do
	NETWORK.sound.menu.invMove[i] = "menus/ui/inv_move" .. i .. ".mp3"
end

for i = 1, 2 do
	NETWORK.sound.menu.invSelect[i] = "menus/ui/inv_select" .. i .. ".wav"
end

NETWORK.sound.menu.start = {}

for i = 1, 5 do
	NETWORK.sound.menu.start[i] = "player/load/start" .. i .. ".mp3"
end

NETWORK.sound.computer = {
	keys = {
		"ambient/machines/keyboard1_clicks.wav",
		"ambient/machines/keyboard2_clicks.wav",
		"ambient/machines/keyboard3_clicks.wav",
		"ambient/machines/keyboard4_clicks.wav",
		"ambient/machines/keyboard6_clicks.wav"
	},
	enter = "ambient/machines/keyboard7_clicks_enter.wav",
	open = "buttons/button9.wav",
	deny = "buttons/combine_button_locked.wav",
	hum = "ambient/machines/computer_ambient_loop.wav"
}

function NETWORK.sound.ComputerKeys()
	local list = NETWORK.sound.computer.keys

	return list[math.random(#list)]
end

NETWORK.sound.music = {
	menu = {
		"framework/music/mainmenu/passive.mp3",
		"framework/music/mainmenu/passive2.mp3",
		"framework/music/mainmenu/passive3.mp3"
	},
	game = {
		"framework/music/game/passive1.mp3",
		"framework/music/game/passive2.mp3",
		"framework/music/game/passive3.mp3"
	}
}
