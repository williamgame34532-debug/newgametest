AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Сборочный терминал"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Needed = 4
ENT.AssembleTime = 10
ENT.RationItem = "ration_basic"

function ENT:GetTopOffset()
	local maxs = self:OBBMaxs()

	return maxs.z + 12
end

function ENT:GetOutputPos()
	local maxs = self:OBBMaxs()

	return self:GetPos() + self:GetUp() * (maxs.z + 8) +
		self:GetForward() * (maxs.x + 10)
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Loaded")
	self:NetworkVar("Float", 0, "AssembleEnd")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_factory_terminal")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = "models/props_combine/breenconsole.mdl"

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	function ENT:ClearStaleClock()
		if (!self.nwAssembling and self:GetAssembleEnd() != 0) then
			self:SetAssembleEnd(0)
		end
	end

	function ENT:Think()
		self:ClearStaleClock()
		self:NextThink(CurTime() + 1)

		return true
	end

	function ENT:IsBroken()
		return self:GetNWBool("nwBroken", false)
	end

	function ENT:Break(client)
		if (self:IsBroken()) then
			return
		end

		self:SetNWBool("nwBroken", true)

		local effect = EffectData()

		effect:SetOrigin(self:WorldSpaceCenter())
		effect:SetMagnitude(2)
		effect:SetScale(1)
		effect:SetRadius(6)

		util.Effect("Sparks", effect)

		self:EmitSound("ambient/energy/spark6.wav", 70)

		if (NETWORK.mechanic and NETWORK.mechanic.StartFault) then
			NETWORK.mechanic.StartFault(self)
		end
	end

	function ENT:Repair(client)
		if (!self:IsBroken()) then
			return
		end

		self:SetNWBool("nwBroken", false)
		self:EmitSound("buttons/lever5.wav", 65)

		if (NETWORK.mechanic and NETWORK.mechanic.StopFault) then
			NETWORK.mechanic.StopFault(self)
		end

		if (IsValid(client)) then
			NETWORK.chat.Notice(client, "factoryRepaired")

			if (NETWORK.currency and NETWORK.currency.Add) then
				NETWORK.currency.Add(client, math.random(1, 2))
			end

			hook.Run("NetworkMechanicRepaired", client, self)
		end
	end

	function ENT:CanRepair(client)
		if (client:IsAdmin()) then
			return true
		end

		local class = client:GetNWString("nwClass", "")

		if (class == "mechanic" or class == "engineer") then
			return true
		end

		return NETWORK.factions.IsCWU(client) and class != ""
	end

	function ENT:Wear()
		self.nwCycles = (self.nwCycles or 0) + 1

		if (self.nwCycles < 4) then
			return
		end

		if (math.random() > 0.18) then
			return
		end

		self.nwCycles = 0

		self:Break()
	end

	function ENT:FindPart()
		for _, entity in ipairs(ents.FindInSphere(self:GetPos(), 90)) do
			local class = entity:GetClass()
			local itemID = class == "nw_item" and
				(entity.nwItemID or (entity.GetItemID and entity:GetItemID()))
			local bPart = class == "nw_factory_part" or
				(itemID and string.sub(tostring(itemID), 1, 8) == "factory_" and
				itemID != "factory_box")

			if (bPart) then
				return entity
			end
		end
	end

	function ENT:Use(client)
		self:ClearStaleClock()

		if (!IsValid(client) or !client:HasCharacter() or
			self:GetAssembleEnd() > CurTime()) then
			return
		end

		if (self:IsBroken()) then
			if (!self:CanRepair(client)) then
				return NETWORK.chat.Notice(client, "factoryBroken")
			end

			return self:Repair(client)
		end

		if (NETWORK.schedule and NETWORK.schedule.IsFactoryShift and
			!NETWORK.schedule.IsFactoryShift()) then
			return NETWORK.chat.Notice(client, "factoryClosedShift")
		end

		local part = self:GetLoaded() < self.Needed and self:FindPart()

		if (IsValid(part)) then
			part:EmitSound("framework/inv/inv_move" .. math.random(3) .. ".wav", 55)
			part:Remove()

			self:SetLoaded(math.min(self.Needed, self:GetLoaded() + 1))

			self.crew = NETWORK.ration.AddWorker(self.crew or {}, client)

			NETWORK.chat.Notice(client, "factoryLoaded")

			return
		end

		if (self:GetLoaded() < self.Needed) then
			NETWORK.chat.Notice(client, "factoryNeedParts")

			return
		end

		local bWorker = NETWORK.factorywork and NETWORK.factorywork.IsWorker(client)

		if (bWorker and !NETWORK.factorywork.CanAssemble(client)) then
			NETWORK.chat.Notice(client, "workShiftOverAssembleV2")

			return
		end

		if (!bWorker and NETWORK.ration.GetLeft() <= 0) then
			NETWORK.chat.Notice(client, "factoryQuotaDone")

			return
		end

		self.nwAssembling = true

		self:SetAssembleEnd(CurTime() + self.AssembleTime)
		self:EmitSound("ambient/machines/combine_terminal_idle2.wav", 65)

		local terminal = self

		timer.Simple(self.AssembleTime, function()
			if (!IsValid(terminal)) then
				return
			end

			terminal.nwAssembling = nil

			terminal:SetLoaded(0)
			terminal:SetAssembleEnd(0)
			terminal:EmitSound("items/ammocrate_open.wav", 65)

			terminal:Wear()

			local crew = NETWORK.ration.AddWorker(terminal.crew or {}, client)

			terminal.crew = {}

			NETWORK.item.Spawn(terminal.RationItem, terminal:GetOutputPos(),
				nil, 1, {crew = crew})

			if (NETWORK.ration.MarkBin) then
				NETWORK.ration.MarkBin(terminal, crew)
			end

			if (!bWorker) then
				NETWORK.ration.SetMade(NETWORK.ration.GetMade() + 1)
			end

			if (NETWORK.factorywork) then
				NETWORK.factorywork.CreditMade(crew)
			end

			for _, entry in ipairs(crew) do
				for _, target in ipairs(player.GetAll()) do
					if (target:HasCharacter() and
						tostring(target:GetCharacterID()) == entry.id) then
						NETWORK.chat.Notice(target, "factoryRationReady")

						break
					end
				end
			end
		end)

		if (NETWORK.FactoryProgress) then
			NETWORK.FactoryProgress(client, "factoryAssembling", self.AssembleTime)
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	local COLOR_IDLE = Color(226, 236, 246, 235)
	local COLOR_BUSY = Color(120, 200, 255, 240)
	local COLOR_DONE = Color(150, 224, 170, 240)

	function ENT:DrawTranslucent()
		local F = NETWORK.factory

		if (!F or !F.DrawPlate or !F.InRange(self, 700)) then
			return
		end

		local client = LocalPlayer()
		local WORK = NETWORK.factorywork
		local bBroken = self:GetNWBool("nwBroken", false)
		local bBusy = self:GetAssembleEnd() > CurTime()
		local bWorker = WORK and WORK.IsWorker(client)
		local own = bWorker and WORK.GetOwn(client)
		local bDone = bWorker and own.bDone or (!bWorker and NETWORK.ration.GetLeft() <= 0)
		local loaded = self:GetLoaded()
		local bOpen = !NETWORK.schedule or !NETWORK.schedule.IsFactoryShift or
			NETWORK.schedule.IsFactoryShift()

		local title, color, hint

		if (bBroken) then
			local blink = 0.55 + math.abs(math.sin(RealTime() * 3)) * 0.45

			title = L("factoryPlateBroken")
			color = Color(232, 92, 84, 245 * blink)
		elseif (bBusy) then
			title, color = L("factoryPlateBusy"), COLOR_BUSY
		elseif (bDone) then
			title = L(bWorker and "factoryPlateShiftDone" or "factoryPlateQuotaDone")
			color = COLOR_DONE
		else
			title, color = L("factoryPlateLoaded", loaded, self.Needed), COLOR_IDLE
		end

		local subtitle

		if (bBroken) then
			local class = client:GetNWString("nwClass", "")

			if (class == "mechanic" or class == "engineer" or client:IsAdmin() or
				(NETWORK.factions.IsCWU(client) and class != "")) then
				hint = L("factoryRepairHint")
			end
		elseif (bWorker) then
			subtitle = L("workPlateLine", own.bDone and WORK.boxSize or own.box,
				WORK.boxSize, own.quotas, WORK.quotas)
		else
			subtitle = L("factoryQuotaLine", NETWORK.ration.GetMade(), NETWORK.ration.quota)
		end

		if (!bBroken and !bBusy and !bDone) then
			if (!bOpen) then
				hint = L("factoryClosedShift")
			elseif (loaded >= self.Needed) then
				hint = L("factoryHintStart")
			else
				hint = L("factoryHintLoad")
			end
		end

		local progress

		if (bBusy) then
			progress = 1 - math.Clamp((self:GetAssembleEnd() - CurTime()) / self.AssembleTime, 0, 1)
		elseif (!bBroken and !bDone) then
			progress = loaded / self.Needed
		end

		cam.Start3D2D(self:GetPos() + self:GetUp() * self:GetTopOffset(), F.FaceAngles(), 0.08)
			F.DrawPlate(title, subtitle, color, progress, 330, hint)
		cam.End3D2D()
	end
end
