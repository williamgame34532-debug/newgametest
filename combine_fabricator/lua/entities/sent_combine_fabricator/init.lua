AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

local C = CFRework
local S = C.State
local SND = 'combine_fabricator/'

function ENT:Initialize()
	self:SetModel(C.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:SetMass(400) ph:EnableMotion(false) end
	for _, name in ipairs(C.ChannelNames) do self:SetChannel(name, 0, true) end
	self:SetTab(1)
	self:SetStage(S.DORMANT)
	self.LastNearby = -100
end

-- animate a channel toward target from wherever it is now (no jumps on reversal)
function ENT:SetChannel(name, target, instant)
	local cur = instant and target or C.Chan(self, name)
	if not instant and self['Get' .. name .. 'To'](self) == target then return end
	self['Set' .. name .. 'From'](self, cur)
	self['Set' .. name .. 'To'](self, target)
	self['Set' .. name .. 'Start'](self, CurTime())
end

function ENT:SetPhase(stage, duration)
	self:SetStage(stage)
	self:SetStageStarted(CurTime())
	self:SetStageUntil(CurTime() + (duration or 0))
end

function ENT:Notify(p, text)
	self:SetStatusText(text)
	self.MessageUntil = CurTime() + 3.5
	if IsValid(p) then p:EmitSound('buttons/button10.wav', 45, 110) end
end

function ENT:Snd(name, level, pitch)
	self:EmitSound(SND .. name, level or 62, pitch or 100)
end

-- the base entity Use is unused: everything goes through the aim-based KeyPress hook (sv_resin.lua)
function ENT:Use() end

function ENT:CanOrder(p, item)
	if item.kind == 'weapon' and p:HasWeapon(item.class) then return false, 'ЭТО ОРУЖИЕ УЖЕ ЕСТЬ' end
	if item.kind == 'health' and p:Health() >= p:GetMaxHealth() then return false, 'ЗДОРОВЬЕ УЖЕ ВОССТАНОВЛЕНО' end
	if item.kind == 'armor' and p:Armor() >= 100 then return false, 'БРОНЯ УЖЕ ВОССТАНОВЛЕНА' end
	return true
end

function ENT:Interact(p, x, y, part)
	if not IsValid(p) or not p:Alive() then return end
	local st = self:GetStage()
	if st == S.DORMANT then return end
	local op = self:GetOperator()
	if IsValid(op) and op ~= p then self:Notify(p, 'ТЕРМИНАЛ ЗАНЯТ') return end
	self.LastAction = CurTime()

	if x then
		local b = C.Layout.ButtonAt(st, self:GetTab(), x, y)
		if not b then return end
		self:SetStatusText('')
		self:EmitSound('buttons/lightswitch2.wav', 45, 125)
		if st == S.MENU then
			if b.id == 'tab' then
				self:SetTab(b.arg)
			elseif b.id == 'select' then
				self:Order(p, b.arg)
			end
		elseif st == S.DEPOSIT and b.id == 'cancel' then
			self:EndSession(true)
		end
		return
	end

	if part == 'cells' and st == S.DEPOSIT then
		self:InsertResin(p)
	elseif part == 'chamber' and st == S.DONE then
		self:Collect(p)
	end
end

function ENT:Order(p, index)
	local item = C.Items[index]
	if not item then return end
	local ok, why = self:CanOrder(p, item)
	if not ok then self:Notify(p, why) return end
	if C.Balance(p) < item.cost then self:Notify(p, 'НЕДОСТАТОЧНО СМОЛЫ — НУЖНО ' .. item.cost) return end
	self:SetOperator(p)
	self.OrderID = p:SteamID64()
	self:SetSelection(index)
	self:SetCost(item.cost)
	self:SetPaid(0)
	self:SetPhase(S.DEPOSIT)
	self:SetChannel('tray', 1)
	self:Snd('combine_3d_printer_resin_tray_open_01.wav', 62)
	if item.cost <= 0 then self:StartPrint() end
end

function ENT:InsertResin(p)
	if self:GetOperator() ~= p or self:GetStage() ~= S.DEPOSIT then return end
	if (self.NextFeed or 0) > CurTime() or self:GetPaid() >= self:GetCost() then return end
	self.NextFeed = CurTime() + C.FeedInterval
	if not C.ChangeBalance(p, -1) then self:Notify(p, 'НЕТ СМОЛЫ — ПОДБЕРИТЕ ЕЁ') return end
	self:SetStatusText('')
	self:SetPaid(self:GetPaid() + 1)
	self:Snd('combine_3d_printer_resin_tray_advance_01.wav', 60, 96 + (self:GetPaid() % 10) * 2)
	if self:GetPaid() >= self:GetCost() then
		timer.Simple(0.35, function() if IsValid(self) and self:GetStage() == S.DEPOSIT then self:StartPrint() end end)
	end
end

function ENT:StartPrint()
	self:SetPhase(S.PRINT, C.PrintTime)
	self:SetChannel('tray', 0)
	self:SetChannel('cradle', 0.55)
	self:Snd('combine_3d_printer_resin_tray_retract_01.wav', 58)
	self:Snd('combine_3d_printer_chamber_open_01.wav', 62)
	self.PrintSounds = {
		{CurTime() + 0.5, 'combine_3d_printer_upgrader_open_01.wav'},
		{CurTime() + 0.9, 'combine_3d_printer_upgrading_01.wav'},
		{CurTime() + 1.4, 'combine_3d_printer_gun_attach_print_01.wav'},
	}
end

function ENT:FinishPrint()
	self:StopSound(SND .. 'combine_3d_printer_upgrading_01.wav')
	self:SetPhase(S.DONE)
	self:SetChannel('cradle', 1)
	self:Snd('combine_3d_printer_work_complete_01.wav', 66)
	self.PrintSounds = nil
end

function ENT:Deliver(p, item)
	if item.kind == 'weapon' then
		if p:HasWeapon(item.class) then return false, 'ЭТО ОРУЖИЕ УЖЕ ЕСТЬ' end
		return IsValid(p:Give(item.class)), 'НЕ УДАЛОСЬ ВЫДАТЬ ОРУЖИЕ'
	elseif item.kind == 'health' then
		if p:Health() >= p:GetMaxHealth() then return false, 'ЗДОРОВЬЕ УЖЕ ВОССТАНОВЛЕНО' end
		p:SetHealth(math.min(p:GetMaxHealth(), p:Health() + item.amount))
		return true
	elseif item.kind == 'armor' then
		if p:Armor() >= 100 then return false, 'БРОНЯ УЖЕ ВОССТАНОВЛЕНА' end
		p:SetArmor(math.min(100, p:Armor() + item.amount))
		return true
	elseif item.kind == 'ammo' then
		return p:GiveAmmo(item.amount, item.ammo, true) > 0, 'НЕ УДАЛОСЬ ВЫДАТЬ ПАТРОНЫ'
	end
	return false, 'НЕИЗВЕСТНЫЙ ПРЕДМЕТ'
end

function ENT:Collect(p)
	if self:GetOperator() ~= p or self:GetStage() ~= S.DONE then return end
	local item = C.Items[self:GetSelection()]
	if not item then self:EndSession(false) return end
	local ok, why = self:Deliver(p, item)
	if not ok then self:Notify(p, why or 'ВЫДАЧА НЕ УДАЛАСЬ') return end
	p:EmitSound(item.kind == 'weapon' and 'items/ammo_pickup.wav' or 'items/smallmedkit1.wav', 60)
	self:Snd('print_item.wav', 55)
	self.OrderID = nil
	self:EndSession(false)
end

-- back to the catalogue; refund = return the resin of an unfinished or uncollected order
function ENT:EndSession(refund)
	self:StopSound(SND .. 'combine_3d_printer_upgrading_01.wav')
	self.PrintSounds = nil
	if refund and self.OrderID then
		local st = self:GetStage()
		local amount = (st == S.DEPOSIT) and self:GetPaid() or ((st == S.PRINT or st == S.DONE) and self:GetCost() or 0)
		C.Refund(self.OrderID, amount)
	end
	self.OrderID = nil
	self:SetOperator(NULL)
	self:SetPaid(0)
	self:SetCost(0)
	self:SetChannel('tray', 0)
	if self:GetcradleTo() > 0 then
		self:SetChannel('cradle', 0)
		self:Snd('combine_3d_printer_resin_tray_retract_01.wav', 56, 90)
	end
	self:SetPhase(self:GetdeployTo() > 0 and S.MENU or S.DORMANT)
end

function ENT:Think()
	local now = CurTime()
	local st = self:GetStage()

	-- wake up / fold away depending on who is around
	if now >= (self.NextScan or 0) then
		self.NextScan = now + 0.3
		local near = false
		for _, v in ipairs(player.GetAll()) do
			if v:Alive() and v:GetPos():DistToSqr(self:GetPos()) < C.WakeRadius * C.WakeRadius then near = true break end
		end
		if near then self.LastNearby = now end
		local awake = near or st > S.MENU or now - self.LastNearby < 4
		if awake and self:GetdeployTo() < 1 then
			self:SetChannel('deploy', 1)
			self:Snd('combine_3d_printer_eyestalk_extend_01.wav', 60)
			self.OpenSoundAt = now + 0.7
			if st == S.DORMANT then self:SetPhase(S.MENU) end
		elseif not awake and self:GetdeployTo() > 0 then
			self:SetChannel('deploy', 0)
			self:Snd('combine_3d_printer_eyestalk_retract_01.wav', 58)
			self:SetPhase(S.DORMANT)
		end
	end
	if self.OpenSoundAt and now >= self.OpenSoundAt then
		self.OpenSoundAt = nil
		self:Snd('combine_3d_printer_interface_open_01.wav', 62)
	end

	-- session watchdog
	if st > S.MENU then
		local p = self:GetOperator()
		local gone = not IsValid(p) or not p:Alive() or p:GetPos():DistToSqr(self:GetPos()) > C.LeaveRadius * C.LeaveRadius
		if gone or now - (self.LastAction or now) > C.IdleTimeout then self:EndSession(true) st = self:GetStage() end
	end

	-- hold E on the cells to keep feeding resin
	if st == S.DEPOSIT then
		local p = self:GetOperator()
		if IsValid(p) and p:KeyDown(IN_USE) and C.AimedPart(self, p) == 'cells' then
			self.LastAction = now
			self:InsertResin(p)
		end
	end

	if st == S.PRINT then
		for i, s in ipairs(self.PrintSounds or {}) do
			if s[1] and now >= s[1] then self:Snd(s[2], 64) s[1] = nil end
		end
		if now >= self:GetStageUntil() then self:FinishPrint() end
	end

	if self.MessageUntil and now >= self.MessageUntil then self.MessageUntil = nil self:SetStatusText('') end
	self:NextThink(now + 0.05)
	return true
end

function ENT:OnRemove()
	if self.OrderID then self:EndSession(true) end
	self:StopSound(SND .. 'combine_3d_printer_upgrading_01.wav')
end
