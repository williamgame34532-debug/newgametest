ITEM.name = "EMP-инструмент"
ITEM.description = "Импульсный взломщик Сопротивления. Выводит из строя силовые поля и вскрывает замки Альянса. Ёмкости хватает на 30 разрядов, затем — долгая перезарядка."
ITEM.model = "models/alyx_emptool_prop.mdl"
ITEM.rarity = "special"
ITEM.weight = 1.2
ITEM.width = 1
ITEM.height = 2
ITEM.category = "misc"

ITEM.maxCharges = 30
ITEM.rechargeTime = 300

ITEM.hackRange = 96

ITEM.rounds = 7
ITEM.maxMisses = 3

function ITEM:OnUse(client, item)
	if (CLIENT) then
		return false
	end

	item = item or {}

	if ((item.recharge or 0) > os.time()) then
		NETWORK.chat.Notice(client, "empRecharging")

		return false
	end

	local target = NETWORK.util.FindLookedAt(client, self.hackRange,
		function(entity)
			local class = entity:GetClass()

			if (class == "nw_forcefield") then
				return entity:IsWorking()
			end

			if (class == "nw_lock") then
				return entity:GetLocked() or !entity.nwHacked
			end

			if (class == "nw_cmbterminal" or class == "nw_cwuterminal") then
				return !entity:GetNWBool("nwBroken", false)
			end

			return NETWORK.door.IsFactionDoor(entity)
		end)

	local bLock = IsValid(target) and target:GetClass() == "nw_lock"
	local bField = IsValid(target) and target:GetClass() == "nw_forcefield"
	local bTerminal = IsValid(target) and (target:GetClass() == "nw_cmbterminal" or target:GetClass() == "nw_cwuterminal") and
		!target:GetNWBool("nwBroken")

	local bDoor = NETWORK.door.IsFactionDoor != nil and
		NETWORK.door.IsFactionDoor(target)

	if (!IsValid(target) or (!bLock and !bField and !bTerminal and !bDoor)) then
		NETWORK.chat.Notice(client, "empNoTarget")

		return false
	end

	if (bField and !target:IsWorking()) then
		NETWORK.chat.Notice(client, "empNoTarget")

		return false
	end

	if (bLock and !target:GetLocked() and target.nwHacked) then
		NETWORK.chat.Notice(client, "empNoTarget")

		return false
	end

	item.charges = (item.charges or self.maxCharges) - 1

	if (item.charges <= 0) then
		item.charges = nil
		item.recharge = os.time() + self.rechargeTime

		NETWORK.chat.Notice(client, "empDepleted")
	end

	NETWORK.emp.Start(client, target, self.rounds, self.maxMisses)

	return false
end

if (SERVER) then
	NETWORK.emp = NETWORK.emp or {}
	NETWORK.emp.sessions = NETWORK.emp.sessions or {}

	util.AddNetworkString("nwEmpHack")
	util.AddNetworkString("nwEmpRound")

	local SPARKS = {
		"framework/emp/spark.mp3",
		"framework/emp/spark2.mp3",
		"framework/emp/spark3.mp3",
		"framework/emp/spark4.mp3"
	}

	function NETWORK.emp.Start(client, entity, rounds, maxMisses)
		NETWORK.emp.sessions[client] = {
			entity = entity,
			rounds = rounds,
			done = 0,
			misses = 0,
			maxMisses = maxMisses,
			nextRound = 0
		}

		client:EmitSound("buttons/combine_button1.wav", 60, 120)

		net.Start("nwEmpHack")
			net.WriteEntity(entity)
			net.WriteUInt(rounds, 5)
			net.WriteUInt(maxMisses, 4)

			net.WriteUInt(math.random(4), 3)
		net.Send(client)
	end

	local function Finish(client, session)
		local entity = session.entity

		NETWORK.emp.sessions[client] = nil

		if (!IsValid(entity)) then
			return
		end

		entity:EmitSound("framework/emp/unlock.mp3", 75)

		if (NETWORK.door.IsDoor(entity)) then
			entity:Fire("unlock")
			entity:Fire("open")

			entity.nwHacked = true

			if (NETWORK.door and NETWORK.door.Sync) then
				NETWORK.door.Sync(entity)
			end

			return
		end

		if (entity:GetClass() == "nw_cmbterminal" or
			entity:GetClass() == "nw_cwuterminal") then

			NETWORK.cmbterm.Break(entity)
		elseif (entity:GetClass() == "nw_forcefield") then

			entity:Shutdown()
		elseif (entity:GetClass() == "nw_lock") then

			entity.nwHacked = true

			entity:Apply(false)
			entity:SetError(true)

			timer.Simple(2, function()
				if (IsValid(entity)) then
					entity:SetError(false)
				end
			end)
		end
	end

	net.Receive("nwEmpRound", function(_, client)
		local session = NETWORK.emp.sessions[client]

		if (!session) then
			return
		end

		local entity = session.entity

		if (!IsValid(entity) or !IsValid(client) or !client:Alive() or
			client:GetPos():Distance(entity:GetPos()) > 160) then
			NETWORK.emp.sessions[client] = nil

			return
		end

		if (session.nextRound > CurTime()) then
			return
		end

		session.nextRound = CurTime() + 0.45

		if (net.ReadBool()) then
			session.done = session.done + 1

			entity:EmitSound(SPARKS[math.random(#SPARKS)], 65,
				math.random(94, 106))

			if (session.done >= session.rounds) then
				Finish(client, session)
			end
		else
			session.misses = session.misses + 1

			if (session.misses > session.maxMisses) then
				NETWORK.emp.sessions[client] = nil

				entity:EmitSound("buttons/combine_button_locked.wav", 60)
			end
		end
	end)

	hook.Add("PlayerDisconnected", "nwEmpHack", function(client)
		NETWORK.emp.sessions[client] = nil
	end)
end

if (CLIENT) then

	local game

	local function CloseGame(bSuccess)
		if (IsValid(game)) then
			game:Remove()
		end

		game = nil
	end

	local GRADIENT = Material("vgui/gradient-u")
	local GRADIENT_DOWN = Material("vgui/gradient-d")

	net.Receive("nwEmpHack", function()
		local entity = net.ReadEntity()
		local rounds = net.ReadUInt(5)
		local maxMisses = net.ReadUInt(4)
		local variant = net.ReadUInt(3)

		CloseGame()

		if (variant == 2) then
			return NETWORK.emp.OpenCodeGame(entity, rounds, maxMisses,
				CloseGame, function(panel) game = panel end)
		end

		if ((variant == 3 or variant == 4) and NETWORK.repairgame) then
			local realStart = net.Start

			net.Start = function(name)
				if (name == "nwRepairCircuit") then
					return realStart("nwEmpRound")
				end

				return realStart(name)
			end

			return NETWORK.repairgame.OpenVariant(variant, entity, rounds,
				function()
					net.Start = realStart

					CloseGame()
				end, function(panel)
					game = panel

					panel.OnRemove = function()
						net.Start = realStart
					end
				end)
		end

		local Sc = NETWORK.util.Scale
		local theme = NETWORK.theme

		game = vgui.Create("DPanel")
		game:SetSize(ScrW(), ScrH())
		game:SetPos(0, 0)
		game:MakePopup()
		game:SetKeyboardInputEnabled(true)

		game.reveal = 0

		local state = {
			entity = entity,
			maxMisses = maxMisses,
			misses = 0,
			done = 0,
			rings = {},
			beam = 0,
			shake = 0,
			flash = 0,
			flashColor = nil
		}

		local direction = 1

		for i = 1, rounds do
			state.rings[i] = {

				gap = math.max(30, 74 - (i - 1) * 7),
				speed = (46 + (i - 1) * 13) * direction,
				angle = math.Rand(0, 360),
				locked = false,
				drawn = 0
			}

			direction = -direction
		end

		local RING_BASE = Sc(88)
		local RING_STEP = Sc(34)

		local function Attempt()
			local ring = state.rings[state.done + 1]

			if (!ring) then
				return
			end

			local offset = math.abs(math.AngleDifference(ring.drawn, -90))
			local bHit = offset <= ring.gap * 0.5 + 3

			net.Start("nwEmpRound")
				net.WriteBool(bHit)
			net.SendToServer()

			state.flash = 1
			state.flashColor = bHit and Color(96, 224, 140) or
				Color(232, 84, 76)

			if (bHit) then
				ring.locked = true
				ring.drawn = -90
				state.done = state.done + 1
				state.beam = 1

				surface.PlaySound("buttons/lightswitch2.wav")

				if (state.done >= rounds) then
					timer.Simple(0.55, CloseGame)
				end
			else
				state.misses = state.misses + 1
				state.shake = 1

				surface.PlaySound("buttons/combine_button_locked.wav")

				if (state.misses > maxMisses) then
					timer.Simple(0.55, CloseGame)
				end
			end
		end

		game.OnKeyCodePressed = function(_, key)
			if (key == KEY_SPACE) then
				Attempt()
			elseif (key == KEY_ESCAPE) then
				CloseGame()
			end
		end

		game.OnMousePressed = function(_, code)
			if (code == MOUSE_LEFT) then
				Attempt()
			end
		end

		game.Think = function()
			local dt = FrameTime()

			game.reveal = math.min(1, (game.reveal or 0) + dt * 3.5)

			state.beam = math.max(0, state.beam - dt * 1.6)
			state.shake = math.max(0, state.shake - dt * 3)
			state.flash = math.max(0, state.flash - dt * 3)

			local client = LocalPlayer()

			if (!IsValid(state.entity) or !IsValid(client) or
				client:GetPos():Distance(state.entity:GetPos()) > 160) then
				CloseGame()
			end
		end

		local function DrawRing(cx, cy, radius, gapCenter, gapSize, color,
			thickness)
			surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

			local step = 4

			for degree = 0, 359, step do
				if (math.abs(math.AngleDifference(degree, gapCenter)) <=
					gapSize * 0.5) then
					continue
				end

				local radian = math.rad(degree)

				surface.DrawRect(
					cx + math.cos(radian) * radius - thickness * 0.5,
					cy + math.sin(radian) * radius - thickness * 0.5,
					thickness, thickness)
			end
		end

		game.Paint = function(_, width, height)
			local reveal = math.min(1, game.reveal or 0)
			local ease = reveal * reveal * (3 - 2 * reveal)
			local jolt = state.shake > 0 and
				math.Round(math.sin(RealTime() * 60) * state.shake * Sc(3)) or 0

			surface.SetDrawColor(4, 8, 16, 205 * ease)
			surface.DrawRect(0, 0, width, height)

			surface.SetMaterial(GRADIENT)
			surface.SetDrawColor(theme.accent.r, theme.accent.g,
				theme.accent.b, 16 * ease)
			surface.DrawTexturedRect(0, 0, width, math.Round(height * 0.55))

			surface.SetMaterial(GRADIENT_DOWN)
			surface.SetDrawColor(theme.accentDeep.r, theme.accentDeep.g,
				theme.accentDeep.b, 22 * ease)
			surface.DrawTexturedRect(0, math.Round(height * 0.45), width,
				math.Round(height * 0.55))

			surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b,
				120 * ease)
			surface.DrawRect(0, math.Round(height * 0.12), width, 1)
			surface.DrawRect(0, math.Round(height * 0.88), width, 1)

			draw.SimpleText("/// ПЕРЕГРУЗКА УЗЛА", "nwTag", width * 0.5,
				height * 0.12 - Sc(26), ColorAlpha(theme.value, 250 * ease),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local pipY = math.Round(height * 0.12) + Sc(18)
			local pipStep = Sc(20)
			local pipsX = width * 0.5 - (#state.rings - 1) * pipStep * 0.5

			for i = 1, #state.rings do
				local bDone = i <= state.done
				local size = bDone and Sc(10) or Sc(7)

				surface.SetDrawColor(bDone and 96 or theme.textFaint.r,
					bDone and 224 or theme.textFaint.g,
					bDone and 140 or theme.textFaint.b,
					(bDone and 250 or 120) * ease)
				surface.DrawRect(pipsX + (i - 1) * pipStep - size * 0.5,
					pipY - size * 0.5, size, size)
			end

			for i = 1, state.maxMisses + 1 do
				surface.SetDrawColor(232, 84, 76,
					(i <= state.misses and 250 or 55) * ease)
				surface.DrawRect(width * 0.5 -
					(state.maxMisses + 1) * Sc(11) + (i - 1) * Sc(22),
					pipY + Sc(14), Sc(16), Sc(3))
			end

			local cx = width * 0.5 + jolt
			local cy = height * 0.52
			local baseRadius = RING_BASE * ease
			local ringStep = RING_STEP

			local reach = baseRadius + state.done * ringStep - Sc(10)

			surface.SetDrawColor(theme.accentSoft.r, theme.accentSoft.g,
				theme.accentSoft.b, (24 + 70 * state.beam) * ease)
			surface.DrawRect(cx - Sc(4), cy - reach, Sc(9), reach)

			surface.SetDrawColor(theme.accentSoft.r, theme.accentSoft.g,
				theme.accentSoft.b, (70 + 170 * state.beam) * ease)
			surface.DrawRect(cx - Sc(1), cy - reach, Sc(3), reach)

			local top = baseRadius + #state.rings * ringStep

			surface.SetDrawColor(theme.accentSoft.r, theme.accentSoft.g,
				theme.accentSoft.b, 220 * ease)
			surface.DrawRect(cx - Sc(1), cy - top - Sc(14), Sc(3), Sc(10))

			local pulse = 0.75 + math.sin(RealTime() * 6) * 0.25

			surface.SetDrawColor(theme.accent.r, theme.accent.g,
				theme.accent.b, 70 * pulse * ease)
			surface.DrawRect(cx - Sc(11), cy - Sc(11), Sc(22), Sc(22))

			surface.SetDrawColor(theme.accent.r, theme.accent.g,
				theme.accent.b, 220 * pulse * ease)
			surface.DrawRect(cx - Sc(5), cy - Sc(5), Sc(10), Sc(10))

			for i, ring in ipairs(state.rings) do
				local radius = baseRadius + (i - 1) * ringStep

				if (!ring.locked) then
					ring.drawn = (ring.angle + RealTime() * ring.speed) % 360
				end

				local bActive = (i == state.done + 1)
				local color

				if (ring.locked) then
					color = Color(96, 224, 140, 190 * ease)
				elseif (bActive) then
					color = Color(255, 255, 255, 245 * ease)
				else
					color = Color(theme.textFaint.r, theme.textFaint.g,
						theme.textFaint.b, 100 * ease)
				end

				DrawRing(cx, cy, radius, ring.drawn, ring.gap,
					ColorAlpha(color, color.a * 0.28), bActive and Sc(9) or Sc(7))
				DrawRing(cx, cy, radius, ring.drawn, ring.gap, color,
					bActive and Sc(4) or Sc(3))
			end

			if (state.flash > 0 and state.flashColor) then
				local flashAlpha = 90 * state.flash * ease

				surface.SetMaterial(GRADIENT)
				surface.SetDrawColor(state.flashColor.r, state.flashColor.g,
					state.flashColor.b, flashAlpha)
				surface.DrawTexturedRect(0, 0, width,
					math.Round(height * 0.4))

				surface.SetMaterial(GRADIENT_DOWN)
				surface.DrawTexturedRect(0, math.Round(height * 0.6), width,
					math.Round(height * 0.4))
			end

			draw.SimpleText("ПРОБЕЛ / ЛКМ — импульс, когда прорезь на луче",
				"nwTagDesc", width * 0.5, height * 0.88 + Sc(24),
				ColorAlpha(theme.textDim, 235 * ease), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end
	end)
end
