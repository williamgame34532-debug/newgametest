NETWORK.lang = NETWORK.lang or {}
NETWORK.lang.stored = NETWORK.lang.stored or {}
NETWORK.lang.default = "ru"

local languageConVar

if (CLIENT) then

	languageConVar = CreateClientConVar("network_language", "ru", true, false,
		"Язык интерфейса Network: ru, en или auto")

	cvars.AddChangeCallback("network_language", function()

		if (IsValid(NETWORK.gui.menu)) then
			NETWORK.gui.OpenMainMenu()
		end
	end, "nwLanguage")
end

function NETWORK.lang.Register(id, data)
	NETWORK.lang.stored[id] = table.Merge(NETWORK.lang.stored[id] or {}, data)
end

function NETWORK.lang.GetCurrent()
	if (CLIENT and languageConVar) then
		local id = languageConVar:GetString()

		if (id == "auto") then
			local convar = GetConVar("gmod_language")

			id = convar and convar:GetString() or NETWORK.lang.default
		end

		if (NETWORK.lang.stored[id]) then
			return id
		end
	end

	return NETWORK.lang.default
end

function NETWORK.lang.Exists(key)
	local current = NETWORK.lang.stored[NETWORK.lang.GetCurrent()]

	return (current and current[key] != nil) or
		(NETWORK.lang.stored[NETWORK.lang.default] or {})[key] != nil
end

function NETWORK.lang.Get(key, ...)
	if (!isstring(key)) then
		return ""
	end

	local current = NETWORK.lang.stored[NETWORK.lang.GetCurrent()] or {}
	local phrase = current[key]

	if (phrase == nil) then
		phrase = (NETWORK.lang.stored[NETWORK.lang.default] or {})[key]
	end

	if (phrase == nil) then
		return key
	end

	if (select("#", ...) > 0) then
		local bSuccess, result = pcall(string.format, phrase, ...)

		if (bSuccess) then
			return result
		end

		return phrase
	end

	return phrase
end

L = NETWORK.lang.Get

if (CLIENT) then
	hook.Add("InitPostEntity", "nwLangCheck", function()
		timer.Simple(8, function()
			local count = table.Count(NETWORK.lang.stored[NETWORK.lang.default] or {})

			if (count >= 3000) then
				return
			end

			local text = "[Network] Языковые файлы не загрузились (" .. count ..
				" строк) — вместо текстов видны ключи. Закройте игру, удалите папку " ..
				"garrysmod/cache/lua и зайдите снова."

			MsgC(Color(240, 90, 80), text .. "\n")

			if (chat and chat.AddText) then
				chat.AddText(Color(240, 90, 80), text)
			end
		end)
	end)
end
