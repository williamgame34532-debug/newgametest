include('shared.lua')

-- the weapon in its hands: the world model of the weapon class, merged to the hand bones
function ENT:Think()
	local cls = self:GetWeapon()
	if cls ~= self.WepClass then
		self.WepClass = cls
		if IsValid(self.Wep) then self.Wep:Remove() end
		local w = cls ~= '' and weapons.GetStored(cls)
		local mdl = w and (w.WorldModel or w.WM)
		if (not mdl or mdl == '') and cls ~= '' and string.sub(cls, 1, 7) == 'weapon_' then
			mdl = ({weapon_ar2 = 'models/weapons/w_irifle.mdl', weapon_smg1 = 'models/weapons/w_smg1.mdl',
				weapon_shotgun = 'models/weapons/w_shotgun.mdl', weapon_pistol = 'models/weapons/w_pistol.mdl'})[cls]
		end
		if mdl and mdl ~= '' and util.IsValidModel(mdl) then
			self.Wep = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
			if IsValid(self.Wep) then
				self.Wep:SetParent(self)
				self.Wep:AddEffects(EF_BONEMERGE)
			end
		end
	end
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:OnRemove()
	if IsValid(self.Wep) then self.Wep:Remove() end
end
