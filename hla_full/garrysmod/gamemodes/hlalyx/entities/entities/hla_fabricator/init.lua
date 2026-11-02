AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

local C = CFRework
local S = C.State
local SND = 'combine_fabricator/'

local LOOPS = {dormant = true, menu_idle = true, hatch_idle = true, bay_idle = true, print_done = true}
for i = 0, 9 do LOOPS[string.format('tray_idle_%02d', i)] = true end

local ON = {}
ON.eye_deploy = function(self) self:Snd('combine_3d_printer_eyestalk_extend_01.wav', 60) end
ON.interface_deploy = function(self) self:Snd('combine_3d_printer_interface_open_01.wav', 62) end
ON.menu_idle = function(self)
	if not self:GetDeployed() then self:SetDeployed(true) self:SetDeployedAt(CurTime()) end
end
ON.interface_retract = function(self) self:SetDeployed(false) self:Snd('combine_3d_printer_interface_open_01.wav', 56, 80) end
ON.eye_retract = function(self) self:Snd('combine_3d_printer_eyestalk_retract_01.wav', 58) end
ON.hatch_open = function(self) self.Mech.hatch = true self:Snd('combine_3d_printer_chamber_open_01.wav', 62) end
ON.hatch_close = function(self) self.Mech.hatch = false self:SetTrayOut(false) self:Snd('combine_3d_printer_chamber_open_01.wav', 58, 85) end
ON.tray_deploy = function(self) self.Mech.tray = true self:SetTrayOut(true) self:Snd('combine_3d_printer_resin_tray_open_01.wav', 62) end
ON.tray_retract = function(self) self.Mech.tray = false self:SetTrayReady(false) self:Snd('combine_3d_printer_resin_tray_retract_01.wav', 60) end
ON.bay_open = function(self) self.Mech.bay = true self:Snd('combine_3d_printer_upgrader_open_01.wav', 62) end
ON.bay_close = function(self) self.Mech.bay = false self:SetBayOpen(false) self:Snd('combine_3d_printer_resin_tray_retract_01.wav', 56, 90) end
ON.print = function(self, dur)
	self.Mech.bay = false
	self:SetTrayOut(false)
	self:SetStageStarted(CurTime())
	self:SetStageUntil(CurTime() + dur)
	self:Snd('combine_3d_printer_upgrading_01.wav', 64)
	self.PrintSounds = {{CurTime() + dur * 0.62, 'combine_3d_printer_gun_attach_print_01.wav'}}
end
ON.bay_idle = function(self) self:SetBayOpen(true) end
for i = 0, 9 do
	ON[string.format('tray_idle_%02d', i)] = function(self) self:SetTrayReady(self:GetStage() == S.DEPOSIT) end
	ON[string.format('tray_cycle_%02d', i)] = function(self)
		self:Snd('combine_3d_printer_resin_tray_advance_01.wav', 60, 96 + i * 2)
	end
end

function ENT:StartSeq(name)
	local seq = self:LookupSequence(name)
	if not seq or seq < 0 then return end
	self:ResetSequence(seq)
	self:SetCycle(0)
	self:SetPlaybackRate(1)
	self.SeqName = name
	self.SeqSerial = (self.SeqSerial or 0) + 1
	local dur = self:SequenceDuration(seq)
	self.SeqEnd = (not LOOPS[name]) and CurTime() + dur or nil
	if ON[name] then ON[name](self, dur) end
end

function ENT:Advance()
	while self.Queue[1] do
		local nxt = table.remove(self.Queue, 1)
		if isfunction(nxt) then
			local serial = self.SeqSerial
			nxt(self)
			if self.SeqSerial ~= serial then return end
		else
			self:StartSeq(nxt)
			return
		end
	end
end

function ENT:Play(list, cut)
	self.Queue = table.Copy(list)
	if cut or not self.SeqEnd or self.SeqName == 'print' then self:Advance() end
end

function ENT:CloseList(tail)
	local out = {}
	local m = self.Mech
	if m.tray then out[#out + 1] = 'tray_retract' end
	if m.bay then out[#out + 1] = 'bay_close' end
	if m.hatch then out[#out + 1] = 'hatch_close' end
	for _, v in ipairs(tail or {}) do out[#out + 1] = v end
	return out
end

function ENT:Initialize()
	if not util.IsValidModel(C.Model) then
		local msg = '[Combine Fabricator] ' .. C.Model .. ' не найдена: скомпилируйте modelsrc/hla_station/hla_station.qc (README_RU.txt)'
		ErrorNoHalt(msg .. '\n')
		for _, p in ipairs(player.GetAll()) do if p:IsAdmin() then p:ChatPrint(msg) end end
	end
	self:SetModel(C.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:SetMass(400) ph:EnableMotion(false) end
	self:SetTab(1)
	self:SetStage(S.DORMANT)
	self.Mech = {}
	self.Queue = {}
	self.Awake = false
	self.LastNearby = -100
	self:StartSeq('dormant')
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

function ENT:Use() end

function ENT:CanOrder(p, item)
	if item.kind == 'weapon' and p:HasWeapon(item.class) then return false, 'ЭТО ОРУЖИЕ УЖЕ ЕСТЬ' end
	if item.kind == 'health' and p:Health() >= p:GetMaxHealth() then return false, 'ЗДОРОВЬЕ УЖЕ ВОССТАНОВЛЕНО' end
	if item.kind == 'armor' and p:Armor() >= 100 then return false, 'БРОНЯ УЖЕ ВОССТАНОВЛЕНА' end
	if item.kind == 'item' and HLA.Items and HLA.Items.Room(p, item.item) < 1 then return false, 'ИНВЕНТАРЬ ЗАПОЛНЕН' end
	return true
end

function ENT:RequestFocus(p)
	if not C.Ready(self) or self:GetStage() == S.DORMANT then return end
	local op = self:GetOperator()
	if IsValid(op) and op ~= p then self:Notify(p, 'ТЕРМИНАЛ ЗАНЯТ') return end
	for _, v in ipairs(player.GetAll()) do
		if v ~= p and v.CFFocus == self then self:Notify(p, 'ТЕРМИНАЛ ЗАНЯТ') return end
	end
	if self:GetStage() == S.DONE then return end
	self.LastAction = CurTime()
	C.SetFocus(p, self)
	self:EmitSound('buttons/lightswitch2.wav', 45, 140)
end

function ENT:ReleaseFocus()
	for _, v in ipairs(player.GetAll()) do
		if v.CFFocus == self then C.SetFocus(v, nil) end
	end
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
		self:EmitSound(C.ClickSounds[math.random(1, 2)], 50, 100)
		if b.id == 'exit' then
			C.SetFocus(p, nil)
			return
		end
		if st == S.MENU then
			if b.id == 'tab' or b.id == 'page' then
				self:SetTab(b.arg)
			elseif b.id == 'select' then
				self:Order(p, b.arg)
			end
		elseif st == S.DEPOSIT and b.id == 'cancel' then
			self:EndSession(true)
		end
		return
	end

	if part == 'cells' and C.CellsOpen(self) then
		self:InsertResin(p)
	elseif part == 'chamber' and st == S.DONE then
		self:Collect(p)
	end
end

function ENT:Order(p, index)
	local item = C.Items[index]
	if not item or item.off or not C.Ready(self) then return end
	local ok, why = self:CanOrder(p, item)
	if not ok then self:Notify(p, why) return end
	if C.Balance(p) < item.cost then self:Notify(p, 'НЕДОСТАТОЧНО СМОЛЫ — НУЖНО ' .. item.cost) return end
	self.SessionSerial = (self.SessionSerial or 0) + 1
	self:SetOperator(p)
	self.OrderID = C.SaveKey and C.SaveKey(p) or p:SteamID64()
	self:SetSelection(index)
	self.HLAOrderItem = item
	self:SetCost(item.cost)
	self:SetPaid(0)
	self:SetPhase(S.DEPOSIT)
	self:Play({'hatch_open', 'tray_deploy', 'tray_idle_00'})
	if item.cost <= 0 then self:StartPrint() end
end

function ENT:InsertResin(p)
	if self:GetOperator() ~= p or not C.CellsOpen(self) then return end
	if (self.NextFeed or 0) > CurTime() or self:GetPaid() >= self:GetCost() then return end
	if self.SeqEnd then return end
	self.NextFeed = CurTime() + C.FeedInterval
	if not C.ChangeBalance(p, -1) then self:Notify(p, 'НЕТ СМОЛЫ — ПОДБЕРИТЕ ЕЁ') return end
	self:SetStatusText('')
	self:SetFeedStarted(CurTime())
	self:SetPaid(self:GetPaid() + 1)
	local k = self:GetPaid() % 10
	local list = {string.format('tray_cycle_%02d', k), string.format('tray_idle_%02d', k)}
	if self:GetPaid() >= self:GetCost() then
		local serial = self.SessionSerial
		list[2] = function(s) if s.SessionSerial == serial then s:StartPrint() end end
	end
	self:Play(list, true)
end

function ENT:StartPrint()
	if self:GetStage() ~= S.DEPOSIT or self:GetPaid() < self:GetCost() then return end
	self:SetTrayReady(false)
	self:SetPhase(S.PRINT, 13)
	self:Play({'tray_retract', 'bay_open', 'print', 'bay_open', function(s) s:FinishPrint() end, 'bay_idle'})
end

function ENT:FinishPrint()
	self:ReleaseFocus()
	self:StopSound(SND .. 'combine_3d_printer_upgrading_01.wav')
	self:SetPhase(S.DONE)
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
	elseif item.kind == 'item' then
		if not (HLA.Items and HLA.Items.Room(p, item.item) >= 1) then return false, 'ИНВЕНТАРЬ ЗАПОЛНЕН' end
		return HLA.Items.Add(p, item.item) ~= false, 'ИНВЕНТАРЬ ЗАПОЛНЕН'
	elseif item.kind == 'ammo' then
		return p:GiveAmmo(item.amount, item.ammo, true) > 0, 'НЕ УДАЛОСЬ ВЫДАТЬ ПАТРОНЫ'
	end
	return false, 'НЕИЗВЕСТНЫЙ ПРЕДМЕТ'
end

function ENT:Collect(p)
	if self:GetOperator() ~= p or self:GetStage() ~= S.DONE or not self:GetBayOpen() then return end
	local item = self.HLAOrderItem or C.Items[self:GetSelection()]
	if not item then self:EndSession(false) return end
	local ok, why = self:Deliver(p, item)
	if not ok then self:Notify(p, why or 'ВЫДАЧА НЕ УДАЛАСЬ') return end
	p:EmitSound('hla/ui/inv_move6.mp3', 65)
	self:Snd('print_item.wav', 55)
	self.OrderID = nil
	self:EndSession(false)
end

function ENT:EndSession(refund, fold)
	self.SessionSerial = (self.SessionSerial or 0) + 1
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
	self:SetTrayReady(false)
	self:SetBayOpen(false)
	if fold then
		self:Fold()
	else
		self:SetPhase(S.MENU)
		self:Play(self:CloseList({'menu_idle'}), self.SeqName == 'print')
	end
end

function ENT:WakeUp()
	if self.Awake then return end
	self.Awake = true
	self:SetPhase(S.MENU)
	self:Play({'eye_deploy', 'interface_deploy', 'menu_idle'})
end

function ENT:Fold()
	if not self.Awake then return end
	self.Awake = false
	self:ReleaseFocus()
	self:SetPhase(S.DORMANT)
	self:Play(self:CloseList({'interface_retract', 'eye_retract', 'dormant'}), self.SeqName == 'print')
end

function ENT:Think()
	local now = CurTime()

	if self.SeqEnd and now >= self.SeqEnd then
		self.SeqEnd = nil
		self:Advance()
	end

	if now >= (self.NextScan or 0) then
		self.NextScan = now + 0.3
		local near = false
		for _, v in ipairs(player.GetAll()) do
			if v:Alive() and v:GetPos():DistToSqr(self:GetPos()) < C.WakeRadius * C.WakeRadius then near = true break end
		end
		if near then self.LastNearby = now end
		local awake = near or now - self.LastNearby < C.CloseDelay
		if not awake and self.Awake then
			if self:GetStage() > S.MENU then self:EndSession(true, true) else self:Fold() end
		end
	end

	local st = self:GetStage()
	if st > S.MENU then
		local p = self:GetOperator()
		local gone = not IsValid(p) or not p:Alive() or p:GetPos():DistToSqr(self:GetPos()) > C.LeaveRadius * C.LeaveRadius
		if gone or now - (self.LastAction or now) > C.IdleTimeout then self:EndSession(true) st = self:GetStage() end
	end
	for _, v in ipairs(player.GetAll()) do
		if v.CFFocus == self and (not v:Alive() or v:GetPos():DistToSqr(self:GetPos()) > C.LeaveRadius * C.LeaveRadius or not C.Ready(self)) then
			C.SetFocus(v, nil)
		end
	end

	if st == S.DEPOSIT then
		local p = self:GetOperator()
		if IsValid(p) and p:KeyDown(IN_USE) and C.AimedPart(self, p) == 'cells' then
			self.LastAction = now
			self:InsertResin(p)
		end
	end

	if self.PrintSounds then
		for _, s in ipairs(self.PrintSounds) do
			if s[1] and now >= s[1] then self:Snd(s[2], 64) s[1] = nil end
		end
	end

	if self.MessageUntil and now >= self.MessageUntil then self.MessageUntil = nil self:SetStatusText('') end
	self:NextThink(now + 0.05)
	return true
end

function ENT:OnRemove()
	self:ReleaseFocus()
	if self.OrderID then
		local st = self:GetStage()
		local amount = (st == S.DEPOSIT) and self:GetPaid() or ((st == S.PRINT or st == S.DONE) and self:GetCost() or 0)
		C.Refund(self.OrderID, amount)
	end
	self:StopSound(SND .. 'combine_3d_printer_upgrading_01.wav')
end
