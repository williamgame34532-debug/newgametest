NETWORK.trap = NETWORK.trap or {}

local function TrapLabel(client, entity)
	local victim = entity.GetVictim and entity:GetVictim()

	if (IsValid(victim)) then
		return victim != client
	end

	return true
end

for class in pairs(NETWORK.trap.rebelClasses) do
	NETWORK.interact.Register(class, {
		label = "trapInteractDefuse",
		icon = "construction",
		CanUse = TrapLabel
	})
end

NETWORK.interact.Register("nw_lasermine", {
	CanUse = function(client)
		return NETWORK.factions.IsAlliance(client)
	end
})

hook.Add("Think", "nwTrapInteractLabel", function()
	local data = NETWORK.interact.targets and NETWORK.interact.targets.nw_beartrap

	if (!data) then
		return
	end

	local client = LocalPlayer()
	local entity = IsValid(client) and client:GetEyeTrace().Entity

	if (IsValid(entity) and entity:GetClass() == "nw_beartrap") then
		data.label = IsValid(entity:GetVictim()) and "trapInteractFree" or "trapInteractDefuse"
	end
end)

hook.Add("InitPostEntity", "nwTrapTurretInteract", function()
	local data = NETWORK.interact.targets and NETWORK.interact.targets.npc_turret_floor

	if (!data or data.bTrapWrapped) then
		return
	end

	local original = data.CanUse

	data.bTrapWrapped = true
	data.CanUse = function(client, entity)
		if (IsValid(entity) and entity:GetNWBool("nwTrapHacked", false)) then
			return client:IsAdmin() or NETWORK.trap.IsRebel(client)
		end

		if (original) then
			return original(client, entity)
		end

		return true
	end
end)

local highlighted = {}
local nextScan = 0
local HALO = Color(236, 172, 72)
local HALO_SPRUNG = Color(150, 150, 150)

hook.Add("PreDrawHalos", "nwTrapHighlight", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !NETWORK.trap.IsRebel(client) or !client:Alive()) then
		return
	end

	if (RealTime() >= nextScan) then
		nextScan = RealTime() + 0.25
		highlighted = {armed = {}, sprung = {}}

		for _, entity in ipairs(ents.FindInSphere(client:EyePos(), NETWORK.trap.highlightRange)) do
			if (IsValid(entity) and entity:GetClass() != "nw_beartrap" and NETWORK.trap.rebelClasses[entity:GetClass()]) then
				local list = entity:GetSprung() and highlighted.sprung or highlighted.armed

				list[#list + 1] = entity
			end
		end
	end

	if (highlighted.armed and #highlighted.armed > 0) then
		halo.Add(highlighted.armed, HALO, 1, 1, 1, true, false)
	end

	if (highlighted.sprung and #highlighted.sprung > 0) then
		halo.Add(highlighted.sprung, HALO_SPRUNG, 1, 1, 1, true, false)
	end
end)

hook.Add("HUDPaint", "nwTrapRooted", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !NETWORK.trap.IsRooted(client) or NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local left = math.max(0, client:GetNWFloat("nwTrapRoot", 0) - CurTime())
	local title = NETWORK.util.Upper(L("trapCaughtTitle"))
	local hint = L("trapStruggleHint", math.ceil(left))

	surface.SetFont("nwHudSmall")

	local hintWidth = surface.GetTextSize(hint)

	surface.SetFont("nwChat")

	local titleWidth = surface.GetTextSize(title)
	local width = math.max(hintWidth, titleWidth) + Sc(40)
	local height = Sc(58)
	local x = math.Round(ScrW() * 0.5 - width * 0.5)
	local y = math.Round(ScrH() * 0.72)

	surface.SetDrawColor(9, 12, 16, 215)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 200)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	surface.SetDrawColor(theme.danger.r, theme.danger.g, theme.danger.b, 235)
	surface.DrawRect(x, y, Sc(3), height)

	local fraction = math.Clamp(left / NETWORK.trap.rootTime, 0, 1)

	surface.SetDrawColor(theme.danger.r, theme.danger.g, theme.danger.b, 160)
	surface.DrawRect(x + Sc(3), y + height - Sc(2), (width - Sc(3)) * fraction, Sc(2))

	draw.SimpleText(title, "nwChat", x + width * 0.5, y + Sc(18), theme.text,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(hint, "nwHudSmall", x + width * 0.5, y + Sc(40), theme.textDim,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
