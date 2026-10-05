local down = {}

local function IsBusy()
	if (gui.IsGameUIVisible() or NETWORK.hud.IsHidden()) then
		return true
	end

	local focus = vgui.GetKeyboardFocus()

	if (IsValid(focus) and focus:IsVisible()) then
		return true
	end

	if (IsValid(NETWORK.gui.chat) and NETWORK.gui.chat.bActive) then
		return true
	end

	return IsValid(NETWORK.gui.bindMenu) or IsValid(NETWORK.gui.menu) or
		IsValid(NETWORK.gui.tabMenu) or IsValid(NETWORK.gui.escape)
end

hook.Add("Think", "nwBinds", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	for _, data in ipairs(NETWORK.bind.GetAll()) do
		if (data.bExternal or !data.OnRun) then
			continue
		end

		local key = NETWORK.bind.GetKey(data)

		if (key <= KEY_NONE) then
			continue
		end

		local bDown = input.IsKeyDown(key)

		if (bDown and !down[data.id] and !IsBusy()) then
			NETWORK.util.SafeCall("бинд " .. data.id, data.OnRun)
		end

		down[data.id] = bDown
	end
end)
