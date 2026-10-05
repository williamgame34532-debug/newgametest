local VORT = NETWORK.vort

local function SendAura(id)
	net.Start("nwVortAura")
		net.WriteString(id)
	net.SendToServer()
end

local function SendCast(id)
	net.Start("nwVortCast")
		net.WriteString(id)
	net.SendToServer()
end

hook.Add("NetworkRadialMenus", "nwVort", function(client, menus, rootItems)
	if (!VORT.IsVort(client)) then
		return
	end

	local bFree = VORT.IsFree(client)
	local current = VORT.GetAura(client)
	local auraItems = {}
	local castItems = {}

	for _, data in ipairs(VORT.auras) do
		local bLocked = data.id != "none" and !bFree

		auraItems[#auraItems + 1] = {
			label = L(data.name),
			icon = data.icon,
			hint = bLocked and L("vortCollared") or L(data.hint),
			bActive = current == data.id,
			bStub = bLocked or nil,
			callback = !bLocked and function()
				SendAura(data.id)
			end or nil
		}
	end

	for _, id in ipairs(VORT.castOrder) do
		local cast = VORT.casts[id]
		local bOk, reason = VORT.CanCast(client, id)
		local hint = L(cast.hint)

		if (id == "pray" and VORT.IsPraying(client)) then
			bOk, hint = true, L("vortCastPrayStop")
		elseif (!bOk) then
			hint = reason == "vortCooldown" and
				L("vortCooldown", math.ceil(VORT.GetCooldown(client, id))) or L(reason)
		elseif (VORT.GetCost(client, id) > 0) then
			hint = hint .. "  ·  " .. L("vortCost", VORT.GetCost(client, id))
		end

		castItems[#castItems + 1] = {
			label = L(cast.name),
			icon = cast.icon,
			hint = hint,
			bActive = id == "pray" and VORT.IsPraying(client) or nil,
			bStub = !bOk or nil,
			callback = bOk and function()
				SendCast(id)
			end or nil
		}
	end

	local voiceItems = {}

	for index, entry in ipairs(VORT.voiceLines or {}) do
		voiceItems[#voiceItems + 1] = {
			label = L(entry.name),
			icon = "icon16/sound_low.png",
			hint = L("vortVoiceHint"),
			callback = function()
				net.Start("nwVortVoice")
					net.WriteUInt(index, 4)
				net.SendToServer()
			end
		}
	end

	local allItems = {}

	for _, item in ipairs(auraItems) do
		allItems[#allItems + 1] = item
	end

	for _, item in ipairs(castItems) do
		allItems[#allItems + 1] = item
	end

	for _, item in ipairs(voiceItems) do
		allItems[#allItems + 1] = item
	end

	menus.vortAuras = {title = L("vortMenuAuras"), items = auraItems}
	menus.vortCasts = {title = L("vortMenuCasts"), items = castItems}
	menus.vortVoice = {title = L("vortMenuVoice"), items = voiceItems}

	menus.vort = {title = L("vortMenu"), items = allItems, bScroll = true}

	table.insert(rootItems, 1, {
		label = L("vortMenu"),
		icon = "icon16/lightning.png",
		hint = L("vortEnergyLine", math.floor(VORT.GetEnergy(client))),
		menu = "vort"
	})
end)

hook.Add("Think", "nwVortLights", function()
	local eye = EyePos()

	for _, client in ipairs(player.GetAll()) do
		if (!VORT.IsVort(client) or !client:Alive() or client:IsDormant()) then
			continue
		end

		if (client:GetPos():DistToSqr(eye) > 2000 * 2000) then
			continue
		end

		local aura = VORT.GetAuraData(VORT.GetAura(client))
		local bPray = VORT.IsPraying(client)
		local bUnity = VORT.HasUnity(client)

		if (!(aura and aura.color) and !bPray and !bUnity) then
			continue
		end

		local light = DynamicLight(client:EntIndex() + 4096)

		if (!light) then
			continue
		end

		local color = bPray and Color(110, 255, 120) or
			(aura and aura.color or Color(120, 240, 120))
		local pulse = 0.7 + math.abs(math.sin(RealTime() * (bPray and 4 or 1.5))) * 0.3

		light.pos = client:WorldSpaceCenter()
		light.r = color.r
		light.g = color.g
		light.b = color.b
		light.brightness = (bUnity and 3 or 1.5) * pulse
		light.decay = 1000
		light.size = (bPray or bUnity) and 280 or 190
		light.dietime = CurTime() + 0.2
	end
end)

hook.Add("PreDrawHalos", "nwVortSight", function()
	local client = LocalPlayer()

	if (!IsValid(client) or client:GetNWFloat("nwVortSight", 0) <= CurTime()) then
		return
	end

	local range = VORT.casts.sight.range
	local allies, enemies = {}, {}

	for _, entity in ipairs(ents.FindInSphere(client:GetPos(), range)) do
		if (entity == client) then
			continue
		end

		if (VORT.IsEnemy(entity)) then
			enemies[#enemies + 1] = entity
		elseif ((entity:IsPlayer() and entity:Alive()) or
			(entity:IsNPC() and entity:Health() > 0)) then
			allies[#allies + 1] = entity
		end
	end

	halo.Add(enemies, Color(240, 90, 80), 2, 2, 1, true, true)
	halo.Add(allies, Color(120, 240, 140), 2, 2, 1, true, true)
end)

local function OpenVortMenu(level)
	local client = LocalPlayer()

	if (!VORT.IsVort(client)) then
		return NETWORK.gui.Notify(L("vortNotVort"), NETWORK.theme.warning)
	end

	local panel, reason = NETWORK.gui.OpenRadial()

	if (!IsValid(panel)) then
		return NETWORK.gui.Notify(tostring(reason or ""), NETWORK.theme.warning)
	end

	timer.Simple(0, function()
		if (IsValid(panel)) then
			panel:SetLevel(level)
		end
	end)
end

concommand.Add("nw_auras", function()
	NETWORK.gui.OpenVortWheel()
end)

concommand.Add("nw_casts", function()
	NETWORK.gui.OpenVortWheel()
end)

local glows = {}

net.Receive("nwVortGlow", function()
	local owner = net.ReadEntity()
	local color = net.ReadColor()
	local duration = net.ReadFloat()

	if (!IsValid(owner)) then
		return
	end

	glows[owner] = {
		color = color,
		start = RealTime(),
		duration = duration
	}
end)

hook.Add("Think", "nwVortGlow", function()
	if (!next(glows)) then
		return
	end

	local now = RealTime()
	local index = 0

	for owner, glow in pairs(glows) do
		local age = now - glow.start

		if (!IsValid(owner) or age > glow.duration) then
			glows[owner] = nil

			continue
		end

		index = index + 1

		local fraction = age / glow.duration
		local power = math.sin(fraction * math.pi)

		local light = DynamicLight(16384 + index)

		if (!light) then
			continue
		end

		light.pos = owner:WorldSpaceCenter() + owner:GetForward() * 12
		light.r = glow.color.r
		light.g = glow.color.g
		light.b = glow.color.b
		light.brightness = 3 * power
		light.decay = 900
		light.size = 220 * (0.5 + power * 0.5)
		light.dietime = CurTime() + 0.1
	end
end)

local flares = {}

local ringMaterial = Material("effects/select_ring")
local glowMaterial = Material("sprites/light_glow02_add")

local function FlareLife(flare)
	return 1.6 + flare.scale * 0.2
end

net.Receive("nwVortFx", function()
	local owner = net.ReadEntity()
	local id = net.ReadString()
	local origin = net.ReadVector()
	local scale = net.ReadFloat()

	flares[#flares + 1] = {
		owner = owner,
		id = id,
		origin = origin,
		scale = math.Clamp(scale, 1, 6),
		start = RealTime()
	}

	local client = LocalPlayer()

	if (IsValid(client) and client:GetPos():Distance(origin) < 1200) then
		surface.PlaySound("ambient/energy/zap" .. math.random(1, 3) .. ".wav")
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwVortFx", function(bDepth, bSky)
	if (bSky or #flares == 0) then
		return
	end

	local now = RealTime()

	for index = #flares, 1, -1 do
		local flare = flares[index]
		local age = now - flare.start
		local life = FlareLife(flare)

		if (age > life) then
			table.remove(flares, index)

			continue
		end

		local fraction = age / life
		local fade = 1 - fraction
		local radius = NETWORK.vort.auraRadius * flare.scale * fraction
		local origin = IsValid(flare.owner) and flare.owner:WorldSpaceCenter() or
			flare.origin

		render.SetMaterial(ringMaterial)
		render.DrawQuadEasy(Vector(origin.x, origin.y, flare.origin.z - 30),
			Vector(0, 0, 1), radius * 2, radius * 2,
			Color(140, 255, 150, 220 * fade), 0)

		render.SetMaterial(glowMaterial)
		render.DrawSprite(origin, 220 * flare.scale * fade,
			220 * flare.scale * fade, Color(150, 255, 160, 200 * fade))

		for step = 1, 6 do
			render.DrawSprite(origin + Vector(0, 0, step * 40 * fraction),
				120 * fade, 120 * fade,
				Color(120, 240, 140, (160 - step * 20) * fade))
		end
	end
end)

hook.Add("Think", "nwVortFxLight", function()
	if (#flares == 0) then
		return
	end

	local now = RealTime()

	for index, flare in ipairs(flares) do
		local fade = 1 - (now - flare.start) / FlareLife(flare)

		if (fade <= 0) then
			continue
		end

		local light = DynamicLight(8192 + index)

		if (!light) then
			continue
		end

		light.pos = flare.origin + Vector(0, 0, 40)
		light.r = 130
		light.g = 255
		light.b = 150
		light.brightness = 6 * fade * flare.scale
		light.decay = 600
		light.size = 400 * flare.scale
		light.dietime = CurTime() + 0.1
	end
end)

hook.Add("HUDPaint", "nwVortFxScreen", function()
	if (#flares == 0 or !NETWORK.util.DrawVignette) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local now = RealTime()
	local strength = 0

	for _, flare in ipairs(flares) do
		local fade = 1 - (now - flare.start) / FlareLife(flare)
		local distance = client:GetPos():Distance(flare.origin)
		local reach = NETWORK.vort.auraRadius * flare.scale * 2

		if (fade > 0 and distance < reach) then
			strength = math.max(strength, fade * (1 - distance / reach))
		end
	end

	if (strength <= 0.01) then
		return
	end

	NETWORK.util.DrawVignette(0, 0, ScrW(), ScrH(),
		math.Round(math.min(ScrW(), ScrH()) * 0.55), 190 * strength,
		Color(60, 200, 90))
end)

local omen

net.Receive("nwVortOmen", function()
	omen = {
		id = net.ReadString(),
		center = net.ReadVector(),
		start = RealTime()
	}

	surface.PlaySound("ambient/levels/citadel/strange_talk" .. math.random(1, 11) .. ".wav")
	surface.PlaySound("ambient/atmosphere/thunder" .. math.random(1, 4) .. ".wav")

	chat.nwAddText(Color(130, 240, 120), L("vortOmen_" .. omen.id))
end)

hook.Add("HUDPaint", "nwVortOmen", function()
	if (!omen) then
		return
	end

	local age = RealTime() - omen.start
	local duration = 10

	if (age > duration) then
		omen = nil

		return
	end

	local fade = age < 1 and age or math.Clamp((duration - age) / (duration - 1), 0, 1)
	local client = LocalPlayer()
	local near = IsValid(client) and client:GetPos():Distance(omen.center) < 1500 and 1 or 0.55

	if (NETWORK.util.DrawVignette) then
		NETWORK.util.DrawVignette(0, 0, ScrW(), ScrH(),
			math.Round(math.min(ScrW(), ScrH()) * 0.6), 150 * fade * near, Color(40, 150, 60))
	end

	local Sc = NETWORK.util.Scale

	draw.SimpleTextOutlined(L("vortOmen_" .. omen.id), "nwTermTitle", ScrW() * 0.5,
		ScrH() * 0.2, Color(160, 255, 160, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
		1, Color(0, 0, 0, 200 * fade))

	draw.SimpleTextOutlined(L("vortOmenSub_" .. omen.id), "nwHudSmall", ScrW() * 0.5,
		ScrH() * 0.2 + Sc(30), Color(200, 240, 200, 230 * fade), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180 * fade))
end)

hook.Add("RenderScreenspaceEffects", "nwVortHaze", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local left = client:GetNWFloat("nwVortHaze", 0) - CurTime()

	if (left <= 0) then
		return
	end

	local strength = math.Clamp(left / 5, 0, 1)

	DrawMotionBlur(0.2, 0.6 * strength, 0.01)
	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0.04 * strength,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.04 * strength,
		["$pp_colour_contrast"] = 1,
		["$pp_colour_colour"] = 1 - 0.5 * strength,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})
end)

hook.Add("HUDPaint", "nwVortState", function()
	local client = LocalPlayer()

	if (!VORT.IsVort(client) or !client:Alive()) then
		return
	end

	if (NETWORK.hud and NETWORK.hud.IsHidden and NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local y = ScrH() - Sc(84)
	local bHigh = VORT.IsHigh(client)
	local parts = {}
	local aura = VORT.GetAura(client)

	if (bHigh) then
		parts[#parts + 1] = L("vortHighLine")
	end

	if (aura != "none") then
		parts[#parts + 1] = L(VORT.GetAuraData(aura).name)
	end

	if (VORT.HasUnity(client)) then
		parts[#parts + 1] = L("vortUnityLine",
			math.ceil((client:GetNWFloat("nwVortUnity", 0) - CurTime()) / 60))
	end

	if (VORT.IsPraying(client)) then
		parts[#parts + 1] = L("vortPrayLine")
	end

	if (#parts == 0) then
		return
	end

	draw.SimpleTextOutlined(table.concat(parts, "  ·  "), "nwHudSmall", ScrW() * 0.5,
		y - Sc(12), Color(170, 245, 180, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1,
		Color(0, 0, 0, 180))
end)

hook.Add("HUDPaint", "nwVortDread", function()
	local client = LocalPlayer()

	if (!IsValid(client) or client:GetNWFloat("nwVortDreaded", 0) <= CurTime()) then
		return
	end

	if (NETWORK.util.DrawVignette) then
		local pulse = 0.7 + math.abs(math.sin(RealTime() * 1.3)) * 0.3

		NETWORK.util.DrawVignette(0, 0, ScrW(), ScrH(),
			math.Round(math.min(ScrW(), ScrH()) * 0.5), 70 * pulse, Color(90, 40, 140))
	end
end)
