AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Ксен-нарост"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.PhysgunDisabled = false

ENT.Models = {
	"models/jq/hlvr/props/xen/xen_foam_anchor01.mdl",
	"models/jq/hlvr/props/xen/xen_foam_base001.mdl"
}

ENT.GrowInterval = 45
ENT.GrowRadius = 160
ENT.MaxColony = 14
ENT.GasRadius = 150
ENT.RespawnDelay = 1800

if (SERVER) then
	NETWORK.xen = NETWORK.xen or {}
	NETWORK.xen.roots = NETWORK.xen.roots or {}

	NETWORK.command.Register("xenclear", {
		description = "cmdXenClear",
		usage = "/xenclear [радиус]",
		example = "/xenclear 600",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local radius = math.Clamp(tonumber(arguments[1]) or 600, 64, 4096)
			local count = 0

			for _, entity in ipairs(ents.FindInSphere(client:GetPos(), radius)) do
				if (entity:GetClass() != "nw_xenlife") then
					continue
				end

				for index = #NETWORK.xen.roots, 1, -1 do
					if (NETWORK.xen.roots[index].entity == entity) then
						table.remove(NETWORK.xen.roots, index)
					end
				end

				entity:Remove()

				count = count + 1
			end

			NETWORK.chat.Notice(client, L("xenCleared", count))
		end
	})

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_xenlife")

		entity:SetPos(trace.HitPos)
		entity:Spawn()
		entity:Activate()
		entity.bRoot = true

		NETWORK.xen.roots[#NETWORK.xen.roots + 1] = {
			position = trace.HitPos,
			entity = entity
		}

		return entity
	end

	function ENT:Initialize()
		local model = self.Models[math.random(#self.Models)]

		if (file.Exists(model, "GAME")) then
			util.PrecacheModel(model)
		else
			model = "models/props_wasteland/antlion_hill.mdl"
			util.PrecacheModel(model)
		end

		self:SetModel(model)

		local mins, maxs = self:OBBMins(), self:OBBMaxs()

		if (maxs:Distance(mins) < 8) then
			mins, maxs = Vector(-16, -16, 0), Vector(16, 16, 32)
		end

		self:SetCollisionBounds(mins, maxs)
		self:SetSolid(SOLID_BBOX)
		self:SetMoveType(MOVETYPE_NONE)
		self:PhysicsInitBox(mins, maxs)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.nextGrow = CurTime() + self.GrowInterval * math.Rand(0.6, 1.4)
		self.nextGas = 0
	end

	local function ColonySize(origin)
		local count = 0

		for _, entity in ipairs(ents.FindInSphere(origin, 600)) do
			if (entity:GetClass() == "nw_xenlife") then
				count = count + 1
			end
		end

		return count
	end

	function ENT:Think()

		if (CurTime() >= (self.nextGrow or 0)) then
			self.nextGrow = CurTime() + self.GrowInterval * math.Rand(0.8, 1.3)

			if (ColonySize(self:GetPos()) < self.MaxColony) then
				local offset = Angle(0, math.Rand(0, 360), 0):Forward() *
					math.Rand(70, self.GrowRadius)
				local trace = util.TraceLine({
					start = self:GetPos() + offset + Vector(0, 0, 60),
					endpos = self:GetPos() + offset - Vector(0, 0, 120)
				})

				if (trace.Hit and !trace.HitSky) then
					local child = ents.Create("nw_xenlife")

					if (IsValid(child)) then
						child:SetPos(trace.HitPos)
						child:Spawn()
						child:Activate()
						child:EmitSound(
							"ambient/levels/canals/toxic_slime_gurgle" ..
							math.random(3) .. ".wav", 55)
					end
				end
			end
		end

		if (CurTime() >= (self.nextGas or 0)) then
			self.nextGas = CurTime() + 1.5

			for _, client in ipairs(ents.FindInSphere(self:GetPos(),
				self.GasRadius)) do
				if (client:IsPlayer() and client:Alive() and
					client:HasCharacter() and
					!NETWORK.factions.IsAlliance(client) and
					!NETWORK.factions.IsCWU(client) and
					!NETWORK.xen.HasGasmask(client)) then
					local damage = DamageInfo()

					damage:SetDamage(3)
					damage:SetDamageType(DMG_NERVEGAS)
					damage:SetAttacker(self)
					damage:SetInflictor(self)

					client:TakeDamageInfo(damage)
					client:ScreenFade(SCREENFADE.IN, Color(120, 160, 60, 40),
						0.5, 0.2)
				end
			end
		end

		self:NextThink(CurTime() + 0.5)

		return true
	end

	function NETWORK.xen.HasGasmask(client)
		return client:GetNWBool("nwGasmask") and
			client:GetNWFloat("nwGasmaskFilter", 0) > os.time()
	end

	function ENT:OnRemove()
		if (!self.bRoot) then
			return
		end

		for _, root in ipairs(NETWORK.xen.roots) do
			if (root.entity != self and IsValid(root.entity)) then
				return
			end
		end

		local positions = {}

		for _, root in ipairs(NETWORK.xen.roots) do
			positions[#positions + 1] = root.position
		end

		NETWORK.xen.roots = {}

		timer.Simple(0.1, function()
			for _, entity in ipairs(ents.FindByClass("nw_xenlife")) do
				entity:EmitSound("npc/antlion_grub/squashed.wav", 60)
				entity:Remove()
			end
		end)

		timer.Simple(self.RespawnDelay, function()
			for _, position in ipairs(positions) do
				local root = ents.Create("nw_xenlife")

				if (IsValid(root)) then
					root:SetPos(position)
					root:Spawn()
					root:Activate()
					root.bRoot = true

					NETWORK.xen.roots[#NETWORK.xen.roots + 1] = {
						position = position,
						entity = root
					}
				end
			end
		end)
	end

	util.AddNetworkString("nwXenStart")
	util.AddNetworkString("nwXenSpot")

	NETWORK.xen.sessions = NETWORK.xen.sessions or {}

	ENT.CleanSpots = 6

	function ENT:Use(client)
		if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 1

		if (!NETWORK.factions.IsCWU(client) and !client:IsAdmin()) then
			NETWORK.chat.Notice(client, "xenNotYours")

			return
		end

		if (NETWORK.xen.sessions[client]) then
			return
		end

		NETWORK.xen.sessions[client] = {
			entity = self,
			done = 0,
			need = self.CleanSpots,
			nextSpot = 0
		}

		self:EmitSound("ambient/levels/canals/toxic_slime_sizzle1.wav", 60)

		net.Start("nwXenStart")
			net.WriteEntity(self)
			net.WriteUInt(self.CleanSpots, 4)
		net.Send(client)
	end

	net.Receive("nwXenSpot", function(_, client)
		local session = NETWORK.xen.sessions[client]

		if (!session) then
			return
		end

		local entity = session.entity

		if (!IsValid(entity) or !IsValid(client) or !client:Alive() or
			client:GetPos():Distance(entity:GetPos()) > 160) then
			NETWORK.xen.sessions[client] = nil

			return
		end

		if (session.nextSpot > CurTime()) then
			return
		end

		session.nextSpot = CurTime() + 0.3
		session.done = session.done + 1

		entity:EmitSound("ambient/levels/canals/toxic_slime_sizzle" ..
			math.random(2, 3) .. ".wav", 55, math.random(95, 110))

		if (session.done < session.need) then
			return
		end

		NETWORK.xen.sessions[client] = nil

		local effect = EffectData()

		effect:SetOrigin(entity:WorldSpaceCenter())
		util.Effect("antlion_gib_02", effect)

		entity:EmitSound("npc/antlion_grub/squashed.wav", 65)
		entity:Remove()

		NETWORK.chat.Notice(client, "xenCleaned")

		hook.Run("NetworkXenRemoved", entity, client)
	end)

	hook.Add("PlayerDisconnected", "nwXenSessions", function(client)
		NETWORK.xen.sessions[client] = nil
	end)

	hook.Add("PlayerTick", "nwXenClean", function(client)
		if (!client:HasCharacter() or
			!NETWORK.factions.IsCWU(client) and
			!NETWORK.factions.IsAlliance(client)) then
			return
		end

		local weapon = client:GetActiveWeapon()

		if (!IsValid(weapon) or weapon:GetClass() != "weapon_applicator" or
			!client:KeyDown(IN_ATTACK2)) then
			client.nwXenTarget = nil

			return
		end

		local trace = client:GetEyeTrace()
		local target = trace.Entity

		if (!IsValid(target) or target:GetClass() != "nw_xenlife" or
			trace.HitPos:Distance(client:GetPos()) > 140) then
			client.nwXenTarget = nil

			return
		end

		if (client.nwXenTarget != target) then
			client.nwXenTarget = target
			client.nwXenEnd = CurTime() + 3

			NETWORK.FactoryProgress(client, "xenCleaning", 3)
			client:EmitSound("ambient/levels/canals/toxic_slime_sizzle2.wav",
				60)
		elseif (CurTime() >= (client.nwXenEnd or 0)) then
			client.nwXenTarget = nil

			target:EmitSound("npc/antlion_grub/squashed.wav", 65)

			local effect = EffectData()

			effect:SetOrigin(target:WorldSpaceCenter())
			util.Effect("antlion_gib_02", effect)

			target:Remove()

			hook.Run("NetworkXenRemoved", target, client)
		end
	end)
else
	function ENT:Draw()
		self:DrawModel()
	end

	local game

	local function CloseGame()
		if (IsValid(game)) then
			game:Remove()
		end

		game = nil
	end

	local HOLD_TIME = 0.6

	net.Receive("nwXenStart", function()
		local entity = net.ReadEntity()
		local need = net.ReadUInt(4)

		CloseGame()

		local Sc = NETWORK.util.Scale
		local theme = NETWORK.theme
		local minigame = NETWORK.minigame
		local GREEN = Color(150, 240, 180)
		local GREEN_DIM = Color(60, 180, 110)

		game = minigame.BasePanel(entity, CloseGame, function(panel)
			game = panel
		end)

		local state = {
			done = 0,
			need = need,
			spot = nil,
			nextSpot = RealTime() + 0.4,
			bHolding = false
		}

		local function Spawn()
			state.spot = {
				x = math.Rand(0.25, 0.75),
				y = math.Rand(0.3, 0.7),
				life = 0,
				span = math.Rand(2.8, 3.6),
				fill = 0
			}
		end

		local function Radius(spot)

			local open = math.min(1, spot.life * 4) *
				(1 - math.max(0, spot.life - 0.7) / 0.3)

			return Sc(56) * open, open
		end

		local function Over(spot)
			local mx, my = game:CursorPos()
			local radius = Radius(spot)

			return math.Distance(mx, my, spot.x * ScrW(), spot.y * ScrH()) <=
				radius + Sc(10)
		end

		game.OnMousePressed = function(panel, code)
			if (code == MOUSE_LEFT) then
				state.bHolding = true

				if (!state.spot or !Over(state.spot)) then
					minigame.Sound("miss")
				end
			end
		end

		game.OnMouseReleased = function(panel, code)
			if (code == MOUSE_LEFT) then
				state.bHolding = false
			end
		end

		game.Think = function(panel)
			panel:BaseThink()

			local dt = FrameTime()

			if (!state.spot) then
				if (RealTime() >= state.nextSpot and state.done < state.need) then
					Spawn()
				end

				return
			end

			local spot = state.spot

			spot.life = spot.life + dt / spot.span

			local bHeld = state.bHolding and input.IsMouseDown(MOUSE_LEFT)

			if (bHeld and Over(spot)) then
				spot.fill = math.min(1, spot.fill + dt / HOLD_TIME)
			elseif (spot.fill > 0) then
				spot.fill = 0

				minigame.Sound("tick")
			end

			if (spot.fill >= 1) then
				state.spot = nil
				state.done = state.done + 1
				state.nextSpot = RealTime() + 0.35

				panel:Flash(true)
				surface.PlaySound("ambient/levels/canals/toxic_slime_gurgle" ..
					math.random(4) .. ".wav")

				net.Start("nwXenSpot")
				net.SendToServer()

				if (state.done >= state.need) then
					minigame.Sound("done")
					timer.Simple(0.45, CloseGame)
				end

				return
			end

			if (spot.life >= 1) then
				state.spot = nil
				state.nextSpot = RealTime() + 0.2
			end
		end

		game.Paint = function(panel, width, height)
			local ease = minigame.Veil(panel, width, height, L("xenGameTitle"),
				state.done, state.need, 0, 0)

			surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-u"))
			surface.SetDrawColor(80, 200, 130, 22 * ease)
			surface.DrawTexturedRect(0, 0, width, height)

			local lineTop = math.Round(height * 0.12)
			local iconSize = Sc(22)

			surface.SetFont("nwInvKey")

			local titleWidth = surface.GetTextSize(NETWORK.util.Upper(L("xenGameTitle")))

			minigame.Icon("pest_control", width * 0.5 - titleWidth * 0.5 -
				iconSize - Sc(10), lineTop - Sc(26) - iconSize * 0.5, iconSize,
				ColorAlpha(GREEN, 230 * ease))

			local spot = state.spot

			if (spot) then
				local x = spot.x * width
				local y = spot.y * height
				local radius, open = Radius(spot)
				local bOver = Over(spot)

				NETWORK.util.DrawCircle(x, y, radius,
					Color(GREEN_DIM.r, GREEN_DIM.g, GREEN_DIM.b,
						(bOver and 170 or 130) * ease))

				NETWORK.util.DrawRing(x, y, radius + Sc(6), math.max(Sc(2), 1),
					ColorAlpha(GREEN_DIM, 160 * ease), 40, 1 - spot.life)

				if (spot.fill > 0) then
					NETWORK.util.DrawRing(x, y, radius + Sc(14),
						math.max(Sc(4), 3), ColorAlpha(GREEN, 245 * ease), 48,
						spot.fill)
				end

				local size = Sc(26) * open

				minigame.Icon("sanitizer", x - size * 0.5, y - size * 0.5,
					math.Round(size),
					ColorAlpha(theme.text, (bOver and 240 or 150) * ease))
			end

			draw.SimpleText(L("xenGameHint"), "nwTagDesc", width * 0.5,
				math.Round(height * 0.88) + Sc(20),
				ColorAlpha(theme.textDim, 220 * ease), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end
	end)
end
