local PANEL = {}

local SHAPES = {
	line = {true, false, true, false},
	elbow = {true, true, false, false},
	tee = {true, true, true, false},
	cross = {true, true, true, true}
}

local function GetSides(tile)
	local base = SHAPES[tile.shape]
	local sides = {}

	for index = 1, 4 do
		sides[index] = base[((index - 1 - tile.rotation) % 4) + 1]
	end

	return sides
end

function PANEL:Init()
	NETWORK.gui.pipegame = self

	self.alpha = 0
	self.tiles = {}
	self.columns = 6
	self.rows = 4
	self.bDone = false

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self:Generate()
end

function PANEL:Generate()
	local columns, rows = self.columns, self.rows
	local grid = {}

	for x = 1, columns do
		grid[x] = {}

		for y = 1, rows do
			grid[x][y] = {up = false, right = false, down = false, left = false}
		end
	end

	local y = math.random(rows)

	self.startRow = y

	for x = 1, columns do

		if (x < columns) then
			local target = math.Clamp(y + math.random(-1, 1), 1, rows)

			while (y != target) do
				local step = target > y and 1 or -1

				grid[x][y][step > 0 and "down" or "up"] = true

				y = y + step

				grid[x][y][step > 0 and "up" or "down"] = true
			end

			grid[x][y].right = true
			grid[x + 1][y].left = true
		end
	end

	self.endRow = y

	grid[1][self.startRow].left = true
	grid[columns][self.endRow].right = true

	self.tiles = {}

	for x = 1, columns do
		self.tiles[x] = {}

		for gy = 1, rows do
			local cell = grid[x][gy]
			local count = (cell.up and 1 or 0) + (cell.right and 1 or 0) +
				(cell.down and 1 or 0) + (cell.left and 1 or 0)
			local tile = {shape = "elbow", rotation = 0, bPath = count > 0}

			if (count == 0) then
				tile.shape = math.random() > 0.5 and "line" or "elbow"
			elseif (count == 1) then
				tile.shape = "elbow"
			elseif (count == 2) then
				tile.shape = ((cell.up and cell.down) or
					(cell.left and cell.right)) and "line" or "elbow"
			elseif (count == 3) then
				tile.shape = "tee"
			else
				tile.shape = "cross"
			end

			if (count > 0) then
				local want = {cell.up, cell.right, cell.down, cell.left}

				for rotation = 0, 3 do
					tile.rotation = rotation

					local sides = GetSides(tile)
					local bMatch = true

					for index = 1, 4 do
						if (want[index] and !sides[index]) then
							bMatch = false

							break
						end
					end

					if (bMatch) then
						break
					end
				end
			end

			tile.solution = tile.rotation
			tile.rotation = math.random(0, 3)

			self.tiles[x][gy] = tile
		end
	end

	if (self:IsSolved()) then
		local tile = self.tiles[1][self.startRow]

		tile.rotation = (tile.rotation + 1) % 4
	end
end

function PANEL:IsSolved()
	local visited = {}
	local queue = {{x = 1, y = self.startRow}}
	local offsets = {
		{0, -1, 1, 3},
		{1, 0, 2, 4},
		{0, 1, 3, 1},
		{-1, 0, 4, 2}
	}

	if (!GetSides(self.tiles[1][self.startRow])[4]) then
		return false
	end

	while (#queue > 0) do
		local node = table.remove(queue)
		local key = node.x .. ":" .. node.y

		if (!visited[key]) then
			visited[key] = true

			local tile = self.tiles[node.x][node.y]
			local sides = GetSides(tile)

			if (node.x == self.columns and node.y == self.endRow and sides[2]) then
				return true
			end

			for _, offset in ipairs(offsets) do
				local nx, ny = node.x + offset[1], node.y + offset[2]

				if (self.tiles[nx] and self.tiles[nx][ny] and sides[offset[3]] and
					GetSides(self.tiles[nx][ny])[offset[4]]) then
					queue[#queue + 1] = {x = nx, y = ny}
				end
			end
		end
	end

	return false
end

function PANEL:GetCell()
	return math.min(NETWORK.util.Scale(96),
		math.Round(ScrW() * 0.75 / self.columns))
end

function PANEL:GetGridX()
	return math.Round((ScrW() - self:GetCell() * self.columns) * 0.5)
end

function PANEL:GetGridY()
	return math.Round((ScrH() - self:GetCell() * self.rows) * 0.5)
end

function PANEL:OnMousePressed(code)
	if (self.bDone) then
		return
	end

	local cell = self:GetCell()
	local x = math.floor((gui.MouseX() - self:GetGridX()) / cell) + 1
	local y = math.floor((gui.MouseY() - self:GetGridY()) / cell) + 1

	if (!self.tiles[x] or !self.tiles[x][y]) then
		if (code == MOUSE_RIGHT) then
			self:Close()
		end

		return
	end

	local tile = self.tiles[x][y]

	tile.rotation = (tile.rotation + (code == MOUSE_RIGHT and 3 or 1)) % 4

	if (self.mode == "emp") then
		local sparks = {"spark.mp3", "spark2.mp3", "spark3.mp3", "spark4.mp3"}

		surface.PlaySound("framework/emp/" .. sparks[math.random(#sparks)])
	else
		surface.PlaySound("buttons/lever7.wav")
	end

	if (self:IsSolved()) then
		self.bDone = true
		self.doneTime = CurTime()

		surface.PlaySound(self.mode == "emp" and "framework/emp/unlock.mp3" or
			"buttons/combine_button1.wav")

		net.Start("nwPipeSolved")
		net.SendToServer()

		timer.Simple(1.4, function()
			if (IsValid(self)) then
				self:Remove()
			end
		end)
	end
end

function PANEL:Close()
	net.Start("nwPipeCancel")
	net.SendToServer()

	self:Remove()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Close()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.pipegame == self) then
		NETWORK.gui.pipegame = nil
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 8)
end

local function DrawSegment(x, y, cell, tile, color, alpha)
	local sides = GetSides(tile)
	local middle = math.Round(cell * 0.5)
	local thickness = math.max(math.Round(cell * 0.11), 3)
	local half = math.Round(thickness * 0.5)

	surface.SetDrawColor(color.r, color.g, color.b, alpha)

	if (sides[1]) then
		surface.DrawRect(x + middle - half, y, thickness, middle)
	end

	if (sides[2]) then
		surface.DrawRect(x + middle, y + middle - half, middle, thickness)
	end

	if (sides[3]) then
		surface.DrawRect(x + middle - half, y + middle, thickness, middle)
	end

	if (sides[4]) then
		surface.DrawRect(x, y + middle - half, middle, thickness)
	end

	local radius = math.Round(cell * 0.13)

	NETWORK.util.DrawCircle(x + middle, y + middle, radius,
		ColorAlpha(color, alpha * 0.35))
	NETWORK.util.DrawCircleOutline(x + middle, y + middle, radius,
		ColorAlpha(color, alpha), math.max(math.Round(cell * 0.03), 2))
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	util.DrawBlur(self, 4 * alpha, 0.25)

	surface.SetDrawColor(3, 4, 6, 170 * alpha)
	surface.DrawRect(0, 0, width, height)

	util.DrawVignette(0, 0, width, height, math.Round(math.min(width, height) * 0.5),
		140 * alpha)

	local cell = self:GetCell()
	local gridX, gridY = self:GetGridX(), self:GetGridY()
	local gridWidth = cell * self.columns
	local gridHeight = cell * self.rows

	local suffix = self.mode == "emp" and "Emp" or ""

	draw.SimpleText(util.Upper(L("pipeTitle" .. suffix)), "nwInvKey",
		math.Round(width * 0.5), gridY - Sc(74),
		ColorAlpha(theme.textFaint, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(L(self.bDone and ("pipeSolved" .. suffix) or "pipeHint"), "nwHudSmall",
		math.Round(width * 0.5), gridY - Sc(40),
		ColorAlpha(self.bDone and theme.positive or theme.textDim, 245 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local plateRadius = math.max(Sc(10), 6)

	draw.RoundedBox(plateRadius, gridX - Sc(14), gridY - Sc(14), gridWidth + Sc(28),
		gridHeight + Sc(28), Color(8, 9, 10, 236 * alpha))

	util.DrawRoundedBorder(gridX - Sc(14), gridY - Sc(14), gridWidth + Sc(28),
		gridHeight + Sc(28), plateRadius, math.max(Sc(1), 1), Color(255, 255, 255, 26 * alpha))

	local mouseX, mouseY = gui.MouseX(), gui.MouseY()
	local hoverX = math.floor((mouseX - gridX) / cell) + 1
	local hoverY = math.floor((mouseY - gridY) / cell) + 1

	for x = 1, self.columns do
		for y = 1, self.rows do
			local tile = self.tiles[x][y]
			local cellX = gridX + (x - 1) * cell
			local cellY = gridY + (y - 1) * cell
			local bHover = (x == hoverX and y == hoverY and !self.bDone)

			draw.RoundedBox(math.max(Sc(4), 3), cellX + 1, cellY + 1, cell - 2, cell - 2,
				Color(15, 16, 18, (200 + (bHover and 30 or 0)) * alpha))

			util.DrawRoundedBorder(cellX + 1, cellY + 1, cell - 2, cell - 2, math.max(Sc(4), 3), 1,
				Color(255, 255, 255, (bHover and 60 or 20) * alpha))

			local colour = self.bDone and theme.positive or theme.combine

			DrawSegment(cellX, cellY, cell, tile, colour, 245 * alpha)
		end
	end

	local inY = gridY + (self.startRow - 1) * cell + math.Round(cell * 0.5)
	local outY = gridY + (self.endRow - 1) * cell + math.Round(cell * 0.5)
	local nub = math.max(math.Round(cell * 0.11), 3)

	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
		250 * alpha)
	surface.DrawRect(gridX - Sc(30), inY - math.Round(nub * 0.5), Sc(30), nub)
	surface.DrawRect(gridX + gridWidth, outY - math.Round(nub * 0.5), Sc(30), nub)

	draw.SimpleText(util.Upper(L("pipeExit" .. suffix)), "nwHudSmall",
		math.Round(width * 0.5), gridY + gridHeight + Sc(46),
		ColorAlpha(theme.textFaint, 225 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

vgui.Register("nwPipeGame", PANEL, "EditablePanel")

net.Receive("nwPipeOpen", function()
	local mode = net.ReadString()

	NETWORK.gui.CloseWindows()

	if (IsValid(NETWORK.gui.pipegame)) then
		NETWORK.gui.pipegame:Remove()
	end

	local panel = vgui.Create("nwPipeGame")

	panel.mode = mode
end)

net.Receive("nwPipeClose", function()
	if (IsValid(NETWORK.gui.pipegame)) then
		NETWORK.gui.pipegame:Remove()
	end
end)
