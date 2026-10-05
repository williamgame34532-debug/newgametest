local damage = {alpha = 0, dir = 0}

hook.Add("HUDPaint", "nwDamageScreen", function()
	if (damage.alpha <= 0.01 or !NETWORK.option.Get("network_damagescreen")) then
		return
	end

	damage.alpha = NETWORK.util.Approach(damage.alpha, 0, 1.6)

	local width, height = ScrW(), ScrH()
	local size = math.Round(width * 0.22)
	local alpha = 200 * damage.alpha

	surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-r"))
	surface.SetDrawColor(150, 20, 20, alpha)

	if (damage.dir <= 0) then
		surface.DrawTexturedRect(0, 0, size, height)
	end

	if (damage.dir >= 0) then
		surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-l"))
		surface.DrawTexturedRect(width - size, 0, size, height)
	end
end)

net.Receive("nwDamageDirection", function()
	damage.alpha = math.min(damage.alpha + net.ReadFloat(), 1)
	damage.dir = net.ReadInt(4)
end)

local colourTable = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

hook.Add("RenderScreenspaceEffects", "nwHurtVision", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or
		!NETWORK.option.Get("network_hurtvision")) then
		return
	end

	local ratio = math.Clamp(client:Health() / math.max(client:GetMaxHealth(), 1),
		0, 1)

	if (ratio > 0.35) then
		return
	end

	local strength = 1 - (ratio / 0.35)

	colourTable["$pp_colour_colour"] = 1 - strength * 0.75
	colourTable["$pp_colour_contrast"] = 1 + strength * 0.15
	colourTable["$pp_colour_brightness"] = -strength * 0.06

	DrawColorModify(colourTable)
end)

local labels = {
	nw_dispenser = "entDispenser",
	nw_vending = "entVending",
	nw_fridge = "entFridge",
	nw_container = "entContainer",
	nw_locker = "entLocker",
	nw_terminal = "entTerminal",
	nw_workterminal = "entWorkTerminal",
	nw_business_terminal = "entBusinessTerminal",
	nw_cmbterminal = "entCmbTerminal",
	nw_cwuterminal = "entCwuTerminal",
	nw_jailterminal = "entJailTerminal",
	nw_factory_terminal = "entFactoryTerminal",
	nw_factory_table = "entFactoryTable",
	nw_factory_box = "entFactoryBox",
	nw_factory_crate = "entFactoryCrate",
	nw_factory_part = "entFactoryPart",
	nw_fabricator = "entFabricator",
	nw_recruiter = "entRecruiter",
	nw_trader = "entTrader",
	nw_stash = "entStash",
	nw_furnitureshop = "entFurnitureShop",
	nw_furniture = "entFurniture",
	nw_breaker = "entBreaker",
	nw_junk = "entJunk",
	nw_bodybag = "entBodybag",
	nw_forcefield = "entForcefield",
	nw_scanner = "entScanner",
	nw_mine = "entMine",
	nw_xenlife = "entXenlife"
}

local hint = {alpha = 0, text = ""}

hook.Add("HUDPaint", "nwEntityHint", function()
	if (!NETWORK.option.Get("network_entityhints")) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity
	local key = IsValid(entity) and labels[entity:GetClass()]

	if (key and client:GetPos():Distance(trace.HitPos) < 110) then
		hint.text = L(key)
		hint.alpha = NETWORK.util.Approach(hint.alpha, 1, 8)
	else
		hint.alpha = NETWORK.util.Approach(hint.alpha, 0, 8)
	end

	if (hint.alpha <= 0.01) then
		return
	end

	NETWORK.util.DrawSimpleTextShadow(NETWORK.util.Upper(hint.text), "nwHudSmall",
		math.Round(ScrW() * 0.5), math.Round(ScrH() * 0.5) +
		NETWORK.util.Scale(38),
		ColorAlpha(NETWORK.theme.textDim, 235 * hint.alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER, math.max(NETWORK.util.Scale(2), 1))
end)

NETWORK.option.Register("network_damagescreen", {
	name = "optDamageScreen",
	description = "optDamageScreenDesc",
	category = "hud",
	type = "bool",
	default = 1
})

NETWORK.option.Register("network_hurtvision", {
	name = "optHurtVision",
	description = "optHurtVisionDesc",
	category = "hud",
	type = "bool",
	default = 1
})

NETWORK.option.Register("network_entityhints", {
	name = "optEntityHints",
	description = "optEntityHintsDesc",
	category = "hud",
	type = "bool",
	default = 1
})

local dim = 0

local function IsMenuOpen()
	local panels = {
		NETWORK.gui.menu, NETWORK.gui.inventory, NETWORK.gui.container,
		NETWORK.gui.search, NETWORK.gui.terminal, NETWORK.gui.squadOrders,
		NETWORK.gui.bodygroups, NETWORK.gui.creation
	}

	for _, panel in ipairs(panels) do
		if (IsValid(panel) and panel:IsVisible()) then
			return true
		end
	end

	return false
end

hook.Add("HUDPaintBackground", "nwMenuDim", function()
	dim = math.Approach(dim, IsMenuOpen() and 1 or 0,
		FrameTime() * 4)

	if (dim <= 0.01) then
		return
	end

	surface.SetDrawColor(2, 4, 7, 175 * NETWORK.util.EaseOut(dim))
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)
