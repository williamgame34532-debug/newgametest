AddCSLuaFile()

-- Служебный КПК в руках.
-- Основной вариант — вьюмодель models/weapons/c_kpk.mdl (аддон КПК): руки персонажа (UseHands)
-- держат КПК двумя руками, анимации доставания, дыхания, нажатия большим пальцем и убирания.
-- Углы экрана заданы аттачментами scr_tl/tr/br/bl — на них рисуется живое меню КПК
-- (рендер в текстуру, см. cl_cityupdate.lua).
-- Если c_kpk.mdl не собрана — запасной вариант на c_arms с КПК между кистями.
-- ПКМ переключает мышь: в игру (осмотреться) и обратно в КПК.

SWEP.PrintName = "Служебный КПК"
SWEP.Author = "Network"
SWEP.Category = "Network"
SWEP.Spawnable = false
SWEP.Slot = 4
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.UseHands = true
SWEP.KPKViewModel = "models/weapons/c_kpk.mdl"
SWEP.bKPKViewModel = file.Exists(SWEP.KPKViewModel, "GAME")
SWEP.ViewModel = SWEP.bKPKViewModel and SWEP.KPKViewModel or "models/weapons/c_arms.mdl"
SWEP.ViewModelFOV = 54
SWEP.WorldModel = "models/props_lab/clipboard.mdl"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.KPKModel = "models/network/kpk.mdl"

function SWEP:Initialize()
	-- Двумя руками перед собой (от третьего лица).
	self:SetHoldType("camera")
end

function SWEP:PlaySequence(name)
	local owner = self:GetOwner()
	local vm = IsValid(owner) and owner:GetViewModel()

	if (!IsValid(vm)) then
		return 0
	end

	local sequence = vm:LookupSequence(name)

	if (!sequence or sequence < 0) then
		return 0
	end

	vm:SendViewModelMatchingSequence(sequence)
	vm:SetCycle(0)

	return vm:SequenceDuration(sequence)
end

function SWEP:Deploy()
	self.equipAt = CurTime()
	self.nwHolsterAt = nil
	self.nwHolsterTo = nil
	self.nwHolstered = nil
	self.nwRaised = false
	self.nwClientIdleAt = nil

	-- Экран «загружается», затем интерфейс открывается на КПК (мышь пока в игре).
	if (CLIENT and NETWORK.city and IsFirstTimePredicted()) then
		NETWORK.city.bootAt = RealTime()
	end

	if (SERVER) then
		local owner = self:GetOwner()

		timer.Simple(1.2, function()
			if (IsValid(self) and IsValid(owner) and owner:GetActiveWeapon() == self) then
				NETWORK.city.OpenPDA(owner, true)
			end
		end)
	end

	if (self.bKPKViewModel) then
		self:SendWeaponAnim(ACT_VM_DRAW)

		local vm = IsValid(self:GetOwner()) and self:GetOwner():GetViewModel()

		self.nwIdleAt = CurTime() + (IsValid(vm) and vm:SequenceDuration() or 0.6)
	else
		self.nwIdleAt = CurTime() + self:PlaySequence("fists_draw")
	end

	return true
end

-- Нажатие большим пальцем — только визуально, на клиенте.
function SWEP:Press()
	if (!CLIENT) then
		return
	end

	if (NETWORK.city) then
		NETWORK.city.pressAt = RealTime()
	end

	if (self.bKPKViewModel and self.nwRaised and !self.nwRaising) then
		local duration = self:PlaySequence("press")

		if (duration > 0) then
			self.nwClientIdleAt = RealTime() + duration
		end
	end
end

-- Поднять КПК к лицу (мышь в КПК) или опустить вниз (мышь в игре). Только визуально, на клиенте.
function SWEP:SetRaised(bRaised)
	if (!CLIENT or !self.bKPKViewModel or self.nwRaised == bRaised or self.nwHolsterAt) then
		return
	end

	self.nwRaised = bRaised

	local duration = self:PlaySequence(bRaised and "raise" or "lower")

	self.nwRaising = bRaised or nil
	self.nwClientIdleAt = RealTime() + math.max(duration, 0.1)
end

function SWEP:GetIdleSequence()
	return self.nwRaised and "idle_up" or "idle"
end

function SWEP:Think()
	if (self.nwHolsterAt and self.nwHolsterAt <= CurTime()) then
		self.nwHolsterAt = nil
		self.nwHolstered = true

		local owner = self:GetOwner()
		local target = self.nwHolsterTo

		if (SERVER and IsValid(owner) and IsValid(target)) then
			owner:SelectWeapon(target:GetClass())
		end

		return
	end

	if (self.nwHolsterAt) then
		return
	end
	if (self.nwIdleAt and self.nwIdleAt <= CurTime()) then
		if (self.bKPKViewModel) then
			self.nwIdleAt = nil
			self:SendWeaponAnim(ACT_VM_IDLE)
		else
			self.nwIdleAt = CurTime() + math.max(self:PlaySequence("fists_idle_01"), 2)
		end
	end

	if (CLIENT and self.nwClientIdleAt and self.nwClientIdleAt <= RealTime()) then
		self.nwClientIdleAt = nil
		self.nwRaising = nil
		self:PlaySequence(self:GetIdleSequence())
	end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.6)

	if (self.nwHolsterAt) then
		return
	end

	if (CLIENT and IsFirstTimePredicted()) then
		self:Press()
	end

	if (SERVER) then
		NETWORK.city.OpenPDA(self:GetOwner())
	end
end

-- ПКМ в режиме «мышь в игре» возвращает курсор в КПК (в самом КПК ПКМ ловит cl_cityupdate).
function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.3)

	if (CLIENT and IsFirstTimePredicted() and NETWORK.city.SetFocus) then
		NETWORK.city.SetFocus(true)
	end
end

function SWEP:Reload()
	if (CLIENT and IsValid(NETWORK.city.frame)) then
		NETWORK.city.frame:Close()
	end
end

-- Убирание с анимацией: смена оружия откладывается, пока КПК опускается.
function SWEP:Holster(weapon)
	if (self.nwHolstered or !IsValid(weapon) or weapon == self) then
		self:FinishHolster()

		return true
	end

	if (self.nwHolsterAt) then
		return false
	end

	self.nwHolsterTo = weapon

	local duration

	if (self.bKPKViewModel) then
		-- 12 кадров при 30 fps; анимация из текущего положения играется на клиенте.
		duration = 0.42

		if (CLIENT) then
			self.nwClientIdleAt = nil
			self:PlaySequence(self.nwRaised and "holster_up" or "holster")
		end
	else
		duration = math.max(self:PlaySequence("fists_holster"), 0.4)
	end

	self.nwHolsterAt = CurTime() + math.Clamp(duration, 0.2, 1)

	if (CLIENT) then
		if (IsValid(NETWORK.city.frame) and !NETWORK.city.frame.terminal) then
			NETWORK.city.frame:Close()
		end

		NETWORK.city.offAt = RealTime()
	end

	return false
end

function SWEP:FinishHolster()
	self.nwHolsterAt = nil

	if (CLIENT) then
		if (IsValid(NETWORK.city.frame) and !NETWORK.city.frame.terminal) then
			NETWORK.city.frame:Close()
		end

		self:RestoreViewModel()
	end
end

function SWEP:OnRemove()
	if (CLIENT) then
		self:RestoreViewModel()
	end
end

if (SERVER) then
	return
end

-- Клиент ----------------------------------------------------------------------------------------

-- Подгонка положения КПК в руке (можно крутить в игре: network_pda_tune).
local tune = {
	x = CreateClientConVar("network_pda_vm_x", "0", true, false),
	y = CreateClientConVar("network_pda_vm_y", "0", true, false),
	z = CreateClientConVar("network_pda_vm_z", "0", true, false),
	p = CreateClientConVar("network_pda_vm_p", "0", true, false),
	yaw = CreateClientConVar("network_pda_vm_yaw", "0", true, false),
	r = CreateClientConVar("network_pda_vm_r", "0", true, false),
	scale = CreateClientConVar("network_pda_vm_scale", "1", true, false)
}

function SWEP:RestoreViewModel()
	if (IsValid(self.nwKPK)) then
		self.nwKPK:Remove()
	end

	local owner = self:GetOwner()
	local vm = IsValid(owner) and owner.GetViewModel and owner:GetViewModel()

	if (IsValid(vm) and NETWORK.city and NETWORK.city.ClearScreenMaterial) then
		NETWORK.city.ClearScreenMaterial(vm)
	end
end

-- Вьюмодель общая для всех оружий: снимаем подменённый материал, если КПК уже не в руках.
hook.Add("Think", "nwPDAScreenMaterial", function()
	local client = LocalPlayer()
	local vm = IsValid(client) and client:GetViewModel()

	if (!IsValid(vm) or !vm.nwScreenIndex) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (!IsValid(weapon) or weapon:GetClass() != "weapon_nw_pda") then
		NETWORK.city.ClearScreenMaterial(vm)
		vm.nwScreenIndex = nil
		vm.nwScreenModel = nil
	end
end)

-- Где держать КПК: посередине между кистями, лицом к камере, по ширине хвата.
function SWEP:GetKPKMatrix(vm)
	local eyeAng = EyeAngles()
	local forward, right, up = eyeAng:Forward(), eyeAng:Right(), eyeAng:Up()
	local left = vm:LookupBone("ValveBiped.Bip01_L_Hand")
	local rightHand = vm:LookupBone("ValveBiped.Bip01_R_Hand")
	local pos, span

	if (left and rightHand) then
		local a = vm:GetBonePosition(left)
		local b = vm:GetBonePosition(rightHand)

		if (a and b and a != vector_origin and b != vector_origin) then
			pos = (a + b) * 0.5
			span = math.abs((b - a):Dot(right))
		end
	end

	if (!pos or !span or span < 2) then
		pos = EyePos() + forward * 18 - up * 4
		span = 10
	end

	local C = NETWORK.city
	local bLandscape = C and C.HasKPKModel and C.HasKPKModel()
	-- Расстояние между центрами ручек: kpk.mdl ~11.2, запасной меш C24 ~10.
	local grip = bLandscape and 11.2 or 10
	local scale = math.Clamp(span / grip, 0.25, 2) * math.Clamp(tune.scale:GetFloat(), 0.1, 3)

	pos = pos + right * tune.y:GetFloat() + up * tune.z:GetFloat() + forward * tune.x:GetFloat()

	-- Доставание снизу и убирание вниз (для варианта без c_kpk.mdl).
	local rise = math.Clamp((CurTime() - (self.equipAt or 0)) / 0.45, 0, 1)
	local lower = 0

	if (self.nwHolsterAt) then
		lower = 1 - math.Clamp((self.nwHolsterAt - CurTime()) / 0.4, 0, 1)
	end

	local away = math.max(1 - rise * rise * (3 - 2 * rise), lower * lower * (3 - 2 * lower))

	pos = pos - up * 12 * away - forward * 3 * away

	-- Нажатие: устройство коротко уходит от камеры и чуть наклоняется.
	local press = C and C.pressAt and math.Clamp(1 - (RealTime() - C.pressAt) / 0.22, 0, 1) or 0

	press = math.sin(press * math.pi)
	pos = pos + forward * press * 0.6 * scale

	-- Лёгкое «дыхание» в руках.
	pos = pos + up * math.sin(RealTime() * 1.3) * 0.08

	local ang

	if (bLandscape) then
		ang = right:AngleEx(-forward)
	else
		ang = (-forward):AngleEx(up)
	end

	ang:RotateAroundAxis(right, tune.p:GetFloat() + press * 3)
	ang:RotateAroundAxis(up, tune.yaw:GetFloat())
	ang:RotateAroundAxis(forward, tune.r:GetFloat())

	return pos, ang, scale
end

function SWEP:PreDrawViewModel(vm)
	if (self.bKPKViewModel and NETWORK.city and NETWORK.city.ApplyScreenMaterial) then
		NETWORK.city.ApplyScreenMaterial(vm)
	end
end

function SWEP:PostDrawViewModel(vm)
	local C = NETWORK.city

	-- c_kpk: КПК уже в модели, живой экран — материал её стекла (см. PreDrawViewModel).
	if (self.bKPKViewModel and vm.nwScreenIndex) then
		return
	end

	local pos, ang, scale = self:GetKPKMatrix(vm)

	if (pos and C and C.DrawDevice) then
		C.DrawDevice(pos, ang, scale, self)
	end
end

-- От третьего лица: КПК между кистями (hold type "camera"), экраном к лицу персонажа.
function SWEP:DrawWorldModel()
	local owner = self:GetOwner()

	if (!IsValid(owner)) then
		return self:DrawModel()
	end

	local left = owner:LookupBone("ValveBiped.Bip01_L_Hand")
	local rightHand = owner:LookupBone("ValveBiped.Bip01_R_Hand")

	if (!left or !rightHand) then
		return
	end

	local a = owner:GetBonePosition(left)
	local b = owner:GetBonePosition(rightHand)

	if (!a or !b) then
		return
	end

	local eye = owner:EyeAngles()

	eye.p = 0

	local forward, right, up = eye:Forward(), eye:Right(), eye:Up()

	-- Экран смотрит вверх-назад, к лицу персонажа (он смотрит на КПК в руках).
	local normal = (up * 0.8 - forward * 0.6):GetNormalized()
	local screenUp = normal:Cross(right):GetNormalized()

	-- studiomdl поворачивает модель на 90° вокруг вертикали: ширина КПК — локальная ось Y,
	-- верх экрана — локальная -X, экран — +Z.
	local ang = (-screenUp):AngleEx(normal)
	local pos = (a + b) * 0.5 + forward * 1.5 - normal * 0.4

	if (util.IsValidModel(self.KPKModel)) then
		if (!IsValid(self.nwKPK)) then
			self.nwKPK = ClientsideModel(self.KPKModel, RENDERGROUP_OPAQUE)

			if (!IsValid(self.nwKPK)) then
				return
			end

			self.nwKPK:SetNoDraw(true)
			self.nwKPK:SetModelScale(0.5, 0)
		end

		-- Свой КПК от третьего лица показывает живой экран, чужие — заставку модели.
		if (owner == LocalPlayer() and NETWORK.city and NETWORK.city.ApplyScreenMaterial) then
			NETWORK.city.ApplyScreenMaterial(self.nwKPK)
		end

		self.nwKPK:SetRenderOrigin(pos)
		self.nwKPK:SetRenderAngles(ang)
		self.nwKPK:SetupBones()
		self.nwKPK:DrawModel()
	elseif (NETWORK.cityModels) then
		NETWORK.cityModels.Draw("pda_", pos, (-forward):AngleEx(up), 0.45, 0)
	end
end

-- Подсказок на экране нет: всё управление видно на самом КПК.
function SWEP:DrawHUD()
end

-- Окно подгонки положения КПК в руке.
concommand.Add("network_pda_tune", function()
	local frame = vgui.Create("DFrame")

	frame:SetTitle("КПК в руке — подгонка")
	frame:SetSize(360, 330)
	frame:SetPos(30, ScrH() / 2 - 165)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	local rows = {
		{"Вперёд/назад", "x", -20, 20}, {"Влево/вправо", "y", -20, 20}, {"Вверх/вниз", "z", -20, 20},
		{"Наклон", "p", -180, 180}, {"Поворот", "yaw", -180, 180}, {"Крен", "r", -180, 180},
		{"Масштаб", "scale", 0.1, 2}
	}

	for _, row in ipairs(rows) do
		local slider = frame:Add("DNumSlider")

		slider:Dock(TOP)
		slider:SetText(row[1])
		slider:SetMinMax(row[3], row[4])
		slider:SetDecimals(2)
		slider:SetConVar("network_pda_vm_" .. row[2])
	end

	local print = frame:Add("DButton")

	print:Dock(BOTTOM)
	print:SetText("Вывести значения в консоль")
	print.DoClick = function()
		for _, row in ipairs(rows) do
			MsgN("network_pda_vm_" .. row[2] .. " " .. GetConVar("network_pda_vm_" .. row[2]):GetString())
		end
	end
end)
