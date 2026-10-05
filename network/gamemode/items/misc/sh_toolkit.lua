ITEM.name = "Набор инструментов"
ITEM.description = "Ремонтный кейс техслужбы Альянса. Восстанавливает сломанные силовые поля и вскрытые замки. Ресурса хватает на 10 ремонтов."
ITEM.model = "models/props_c17/toolbox02a.mdl"
ITEM.rarity = "special"
ITEM.weight = 2.4
ITEM.width = 2
ITEM.height = 1

ITEM.useCooldown = 60

ITEM.category = "misc"

ITEM.maxUses = 10
ITEM.repairRange = 96

ITEM.circuits = 6

function ITEM:OnUse(client, item)
	if (CLIENT) then
		return false
	end

	item = item or {}

	if (!NETWORK.factions.IsAlliance(client) and
		!NETWORK.factions.IsCWU(client) and
		client:GetNWString("nwClass", "") != "mechanic") then
		NETWORK.chat.Notice(client, "toolkitAlliance")

		return false
	end

	local target = NETWORK.util.FindLookedAt(client, self.repairRange,
		function(entity)
			local class = entity:GetClass()

			if (class == "nw_forcefield") then
				return entity:GetMode() == entity.MODE_SHUTDOWN
			end

			if (class == "nw_lock") then
				return entity.nwHacked == true
			end

			if (class == "nw_cmbterminal" or class == "nw_cwuterminal" or
				class == "npc_combine_camera" or class == "nw_terminal" or
				class == "nw_jailterminal" or class == "nw_admin_computer" or
				class == "nw_council_computer") then
				return entity:GetNWBool("nwBroken", false)
			end

			return false
		end)

	if (!IsValid(target)) then
		local healthy = NETWORK.mechanic and NETWORK.mechanic.diagClasses and
			NETWORK.util.FindLookedAt(client, self.repairRange,
				function(entity)
					return NETWORK.mechanic.diagClasses[entity:GetClass()] == true
				end)

		if (IsValid(healthy)) then
			NETWORK.mechanic.Diagnose(client, healthy, item)

			return false
		end

		NETWORK.chat.Notice(client, "toolkitNoTarget")

		return false
	end

	if (client:GetNWString("nwClass", "") == "mechanic" and !client:IsAdmin() and
		NETWORK.cmbterm and NETWORK.cmbterm.breakClasses and
		NETWORK.cmbterm.breakClasses[target:GetClass()]) then
		local owner = target:GetNWString("nwBreakOwner", "")

		if (owner == "") then
			NETWORK.chat.Notice(client, "mechanicNeedClaim")

			return false
		end

		if (owner != client:GetCharacterName()) then
			NETWORK.notice.Send(client, "mechanicClaimedBy", "warn", owner)

			return false
		end
	end

	NETWORK.repairgame.Start(client, target, self.circuits, item)

	return false
end

if (SERVER) then
	NETWORK.repairgame = NETWORK.repairgame or {}
	NETWORK.repairgame.sessions = NETWORK.repairgame.sessions or {}

	util.AddNetworkString("nwRepairStart")
	util.AddNetworkString("nwRepairCircuit")

	function NETWORK.repairgame.Start(client, entity, circuits, item)
		NETWORK.repairgame.sessions[client] = {
			entity = entity,
			item = item,
			circuits = circuits,
			done = 0,

			nextCircuit = CurTime() + 0.5
		}

		net.Start("nwRepairStart")
			net.WriteEntity(entity)
			net.WriteUInt(circuits, 4)

			net.WriteUInt(math.random(4), 3)
		net.Send(client)
	end

	local function Finish(client, session)
		local entity = session.entity
		local item = session.item

		NETWORK.repairgame.sessions[client] = nil

		if (!IsValid(entity)) then
			return
		end

		if (entity:GetClass() == "nw_cmbterminal" or
			entity:GetClass() == "nw_cwuterminal" or entity:GetClass() == "nw_terminal" or
			entity:GetClass() == "nw_jailterminal" or entity:GetClass() == "nw_admin_computer" or
			entity:GetClass() == "nw_council_computer") then

			NETWORK.cmbterm.Restore(entity)
			entity:EmitSound("framework/cmb/forcefield/repair_complete.mp3", 70)
		elseif (entity:GetClass() == "nw_forcefield") then
			entity:Repair()
		elseif (entity:GetClass() == "nw_lock") then
			entity.nwHacked = nil

			entity:Apply(true)
		elseif (entity:GetClass() == "npc_combine_camera") then
			NETWORK.camera.Repair(entity)
		end

		if (NETWORK.mechanic and NETWORK.mechanic.StopFault) then
			NETWORK.mechanic.StopFault(entity)
		end

		NETWORK.currency.Add(client, math.random(1, 2))

		if (NETWORK.cmbterm and NETWORK.cmbterm.Journal) then
			NETWORK.cmbterm.Journal(client, "journalRepair", entity)
		end

		NETWORK.chat.Notice(client, "toolkitRepaired")

		hook.Run("NetworkMechanicRepaired", client, entity)

		if (istable(item)) then
			item.uses = (item.uses or NETWORK.item.Get("toolkit").maxUses) - 1

			if (item.uses <= 0) then

				local state = NETWORK.inventory.GetState(client)

				for _, list in ipairs({state.items, state.equipped,
					state.storage}) do
					for key, entry in pairs(list or {}) do
						if (entry == item) then
							list[key] = nil
						end
					end
				end

				NETWORK.inventory.Sync(client)
				NETWORK.chat.Notice(client, "toolkitBroken")
			end
		end
	end

	net.Receive("nwRepairCircuit", function(_, client)
		local session = NETWORK.repairgame.sessions[client]

		if (!session) then
			return
		end

		local entity = session.entity

		if (!IsValid(entity) or !IsValid(client) or !client:Alive() or
			client:GetPos():Distance(entity:GetPos()) > 160) then
			NETWORK.repairgame.sessions[client] = nil

			return
		end

		if (session.nextCircuit > CurTime()) then
			return
		end

		session.nextCircuit = CurTime() + 0.5
		session.done = session.done + 1

		if (session.done >= session.circuits) then
			Finish(client, session)
		end
	end)

	hook.Add("PlayerDisconnected", "nwRepairGame", function(client)
		NETWORK.repairgame.sessions[client] = nil
	end)
end

if (CLIENT) then
	local game

	local function CloseGame()
		if (IsValid(game)) then
			game:Remove()
		end

		game = nil
	end

	local GRADIENT = Material("vgui/gradient-u")
	local GRADIENT_DOWN = Material("vgui/gradient-d")

	net.Receive("nwRepairStart", function()
		local entity = net.ReadEntity()
		local circuits = net.ReadUInt(4)
		local variant = net.ReadUInt(3)

		CloseGame()

		if (variant > 1) then
			return NETWORK.repairgame.OpenVariant(variant, entity, circuits,
				CloseGame, function(panel) game = panel end)
		end

		local Sc = NETWORK.util.Scale
		local theme = NETWORK.theme

		game = vgui.Create("DPanel")
		game:SetSize(ScrW(), ScrH())
		game:SetPos(0, 0)
		game:MakePopup()
		game:SetKeyboardInputEnabled(true)
		game.reveal = 0

		local COLORS = {
			Color(240, 96, 86), Color(240, 196, 84), Color(96, 224, 140),
			Color(96, 190, 255), Color(190, 130, 250), Color(245, 245, 245)
		}

		local GLYPHS = {"Α", "Δ", "Ω", "Σ", "Ψ", "Λ"}

		local state = {
			entity = entity,
			total = math.min(circuits, #COLORS),
			done = 0,
			misses = 0,
			maxMisses = 3,
			selected = nil,
			pins = {},
			sockets = {},
			flash = 0,
			flashColor = nil
		}

		local order = {}

		for i = 1, state.total do
			order[i] = i
		end

		for i = state.total, 2, -1 do
			local j = math.random(i)

			order[i], order[j] = order[j], order[i]
		end

		local bStraight = true

		for i = 1, state.total do
			if (order[i] != i) then
				bStraight = false

				break
			end
		end

		if (bStraight) then
			order[1], order[state.total] = order[state.total], order[1]
		end

		for i = 1, state.total do
			state.pins[i] = {index = i, connected = false}
			state.sockets[i] = {index = order[i], connected = false}
		end

		local NODE = Sc(46)

		local function Layout(width, height)
			local top = height * 0.24
			local span = height * 0.58
			local step = span / state.total

			for i = 1, state.total do
				local y = math.Round(top + step * (i - 0.5))

				state.pins[i].x = math.Round(width * 0.3)
				state.pins[i].y = y
				state.sockets[i].x = math.Round(width * 0.7)
				state.sockets[i].y = y
			end
		end

		local function Hit(list, x, y)
			for _, node in ipairs(list) do
				if (math.abs(x - node.x) <= NODE * 0.75 and
					math.abs(y - node.y) <= NODE * 0.62) then
					return node
				end
			end
		end

		game.OnMousePressed = function(panel, code)
			if (code != MOUSE_LEFT) then
				return
			end

			local x, y = panel:CursorPos()

			local pin = Hit(state.pins, x, y)

			if (pin and !pin.connected) then
				state.selected = pin

				surface.PlaySound("buttons/lightswitch2.wav")

				return
			end

			if (!state.selected) then
				return
			end

			local socket = Hit(state.sockets, x, y)

			if (!socket or socket.connected) then
				return
			end

			if (socket.index == state.selected.index) then
				state.selected.connected = true
				socket.connected = true
				state.selected.socket = socket
				state.selected = nil
				state.done = state.done + 1
				state.flash = 1
				state.flashColor = Color(96, 224, 140)

				surface.PlaySound("buttons/lightswitch2.wav")

				net.Start("nwRepairCircuit")
				net.SendToServer()

				if (state.done >= state.total) then
					timer.Simple(0.55, CloseGame)
				end
			else
				state.misses = state.misses + 1
				state.selected = nil
				state.flash = 1
				state.flashColor = Color(232, 84, 76)

				surface.PlaySound("buttons/combine_button_locked.wav")

				if (state.misses >= state.maxMisses) then
					timer.Simple(0.55, CloseGame)
				end
			end
		end

		game.OnKeyCodePressed = function(_, key)
			if (key == KEY_ESCAPE) then
				CloseGame()
			end
		end

		game.Think = function()
			local dt = FrameTime()

			game.reveal = math.min(1, (game.reveal or 0) + dt * 3.5)
			state.flash = math.max(0, state.flash - dt * 2.6)

			local client = LocalPlayer()

			if (!IsValid(state.entity) or !IsValid(client) or
				client:GetPos():Distance(state.entity:GetPos()) > 160) then
				CloseGame()
			end
		end

		local function Wire(x1, y1, x2, y2, color, alpha)
			surface.SetDrawColor(color.r, color.g, color.b, alpha * 0.35)

			for offset = -2, 2 do
				surface.DrawLine(x1, y1 + offset, x2, y2 + offset)
			end

			surface.SetDrawColor(color.r, color.g, color.b, alpha)

			for offset = -1, 1 do
				surface.DrawLine(x1, y1 + offset, x2, y2 + offset)
			end
		end

		game.Paint = function(panel, width, height)
			Layout(width, height)

			local reveal = math.min(1, game.reveal or 0)
			local ease = reveal * reveal * (3 - 2 * reveal)

			surface.SetDrawColor(4, 8, 16, 205 * ease)
			surface.DrawRect(0, 0, width, height)

			surface.SetMaterial(GRADIENT)
			surface.SetDrawColor(theme.accent.r, theme.accent.g,
				theme.accent.b, 16 * ease)
			surface.DrawTexturedRect(0, 0, width, height)

			surface.SetMaterial(GRADIENT_DOWN)
			surface.SetDrawColor(theme.plateDeep.r, theme.plateDeep.g,
				theme.plateDeep.b, 150 * ease)
			surface.DrawTexturedRect(0, 0, width, math.Round(height * 0.35))

			local lineTop = math.Round(height * 0.12)
			local lineBottom = math.Round(height * 0.88)

			surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b,
				150 * ease)
			surface.DrawRect(math.Round(width * 0.18), lineTop,
				math.Round(width * 0.64), 1)
			surface.DrawRect(math.Round(width * 0.18), lineBottom,
				math.Round(width * 0.64), 1)

			draw.SimpleText("/// КОММУТАЦИЯ ПРОВОДКИ", "nwTag", width * 0.5,
				lineTop - Sc(26), ColorAlpha(theme.value, 250 * ease),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local pipY = lineTop + Sc(18)
			local pipSpan = Sc(16)
			local pipStart = width * 0.5 - (state.total - 1) * pipSpan * 0.5

			for i = 1, state.total do
				local bDone = i <= state.done

				surface.SetDrawColor(bDone and 96 or theme.textFaint.r,
					bDone and 224 or theme.textFaint.g,
					bDone and 140 or theme.textFaint.b,
					(bDone and 250 or 120) * ease)
				surface.DrawRect(pipStart + (i - 1) * pipSpan - Sc(5),
					pipY, Sc(10), Sc(10))
			end

			for i = 1, state.maxMisses do
				surface.SetDrawColor(232, 84, 76,
					(i <= state.misses and 250 or 55) * ease)
				surface.DrawRect(pipStart + (i - 1) * pipSpan - Sc(5),
					pipY + Sc(16), Sc(10), Sc(3))
			end

			for _, pin in ipairs(state.pins) do
				if (pin.connected and pin.socket) then
					Wire(pin.x, pin.y, pin.socket.x, pin.socket.y,
						COLORS[pin.index], 210 * ease)
				end
			end

			if (state.selected) then
				local mx, my = panel:CursorPos()

				Wire(state.selected.x, state.selected.y, mx, my,
					COLORS[state.selected.index], 165 * ease)
			end

			local function Node(node)
				local color = COLORS[node.index]
				local x = node.x - NODE * 0.5
				local y = node.y - NODE * 0.5
				local bSelected = state.selected == node

				surface.SetDrawColor(color.r, color.g, color.b,
					(node.connected and 46 or (bSelected and 60 or 24)) * ease)
				surface.DrawRect(x - Sc(6), y - Sc(6), NODE + Sc(12),
					NODE + Sc(12))

				surface.SetDrawColor(theme.plate.r, theme.plate.g,
					theme.plate.b, 235 * ease)
				surface.DrawRect(x, y, NODE, NODE)

				surface.SetDrawColor(color.r, color.g, color.b,
					(node.connected and 250 or 185) * ease)
				surface.DrawOutlinedRect(x, y, NODE, NODE, math.max(Sc(2), 2))

				draw.SimpleText(GLYPHS[node.index], "nwTag", node.x, node.y,
					ColorAlpha(color, (node.connected and 250 or 215) * ease),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			for i = 1, state.total do
				Node(state.pins[i])
				Node(state.sockets[i])
			end

			if (state.flash > 0 and state.flashColor) then
				local flash = state.flash * state.flash
				local band = math.Round(height * 0.3)

				surface.SetMaterial(GRADIENT)
				surface.SetDrawColor(state.flashColor.r, state.flashColor.g,
					state.flashColor.b, 70 * flash * ease)
				surface.DrawTexturedRect(0, height - band, width, band)

				surface.SetMaterial(GRADIENT_DOWN)
				surface.SetDrawColor(state.flashColor.r, state.flashColor.g,
					state.flashColor.b, 55 * flash * ease)
				surface.DrawTexturedRect(0, 0, width, band)
			end

			draw.SimpleText("Соедините клеммы с гнёздами по цвету и символу  //  ESC — отмена",
				"nwTagDesc", width * 0.5, lineBottom + Sc(20),
				ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end
	end)
end
