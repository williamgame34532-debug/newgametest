local shield = NETWORK.shield

local PANEL = Material("effects/combinemuzzle2")
local FLARE = Material("effects/blueflare1")
local GLOW = Material("sprites/light_glow02_add_noz")
local BEAM = Material("trails/electric")

local flashUntil = 0
local flashPower = 0
local hits = {}
local states = {}

net.Receive("nwShieldFlash", function()
	flashPower = math.Clamp(net.ReadFloat(), 0, 1)
	flashUntil = CurTime() + 2.6 * flashPower
end)

net.Receive("nwShieldHit", function()
	hits[#hits + 1] = {
		owner = net.ReadEntity(),
		position = net.ReadVector(),
		endTime = CurTime() + 0.45
	}
end)

local WIDTH = 34
local HEIGHT = 62
local FORWARD = 36
local CURVE = 5
local RIM_POINTS = 48

local function Profile(theta)
	local cos = math.cos(theta)
	local sin = math.sin(theta)

	local x = math.pow(math.abs(cos), 2 / 3.2) * (cos >= 0 and 1 or -1)
	local y = math.pow(math.abs(sin), 2 / 2.6) * (sin >= 0 and 1 or -1)

	return x, y
end

local function ShieldPoint(origin, forward, right, up, index, total)
	local theta = (index / total) * math.pi * 2
	local x, y = Profile(theta)

	return origin +
		forward * (FORWARD - math.cos(theta) ^ 2 * CURVE) +
		right * x * WIDTH +
		up * y * HEIGHT
end

NETWORK.shield.model = "models/synapse/props/combine_hand_shield.mdl"

local offF = CreateClientConVar("network_shield_f", "-2", true, false)
local offR = CreateClientConVar("network_shield_r", "15", true, false)
local offU = CreateClientConVar("network_shield_u", "11", true, false)
local rotP = CreateClientConVar("network_shield_pitch", "180", true, false)
local rotY = CreateClientConVar("network_shield_yaw", "-172", true, false)
local rotR = CreateClientConVar("network_shield_roll", "-19", true, false)
local scale = CreateClientConVar("network_shield_scale", "1", true, false)

local fbWidth = CreateClientConVar("network_shield_fw", "34", true, false)
local fbHeight = CreateClientConVar("network_shield_fh", "62", true, false)
local fbForward = CreateClientConVar("network_shield_ff", "36", true, false)
local fbHand = CreateClientConVar("network_shield_hand", "0", true, false)

NETWORK.shield.server = NETWORK.shield.server or nil

local SETTING_CONVARS = {
	f = offF, r = offR, u = offU, pitch = rotP, yaw = rotY, roll = rotR, scale = scale,
	fw = fbWidth, fh = fbHeight, ff = fbForward, hand = fbHand
}

local function Setting(key)
	local server = NETWORK.shield.server

	if (server and server[key] != nil) then
		return tonumber(server[key]) or 0
	end

	local convar = SETTING_CONVARS[key]

	return convar and convar:GetFloat() or 0
end

net.Receive("nwShieldSettings", function()
	local data = NETWORK.util.ReadTable()

	NETWORK.shield.server = istable(data) and next(data) != nil and data or nil
end)

net.Receive("nwShieldSaveRequest", function()
	local data = {}

	for key, convar in pairs(SETTING_CONVARS) do
		data[key] = convar:GetFloat()
	end

	net.Start("nwShieldSave")
		NETWORK.util.WriteTable(data)
	net.SendToServer()
end)

local models = {}

local function ShieldModel(owner)
	local entry = models[owner]

	if (entry == false) then

		return
	end

	if (entry and IsValid(entry)) then
		return entry
	end

	local entity = ClientsideModel(NETWORK.shield.model, RENDERGROUP_TRANSLUCENT)

	if (!IsValid(entity)) then
		models[owner] = false

		return
	end

	local loaded = entity:GetModel() or ""

	if (loaded == "" or string.find(loaded, "error", 1, true)) then
		entity:Remove()

		models[owner] = false

		return
	end

	entity:SetNoDraw(true)

	models[owner] = entity

	return entity
end

timer.Create("nwShieldModels", 1, 0, function()
	for owner, entity in pairs(models) do
		if (!IsValid(owner) or !shield.IsActive(owner) or !owner:Alive()) then
			if (isentity(entity) and IsValid(entity)) then
				entity:Remove()
			end

			models[owner] = nil
		end
	end
end)

local function DrawShieldModel(owner, entity)
	local pulse = 0.86 + math.sin(RealTime() * 3) * 0.14
	local alpha = shield.GetAlpha and shield.GetAlpha(owner) or 1

	local origin, angles

	local origin, angles

	if (owner == LocalPlayer() and !owner:ShouldDrawLocalPlayer()) then
		owner:InvalidateBoneCache()
	end

	owner:SetupBones()

	for _, name in ipairs({"ValveBiped.Bip01_L_Hand",
		"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_UpperArm"}) do
		local bone = owner:LookupBone(name)

		if (bone) then
			local matrix = owner:GetBoneMatrix(bone)

			if (matrix) then
				local position = matrix:GetTranslation()

				if (position:DistToSqr(owner:GetPos()) < 150 * 150) then
					origin = position
					angles = matrix:GetAngles()

					break
				end
			end
		end
	end

	if (!origin) then
		if (owner == LocalPlayer() and !owner:ShouldDrawLocalPlayer()) then
			local eyeAngles = owner:EyeAngles()

			origin = owner:EyePos() + eyeAngles:Forward() * 18 -
				eyeAngles:Right() * 14 - eyeAngles:Up() * 6
			angles = Angle(eyeAngles.p, eyeAngles.y, eyeAngles.r)
		else
			origin = shield.GetOrigin(owner)
			angles = shield.GetForward(owner):Angle()
		end
	end

	origin = origin + angles:Forward() * Setting("f") +
		angles:Right() * Setting("r") + angles:Up() * Setting("u")

	angles:RotateAroundAxis(angles:Up(), Setting("yaw"))
	angles:RotateAroundAxis(angles:Right(), Setting("pitch"))
	angles:RotateAroundAxis(angles:Forward(), Setting("roll"))

	entity:SetPos(origin)
	entity:SetAngles(angles)
	entity:SetModelScale(math.Clamp(Setting("scale"), 0.2, 4), 0)
	entity:SetupBones()

	render.SetBlend(0.82 * alpha * pulse)
	render.SetColorModulation(0.55, 0.95, 1)

	entity:DrawModel()

	render.SetBlend(0.35 * alpha * pulse)
	render.SetColorModulation(0.7, 1, 1)
	render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)

	entity:DrawModel()

	render.OverrideBlend(false)
	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)
end

local function HandTransform(owner)
	local origin, angles

	if (owner == LocalPlayer() and !owner:ShouldDrawLocalPlayer()) then
		owner:InvalidateBoneCache()
	end

	owner:SetupBones()

	for _, name in ipairs({"ValveBiped.Bip01_L_Hand",
		"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_UpperArm"}) do
		local bone = owner:LookupBone(name)

		if (bone) then
			local matrix = owner:GetBoneMatrix(bone)

			if (matrix) then
				local position = matrix:GetTranslation()

				if (position:DistToSqr(owner:GetPos()) < 150 * 150) then
					origin = position
					angles = matrix:GetAngles()

					break
				end
			end
		end
	end

	if (!origin) then
		if (owner == LocalPlayer() and !owner:ShouldDrawLocalPlayer()) then
			local eyeAngles = owner:EyeAngles()

			origin = owner:EyePos() + eyeAngles:Forward() * 18 -
				eyeAngles:Right() * 14 - eyeAngles:Up() * 6
			angles = Angle(eyeAngles.p, eyeAngles.y, eyeAngles.r)
		else
			origin = shield.GetOrigin(owner)
			angles = shield.GetForward(owner):Angle()
		end
	end

	return origin, angles
end

local function DrawShield(owner)

	local entity = ShieldModel(owner)

	if (IsValid(entity)) then
		DrawShieldModel(owner, entity)

		return
	end

	WIDTH = math.max(Setting("fw"), 4)
	HEIGHT = math.max(Setting("fh"), 4)
	FORWARD = Setting("ff")

	local angles = Angle(0, owner:EyeAngles().yaw, 0)
	local forward = angles:Forward()
	local right = angles:Right()
	local up = angles:Up()
	local origin

	if (Setting("hand") > 0.5) then
		origin = HandTransform(owner) + forward * 6 - right * 2 + up * 4
	else
		origin = shield.GetOrigin(owner)
	end

	local firstPerson = (owner == LocalPlayer() and
		!owner:ShouldDrawLocalPlayer())
	local alpha = firstPerson and 0.35 or 1

	local pulse = 0.75 + math.sin(CurTime() * 9) * 0.1 + math.Rand(-0.04, 0.04)

	local flash = math.max(0,
		1 - (CurTime() - owner:GetNWFloat("nwShieldFlashT", 0)) / 0.5)
	pulse = math.min(1.6, pulse + flash * 2)

	local slices = 12

	local color = Color(46 * pulse * alpha, 150 * pulse * alpha,
		168 * pulse * alpha)

	render.SetMaterial(PANEL)

	slices = 24

	local function Column(fraction)
		local x = fraction * 2 - 1

		local limit = math.pow(math.max(0, 1 - math.pow(math.abs(x), 3.2)),
			1 / 2.6)

		local across = right * x * WIDTH
		local bulge = forward * (FORWARD - x * x * CURVE)
		local half = limit * HEIGHT

		return origin + across + bulge + up * half,
			origin + across + bulge - up * half
	end

	local previousTop, previousBottom = Column(0)

	for index = 1, slices do
		local top, bottom = Column(index / slices)

		render.DrawQuad(previousTop, top, bottom, previousBottom, color)

		render.DrawQuad(top, previousTop, previousBottom, bottom, color)

		previousTop, previousBottom = top, bottom
	end

	render.SetMaterial(BEAM)

	local previous

	for index = 0, RIM_POINTS do
		local point = ShieldPoint(origin, forward, right, up, index, RIM_POINTS)

		if (previous) then

			render.DrawBeam(previous, point, 9, 0, 1,
				Color(90 * alpha, 210 * alpha, 225 * alpha, 140))
			render.DrawBeam(previous, point, 3.4, 0, 1,
				Color(210 * alpha, 255 * alpha, 255 * alpha))
		end

		previous = point
	end

	render.SetMaterial(BEAM)

	for index = 1, 5 do
		local height = (index / 6 * 2 - 1) * HEIGHT
		local half = math.sqrt(math.max(0, 1 - (height / HEIGHT) ^ 2)) * WIDTH

		render.DrawBeam(
			origin + forward * FORWARD - right * half + up * height,
			origin + forward * FORWARD + right * half + up * height,
			1.4, 0, 1, Color(120 * alpha, 240 * alpha, 235 * alpha, 140))
	end

	render.SetMaterial(FLARE)

	for _ = 1, 3 do
		local point = ShieldPoint(origin, forward, right, up,
			math.random(0, RIM_POINTS), RIM_POINTS)

		render.DrawSprite(point, math.Rand(4, 9), math.Rand(4, 9),
			Color(180, 240, 255, 200 * alpha))
	end

	render.SetMaterial(GLOW)
	render.DrawSprite(origin + forward * FORWARD, 46 * pulse, 60 * pulse,
		Color(70, 190, 255, 90 * alpha))

	for index = #hits, 1, -1 do
		local hit = hits[index]

		if (hit.endTime < CurTime()) then
			table.remove(hits, index)

			continue
		end

		if (hit.owner != owner) then
			continue
		end

		local life = (hit.endTime - CurTime()) / 0.45

		render.SetMaterial(FLARE)
		render.DrawSprite(hit.position, (1 - life) * 34 + 8, (1 - life) * 34 + 8,
			Color(255, 255, 255, 255 * life))
	end
end

hook.Add("PostDrawTranslucentRenderables", "nwShieldDraw", function(_, skybox)
	if (skybox) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (client:Alive() and shield.IsActive(client)) then
			DrawShield(client)
		end
	end
end)

hook.Add("Think", "nwShieldWatch", function()
	for _, client in ipairs(player.GetAll()) do
		local active = shield.IsActive(client)
		local state = states[client]

		if (state == nil) then
			states[client] = {active = active}

			continue
		end

		if (state.active != active) then
			state.active = active

			if (IsValid(client) and client:Alive()) then
				local sequence = client:LookupSequence(active and
					"shield_equip" or "shield_unequip")

				if (sequence and sequence >= 0) then
					client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM,
						sequence, 0, true)
				end
			end
		end

		if (active) then
			if (!state.loop) then
				state.loop = CreateSound(client,
					"ambient/energy/electric_loop.wav")
				state.loop:PlayEx(0.28, 130)
			end
		elseif (state.loop) then
			state.loop:Stop()
			state.loop = nil
		end
	end

	for client, state in pairs(states) do
		if (!IsValid(client)) then
			if (state.loop) then
				state.loop:Stop()
			end

			states[client] = nil
		end
	end
end)

hook.Add("HUDPaint", "nwShieldFlash", function()
	if (flashUntil < CurTime()) then
		return
	end

	local fraction = (flashUntil - CurTime()) / (2.6 * flashPower)

	surface.SetDrawColor(255, 255, 255, 255 * math.min(1, fraction * 1.6))
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)

hook.Add("HUDPaint", "nwShieldEnergy", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !shield.IsUser(client)) then
		return
	end

	local Sc = NETWORK.util.Scale
	local fraction = shield.GetEnergy(client) / shield.maxEnergy
	local broken = shield.IsBroken(client)
	local active = shield.IsActive(client)

	if (!active and !broken and fraction >= 1) then
		return
	end

	local width = Sc(190)
	local height = math.max(Sc(3), 2)
	local x = math.Round(ScrW() * 0.5 - width * 0.5)
	local y = ScrH() * 0.5 + Sc(58)

	local accent = broken and Color(238, 96, 84) or Color(104, 214, 255)
	local grace = client:GetNWFloat("nwShieldGrace", 0) - CurTime()

	if (grace > 0) then
		accent = Color(235, 245, 255)
	end

	surface.SetDrawColor(0, 0, 0, 170)
	surface.DrawRect(x - 1, y - 1, width + 2, height + 2)

	surface.SetDrawColor(18, 26, 34, 220)
	surface.DrawRect(x, y, width, height)

	local pulse = active and (0.82 + math.sin(CurTime() * 6) * 0.18) or 1

	surface.SetDrawColor(accent.r * pulse, accent.g * pulse, accent.b * pulse,
		250)
	surface.DrawRect(x, y, math.Round(width * math.Clamp(fraction, 0, 1)),
		height)

	surface.SetDrawColor(255, 255, 255, 60)
	surface.DrawRect(x + math.Round(width * 0.33), y - Sc(2), 1,
		height + Sc(4))

	local label

	if (broken) then
		label = L("shieldRecharge") .. "  " ..
			string.format("%.1f", math.max(
			client:GetNWFloat("nwShieldBroken", 0) - CurTime(), 0))
	elseif (grace > 0) then
		label = string.format("%.0f", grace)
	end

	if (label) then
		draw.SimpleTextOutlined(label, "nwHudSmall", ScrW() * 0.5,
			y + Sc(12), ColorAlpha(accent, 240), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
	end
end)
