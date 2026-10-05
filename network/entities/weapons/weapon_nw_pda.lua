AddCSLuaFile()

-- Служебный КПК в руках. Руки — настоящие руки персонажа (UseHands) на анимациях
-- детонатора из c_slam: доставание, держание, нажатие и убирание. Сам пульт SLAM
-- скрыт, вместо него в руке рисуется модель КПК, а на его экране — живое меню КПК
-- (рендер в текстуру, см. cl_cityupdate.lua).

SWEP.PrintName = "Служебный КПК"
SWEP.Author = "Network"
SWEP.Category = "Network"
SWEP.Spawnable = false
SWEP.Slot = 4
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_slam.mdl"
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

-- КПК не «опускается» как оружие: вьюмодель видна всегда (см. cl_weapon.lua).
function SWEP:IsSafety()
	return true
end

function SWEP:PlayAnim(act, nextIdle)
	self:SendWeaponAnim(act)

	local vm = IsValid(self:GetOwner()) and self:GetOwner():GetViewModel()
	local duration = IsValid(vm) and vm:SequenceDuration() or 0.5

	self.nwIdleAt = CurTime() + (nextIdle or duration)
end

function SWEP:Deploy()
	self.equipAt = CurTime()
	self:PlayAnim(ACT_SLAM_DETONATOR_DRAW)

	return true
end

-- Нажатие: проигрывается при открытии КПК и при каждом клике по меню.
function SWEP:Press()
	if ((self.nwPressAt or 0) > CurTime()) then
		return
	end

	self.nwPressAt = CurTime() + 0.2
	self:PlayAnim(ACT_SLAM_DETONATOR_DETONATE)
end

function SWEP:Think()
	if (self.nwIdleAt and self.nwIdleAt <= CurTime()) then
		self.nwIdleAt = nil
		self:SendWeaponAnim(ACT_SLAM_DETONATOR_IDLE)
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
	util.AddNetworkString("nwPDAPress")

	net.Receive("nwPDAPress", function(_, client)
		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and weapon:GetClass() == "weapon_nw_pda") then
			weapon:Press()
		end
	end)

	return
end

-- Клиент ----------------------------------------------------------------------------------------

local hidden = CreateMaterial("nwPDAHiddenVM", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$translucent"] = "1",
	["$alpha"] = "0"
})

-- Подгонка положения КПК в руке (можно крутить в игре: network_pda_tune).
local tune = {
	x = CreateClientConVar("network_pda_vm_x", "0", true, false),
	y = CreateClientConVar("network_pda_vm_y", "0", true, false),
	z = CreateClientConVar("network_pda_vm_z", "0", true, false),
	p = CreateClientConVar("network_pda_vm_p", "0", true, false),
	yaw = CreateClientConVar("network_pda_vm_yaw", "0", true, false),
	r = CreateClientConVar("network_pda_vm_r", "0", true, false),
	scale = CreateClientConVar("network_pda_vm_scale", "0.45", true, false)
}

function SWEP:RestoreViewModel()
	local owner = self:GetOwner()
	local vm = IsValid(owner) and owner.GetViewModel and owner:GetViewModel()

	if (IsValid(vm) and vm.nwPDAHidden) then
		vm:SetMaterial("")
		vm.nwPDAHidden = nil
	end

	if (IsValid(self.nwKPK)) then
		self.nwKPK:Remove()
	end
end

-- Кость, к которой крепится КПК: пульт детонатора в c_slam, иначе левая кисть.
local function FindAnchor(vm)
	if (vm.nwPDAAnchorModel == vm:GetModel() and vm.nwPDAAnchor) then
		return vm.nwPDAAnchor
	end

	local anchor

	for index = 0, vm:GetBoneCount() - 1 do
		local name = string.lower(vm:GetBoneName(index) or "")

		if (string.find(name, "deton", 1, true)) then
			anchor = index

			break
		end
	end

	anchor = anchor or vm:LookupBone("ValveBiped.Bip01_L_Hand") or 0

	vm.nwPDAAnchorModel = vm:GetModel()
	vm.nwPDAAnchor = anchor

	return anchor
end

-- Матрица КПК во вьюмодели: кость-якорь + подгонка из конваров.
function SWEP:GetKPKMatrix(vm)
	local matrix = vm:GetBoneMatrix(FindAnchor(vm))

	if (!matrix) then
		return
	end

	local pos, ang = matrix:GetTranslation(), matrix:GetAngles()

	ang:RotateAroundAxis(ang:Right(), tune.p:GetFloat())
	ang:RotateAroundAxis(ang:Up(), tune.yaw:GetFloat())
	ang:RotateAroundAxis(ang:Forward(), tune.r:GetFloat())

	pos = pos + ang:Forward() * tune.x:GetFloat() + ang:Right() * tune.y:GetFloat() +
		ang:Up() * tune.z:GetFloat()

	return pos, ang, math.Clamp(tune.scale:GetFloat(), 0.05, 3)
end

function SWEP:PreDrawViewModel(vm)
	-- Сам пульт SLAM не рисуем, руки — отдельная сущность и остаются видны.
	if (!vm.nwPDAHidden) then
		vm:SetMaterial("!nwPDAHiddenVM")
		vm.nwPDAHidden = true
	end
end

function SWEP:PostDrawViewModel(vm)
	local pos, ang, scale = self:GetKPKMatrix(vm)

	if (!pos) then
		return
	end

	local C = NETWORK.city

	if (C and C.DrawDevice) then
		C.DrawDevice(pos, ang, scale, self)
	end
end

-- Если вьюмодель сменилась без Holster (смерть, принудительная смена оружия) — чистим.
hook.Add("Think", "nwPDAViewModel", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local vm = client:GetViewModel()
	local weapon = client:GetActiveWeapon()

	if (IsValid(vm) and vm.nwPDAHidden and
		(!IsValid(weapon) or weapon:GetClass() != "weapon_nw_pda")) then
		vm:SetMaterial("")
		vm.nwPDAHidden = nil
	end
end)

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
