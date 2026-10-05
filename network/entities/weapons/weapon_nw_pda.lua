AddCSLuaFile()

-- Служебный КПК в руках. Руки — настоящие руки персонажа (UseHands) на c_arms
-- (как у weapon_fists): доставание и держание двумя руками перед собой. КПК ставится
-- между кистями и масштабируется по расстоянию между ними, экран смотрит в камеру,
-- на нём — живое меню КПК (рендер в текстуру, см. cl_cityupdate.lua).
-- Нажатие — короткий «тычок» устройства при открытии и каждом клике по меню.

SWEP.PrintName = "Служебный КПК"
SWEP.Author = "Network"
SWEP.Category = "Network"
SWEP.Spawnable = false
SWEP.Slot = 4
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_arms.mdl"
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
	self:SetHoldType("slam")
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

	return vm:SequenceDuration(sequence)
end

function SWEP:Deploy()
	self.equipAt = CurTime()
	self.nwIdleAt = CurTime() + self:PlaySequence("fists_draw")

	return true
end

-- Нажатие: визуально на клиенте (тычок устройства), см. C.pressAt.
function SWEP:Press()
	if (CLIENT and NETWORK.city) then
		NETWORK.city.pressAt = RealTime()
	end
end

function SWEP:Think()
	if (self.nwIdleAt and self.nwIdleAt <= CurTime()) then
		self.nwIdleAt = CurTime() + math.max(self:PlaySequence("fists_idle_01"), 2)
	end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 1)
	self:Press()

	if (SERVER) then
		NETWORK.city.OpenPDA(self:GetOwner())
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
	if (CLIENT and IsValid(NETWORK.city.frame)) then
		NETWORK.city.frame:Close()
	end
end

function SWEP:Holster()
	if (CLIENT) then
		if (IsValid(NETWORK.city.frame) and !NETWORK.city.frame.terminal) then
			NETWORK.city.frame:Close()
		end

		self:RestoreViewModel()
	end

	return true
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
end

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

function SWEP:PostDrawViewModel(vm)
	local pos, ang, scale = self:GetKPKMatrix(vm)
	local C = NETWORK.city

	if (pos and C and C.DrawDevice) then
		C.DrawDevice(pos, ang, scale, self)
	end
end

function SWEP:DrawWorldModel()
	local owner = self:GetOwner()

	if (!IsValid(owner)) then
		return self:DrawModel()
	end

	local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")

	if (!bone) then
		return
	end

	local pos, ang = owner:GetBonePosition(bone)

	ang:RotateAroundAxis(ang:Forward(), 90)

	if (util.IsValidModel(self.KPKModel)) then
		if (!IsValid(self.nwKPK)) then
			self.nwKPK = ClientsideModel(self.KPKModel, RENDERGROUP_OPAQUE)

			if (!IsValid(self.nwKPK)) then
				return
			end

			self.nwKPK:SetNoDraw(true)
		end

		self.nwKPK:SetModelScale(0.42, 0)
		self.nwKPK:SetRenderOrigin(pos + ang:Forward() * 3 + ang:Right() * 1)
		self.nwKPK:SetRenderAngles(ang)
		self.nwKPK:SetupBones()
		self.nwKPK:DrawModel()
	elseif (NETWORK.cityModels) then
		NETWORK.cityModels.Draw("pda_", pos, ang, 0.55, 0)
	end
end

function SWEP:DrawHUD()
	if (IsValid(NETWORK.city.frame)) then
		return
	end

	draw.SimpleTextOutlined("ЛКМ — открыть КПК  •  R — закрыть", "nwChatSmall", ScrW() / 2,
		ScrH() - 80, Color(200, 220, 228), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 160))
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
