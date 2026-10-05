NETWORK.visor = NETWORK.visor or {}

NETWORK.visor.overlay = "framework/cmb/visor/cmb_overlay"
NETWORK.visor.overlays = {
	cp = "framework/cmb/visor/cmb_overlay",
	cmb = "framework/cmb/visor/soldier_overlay",
	elite = "framework/cmb/visor/elite_overlay",
	cwu = "framework/cmb/visor/cmb_overlay"
}

NETWORK.visor.classicOverlay = "effects/combine_binocoverlay"

NETWORK.visor.fallback = "effects/combine_binocoverlay"

local styleConVar = CreateClientConVar("network_visorstyle", "modern", true,
	false, "Стиль визора Альянса: modern или classic")

function NETWORK.visor.IsClassic()
	return styleConVar:GetString() == "classic"
end
NETWORK.visor.maxCracks = 16
NETWORK.visor.growTime = 0.22
NETWORK.visor.settleTime = 2

local cracks = {}
local materials = {}
local visorFrac = 0

local scaleConVar = CreateClientConVar("network_visor", "1", true, false,
	"Насколько заметен визор Альянса (0-1)")

function NETWORK.visor.IsWearing()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (NETWORK.classes and NETWORK.classes.HasCivilianHud(client)) then
		return false
	end

	return client:IsCombine() or
		(client.IsCWUMember and client:IsCWUMember())
end

function NETWORK.visor.GetOverlayPath()
	if (!NETWORK.visor.IsWearing()) then
		return
	end

	if (NETWORK.visor.IsClassic()) then
		return NETWORK.visor.classicOverlay
	end

	local client = LocalPlayer()
	local kind = NETWORK.chud and NETWORK.chud.GetKind(client)

	if (kind == "cmb" and client:GetNWString("nwClass", "") == "wallhammer") then
		kind = "elite"
	end

	return NETWORK.visor.overlays[kind or ""] or NETWORK.visor.overlay
end

local function GetMaterial(path)

	if (!isstring(path) or path == "") then
		return
	end

	local material = materials[path]

	if (!material) then
		material = Material(path)
		materials[path] = material
	end

	if (!material:IsError()) then
		return material
	end

	local fallback = NETWORK.visor.fallback

	if (!isstring(fallback) or fallback == "" or fallback == path) then
		return
	end

	return GetMaterial(fallback)
end

function NETWORK.visor.GetScale()
	return math.Clamp(scaleConVar:GetFloat(), 0, 1)
end

local function BuildCrack(power)
	local branches = {}

	for _ = 1, math.random(6, 9) do
		local angle = math.Rand(0, math.pi * 2)
		local length = math.Rand(0.05, 0.14) * power
		local steps = math.random(3, 5)
		local step = length / steps
		local segments = {}
		local pointX, pointY = 0, 0

		for _ = 1, steps do
			angle = angle + math.Rand(-0.38, 0.38)

			local nextX = pointX + math.cos(angle) * step
			local nextY = pointY + math.sin(angle) * step * 1.7

			segments[#segments + 1] = {pointX, pointY, nextX, nextY}
			pointX, pointY = nextX, nextY
		end

		if (math.random() > 0.45) then
			local origin = segments[math.random(1, #segments)]
			local forkAngle = angle + math.Rand(-1.2, 1.2)
			local forkLength = length * math.Rand(0.25, 0.5)

			segments[#segments + 1] = {
				origin[3], origin[4],
				origin[3] + math.cos(forkAngle) * forkLength,
				origin[4] + math.sin(forkAngle) * forkLength * 1.7
			}
		end

		branches[#branches + 1] = segments
	end

	return branches
end

function NETWORK.visor.AddCrack(x, y, power)
	if (#cracks >= NETWORK.visor.maxCracks) then
		table.remove(cracks, 1)
	end

	cracks[#cracks + 1] = {
		fade = 1,
		x = math.Clamp(x, 0.08, 0.92),
		y = math.Clamp(y, 0.1, 0.9),
		power = power,
		born = RealTime(),
		branches = BuildCrack(power)
	}
end

function NETWORK.visor.Clear()
	cracks = {}
	visorFrac = 0
end

net.Receive("nwVisorCrack", function()
	local x = net.ReadFloat()
	local y = net.ReadFloat()
	local power = math.Clamp(net.ReadFloat(), 0.5, 2)

	visorFrac = math.Clamp(net.ReadFloat(), 0, 1)

	NETWORK.visor.AddCrack(x, y, power)
end)

net.Receive("nwVisorReset", function()
	NETWORK.visor.Clear()
end)

hook.Add("NetworkCharacterLoaded", "nwVisor", function()
	NETWORK.visor.Clear()
end)

hook.Add("RenderScreenspaceEffects", "nwVisor", function()
	local path = NETWORK.visor.GetOverlayPath()

	if (!path) then
		return
	end

	local scale = NETWORK.visor.GetScale()

	if (scale <= 0.01) then
		return
	end

	local material = GetMaterial(path)

	if (!material) then
		return
	end

	DrawMaterialOverlay(path, 0.06 * scale)
end)

local function DrawStatic(color, level, alpha)
	if (level < 0.2) then
		return
	end

	local width, height = ScrW(), ScrH()
	local power = (level - 0.2) / 0.8

	for _ = 1, 1 + math.floor(power * 5) do
		if (math.random() < 0.3 + power * 0.4) then
			local bandHeight = math.random(2, math.floor(8 + power * 26))

			surface.SetDrawColor(color.r, color.g, color.b, (14 + power * 30) * alpha)
			surface.DrawRect(math.random(-40, 40), math.random(0, height - bandHeight),
				width, bandHeight)
		end
	end
end

hook.Add("HUDPaint", "nwVisor", function()
	if (!NETWORK.visor.GetOverlayPath() or NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local scale = NETWORK.visor.GetScale()

	if (scale <= 0.01) then
		return
	end

	local client = LocalPlayer()
	local faction = NETWORK.factions.Get(client:GetCharacterFaction())
	local color = faction and faction.color or NETWORK.theme.accent
	local alpha = 1

	DrawStatic(color, visorFrac * scale, alpha)

	if (#cracks == 0) then
		return
	end

	local width, height = ScrW(), ScrH()
	local now = RealTime()
	local allowed = math.floor(visorFrac * NETWORK.visor.maxCracks + 0.5)
	local frameTime = FrameTime()

	for index = #cracks, 1, -1 do
		local crack = cracks[index]
		local age = now - crack.born

		local bKeep = index <= allowed or age < NETWORK.visor.settleTime

		crack.fade = math.Approach(crack.fade or 1, bKeep and 1 or 0, frameTime * 1.5)

		if (crack.fade <= 0) then
			table.remove(cracks, index)

			continue
		end

		local grow = math.Clamp(age / NETWORK.visor.growTime, 0, 1)
		local visual = alpha * scale * crack.fade
		local originX = crack.x * width
		local originY = crack.y * height

		if (visual <= 0.01) then
			continue
		end

		for _, segments in ipairs(crack.branches) do
			for step = 1, math.max(math.ceil(#segments * grow), 1) do
				local line = segments[step]
				local x1 = originX + line[1] * height
				local y1 = originY + line[2] * height
				local x2 = originX + line[3] * height
				local y2 = originY + line[4] * height

				surface.SetDrawColor(4, 6, 9, 210 * visual)
				surface.DrawLine(x1 + 1, y1 + 1, x2 + 1, y2 + 1)

				surface.SetDrawColor(color.r, color.g, color.b, 180 * visual)
				surface.DrawLine(x1, y1, x2, y2)
			end
		end

		local flare = math.max(Sc(5), 3) * crack.power * grow

		surface.SetDrawColor(color.r, color.g, color.b, 140 * visual)
		surface.DrawRect(originX - flare * 0.5, originY - flare * 0.5, flare, flare)

		surface.SetDrawColor(255, 255, 255, 90 * visual)
		surface.DrawRect(originX - flare * 0.2, originY - flare * 0.2,
			flare * 0.4, flare * 0.4)
	end
end)

concommand.Add("network_visor_material", function(_, _, arguments)
	local path = arguments[1]

	if (!path) then
		NETWORK.util.Print("Текущие накладки:")

		for label, current in pairs({overlay = NETWORK.visor.overlay}) do
			local material = Material(current)

			NETWORK.util.Print("  " .. label .. " = " .. current ..
				(material:IsError() and "  [НЕ НАЙДЕНА]" or "  [ок]"))
		end

		NETWORK.util.Print("Использование: network_visor_material <путь> [фракция]")

		return
	end

	local faction = arguments[2] or "cp"

	NETWORK.visor.overlay = path
	materials[path] = nil

	NETWORK.util.Print("Накладка " .. faction .. " -> " .. path)
end)

concommand.Add("network_visor_test", function()
	NETWORK.visor.AddCrack(math.Rand(0.2, 0.8), math.Rand(0.25, 0.7), math.Rand(0.8, 1.5))

	visorFrac = math.min(visorFrac + 0.15, 1)
end)

local askedConVar = CreateClientConVar("network_visorasked", "0", true, false,
	"Предложение сменить визор уже показывалось")

local function OfferVisor()
	if (askedConVar:GetBool() or !NETWORK.visor.IsWearing()) then
		return
	end

	local chat = NETWORK.gui.chat

	if (!IsValid(chat) or !chat.AddPrompt) then
		return
	end

	askedConVar:SetBool(true)

	chat:AddPrompt("<font=nwChatBig><color=240,196,84>" .. L("visorOffer") ..
		"</color></font>", "notice", function()
			RunConsoleCommand("network_visorstyle", "classic")

			chat:AddMarkup("<font=nwChatBig><color=120,220,140>" ..
				L("visorSwitched") .. "</color></font>", "notice")
		end)
end

hook.Add("NetworkCharacterLoaded", "nwVisorOffer", function()
	timer.Simple(5, OfferVisor)
end)

concommand.Add("network_visor_toggle", function()
	local bClassic = !NETWORK.visor.IsClassic()

	RunConsoleCommand("network_visorstyle", bClassic and "classic" or "modern")

	local panel = NETWORK.gui.chat

	if (IsValid(panel)) then
		panel:AddMarkup("<color=120,220,140>" ..
			L(bClassic and "visorSwitched" or "visorReverted") .. "</color>",
			"notice")
	end
end)
