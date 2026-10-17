-- The framework's own keys (changed in the pause menu → Бинды, saved per player):
--   Инвентарь (Q), Круговое меню (G), Предохранитель (R, hold), Третье / первое лицо (F3),
--   Сменить плечо (F4), Принять / Отказаться от запроса другого игрока (F1 / F2), Рация: настроить (B),
--   Рация: говорить (H, зажать).
-- The client turns a press into hook.Run("NWKey", id); the safety key is read by the server too
-- (the convars go with the userinfo).

NW.keys = NW.keys or {}

local KS = NW.keys

KS.list = {
	{id = "inventory", name = "Инвентарь", convar = "nw_key_inventory", default = KEY_Q},
	{id = "wheel", name = "Круговое меню", convar = "nw_key_wheel", default = KEY_G},
	{id = "safety", name = "Предохранитель (зажать)", convar = "nw_key_safety", default = KEY_R},
	{id = "camera", name = "Третье / первое лицо", convar = "nw_key_camera", default = KEY_F3},
	{id = "shoulder", name = "Сменить плечо", convar = "nw_key_shoulder", default = KEY_F4},
	{id = "accept", name = "Принять запрос", convar = "nw_key_accept", default = KEY_F1},
	{id = "decline", name = "Отказаться от запроса", convar = "nw_key_decline", default = KEY_F2},
	{id = "radio", name = "Рация: настроить", convar = "nw_key_radio", default = KEY_B},
	{id = "radio_talk", name = "Рация: говорить (зажать)", convar = "nw_key_radio_talk", default = KEY_H},
	{id = "thermal", name = "Тепловизор (Альянс)", convar = "nw_key_thermal", default = KEY_N}
}

KS.byID = {}

for _, key in ipairs(KS.list) do
	KS.byID[key.id] = key

	if (CLIENT) then
		CreateClientConVar(key.convar, tostring(key.default), true, true, "Клавиша: " .. key.name)
	end
end

-- the key of an action (for a player on the server)
function KS.Get(id, client)
	local key = KS.byID[id]

	if (!key) then
		return
	end

	if (SERVER) then
		return IsValid(client) and client:GetInfoNum(key.convar, key.default) or key.default
	end

	local convar = GetConVar(key.convar)

	return convar and convar:GetInt() or key.default
end

if (CLIENT) then
	hook.Add("PlayerButtonDown", "nwKeys", function(client, button)
		if (!IsFirstTimePredicted() or client != LocalPlayer() or vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or
			(NW.Incapable and NW.Incapable(client))) then
			return
		end

		for _, key in ipairs(KS.list) do
			if (KS.Get(key.id) == button) then
				hook.Run("NWKey", key.id)
			end
		end
	end)

	-- letting a key go (held keys: the radio)
	hook.Add("PlayerButtonUp", "nwKeys", function(client, button)
		if (!IsFirstTimePredicted() or client != LocalPlayer()) then
			return
		end

		for _, key in ipairs(KS.list) do
			if (KS.Get(key.id) == button) then
				hook.Run("NWKeyUp", key.id)
			end
		end
	end)
end
