if (!CLIENT) then return end

local GRADIENT = Material("vgui/gradient-u")
local GRADIENT_DOWN = Material("vgui/gradient-d")

local COLORS = {
	Color(240, 96, 86), Color(240, 196, 84), Color(96, 224, 140),
	Color(96, 190, 255), Color(190, 130, 250), Color(245, 245, 245)
}
local GLYPHS = {"Α", "Δ", "Ω", "Σ", "Ψ", "Λ"}

local function Veil(panel, width, height, title, done, total, misses,
	maxMisses)
	local theme = NETWORK.theme
	local Sc = NETWORK.util.Scale
	local reveal = math.min(1, panel.reveal or 0)
	local ease = reveal * reveal * (3 - 2 * reveal)

	NETWORK.util.DrawBlur(panel, 4 * ease, 0.25)

	surface.SetDrawColor(3, 4, 6, 170 * ease)
	surface.DrawRect(0, 0, width, height)

	NETWORK.util.DrawVignette(0, 0, width, height,
		math.Round(math.min(width, height) * 0.5), 140 * ease)

	local lineTop = math.Round(height * 0.12)

	draw.SimpleText(NETWORK.util.Upper(title), "nwInvKey", width * 0.5, lineTop - Sc(26),
		ColorAlpha(theme.textFaint, 250 * ease), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	local pipY = lineTop + Sc(4)
	local pipStart = width * 0.5 - (total - 1) * Sc(16) * 0.5
	local dot = Sc(8)

	for i = 1, total do
		local bDone = i <= done

		draw.RoundedBox(math.floor(dot * 0.5), pipStart + (i - 1) * Sc(16) - Sc(4), pipY, dot, dot,
			bDone and ColorAlpha(theme.combine, 250 * ease) or Color(255, 255, 255, 40 * ease))
	end

	for i = 1, (maxMisses or 0) do
		surface.SetDrawColor(232, 84, 76,
			(i <= (misses or 0) and 250 or 55) * ease)
		surface.DrawRect(pipStart + (i - 1) * Sc(16) - Sc(4), pipY + Sc(14),
			dot, math.max(Sc(2), 2))
	end

	if ((panel.flash or 0) > 0 and panel.flashColor) then
		local flash = panel.flash * panel.flash
		local band = math.Round(height * 0.3)

		surface.SetMaterial(GRADIENT)
		surface.SetDrawColor(panel.flashColor.r, panel.flashColor.g,
			panel.flashColor.b, 70 * flash * ease)
		surface.DrawTexturedRect(0, height - band, width, band)

		surface.SetMaterial(GRADIENT_DOWN)
		surface.SetDrawColor(panel.flashColor.r, panel.flashColor.g,
			panel.flashColor.b, 55 * flash * ease)
		surface.DrawTexturedRect(0, 0, width, band)
	end

	return ease
end

local SOUNDS = {
	start = "buttons/combine_button1.wav",
	step = {
		"framework/emp/spark.mp3",
		"framework/emp/spark2.mp3",
		"framework/emp/spark3.mp3",
		"framework/emp/spark4.mp3"
	},
	miss = "buttons/combine_button_locked.wav",
	done = "framework/emp/unlock.mp3",
	tick = "buttons/lever5.wav"
}

local function PlayGameSound(key, pitch)
	local entry = SOUNDS[key]

	if (!entry) then
		return
	end

	if (istable(entry)) then
		entry = entry[math.random(#entry)]
	end

	surface.PlaySound(entry)
end

local function BasePanel(entity, close, register)
	local panel = vgui.Create("DPanel")

	panel:SetSize(ScrW(), ScrH())
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)
	panel.reveal = 0
	panel.flash = 0

	register(panel)

	PlayGameSound("start")

	panel.Flash = function(this, bOk)
		this.flash = 1
		this.flashColor = bOk and Color(96, 224, 140) or Color(232, 84, 76)

		surface.PlaySound(bOk and "buttons/lightswitch2.wav" or
			"buttons/combine_button_locked.wav")
	end

	panel.OnKeyCodePressed = function(_, key)
		if (key == KEY_ESCAPE) then
			close()
		end
	end

	panel.BaseThink = function(this)
		local dt = FrameTime()

		this.reveal = math.min(1, this.reveal + dt * 3.5)
		this.flash = math.max(0, this.flash - dt * 2.6)

		this.opened = this.opened or CurTime()

		if (CurTime() - this.opened > 150) then
			close()

			return
		end

		local client = LocalPlayer()

		if (!IsValid(entity) or !IsValid(client) or
			client:GetPos():Distance(entity:GetPos()) > 160) then
			close()
		end
	end

	return panel
end

NETWORK.emp = NETWORK.emp or {}

function NETWORK.emp.OpenCodeGame(entity, rounds, maxMisses, close, register)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local panel = BasePanel(entity, close, register)

	local state = {
		sequence = {},
		step = 1,
		done = 0,
		misses = 0,

		showUntil = RealTime() + rounds * 0.7 + 1
	}

	for i = 1, rounds do
		state.sequence[i] = math.random(#GLYPHS)
	end

	local grid = {}

	for i = 1, #GLYPHS do
		grid[i] = i
	end

	for i = #grid, 2, -1 do
		local j = math.random(i)

		grid[i], grid[j] = grid[j], grid[i]
	end

	panel.OnMousePressed = function(this, code)
		if (code != MOUSE_LEFT or RealTime() < state.showUntil) then
			return
		end

		local x, y = this:CursorPos()
		local cell = Sc(92)
		local gap = Sc(18)
		local totalWidth = #grid * cell + (#grid - 1) * gap
		local startX = ScrW() * 0.5 - totalWidth * 0.5
		local cellY = ScrH() * 0.56

		for slot, glyph in ipairs(grid) do
			local cx = startX + (slot - 1) * (cell + gap)

			if (x >= cx and x <= cx + cell and y >= cellY and
				y <= cellY + cell) then
				local bOk = glyph == state.sequence[state.step]

				net.Start("nwEmpRound")
					net.WriteBool(bOk)
				net.SendToServer()

				panel:Flash(bOk)

				if (bOk) then
					state.step = state.step + 1
					state.done = state.done + 1

					if (state.done >= rounds) then
						timer.Simple(0.55, close)
					end
				else
					state.misses = state.misses + 1

					if (state.misses > maxMisses) then
						timer.Simple(0.55, close)
					end
				end

				return
			end
		end
	end

	panel.Think = function(this)
		this:BaseThink()
	end

	panel.Paint = function(this, width, height)
		local ease = Veil(this, width, height, "/// КОД ДОСТУПА",
			state.done, rounds, state.misses, maxMisses + 1)
		local bShowing = RealTime() < state.showUntil

		if (bShowing) then
			local index = math.floor((RealTime() -
				(state.showUntil - rounds * 0.7 - 1)) / 0.7) + 1

			if (index >= 1 and index <= rounds) then
				local glyph = state.sequence[index]

				draw.SimpleText(GLYPHS[glyph], "nwTag", width * 0.5,
					height * 0.38, ColorAlpha(COLORS[glyph], 250 * ease),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(index .. " / " .. rounds, "nwTagDesc",
					width * 0.5, height * 0.46,
					ColorAlpha(theme.textDim, 200 * ease),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			draw.SimpleText("ЗАПОМИНАЙТЕ ПОСЛЕДОВАТЕЛЬНОСТЬ", "nwTagDesc",
				width * 0.5, height * 0.88 + Sc(20),
				ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		else
			draw.SimpleText("Введите код: символ " .. state.step .. " из " ..
				rounds, "nwTagDesc", width * 0.5, height * 0.88 + Sc(20),
				ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		local cell = Sc(92)
		local gap = Sc(18)
		local totalWidth = #grid * cell + (#grid - 1) * gap
		local startX = width * 0.5 - totalWidth * 0.5
		local cellY = height * 0.56
		local mx, my = this:CursorPos()

		for slot, glyph in ipairs(grid) do
			local cx = startX + (slot - 1) * (cell + gap)
			local bHover = !bShowing and mx >= cx and mx <= cx + cell and
				my >= cellY and my <= cellY + cell

			surface.SetDrawColor(COLORS[glyph].r, COLORS[glyph].g,
				COLORS[glyph].b, (bHover and 60 or 22) * ease)
			surface.DrawRect(cx - Sc(4), cellY - Sc(4), cell + Sc(8),
				cell + Sc(8))

			surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b,
				235 * ease)
			surface.DrawRect(cx, cellY, cell, cell)

			surface.SetDrawColor(COLORS[glyph].r, COLORS[glyph].g,
				COLORS[glyph].b, (bShowing and 90 or 200) * ease)
			surface.DrawOutlinedRect(cx, cellY, cell, cell, 2)

			draw.SimpleText(GLYPHS[glyph], "nwTag", cx + cell * 0.5,
				cellY + cell * 0.5,
				ColorAlpha(COLORS[glyph], (bShowing and 90 or 230) * ease),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

NETWORK.repairgame = NETWORK.repairgame or {}

function NETWORK.repairgame.OpenVariant(variant, entity, circuits, close,
	register)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local panel = BasePanel(entity, close, register)

	local function Circuit()
		net.Start("nwRepairCircuit")
		net.SendToServer()
	end

	if (variant == 4) then
		local COLUMNS = 5
		local ROWS = 4

		circuits = 2

		local limit = 120
		local started = CurTime()

		local SHAPES = {
			{true, false, true, false},
			{false, true, true, false},
			{false, true, true, true}
		}

		local state = {done = 0, misses = 0, grid = {}}

		local function Sides(cell)
			local shape = SHAPES[cell.shape]
			local sides = {}

			for index = 0, 3 do
				sides[index + 1] = shape[((index - cell.turn) % 4) + 1]
			end

			return sides
		end

		local function Generate()
			local grid = {}

			for x = 1, COLUMNS do
				grid[x] = {}

				for y = 1, ROWS do
					grid[x][y] = {shape = math.random(3),
						turn = math.random(0, 3), lit = false}
				end
			end

			local y = math.random(ROWS)

			state.entry = y

			for x = 1, COLUMNS do
				local nextY = y

				if (x < COLUMNS and math.random(3) == 1) then
					nextY = math.Clamp(y + (math.random(2) == 1 and 1 or -1),
						1, ROWS)
				end

				grid[x][y].shape = 3
				grid[x][y].turn = math.random(0, 3)

				if (nextY != y) then
					grid[x][nextY].shape = 3
					grid[x][nextY].turn = math.random(0, 3)
				end

				y = nextY
			end

			state.exit = y
			state.grid = grid
		end

		local function Trace()
			local grid = state.grid
			local queue = {{1, state.entry}}
			local seen = {}
			local bDone = false

			for x = 1, COLUMNS do
				for y = 1, ROWS do
					grid[x][y].lit = false
				end
			end

			while (#queue > 0) do
				local cell = table.remove(queue)
				local x, y = cell[1], cell[2]
				local key = x .. ":" .. y

				if (seen[key] or !grid[x] or !grid[x][y]) then
					continue
				end

				seen[key] = true
				grid[x][y].lit = true

				if (x == COLUMNS and y == state.exit) then
					bDone = true
				end

				local sides = Sides(grid[x][y])
				local steps = {{0, -1, 1, 3}, {1, 0, 2, 4}, {0, 1, 3, 1},
					{-1, 0, 4, 2}}

				for _, step in ipairs(steps) do
					local nx, ny = x + step[1], y + step[2]

					if (!sides[step[3]] or !grid[nx] or !grid[nx][ny]) then
						continue
					end

					if (Sides(grid[nx][ny])[step[4]]) then
						queue[#queue + 1] = {nx, ny}
					end
				end
			end

			return bDone
		end

		Generate()
		Trace()

		panel.OnMousePressed = function(this, code)
			if (code != MOUSE_LEFT) then
				return
			end

			local mx, my = this:CursorPos()
			local cell = Sc(64)
			local originX = math.Round((ScrW() - cell * COLUMNS) * 0.5)
			local originY = math.Round((ScrH() - cell * ROWS) * 0.5)
			local x = math.floor((mx - originX) / cell) + 1
			local y = math.floor((my - originY) / cell) + 1

			if (!state.grid[x] or !state.grid[x][y]) then
				PlayGameSound("miss")

				return
			end

			state.grid[x][y].turn = (state.grid[x][y].turn + 1) % 4

			PlayGameSound("tick")

			if (Trace()) then
				state.done = state.done + 1

				this:Flash(true)
				Circuit()

				PlayGameSound("step")

				if (state.done >= circuits) then
					PlayGameSound("done")

					timer.Simple(0.55, close)

					return
				end

				Generate()
				Trace()
			end
		end

		panel.Think = function(this)
			this:BaseThink()

			if (CurTime() - started >= limit) then
				PlayGameSound("miss")

				close()
			end
		end

		panel.OnKeyCodePressed = function(this, key)
			if (key == KEY_ESCAPE) then
				close()
			end
		end

		panel.Paint = function(this, width, height)
			Veil(this, width, height, L("repairTrace"), state.done, circuits,
				state.misses, 3)

			local left = math.max(limit - (CurTime() - started), 0)
			local bRush = left <= 20

			draw.SimpleText(string.format("%s  %d:%02d", L("repairTimeLeft"),
				math.floor(left / 60), math.floor(left % 60)), "nwField",
				math.Round(width * 0.5), math.Round(height * 0.5) +
				Sc(64) * 2 + Sc(20),
				ColorAlpha(bRush and Color(232, 92, 92) or theme.textDim,
				240 * math.min(1, this.reveal or 0)), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			local ease = math.min(1, this.reveal or 0)
			local cell = Sc(64)
			local originX = math.Round((width - cell * COLUMNS) * 0.5)
			local originY = math.Round((height - cell * ROWS) * 0.5)

			for x = 1, COLUMNS do
				for y = 1, ROWS do
					local data = state.grid[x][y]
					local cellX = originX + (x - 1) * cell
					local cellY = originY + (y - 1) * cell
					local color = data.lit and Color(120, 220, 235) or
						Color(90, 96, 102)

					surface.SetDrawColor(8, 12, 16, 225 * ease)
					surface.DrawRect(cellX, cellY, cell - 2, cell - 2)

					surface.SetDrawColor(60, 66, 72, 150 * ease)
					surface.DrawOutlinedRect(cellX, cellY, cell - 2, cell - 2, 1)

					local sides = Sides(data)
					local centerX = cellX + math.Round((cell - 2) * 0.5)
					local centerY = cellY + math.Round((cell - 2) * 0.5)
					local thick = math.max(Sc(5), 3)

					surface.SetDrawColor(color.r, color.g, color.b,
						(data.lit and 250 or 170) * ease)

					if (sides[1]) then
						surface.DrawRect(centerX - thick * 0.5, cellY,
							thick, centerY - cellY)
					end

					if (sides[3]) then
						surface.DrawRect(centerX - thick * 0.5, centerY,
							thick, cellY + cell - 2 - centerY)
					end

					if (sides[4]) then
						surface.DrawRect(cellX, centerY - thick * 0.5,
							centerX - cellX, thick)
					end

					if (sides[2]) then
						surface.DrawRect(centerX, centerY - thick * 0.5,
							cellX + cell - 2 - centerX, thick)
					end

					surface.DrawRect(centerX - thick, centerY - thick,
						thick * 2, thick * 2)
				end
			end

			surface.SetDrawColor(120, 220, 140, 245 * ease)
			surface.DrawRect(originX - Sc(18), originY +
				(state.entry - 1) * cell + math.Round(cell * 0.5) - Sc(3),
				Sc(16), Sc(6))

			surface.SetDrawColor(240, 200, 90, 245 * ease)
			surface.DrawRect(originX + cell * COLUMNS + Sc(2), originY +
				(state.exit - 1) * cell + math.Round(cell * 0.5) - Sc(3),
				Sc(16), Sc(6))

			draw.SimpleText(L("repairTraceHint"), "nwHudSmall",
				math.Round(width * 0.5), originY + cell * ROWS + Sc(30),
				ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		return panel
	end

	if (variant == 3) then
		local state = {
			done = 0,
			misses = 0,
			value = 0,
			direction = 1,
			zoneFrom = 0.4,
			zoneSize = 0.22,
			lock = 0
		}

		local function NextPhase()

			state.zoneSize = math.max(0.22 - state.done * 0.012, 0.07)
			state.zoneFrom = math.Rand(0.08, 0.92 - state.zoneSize)
			state.direction = math.random(2) == 1 and 1 or -1
		end

		NextPhase()

		panel.OnMousePressed = function(this, code)
			if (code != MOUSE_LEFT or state.lock > CurTime()) then
				return
			end

			state.lock = CurTime() + 0.15

			if (state.value >= state.zoneFrom and
				state.value <= state.zoneFrom + state.zoneSize) then
				state.done = state.done + 1

				this:Flash(true)
				Circuit()

				PlayGameSound("step")

				if (state.done >= circuits) then
					PlayGameSound("done")

					timer.Simple(0.55, close)

					return
				end

				NextPhase()
			else
				state.misses = state.misses + 1

				this:Flash(false)

				PlayGameSound("miss")

				if (state.misses > 3) then
					timer.Simple(0.55, close)
				end
			end
		end

		panel.Think = function(this)
			this:BaseThink()

			local speed = 0.55 + state.done * 0.05

			state.value = state.value + state.direction * speed * FrameTime()

			if (state.value <= 0) then
				state.value = 0
				state.direction = 1

				PlayGameSound("tick")
			elseif (state.value >= 1) then
				state.value = 1
				state.direction = -1

				PlayGameSound("tick")
			end
		end

		panel.Paint = function(this, width, height)
			Veil(this, width, height, L("repairCalibrate"), state.done,
				circuits, state.misses, 3)

			local ease = math.min(1, this.reveal or 0)
			local barWidth = math.min(Sc(520), width - Sc(120))
			local barHeight = Sc(46)
			local x = math.Round((width - barWidth) * 0.5)
			local y = math.Round(height * 0.5) - math.Round(barHeight * 0.5)

			surface.SetDrawColor(6, 10, 16, 235 * ease)
			surface.DrawRect(x, y, barWidth, barHeight)

			surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b,
				120 * ease)
			surface.DrawOutlinedRect(x, y, barWidth, barHeight, 1)

			for index = 1, 19 do
				local tick = x + math.Round(barWidth * (index / 20))
				local long = index % 5 == 0

				surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b,
					(long and 150 or 80) * ease)
				surface.DrawRect(tick, y + barHeight - (long and Sc(12) or
					Sc(7)), 1, long and Sc(12) or Sc(7))
			end

			local zoneX = x + math.Round(barWidth * state.zoneFrom)
			local zoneWidth = math.Round(barWidth * state.zoneSize)

			surface.SetDrawColor(96, 224, 140, 60 * ease)
			surface.DrawRect(zoneX, y, zoneWidth, barHeight)

			surface.SetDrawColor(96, 224, 140, 235 * ease)
			surface.DrawRect(zoneX, y, math.max(Sc(2), 1), barHeight)
			surface.DrawRect(zoneX + zoneWidth - math.max(Sc(2), 1), y,
				math.max(Sc(2), 1), barHeight)

			local markX = x + math.Round(barWidth * state.value)

			surface.SetDrawColor(226, 236, 246, 40 * ease)
			surface.DrawRect(markX - Sc(6), y, Sc(12), barHeight)

			surface.SetDrawColor(226, 236, 246, 250 * ease)
			surface.DrawRect(markX - math.max(Sc(2), 1), y - Sc(6),
				math.max(Sc(4), 2), barHeight + Sc(12))

			draw.SimpleText(L("repairCalibrateHint"), "nwHudSmall",
				math.Round(width * 0.5), y + barHeight + Sc(34),
				ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		return panel
	end

	if (variant == 2) then

		local state = {
			done = 0,
			value = 0,
			bHold = false,
			zoneFrom = math.Rand(0.55, 0.7),
			zoneSize = 0.16
		}

		local function Release()
			if (!state.bHold) then
				return
			end

			state.bHold = false

			if (state.value >= state.zoneFrom and
				state.value <= state.zoneFrom + state.zoneSize) then
				state.done = state.done + 1
				state.value = 0
				state.zoneFrom = math.Rand(0.45, 0.78)
				state.zoneSize = math.max(0.09, state.zoneSize * 0.9)

				panel:Flash(true)
				Circuit()

				if (state.done >= circuits) then
					timer.Simple(0.55, close)
				end
			else
				state.value = 0

				panel:Flash(false)
			end
		end

		panel.OnMousePressed = function(_, code)
			if (code == MOUSE_LEFT) then
				state.bHold = true
			end
		end
		panel.OnMouseReleased = function(_, code)
			if (code == MOUSE_LEFT) then
				Release()
			end
		end
		panel.OnKeyCodePressed = function(this, key)
			if (key == KEY_SPACE) then
				state.bHold = true
			elseif (key == KEY_ESCAPE) then
				close()
			end
		end
		panel.OnKeyCodeReleased = function(_, key)
			if (key == KEY_SPACE) then
				Release()
			end
		end

		panel.Think = function(this)
			this:BaseThink()

			local dt = FrameTime()

			if (state.bHold) then
				state.value = state.value + dt * 0.42

				if (state.value > 1) then
					state.value = 0
					state.bHold = false

					panel:Flash(false)
				end
			end
		end

		panel.Paint = function(this, width, height)
			local ease = Veil(this, width, height, "/// ЗАТЯЖКА КЛАПАНОВ",
				state.done, circuits, 0, 0)

			local barWidth = math.Round(width * 0.44)
			local barX = width * 0.5 - barWidth * 0.5
			local barY = height * 0.5 - Sc(20)
			local barH = Sc(40)

			surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b,
				235 * ease)
			surface.DrawRect(barX, barY, barWidth, barH)

			surface.SetDrawColor(96, 224, 140, 60 * ease)
			surface.DrawRect(barX + barWidth * state.zoneFrom, barY,
				barWidth * state.zoneSize, barH)
			surface.SetDrawColor(96, 224, 140, 200 * ease)
			surface.DrawOutlinedRect(barX + barWidth * state.zoneFrom, barY,
				barWidth * state.zoneSize, barH, 1)

			surface.SetDrawColor(255, 255, 255, 250 * ease)
			surface.DrawRect(barX + barWidth * state.value - Sc(1),
				barY - Sc(6), Sc(3), barH + Sc(12))

			draw.SimpleText(
				"Удерживайте ПРОБЕЛ/ЛКМ и отпустите в зелёной зоне",
				"nwTagDesc", width * 0.5, height * 0.88 + Sc(20),
				ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		return
	end

	local state = {
		done = 0,
		misses = 0,
		maxMisses = 3,
		current = math.random(3),
		bins = {1, 2, 3}
	}

	for i = 3, 2, -1 do
		local j = math.random(i)

		state.bins[i], state.bins[j] = state.bins[j], state.bins[i]
	end

	panel.OnMousePressed = function(this, code)
		if (code != MOUSE_LEFT) then
			return
		end

		local x, y = this:CursorPos()
		local cell = Sc(130)
		local gap = Sc(40)
		local startX = ScrW() * 0.5 - (3 * cell + 2 * gap) * 0.5
		local cellY = ScrH() * 0.58

		for slot, bin in ipairs(state.bins) do
			local cx = startX + (slot - 1) * (cell + gap)

			if (x >= cx and x <= cx + cell and y >= cellY and
				y <= cellY + cell) then
				local bOk = bin == state.current

				panel:Flash(bOk)

				if (bOk) then
					state.done = state.done + 1
					state.current = math.random(3)

					Circuit()

					if (state.done >= circuits) then
						timer.Simple(0.55, close)
					end
				else
					state.misses = state.misses + 1

					if (state.misses >= state.maxMisses) then
						timer.Simple(0.55, close)
					end
				end

				return
			end
		end
	end

	panel.Think = function(this)
		this:BaseThink()
	end

	panel.Paint = function(this, width, height)
		local ease = Veil(this, width, height, "/// СОРТИРОВКА КОМПОНЕНТОВ",
			state.done, circuits, state.misses, state.maxMisses)

		local color = COLORS[state.current]

		surface.SetDrawColor(color.r, color.g, color.b, 30 * ease)
		surface.DrawRect(width * 0.5 - Sc(56), height * 0.32 - Sc(56),
			Sc(112), Sc(112))
		surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b,
			235 * ease)
		surface.DrawRect(width * 0.5 - Sc(48), height * 0.32 - Sc(48),
			Sc(96), Sc(96))
		surface.SetDrawColor(color.r, color.g, color.b, 220 * ease)
		surface.DrawOutlinedRect(width * 0.5 - Sc(48), height * 0.32 - Sc(48),
			Sc(96), Sc(96), 2)

		draw.SimpleText(GLYPHS[state.current], "nwTag", width * 0.5,
			height * 0.32, ColorAlpha(color, 240 * ease), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		local cell = Sc(130)
		local gap = Sc(40)
		local startX = width * 0.5 - (3 * cell + 2 * gap) * 0.5
		local cellY = height * 0.58
		local mx, my = this:CursorPos()

		for slot, bin in ipairs(state.bins) do
			local cx = startX + (slot - 1) * (cell + gap)
			local binColor = COLORS[bin]
			local bHover = mx >= cx and mx <= cx + cell and my >= cellY and
				my <= cellY + cell

			surface.SetDrawColor(binColor.r, binColor.g, binColor.b,
				(bHover and 60 or 24) * ease)
			surface.DrawRect(cx - Sc(5), cellY - Sc(5), cell + Sc(10),
				cell + Sc(10))
			surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b,
				235 * ease)
			surface.DrawRect(cx, cellY, cell, cell)
			surface.SetDrawColor(binColor.r, binColor.g, binColor.b,
				210 * ease)
			surface.DrawOutlinedRect(cx, cellY, cell, cell, 2)

			draw.SimpleText(GLYPHS[bin], "nwTag", cx + cell * 0.5,
				cellY + cell * 0.5, ColorAlpha(binColor, 230 * ease),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		draw.SimpleText("Кликните по ящику с символом детали", "nwTagDesc",
			width * 0.5, height * 0.88 + Sc(20),
			ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end

net.Receive("nwMechanicStart", function()
	local entity = net.ReadEntity()
	local rounds = net.ReadUInt(4)
	local variant = net.ReadUInt(3)

	if (IsValid(NETWORK.mechanicGame)) then
		NETWORK.mechanicGame:Remove()
	end

	local function close()
		if (IsValid(NETWORK.mechanicGame)) then
			NETWORK.mechanicGame:Remove()
		end

		NETWORK.mechanicGame = nil
	end

	local realStart = net.Start

	local function patchedStart(name)
		if (name == "nwRepairCircuit") then
			return realStart("nwMechanicRound")
		end

		return realStart(name)
	end

	net.Start = patchedStart

	local function closePatched()
		net.Start = realStart

		close()
	end

	if (variant == 1) then
		variant = math.random(2, 4)
	end

	NETWORK.repairgame.OpenVariant(variant, entity, rounds, closePatched,
		function(panel)
			NETWORK.mechanicGame = panel

			panel.OnRemove = function()
				net.Start = realStart
			end
		end)
end)

NETWORK.minigame = NETWORK.minigame or {}
NETWORK.minigame.Veil = Veil
NETWORK.minigame.BasePanel = BasePanel
NETWORK.minigame.Sound = PlayGameSound

function NETWORK.minigame.Icon(name, x, y, size, color)
	local material = NETWORK.util.GetMaterial("framework/icons/" .. name ..
		".png", "smooth")

	if (!material or material:IsError()) then
		return false
	end

	surface.SetMaterial(material)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawTexturedRect(math.Round(x), math.Round(y), size, size)

	return true
end

net.Receive("nwBagStart", function()
	local entity = net.ReadEntity()
	local steps = net.ReadUInt(4)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local maxMisses = 3
	local bFinished = false

	if (IsValid(NETWORK.bagGame)) then
		NETWORK.bagGame:Remove()
	end

	local function close()
		if (IsValid(NETWORK.bagGame)) then
			NETWORK.bagGame:Remove()
		end

		NETWORK.bagGame = nil
	end

	local function cancel()
		if (!bFinished) then
			bFinished = true

			net.Start("nwBagStep")
				net.WriteBool(false)
			net.SendToServer()
		end

		close()
	end

	local panel = BasePanel(entity, cancel, function(this)
		NETWORK.bagGame = this
	end)

	local state = {
		done = 0,
		misses = 0,
		position = 0,
		direction = 1,
		speed = 0.55,
		zoneStart = 0,
		zoneWidth = 0.16,
		locked = 0
	}

	local function NewZone()
		state.zoneWidth = math.max(0.09, 0.16 - state.done * 0.014)

		for _ = 1, 8 do
			state.zoneStart = math.Rand(0.05, 0.95 - state.zoneWidth)

			if (state.position < state.zoneStart - 0.08 or
				state.position > state.zoneStart + state.zoneWidth + 0.08) then
				break
			end
		end
	end

	NewZone()

	local function InZone()
		return state.position >= state.zoneStart and
			state.position <= state.zoneStart + state.zoneWidth
	end

	panel.OnMousePressed = function(this, code)
		if (code != MOUSE_LEFT or bFinished or state.locked > RealTime()) then
			return
		end

		if (InZone()) then
			state.done = state.done + 1
			state.speed = state.speed + 0.08
			state.locked = RealTime() + 0.18

			this:Flash(true)

			net.Start("nwBagStep")
				net.WriteBool(true)
			net.SendToServer()

			if (state.done >= steps) then
				bFinished = true

				PlayGameSound("done")
				timer.Simple(0.55, close)

				return
			end

			NewZone()

			return
		end

		state.misses = state.misses + 1
		state.locked = RealTime() + 0.25

		this:Flash(false)

		if (state.misses >= maxMisses) then
			timer.Simple(0.55, cancel)
		end
	end

	panel.Think = function(this)
		this:BaseThink()

		if (bFinished) then
			return
		end

		local dt = FrameTime()

		state.position = state.position + state.direction * state.speed * dt

		if (state.position >= 1) then
			state.position = 1
			state.direction = -1
		elseif (state.position <= 0) then
			state.position = 0
			state.direction = 1
		end
	end

	panel.Paint = function(this, width, height)
		local ease = Veil(this, width, height, L("bagGameTitle"), state.done,
			steps, state.misses, maxMisses)
		local iconSize = Sc(22)
		local lineTop = math.Round(height * 0.12)

		surface.SetFont("nwInvKey")

		local titleWidth = surface.GetTextSize(NETWORK.util.Upper(L("bagGameTitle")))

		NETWORK.minigame.Icon("masks", width * 0.5 - titleWidth * 0.5 - iconSize -
			Sc(10), lineTop - Sc(26) - iconSize * 0.5, iconSize,
			ColorAlpha(theme.textDim, 230 * ease))

		local bagWidth = math.Round(math.min(width * 0.62, Sc(760)))
		local bagHeight = math.Round(bagWidth * 0.3)
		local bagX = math.Round(width * 0.5 - bagWidth * 0.5)
		local bagY = math.Round(height * 0.5 - bagHeight * 0.5)
		local fraction = state.done / math.max(steps, 1)

		surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b,
			225 * ease)
		surface.DrawRect(bagX, bagY, bagWidth, bagHeight)

		surface.SetDrawColor(255, 255, 255, 14 * ease)
		surface.DrawRect(bagX, bagY, math.Round(bagWidth * fraction), bagHeight)

		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b,
			220 * ease)
		surface.DrawOutlinedRect(bagX, bagY, bagWidth, bagHeight, 1)

		surface.DrawLine(bagX, bagY + Sc(18), bagX + Sc(18), bagY)

		NETWORK.minigame.Icon("cleaning_services", bagX + bagWidth - Sc(44),
			bagY + Sc(12), Sc(28), ColorAlpha(theme.textFaint, 160 * ease))

		local zipY = bagY + math.Round(bagHeight * 0.5)
		local zipX = bagX + Sc(24)
		local zipWidth = bagWidth - Sc(48)

		surface.SetDrawColor(theme.textFaint.r, theme.textFaint.g,
			theme.textFaint.b, 200 * ease)
		surface.DrawRect(zipX, zipY, zipWidth, math.max(Sc(2), 2))

		local tooth = math.max(Sc(6), 4)

		for x = zipX, zipX + zipWidth - tooth, tooth * 2 do
			surface.DrawRect(x, zipY - Sc(4), math.max(Sc(2), 1), Sc(4))
			surface.DrawRect(x + tooth, zipY + Sc(2), math.max(Sc(2), 1), Sc(4))
		end

		surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
			230 * ease)
		surface.DrawRect(zipX, zipY - Sc(1), math.Round(zipWidth * fraction),
			math.max(Sc(4), 3))

		local zoneX = zipX + math.Round(zipWidth * state.zoneStart)
		local zoneWidth = math.Round(zipWidth * state.zoneWidth)
		local bInside = InZone()

		surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
			(bInside and 70 or 34) * ease)
		surface.DrawRect(zoneX, zipY - Sc(22), zoneWidth, Sc(44))

		surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
			(bInside and 250 or 150) * ease)
		surface.DrawOutlinedRect(zoneX, zipY - Sc(22), zoneWidth, Sc(44), 1)

		local markerX = zipX + math.Round(zipWidth * state.position)
		local marker = Sc(14)

		surface.SetDrawColor(theme.text.r, theme.text.g, theme.text.b,
			245 * ease)
		surface.DrawRect(markerX - marker * 0.5, zipY - marker * 0.5 + Sc(1),
			marker, marker)

		surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b,
			255 * ease)
		surface.DrawRect(markerX - Sc(1), zipY - marker * 0.5 + Sc(4),
			math.max(Sc(2), 2), marker - Sc(6))

		draw.SimpleText(L("bagGameHint"), "nwTagDesc", width * 0.5,
			math.Round(height * 0.88) + Sc(20),
			ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end)
