-- Иконки голосового чата над головами игроков.
hook.Add("Initialize", "HLARP.DisableVoiceIcons", function()
	RunConsoleCommand("mp_show_voice_icons", "0")
end)
