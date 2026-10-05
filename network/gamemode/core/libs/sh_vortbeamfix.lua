local BEAM = "swep_vortigaunt_beam"

local ATTACHMENTS = {"anim_attachment_rh", "muzzle", "righthand", "hand_R",
	"rightarm", "lefthand"}

local HAND_BONES = {"ValveBiped.Bip01_R_Hand", "Vort.RightHand",
	"ValveBiped.Vort_R_Hand", "Bip01 R Hand", "RightHand", "Vortigaunt.R_Hand"}

local function BeamOrigin(client)
	if (!IsValid(client)) then
		return vector_origin, 0
	end

	for _, name in ipairs(ATTACHMENTS) do
		local index = client:LookupAttachment(name)

		if (index and index > 0) then
			local data = client:GetAttachment(index)

			if (data and data.Pos) then
				return data.Pos, index
			end
		end
	end

	for _, name in ipairs(HAND_BONES) do
		local bone = client:LookupBone(name)

		if (bone) then
			local matrix = client:GetBoneMatrix(bone)

			if (matrix) then
				return matrix:GetTranslation(), 0
			end
		end
	end

	return client:EyePos() + client:GetAimVector() * 16, 0
end

local function Patch(weapon)
	if (!weapon or weapon.nwBeamPatched) then
		return
	end

	weapon.nwBeamPatched = true

	function weapon:ShootEffect(effect, startpos, endpos)
		local client = self.Owner

		if (!IsValid(client)) then
			return
		end

		local view = CLIENT and GetViewEntity() or client:GetViewEntity()
		local viewModel = client:GetViewModel()

		if (!client:IsNPC() and IsValid(view) and view:IsPlayer() and
			IsValid(viewModel)) then
			local muzzle = IsValid(self.Weapon) and
				self.Weapon:LookupAttachment("muzzle") or 0
			local data = muzzle > 0 and self.Weapon:GetAttachment(muzzle)
			local origin = data and data.Pos or BeamOrigin(client)

			util.ParticleTracerEx(effect, origin, endpos, true,
				viewModel:EntIndex(), viewModel:LookupAttachment("muzzle") or 0)

			return
		end

		local origin, attachment = BeamOrigin(client)

		util.ParticleTracerEx(effect, origin, endpos, true, client:EntIndex(),
			attachment)
	end

	function weapon:ChargeEffect(effect)
		local client = self.Owner

		if (!IsValid(client)) then
			return
		end

		local view = CLIENT and GetViewEntity() or client:GetViewEntity()
		local viewModel = client:GetViewModel()

		if (!client:IsNPC() and IsValid(view) and view:IsPlayer() and
			IsValid(viewModel)) then
			ParticleEffectAttach(effect, PATTACH_POINT_FOLLOW, viewModel,
				viewModel:LookupAttachment("muzzle") or 0)

			return
		end

		local _, attachment = BeamOrigin(client)

		ParticleEffectAttach(effect, PATTACH_POINT_FOLLOW, client, attachment)
	end

	function weapon:StopEveryThing()
		self.Charging = false
		self.Healing = false

		if (SERVER and self.ChargeSound) then
			self.ChargeSound:Stop()
		end

		if (SERVER and self.HealingSound) then
			self.HealingSound:Stop()
		end

		local client = self.LastOwner

		if (!IsValid(client)) then
			return
		end

		local viewModel = client:GetViewModel()

		if (CLIENT and client == LocalPlayer() and IsValid(viewModel)) then
			viewModel:StopParticles()
		end

		client:StopParticles()
	end

	local primary = weapon.PrimaryAttack
	local secondary = weapon.SecondaryAttack

	if (isfunction(primary)) then
		function weapon:PrimaryAttack(...)
			self.nwLoopStamp = CurTime()

			return primary(self, ...)
		end
	end

	if (isfunction(secondary)) then
		function weapon:SecondaryAttack(...)
			self.nwLoopStamp = CurTime()

			return secondary(self, ...)
		end
	end

	weapon.UseHands = false
end

local LOOP_GRACE = 1.6

local function ShouldStopLoops(weapon)
	local owner = weapon:GetOwner()

	if (!IsValid(owner) or !owner:IsPlayer() or !owner:Alive() or
		owner:GetActiveWeapon() != weapon) then
		return true
	end

	if (weapon.Charging or weapon.Healing) then
		return false
	end

	return CurTime() - (weapon.nwLoopStamp or 0) > LOOP_GRACE
end

if (SERVER) then
	hook.Add("Think", "nwVortBeamLoops", function()
		if (!NETWORK.util.Throttle("vort.beamLoops", 0.25)) then
			return
		end

		for _, weapon in ipairs(ents.FindByClass(BEAM)) do
			local charge = weapon.ChargeSound
			local heal = weapon.HealingSound

			if (!(charge and charge:IsPlaying()) and !(heal and heal:IsPlaying())) then
				continue
			end

			if (ShouldStopLoops(weapon)) then
				if (charge) then
					charge:Stop()
				end

				if (heal) then
					heal:Stop()
				end
			end
		end
	end)
end

local function PatchAll()
	Patch(weapons.GetStored(BEAM))

	for _, entity in ipairs(ents.FindByClass(BEAM)) do
		Patch(entity:GetTable())
	end
end

hook.Add("Initialize", "nwVortBeamFix", PatchAll)
hook.Add("OnReloaded", "nwVortBeamFix", PatchAll)

hook.Add("OnEntityCreated", "nwVortBeamFix", function(entity)
	if (!IsValid(entity) or entity:GetClass() != BEAM) then
		return
	end

	timer.Simple(0, function()
		if (IsValid(entity)) then
			Patch(weapons.GetStored(BEAM))
			Patch(entity:GetTable())
		end
	end)
end)

PatchAll()
