AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "nw_terminal"
ENT.PrintName = "Рабочий терминал"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_BOTH

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_workterminal")
		local angles = trace.HitNormal:Angle()

		angles.p = 0
		angles.r = 0

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer()) then
			return
		end

		if (self:GetNWBool("nwBroken", false)) then
			self:EmitSound("framework/cmb/forcefield/sparkle" .. math.random(4) .. ".mp3", 60, 110)
			NETWORK.chat.Notice(activator, "empTerminalBroken")

			return
		end

		if (!NETWORK.terminal.IsUsable(activator, self)) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.4

		if (!NETWORK.factorywork.IsWorker(activator) and !activator:IsAdmin()) then
			self:EmitSound(NETWORK.terminal.sounds.denied, 65)
			NETWORK.chat.Notice(activator, "workTermDenied")

			return
		end

		if (IsValid(self:GetUser()) and self:GetUser() != activator) then
			self:EmitSound(NETWORK.terminal.sounds.denied, 65)

			return
		end

		NETWORK.terminal.Open(activator, self)
	end
else

	local style = {
		brand = "WORK STATION",
		color = Color(236, 190, 96),
		background = Color(30, 20, 6)
	}

	local DONE = Color(140, 226, 160)
	local DONE_TEXT = Color(10, 24, 14)

	function style.Body(entity, width, height, color)
		local client = LocalPlayer()
		local WORK = NETWORK.factorywork
		local middle = width * 0.5

		if (!WORK.IsWorker(client)) then
			local bBusy = IsValid(entity:GetUser())
			local alpha = 130 + math.abs(math.cos(RealTime() * 2)) * 125

			draw.SimpleText(NETWORK.util.Upper(L(bBusy and "termBusy" or "workScreenStaff")),
				"nwTermScreenBody", middle, height * 0.55,
				ColorAlpha(bBusy and Color(240, 196, 84) or color, alpha),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			return
		end

		local stats = WORK.GetOwn(client)
		local done = DONE

		draw.SimpleText(NETWORK.util.Upper(stats.bDone and L("workStateDone") or
			L("workStateActive")), "nwTermScreenBody", middle, 112,
			stats.bDone and done or color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local gap = 12
		local segment = math.floor((width - 60 - gap * (WORK.quotas - 1)) / WORK.quotas)

		for index = 1, WORK.quotas do
			local x = 30 + (index - 1) * (segment + gap)
			local bFilled = index <= stats.quotas

			draw.RoundedBox(10, x, 146, segment, 34, bFilled and ColorAlpha(done, 200) or
				ColorAlpha(color, 40))

			draw.SimpleText(L("workTermQuotaN", index), "nwTermScreenSmall", x + segment * 0.5,
				163, bFilled and DONE_TEXT or ColorAlpha(color, 220),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local cell = 34
		local cellGap = 10
		local boxWidth = WORK.boxSize * cell + (WORK.boxSize - 1) * cellGap
		local boxX = middle - boxWidth * 0.5

		for index = 1, WORK.boxSize do
			local x = boxX + (index - 1) * (cell + cellGap)
			local bFilled = stats.bDone or index <= stats.box

			draw.RoundedBox(8, x, 200, cell, cell, ColorAlpha(color, bFilled and 210 or 36))
		end

		draw.SimpleText(L("workScreenLine", stats.bDone and WORK.boxSize or stats.box,
			WORK.boxSize, stats.made, stats.delivered), "nwTermScreenSmall", middle, 256,
			ColorAlpha(color, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (stats.bDone) then
			local alpha = 130 + math.abs(math.cos(RealTime() * 2)) * 125

			draw.SimpleText(NETWORK.util.Upper(L("workScreenRecruiter")), "nwTermScreenSmall",
				middle, 290, ColorAlpha(done, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(L("workScreenEarned", stats.earned, stats.points), "nwTermScreenSmall",
				middle, 290, ColorAlpha(color, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	function ENT:Draw()
		self:DrawModel()

		NETWORK.terminal.DrawScreen(self, style)
	end
end
