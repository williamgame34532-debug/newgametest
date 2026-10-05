AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Сканнер"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.Model = "models/combine_scanner.mdl"

ENT.PatrolRadius = 220
ENT.DetectRadius = 380
ENT.PhotoCooldown = 12
ENT.RunSpeed = 190
ENT.FleeTime = 6
ENT.MaxHealth = 60

ENT.PatrolVelocity = 70
ENT.FleeVelocity = 250

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Alert")
end

if (SERVER) then
	util.AddNetworkString("nwScannerPhoto")

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_scanner")

		if (!IsValid(entity)) then
			return
		end

		entity:SetPos(trace.HitPos + trace.HitNormal * 16 + Vector(0, 0, 90))
		entity:SetAngles(Angle(0, IsValid(client) and client:EyeAngles().y or 0, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		util.PrecacheModel(self.Model)

		self:SetModel(self.Model)
		self:SetMoveType(MOVETYPE_NOCLIP)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-16, -16, -14), Vector(16, 16, 14))
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:DrawShadow(true)
		self:SetHealth(self.MaxHealth)

		local sequence = self:LookupSequence("idle01")

		if (sequence and sequence > 0) then
			self:ResetSequence(sequence)
		end

		self.anchor = self:GetPos()
		self.goal = self:GetPos()
		self.photos = {}
		self.nextPatrol = 0
		self.nextScan = 0
		self.fleeUntil = 0
		self.lastThink = CurTime()

		self.loop = CreateSound(self, "npc/scanner/scanner_scan_loop1.wav")

		if (self.loop) then
			self.loop:Play()
			self.loop:ChangeVolume(0.35, 0.5)
		end
	end

	function ENT:OnRemove()
		if (self.loop) then
			self.loop:Stop()
		end
	end

	function ENT:PickPatrolGoal()
		for _ = 1, 6 do
			local offset = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0)

			offset:Normalize()

			local goal = self.anchor + offset * math.Rand(40, self.PatrolRadius) +
				Vector(0, 0, math.Rand(-24, 30))

			local trace = util.TraceLine({
				start = self.anchor,
				endpos = goal,
				filter = self,
				mask = MASK_SOLID_BRUSHONLY
			})

			if (!trace.Hit) then
				return goal
			end
		end

		return self.anchor
	end

	function ENT:PickFleeGoal(target)
		local away = self:GetPos() - target:GetPos()

		away.z = 0
		away:Normalize()
		away:Rotate(Angle(0, math.Rand(-45, 45), 0))

		local goal = self:GetPos() + away * math.Rand(400, 600) +
			Vector(0, 0, math.Rand(40, 90))

		local trace = util.TraceLine({
			start = self:GetPos(),
			endpos = goal,
			filter = self,
			mask = MASK_SOLID_BRUSHONLY
		})

		if (trace.Hit) then
			return trace.HitPos - away * 24
		end

		return goal
	end

	function ENT:Fly(delta)
		local goal = self.goal or self.anchor
		local difference = goal - self:GetPos()
		local distance = difference:Length()

		if (distance < 24) then
			return true
		end

		local speed = self.fleeUntil > CurTime() and self.FleeVelocity or
			self.PatrolVelocity
		local step = math.min(distance, speed * delta)
		local target = self:GetPos() + difference:GetNormalized() * step

		target.z = target.z + math.sin(CurTime() * 2.2) * 0.6

		local trace = util.TraceHull({
			start = self:GetPos(),
			endpos = target,
			mins = Vector(-14, -14, -12),
			maxs = Vector(14, 14, 12),
			filter = self,
			mask = MASK_SOLID_BRUSHONLY
		})

		self:SetPos(trace.HitPos)

		if (trace.Hit) then
			return true
		end

		local look = self.watch

		if (IsValid(look)) then
			difference = look:WorldSpaceCenter() - self:GetPos()
		end

		local angles = difference:Angle()

		self:SetAngles(Angle(0, angles.y, 0))

		return false
	end

	function ENT:IsTarget(client)
		if (!IsValid(client) or !client:IsPlayer() or !client:Alive() or
			!client:HasCharacter()) then
			return false
		end

		if (NETWORK.factions.IsAlliance(client) or NETWORK.factions.IsCWU(client)) then
			return false
		end

		return true
	end

	function ENT:GetReason(client)
		if (client:GetVelocity():Length2D() > self.RunSpeed and
			client:OnGround() and !client:Crouching()) then
			return "scannerRunning"
		end

		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and client:IsWeaponRaised()) then
			local class = weapon:GetClass()

			if (class != "nw_hands" and class != "weapon_nwhands" and
				class != "nw_keys" and class != "weapon_nwkeys") then
				return "scannerArmed"
			end
		end

		return nil
	end

	function ENT:TakePhoto(target, reason)
		self:SetAlert(true)
		self:EmitSound("npc/scanner/scanner_photo1.wav", 75)

		local effect = EffectData()

		effect:SetOrigin(self:WorldSpaceCenter() + self:GetForward() * 12)
		effect:SetScale(1)
		util.Effect("MuzzleFlash", effect)

		local zone = NETWORK.zone and NETWORK.zone.At(target:GetPos())
		local name = target:GetCharacterName()
		local zoneName = (zone and zone.name) or L("owUnknownZone")

		for _, receiver in ipairs(player.GetAll()) do
			if (!NETWORK.factions.IsAlliance(receiver) and
				!NETWORK.factions.IsCWU(receiver)) then
				continue
			end

			net.Start("nwScannerPhoto")
				net.WriteString(name)
				net.WriteString(reason)
				net.WriteString(zoneName)
			net.Send(receiver)
		end

		self.watch = target
		self.goal = self:PickFleeGoal(target)
		self.fleeUntil = CurTime() + self.FleeTime

		self:EmitSound("npc/scanner/scanner_scan" .. math.random(4) .. ".wav", 70)

		timer.Simple(1.5, function()
			if (IsValid(self)) then
				self:SetAlert(false)

				self.watch = nil
			end
		end)
	end

	function ENT:Scan()
		for _, client in ipairs(ents.FindInSphere(self:GetPos(), self.DetectRadius)) do
			if (!self:IsTarget(client)) then
				continue
			end

			if ((self.photos[client] or 0) > CurTime()) then
				continue
			end

			local reason = self:GetReason(client)

			if (!reason) then
				continue
			end

			local trace = util.TraceLine({
				start = self:WorldSpaceCenter(),
				endpos = client:EyePos(),
				filter = self,
				mask = MASK_SHOT
			})

			if (trace.Entity != client) then
				continue
			end

			self.photos[client] = CurTime() + self.PhotoCooldown

			self:TakePhoto(client, reason)

			return
		end
	end

	function ENT:Think()
		local now = CurTime()
		local delta = math.Clamp(now - (self.lastThink or now), 0, 0.5)

		self.lastThink = now

		if (self:GetNWBool("nwSabotaged", false)) then
			self:SetPos(self:GetPos() + Vector(0, 0, math.sin(now * 3) * 0.15))
			self:NextThink(now + 0.1)

			return true
		end

		local bArrived = self:Fly(delta)

		if (self.fleeUntil > now) then
			if (bArrived) then
				self.goal = self:PickFleeGoal(self)
			end
		else
			if (bArrived and self.nextPatrol < now) then
				self.goal = self:PickPatrolGoal()
				self.nextPatrol = now + math.Rand(2, 5)
			end

			if (self.nextScan < now) then
				self.nextScan = now + 0.3

				self:Scan()
			end
		end

		self:NextThink(now)

		return true
	end

	function ENT:OnTakeDamage(damage)
		self:SetHealth(self:Health() - damage:GetDamage())

		self:EmitSound("npc/scanner/scanner_pain" .. math.random(2) .. ".wav", 70)

		if (self:Health() > 0) then
			return
		end

		self:Destroy(damage:GetAttacker())
	end

	function ENT:Destroy(attacker)
		local position = self:WorldSpaceCenter()
		local effect = EffectData()

		effect:SetOrigin(position)
		util.Effect("Explosion", effect)

		self:EmitSound("npc/scanner/scanner_explode_crash1.wav", 85)

		if (NETWORK.scanner and NETWORK.scanner.wreck) then
			NETWORK.item.Spawn(NETWORK.scanner.wreck, position + Vector(0, 0, 8))
		end

		if (NETWORK.dispatch and NETWORK.dispatch.SendRadio) then
			local zone = NETWORK.zone and NETWORK.zone.At(position)

			NETWORK.dispatch.SendRadio(L("dispatchScannerDown",
				(zone and zone.name) or L("owUnknownZone")), Color(240, 96, 86))
		end

		hook.Run("NetworkScannerDown", self, attacker)

		self:Remove()
	end

	hook.Add("OnNPCKilled", "nwCityScannerDown", function(npc)
		if (!IsValid(npc) or npc:GetClass() != "npc_cscanner" or !npc.nwCity) then
			return
		end

		if (NETWORK.dispatch and NETWORK.dispatch.SendRadio) then
			local zone = NETWORK.zone and NETWORK.zone.At(npc:GetPos())

			NETWORK.dispatch.SendRadio(L("dispatchScannerDown",
				(zone and zone.name) or L("owUnknownZone")), Color(240, 96, 86))
		end
	end)
else
	function ENT:Draw()
		self:DrawModel()

		if (self:GetAlert()) then
			local light = DynamicLight(self:EntIndex())

			if (light) then
				light.Pos = self:WorldSpaceCenter() + self:GetForward() * 14
				light.r = 255
				light.g = 240
				light.b = 220
				light.Brightness = 4
				light.Decay = 900
				light.Size = 220
				light.DieTime = CurTime() + 0.2
			end
		end
	end

	local photos = {}

	net.Receive("nwScannerPhoto", function()
		photos[#photos + 1] = {
			name = net.ReadString(),
			reason = net.ReadString(),
			zone = net.ReadString(),
			time = RealTime()
		}

		surface.PlaySound("npc/scanner/combat_scan4.wav")

		while (#photos > 4) do
			table.remove(photos, 1)
		end
	end)

	hook.Add("NetworkDrawHUD", "nwScannerPhotos", function()
		local client = LocalPlayer()

		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		if (!client:IsCombine() and
			!(client.IsCWUMember and client:IsCWUMember())) then
			return
		end

		local Sc = NETWORK.util.Scale
		local y = Sc(180)

		for index = #photos, 1, -1 do
			local photo = photos[index]
			local age = RealTime() - photo.time

			if (age > 6) then
				table.remove(photos, index)

				continue
			end

			local alpha = math.min(1, age * 4) * math.min(1, (6 - age) * 2)
			local width = Sc(260)
			local x = ScrW() - width - Sc(24)

			surface.SetDrawColor(9, 24, 32, 225 * alpha)
			surface.DrawRect(x, y, width, Sc(58))

			surface.SetDrawColor(240, 196, 84, 235 * alpha)
			surface.DrawRect(x, y, Sc(3), Sc(58))

			draw.SimpleText("СКАННЕР // " .. L(photo.reason), "nwHudSmall",
				x + Sc(14), y + Sc(14), Color(240, 196, 84, 250 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(photo.name, "nwTagDesc", x + Sc(14), y + Sc(32),
				Color(226, 236, 246, 250 * alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(photo.zone, "nwHudSmall", x + Sc(14), y + Sc(47),
				Color(150, 168, 184, 235 * alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			y = y + Sc(66)
		end
	end)
end
