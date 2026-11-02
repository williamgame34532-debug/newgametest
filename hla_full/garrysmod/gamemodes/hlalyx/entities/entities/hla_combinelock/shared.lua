ENT.Type = 'anim'
ENT.PrintName = 'Замок Альянса'
ENT.Category = 'Half-Life: Alyx'
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.LockModel = 'models/props_combine/combine_lock01.mdl'
ENT.SndLock = 'hla/lock/combine_lock.wav'
ENT.SndUnlock = {'hla/lock/combine_locker_open1.wav', 'hla/lock/combine_locker_open2.wav', 'hla/lock/combine_locker_open3.wav'}
ENT.SndError = 'buttons/combine_button_locked.wav'

HLA = HLA or {}
HLA.DoorClasses = {prop_door_rotating = true, func_door = true, func_door_rotating = true}
function HLA.IsDoor(e)
	return IsValid(e) and HLA.DoorClasses[e:GetClass()] == true
end

function ENT:SetupDataTables()
	self:NetworkVar('Bool', 0, 'Locked')
	self:NetworkVar('Bool', 1, 'DisplayError')
	if SERVER then self:NetworkVarNotify('Locked', self.OnLockChanged) end
end
