NETWORK.chud = NETWORK.chud or {}

local hud = NETWORK.chud

local COLS = 22
local ROWS = 14
local BEND = 0.072

local curveConVar = CreateClientConVar("network_visor_curve", "1", true, false,
	"Выгибает интерфейс Альянса на визор")

local state = {}

local function GetTarget()
	local width, height = ScrW(), ScrH()

	if (state.material and state.width == width and state.height == height) then
		return state.texture, state.material
	end

	local name = "nwCombineCurve_" .. width .. "x" .. height

	state.width = width
	state.height = height
	state.texture = GetRenderTarget(name, width, height)

	if (!state.texture) then
		state.material = nil

		return
	end

	state.material = CreateMaterial(name .. "_mat", "UnlitGeneric", {
		["$basetexture"] = "color/white",
		["$translucent"] = "1",
		["$vertexcolor"] = "1",
		["$vertexalpha"] = "1",
		["$nolod"] = "1"
	})

	state.material:SetTexture("$basetexture", state.texture)

	return state.texture, state.material
end

local function GetMesh()
	local width, height = ScrW(), ScrH()

	if (state.mesh and state.meshWidth == width and state.meshHeight == height) then
		return state.mesh, state.points
	end

	local edge = 1 + BEND * 2
	local grid = {}
	local points = {}

	for row = 0, ROWS do
		grid[row] = {}

		for col = 0, COLS do
			local u = col / COLS
			local v = row / ROWS
			local nx = u * 2 - 1
			local ny = v * 2 - 1

			local factor = (1 + BEND * (nx * nx + ny * ny)) / edge
			local baseX = (nx * factor * 0.5 + 0.5) * width
			local baseY = (ny * factor * 0.5 + 0.5) * height

			grid[row][col] = {
				x = baseX,
				y = baseY,
				baseX = baseX,
				baseY = baseY,
				u = u,
				v = v
			}

			points[#points + 1] = grid[row][col]
		end
	end

	local quads = {}

	for row = 0, ROWS - 1 do
		for col = 0, COLS - 1 do
			quads[#quads + 1] = {
				grid[row][col],
				grid[row][col + 1],
				grid[row + 1][col + 1],
				grid[row + 1][col]
			}
		end
	end

	state.mesh = quads
	state.points = points
	state.meshWidth = width
	state.meshHeight = height

	return quads, points
end

local sway = {x = 0, y = 0, lastYaw = 0, lastPitch = 0}

local swayConVar = CreateClientConVar("network_visor_sway", "1", true, false,
	"Панели визора отстают от поворота головы")

function hud.GetSway()
	if (!swayConVar:GetBool()) then
		return 0, 0
	end

	return sway.x, sway.y
end

function hud.UpdateSway(client)
	if (!swayConVar:GetBool()) then
		sway.x, sway.y = 0, 0

		return
	end

	if (sway.frame == FrameNumber()) then
		return
	end

	sway.frame = FrameNumber()

	local angles = client:EyeAngles()
	local deltaYaw = math.AngleDifference(angles.y, sway.lastYaw)
	local deltaPitch = math.AngleDifference(angles.p, sway.lastPitch)

	sway.lastYaw = angles.y
	sway.lastPitch = angles.p

	local frameTime = math.min(FrameTime(), 0.1)

	sway.x = math.Clamp(sway.x + deltaYaw * 0.9, -40, 40)
	sway.y = math.Clamp(sway.y - deltaPitch * 0.9, -30, 30)

	sway.x = math.Approach(sway.x, 0, math.abs(sway.x) * frameTime * 7 + frameTime * 20)
	sway.y = math.Approach(sway.y, 0, math.abs(sway.y) * frameTime * 7 + frameTime * 20)
end

function hud.DrawCurved(callback)
	if (!curveConVar:GetBool()) then
		callback()

		return
	end

	local texture, material = GetTarget()

	if (!texture or !material) then
		callback()

		return
	end

	NETWORK.util.PushBlurBlock()

	render.PushRenderTarget(texture)
		render.OverrideAlphaWriteEnable(true, true)
		render.Clear(0, 0, 0, 0, true, true)

		cam.Start2D()

			local bSuccess, err = pcall(callback)
		cam.End2D()

		render.OverrideAlphaWriteEnable(false)
	render.PopRenderTarget()

	NETWORK.util.PopBlurBlock()

	if (!bSuccess) then
		ErrorNoHalt("[network] visor curve: " .. tostring(err) .. "\n")

		return
	end

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(material)

	local quads, points = GetMesh()
	local offsetX, offsetY = hud.GetSway()

	for index = 1, #points do
		local point = points[index]

		point.x = point.baseX + offsetX
		point.y = point.baseY + offsetY
	end

	for index = 1, #quads do
		surface.DrawPoly(quads[index])
	end
end
