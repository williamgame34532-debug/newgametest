NETWORK.bind = NETWORK.bind or {}
NETWORK.bind.stored = NETWORK.bind.stored or {}
NETWORK.bind.order = NETWORK.bind.order or {}

function NETWORK.bind.Register(id, data)
	data.id = id
	data.convar = data.convar or ("network_bind_" .. id)
	data.default = data.default or KEY_NONE

	if (!NETWORK.bind.stored[id]) then
		NETWORK.bind.order[#NETWORK.bind.order + 1] = id
	end

	NETWORK.bind.stored[id] = data

	if (CLIENT) then
		CreateClientConVar(data.convar, tostring(data.default), true, false,
			data.help or "")
	end

	return data
end

function NETWORK.bind.Get(id)
	return NETWORK.bind.stored[id]
end

function NETWORK.bind.GetAll()
	local list = {}

	for _, id in ipairs(NETWORK.bind.order) do
		list[#list + 1] = NETWORK.bind.stored[id]
	end

	return list
end

if (CLIENT) then
	function NETWORK.bind.GetKey(data)
		local convar = GetConVar(data.convar)

		return convar and math.Round(convar:GetInt()) or KEY_NONE
	end

	function NETWORK.bind.SetKey(data, key)
		RunConsoleCommand(data.convar, tostring(math.max(key or KEY_NONE, 0)))
	end

	function NETWORK.bind.Assign(data, key)
		key = math.max(key or KEY_NONE, 0)

		if (key > KEY_NONE) then
			for _, other in ipairs(NETWORK.bind.GetAll()) do
				if (other != data and NETWORK.bind.GetKey(other) == key) then
					NETWORK.bind.SetKey(other, KEY_NONE)

					if (NETWORK.gui and NETWORK.gui.Notify) then
						NETWORK.gui.Notify(L("bindTakenFrom", L(other.name)), NETWORK.theme.combine)
					end
				end
			end
		end

		NETWORK.bind.SetKey(data, key)
	end

	hook.Add("InitPostEntity", "nwBindDedupe", function()
		local taken = {}

		for _, data in ipairs(NETWORK.bind.GetAll()) do
			local key = NETWORK.bind.GetKey(data)

			if (key > KEY_NONE) then
				if (taken[key]) then
					NETWORK.bind.SetKey(data, KEY_NONE)
				else
					taken[key] = data.id
				end
			end
		end
	end)

	function NETWORK.bind.GetKeyName(key)
		if (!key or key <= KEY_NONE) then
			return "—"
		end

		local name = input.GetKeyName(key)

		return string.upper(name and language.GetPhrase(name) or "?")
	end

	local function OpenTab(tab)
		return function()
			local menu = NETWORK.gui.OpenTabMenu()

			if (IsValid(menu) and tab) then
				menu:SetTab(tab)
			end
		end
	end

	NETWORK.bind.Register("inventory", {
		name = "bindInventory",
		OnRun = OpenTab("inventory")
	})

	NETWORK.bind.Register("character", {
		name = "bindCharacter",
		OnRun = OpenTab("character")
	})

	NETWORK.bind.Register("quests", {
		name = "bindQuests",
		OnRun = function()
			NETWORK.gui.OpenQuestLog()
		end
	})

	NETWORK.bind.Register("help", {
		name = "bindHelp",
		OnRun = function()
			NETWORK.gui.OpenHelp()
		end
	})

	NETWORK.bind.Register("settings", {
		name = "bindSettings",
		OnRun = OpenTab("settings")
	})

	NETWORK.bind.Register("characters", {
		name = "bindCharacters",
		OnRun = function()
			NETWORK.gui.OpenMainMenu()
		end
	})

	NETWORK.bind.Register("waypoint", {
		name = "bindWaypoint",
		default = KEY_R,
		OnRun = function()
			local client = LocalPlayer()

			if (!IsValid(client) or !NETWORK.waypoint or
				!NETWORK.waypoint.CanQuickPlace(client)) then
				return
			end

			local aimed = NETWORK.waypoint.aimed

			if (aimed) then
				net.Start("nwWaypointRemove")
					net.WriteVector(aimed.pos)
				net.SendToServer()

				return
			end

			net.Start("nwWaypointQuick")
			net.SendToServer()
		end
	})

	NETWORK.bind.Register("squadselect", {
		name = "bindSquadSelect",
		default = KEY_G,
		OnRun = function()
			local client = LocalPlayer()

			if (!IsValid(client) or !client:HasCharacter() or
				!client.IsSquadLeader or !client:IsSquadLeader()) then
				return
			end

			local trace = client:GetEyeTrace()
			local target = trace.Entity

			net.Start("nwSquadSelect")
				net.WriteEntity((IsValid(target) and target:IsPlayer()) and
					target or NULL)
			net.SendToServer()
		end
	})

	NETWORK.bind.Register("squadorder", {
		name = "bindSquadOrder",
		default = KEY_H,
		OnRun = function()
			local client = LocalPlayer()

			if (!IsValid(client) or !client:HasCharacter() or
				!client.IsSquadLeader or !client:IsSquadLeader()) then
				return
			end

			if (IsValid(NETWORK.gui.squadOrders)) then
				NETWORK.gui.squadOrders:Remove()

				return
			end

			vgui.Create("nwSquadOrders")
		end
	})

	NETWORK.bind.Register("radial", {
		name = "bindRadial",
		convar = "network_radial_key",
		default = KEY_G,
		bExternal = true
	})

	NETWORK.bind.Register("vortauras", {
		name = "bindVortAuras",
		default = KEY_NONE,
		OnRun = function()
			if (NETWORK.vort and NETWORK.vort.IsVort(LocalPlayer())) then
				RunConsoleCommand("nw_auras")
			end
		end
	})

	NETWORK.bind.Register("vortcasts", {
		name = "bindVortCasts",
		default = KEY_NONE,
		OnRun = function()
			if (NETWORK.vort and NETWORK.vort.IsVort(LocalPlayer())) then
				RunConsoleCommand("nw_casts")
			end
		end
	})

	NETWORK.bind.Register("shield", {
		name = "bindShield",
		default = KEY_I,
		OnRun = function()
			if (NETWORK.shield and NETWORK.shield.IsUser(LocalPlayer())) then
				RunConsoleCommand("nw_shield")
			end
		end
	})

	NETWORK.bind.Register("knockout", {
		name = "bindKnockout",
		default = KEY_NONE,
		OnRun = function()
			local client = LocalPlayer()

			if (NETWORK.shield and NETWORK.shield.IsUser and NETWORK.shield.IsUser(client)) then
				net.Start("nwWallhammerKnock")
				net.SendToServer()
			end
		end
	})

	NETWORK.bind.Register("shieldflash", {
		name = "bindShieldFlash",
		default = KEY_NONE,
		OnRun = function()
			if (NETWORK.shield and NETWORK.shield.IsUser(LocalPlayer())) then
				RunConsoleCommand("nw_shieldflash")
			end
		end
	})

	NETWORK.bind.Register("nvg", {
		name = "bindNVG",
		default = KEY_N,
		OnRun = function()
			if (NETWORK.nvg and NETWORK.nvg.CanUse(LocalPlayer())) then
				RunConsoleCommand("nw_nvg")
			end
		end
	})

	NETWORK.bind.Register("thirdperson", {
		name = "bindThirdPerson",
		convar = "network_thirdperson_key",
		default = KEY_NONE,
		bExternal = true
	})
end
