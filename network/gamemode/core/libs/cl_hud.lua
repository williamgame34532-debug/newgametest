NETWORK.hud = NETWORK.hud or {}

NETWORK.hud.fade = NETWORK.hud.fade or 0

NETWORK.hud.logoPath = NETWORK.hud.logoPath or "framework/icons/logo.png"
NETWORK.hud.curve = NETWORK.hud.curve or {}

local CURVE_COLS = 22
local CURVE_ROWS = 14

local CURVE_BEND = 0.03
local hudEnabled = CreateClientConVar("network_hud", "1", true, false, "Показывать HUD")
local hudThird = CreateClientConVar("network_thirdperson_hidehud", "1", true, false,
	"Прятать HUD от третьего лица (кроме баннера проекта)")

local iconPaths = {
	"framework/icon/stamina.png",
	"framework/icons/stamina.png",
	"framework/icon/stamina.vmt",
	"framework/icons/stamina.vmt"
}

local staminaIcon
local bIconChecked = false

local function GetStaminaIcon()
	if (bIconChecked) then
		return staminaIcon
	end

	bIconChecked = true

	for _, path in ipairs(iconPaths) do
		if (file.Exists("materials/" .. path, "GAME")) then
			local material = Material(path, "smooth")

			if (material and !material:IsError()) then
				staminaIcon = material

				return staminaIcon
			end
		end
	end
end

local function DrawBolt(x, y, size, color)
	local half = size * 0.5

	draw.NoTexture()
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawPoly({
		{x = x + half * 0.35, y = y - half},
		{x = x + half, y = y - half},
		{x = x + half * 0.15, y = y - half * 0.05},
		{x = x + half * 0.75, y = y - half * 0.05},
		{x = x - half * 0.4, y = y + half},
		{x = x - half * 0.05, y = y + half * 0.1},
		{x = x - half * 0.7, y = y + half * 0.1},
		{x = x - half * 0.1, y = y - half}
	})
end

local staminaAlpha = 0
local values = {}

local function Approach(key, target, speed)
	values[key] = NETWORK.util.Approach(values[key] or target, target, speed or 8)

	return values[key]
end

local function GetCurveTarget()
	local state = NETWORK.hud.curve
	local width, height = ScrW(), ScrH()

	if (state.material and state.width == width and state.height == height) then
		return state.texture, state.material
	end

	local name = "nwHudCurve_" .. width .. "x" .. height

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

local function BuildCurveMesh()
	local state = NETWORK.hud.curve
	local width, height = ScrW(), ScrH()

	if (state.mesh and state.meshWidth == width and state.meshHeight == height) then
		return state.mesh
	end

	local edge = 1 + CURVE_BEND * 2
	local grid = {}

	for row = 0, CURVE_ROWS do
		grid[row] = {}

		for col = 0, CURVE_COLS do
			local u = col / CURVE_COLS
			local v = row / CURVE_ROWS
			local nx = u * 2 - 1
			local ny = v * 2 - 1
			local factor = (1 + CURVE_BEND * (nx * nx + ny * ny)) / edge

			grid[row][col] = {
				x = (nx * factor * 0.5 + 0.5) * width,
				y = (ny * factor * 0.5 + 0.5) * height,
				u = u,
				v = v
			}
		end
	end

	local quads = {}

	for row = 0, CURVE_ROWS - 1 do
		for col = 0, CURVE_COLS - 1 do
			quads[#quads + 1] = {
				grid[row][col],
				grid[row][col + 1],
				grid[row + 1][col + 1],
				grid[row + 1][col]
			}
		end
	end

	state.mesh = quads
	state.meshWidth = width
	state.meshHeight = height

	return quads
end

function NETWORK.hud.IsThirdPersonHidden()
	return hudThird:GetBool() and NETWORK.thirdperson != nil and
		NETWORK.thirdperson.IsEnabled != nil and NETWORK.thirdperson.IsEnabled()
end

function NETWORK.hud.IsHidden(bIgnoreThird)
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return true
	end

	if (!hudEnabled:GetBool()) then
		return true
	end

	if (!bIgnoreThird and NETWORK.hud.IsThirdPersonHidden()) then
		return true
	end

	if (IsValid(NETWORK.gui.menu) or IsValid(NETWORK.gui.tabMenu) or
		IsValid(NETWORK.gui.cmbTerminal) or IsValid(NETWORK.gui.radial)) then
		return true
	end

	return client:GetNWBool("nwHideHUD", false)
end

function NETWORK.hud.GetFade()
	return NETWORK.hud.fade or 0
end

function NETWORK.hud.DrawContents()
	local function Block(name)
		local callback = NETWORK.hud[name]

		if (!isfunction(callback)) then
			return
		end

		local bSuccess, err = pcall(callback)

		if (!bSuccess and NETWORK.hud.reported != name) then
			NETWORK.hud.reported = name

			ErrorNoHalt("[network] HUD " .. name .. ": " .. tostring(err) .. "\n")
		end
	end

	if (hook.Run("NetworkShouldDrawHUD") != false) then

		Block("DrawStamina")
		Block("DrawStatus")
		Block("DrawAmmo")
	end

	local hooks = hook.GetTable().NetworkDrawHUD

	if (!hooks) then
		return
	end

	NETWORK.hud.reportedHooks = NETWORK.hud.reportedHooks or {}

	for name, callback in pairs(hooks) do
		local bSuccess, err = pcall(callback)

		if (!bSuccess and !NETWORK.hud.reportedHooks[name]) then
			NETWORK.hud.reportedHooks[name] = true

			ErrorNoHalt("[network] NetworkDrawHUD " .. tostring(name) .. ": " ..
				tostring(err) .. "\n")
		end
	end
end

local function Bar(x, y, width, height, value, maximum, color, alpha)
	local fraction = math.Clamp(value / math.max(maximum, 1), 0, 1)
	local fill = math.Round(width * fraction)

	surface.SetDrawColor(0, 0, 0, 195 * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(color.r, color.g, color.b, 250 * alpha)
	surface.DrawRect(x, y, fill, height)

	if (fill > 0) then
		surface.SetDrawColor(255, 255, 255, 30 * alpha)
		surface.DrawRect(x, y, fill, 1)
	end
end

function NETWORK.hud.DrawStatus()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local client = LocalPlayer()
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local alpha = NETWORK.hud.GetFade()
	local width = math.min(Sc(340), math.Round(ScrW() * 0.2))
	local height = math.max(Sc(4), 3)
	local x = Sc(22)
	local y = Sc(72)
	local step = height + Sc(8)

	local healthColor = Color(112, 34, 32)

	Bar(x, y, width, height, client:Health(),
		math.max(client:GetMaxHealth(), 1), healthColor, alpha)

	y = y + step

	local staminaShow = NETWORK.util.EaseInOut(NETWORK.hud.staminaShow or 0)

	if (staminaShow > 0.002) then
		local color = client:IsExhausted() and Color(150, 48, 42) or Color(96, 104, 112)
		local fraction = math.Clamp(client:GetStamina() /
			math.max(NETWORK.stamina.GetMax(client), 1), 0, 1)

		Bar(x, y, width, height, fraction * 100, 100, color, alpha * staminaShow)

		y = y + step * staminaShow
	end

	local name = character:GetName()

	local limit = math.Round(ScrW() * 0.3)

	surface.SetFont("nwHudPlayer")

	local nameWidth = surface.GetTextSize(name)

	if (nameWidth > limit) then
		name = util.TruncateWidth(name, "nwHudPlayer", limit)
		nameWidth = limit
	end

	local factionID = client:GetCharacterFaction()
	local faction = factionID and NETWORK.factions.Get(factionID)
	local classID = client:GetNWString("nwClass", "")
	local classTable = classID != "" and NETWORK.classes and
		NETWORK.classes.Get(classID)
	local job = util.Upper(classTable and classTable.name and L(classTable.name) or
		(faction and L(faction.name) or ""))

	local nameY = y + Sc(16)

	util.DrawSimpleTextShadow(name, "nwHudPlayer", x, nameY,
		ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)

	local jobX = x + nameWidth + Sc(16)
	local room = math.max(math.Round(ScrW() * 0.5) - (jobX - x), Sc(80))

	if (util.TextSpacedSize(job, "nwHudLabelSmall", Sc(3)) > room) then
		job = util.TruncateWidth(job, "nwHudLabelSmall", room)
	end

	util.DrawTextSpacedShadow(job, "nwHudLabelSmall", jobX, nameY,
		ColorAlpha(faction and faction.color or theme.textDim, 235 * alpha),
		Sc(3), TEXT_ALIGN_LEFT, 1)

	util.DrawSimpleTextShadow(client:GetTokens() .. " " .. L("furnTokens"),
		"nwHudLabelSmall", jobX, nameY + Sc(18),
		ColorAlpha(theme.value, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)

	NETWORK.hud.statusX = x
	NETWORK.hud.statusWidth = width
end

function NETWORK.hud.DrawStamina()
	local client = LocalPlayer()

	if (!client:HasCharacter()) then
		NETWORK.hud.staminaShow = 0

		return
	end

	local fraction = math.Clamp(client:GetStamina() /
		math.max(NETWORK.stamina.GetMax(client), 1), 0, 1)

	NETWORK.hud.staminaShow = math.Approach(NETWORK.hud.staminaShow or 0,
		fraction < 0.99 and 1 or 0, FrameTime() * 3)
end

function NETWORK.hud.DrawAmmo()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local client = LocalPlayer()
	local weapon = client:GetActiveWeapon()
	local bValid = IsValid(weapon) and weapon:GetPrimaryAmmoType() > -1 and
		weapon:GetMaxClip1() > 0

	NETWORK.hud.ammoShow = math.Approach(NETWORK.hud.ammoShow or 0,
		bValid and 1 or 0, FrameTime() * 5)

	local show = NETWORK.hud.ammoShow

	if (show <= 0.01) then
		return
	end

	local alpha = NETWORK.hud.GetFade() * show
	local clip = bValid and weapon:Clip1() or 0
	local reserve = bValid and client:GetAmmoCount(weapon:GetPrimaryAmmoType()) or 0
	local maximum = bValid and math.max(weapon:GetMaxClip1(), 1) or 1

	local right = ScrW() - Sc(34)
	local bottom = ScrH() - Sc(28)
	if (NETWORK.tk and NETWORK.tk.GetBrandSize) then
		local _, brandHeight = NETWORK.tk.GetBrandSize()

		bottom = bottom - brandHeight - Sc(18)
	end

	local y = bottom - Sc(18)
	local color = clip <= math.max(1, math.floor(maximum * 0.25)) and
		Color(226, 74, 66) or theme.text

	util.DrawSimpleTextShadow(clip, "nwHudPlayer", right - Sc(64), y,
		ColorAlpha(color, 252 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1)

	util.DrawSimpleTextShadow("/ " .. reserve, "nwHudLabelSmall", right, y + Sc(4),
		ColorAlpha(theme.textDim, 230 * alpha), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER, 1)

	NETWORK.hud.raiseShow = math.Approach(NETWORK.hud.raiseShow or 0,
		client:IsWeaponRaised() and 1 or 0, FrameTime() * 6)

	local raise = util.EaseInOut(NETWORK.hud.raiseShow)
	local barWidth = Sc(96)
	local barHeight = math.max(Sc(3), 2)
	local barX = right - barWidth
	local barY = y - Sc(24)

	surface.SetDrawColor(0, 0, 0, 170 * alpha)
	surface.DrawRect(barX, barY, barWidth, barHeight)

	local tint = raise > 0.5 and theme.hover or theme.textFaint

	surface.SetDrawColor(tint.r, tint.g, tint.b, 245 * alpha)
	surface.DrawRect(barX + math.Round(barWidth * (1 - raise) * 0.5), barY,
		math.max(math.Round(barWidth * (0.12 + 0.88 * raise)), 3), barHeight)
end

NETWORK.hud.bannerPath = NETWORK.hud.bannerPath or "logos/banner.png"

function NETWORK.hud.DrawBrand()
	-- Вместо картинки-баннера: иконка logos/n-logo.png и «Network: HL-A Roleplay».
	if (!NETWORK.tk or !NETWORK.tk.DrawBrand) then
		return
	end

	local Sc = NETWORK.util.Scale

	NETWORK.tk.DrawBrand(ScrW() - Sc(34), ScrH() - Sc(28), 1)
end

hook.Add("HUDPaint", "nwHud", function()
	local client = LocalPlayer()

	NETWORK.hud.fade = NETWORK.util.Approach(NETWORK.hud.fade,
		NETWORK.hud.IsHidden() and 0 or 1, 9)

	if (!hudEnabled:GetBool() or !IsValid(client) or !client:Alive() or
		!client:HasCharacter()) then
		return
	end

	local fade = NETWORK.hud.GetFade()

	if (fade < 0.01) then
		return
	end

	local offsetX, offsetY = 0, 0

	if (NETWORK.chud and NETWORK.chud.UpdateSway) then
		NETWORK.chud.UpdateSway(client)

		offsetX, offsetY = NETWORK.chud.GetSway()
	end

	local texture, material = GetCurveTarget()

	if (!texture or !material) then
		NETWORK.hud.DrawContents()

		return
	end

	NETWORK.util.PushBlurBlock()

	render.PushRenderTarget(texture)
		render.OverrideAlphaWriteEnable(true, true)
		render.Clear(0, 0, 0, 0, true, true)

		cam.Start2D()

			local matrix = Matrix()

			matrix:Translate(Vector(offsetX, offsetY, 0))

			cam.PushModelMatrix(matrix)
				local bDrawn, drawError = pcall(NETWORK.hud.DrawContents)
			cam.PopModelMatrix()
		cam.End2D()

		render.OverrideAlphaWriteEnable(false)
	render.PopRenderTarget()

	NETWORK.util.PopBlurBlock()

	if (!bDrawn) then
		NETWORK.util.PrintWarning("HUD: " .. tostring(drawError))

		return
	end

	surface.SetDrawColor(255, 255, 255, 255 * fade)
	surface.SetMaterial(material)

	for _, quad in ipairs(BuildCurveMesh()) do
		surface.DrawPoly(quad)
	end
end)

hook.Add("HUDPaint", "nwHudBrand", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	if (NETWORK.hud.IsHidden(true)) then
		return
	end

	-- Таб-меню рисует ту же подпись в своей нижней панели.
	if (IsValid(NETWORK.gui.tabMenu)) then
		return
	end

	NETWORK.hud.DrawBrand()
end)

hook.Add("InitPostEntity", "nwBuildStamp", function()
	timer.Simple(4, function()
		NETWORK.gui.Notify("Сборка " .. NETWORK.version .. " от " .. NETWORK.build,
			NETWORK.theme.value)
	end)
end)

concommand.Add("network_build", function()
	NETWORK.util.Print("Версия: " .. NETWORK.version)
	NETWORK.util.Print("Сборка: " .. NETWORK.build)
	NETWORK.util.Print("Файл: " .. debug.getinfo(1, "S").short_src)
end)

hook.Add("HUDShouldDraw", "nwCrosshair", function(name)
	if (name == "CHudCrosshair") then
		return false
	end
end)
