local HEAD_BONES = {
	"ValveBiped.Bip01_Head1",
	"ValveBiped.Bip01_Head",
	"Bip01_Head1",
	"Bip01 Head",
	"Head",
	"head",
	"Vort.Head",
	"ValveBiped.Vort_Head",
	"Vortigaunt.Head"
}

local ARM_BONES = {
	"ValveBiped.Bip01_L_Clavicle",
	"ValveBiped.Bip01_R_Clavicle"
}

local ARM_BONES_FALLBACK = {
	"Bip01 L Clavicle", "Bip01 R Clavicle",
	"bip_collar_L", "bip_collar_R",
	"L_Clavicle", "R_Clavicle",
	"clavicle_L", "clavicle_R"
}

local HIDE_OFFSET = Vector(0, -120, 0)

local BODY_BONES = {
	"ValveBiped.Bip01_Spine4",
	"ValveBiped.Bip01_Spine2"
}

local CLIP_VECTOR = vector_up * -1

NETWORK.legs = NETWORK.legs or {}
NETWORK.legs.clipDown = 6
NETWORK.legs.forwardOffset = -14

local enabled = CreateClientConVar("network_legs_v2", "1", true, false,
	"Показывать своё тело от первого лица")
local showArms = CreateClientConVar("network_legs_arms", "1", true, false,
	"Показывать руки")
local showBody = CreateClientConVar("network_legs_body", "1", true, false,
	"Показывать торс")
local hideArmsWeapon = CreateClientConVar("network_legs_hidearms", "1", true, false,
	"Прятать руки, когда оружие поднято")

local Legs = NETWORK.legs

Legs.entity = Legs.entity or nil
Legs.weapon = Legs.weapon or nil
Legs.weaponClass = Legs.weaponClass or ""
Legs.sequence = nil
Legs.playback = 1
Legs.lastTick = 0

function Legs:ShouldHideArms()
	if (!showArms:GetBool()) then
		return true
	end

	if (!hideArmsWeapon:GetBool()) then
		return false
	end

	local client = LocalPlayer()
	local weapon = client:GetActiveWeapon()

	if (!IsValid(weapon) or weapon:GetClass() == NETWORK.weapon.hands) then
		return false
	end

	return true
end

function Legs:ShouldDraw()
	if (!enabled:GetBool() or hook.Run("NetworkShouldDrawLegs") == false) then
		return false
	end

	local client = LocalPlayer()

	if (NETWORK.thirdperson and NETWORK.thirdperson.IsEnabled and
		NETWORK.thirdperson.IsEnabled()) then
		return false
	end

	if (NETWORK.immersive and NETWORK.immersive.IsEnabled and
		NETWORK.immersive.IsEnabled()) then
		return false
	end

	if (client:GetMoveType() == MOVETYPE_NOCLIP) then
		return false
	end

	return IsValid(self.entity) and client:Alive() and client:HasCharacter() and
		GetViewEntity() == client and !client:ShouldDrawLocalPlayer() and
		!IsValid(client:GetObserverTarget()) and !client:GetNoDraw()
end

function Legs:Setup(model)
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	model = model or client:GetModel()

	if (!IsValid(self.entity)) then
		self.entity = ClientsideModel(model, RENDERGROUP_OPAQUE)
		self.model = model
	else
		self.entity:SetModel(model)
	end

	if (!IsValid(self.entity)) then
		return
	end

	self.entity:SetNoDraw(true)
	self.entity:SetModelScale(client:GetModelScale(), 0)

	for _, data in pairs(client:GetBodyGroups()) do
		self.entity:SetBodygroup(data.id, client:GetBodygroup(data.id))
	end

	self.entity:SetSkin(client:GetSkin())
	self.entity:SetColor(client:GetColor())

	self.sequence = nil
	self.playback = 1
	self.lastTick = 0

	self:FixBones()
end

function Legs:FixBones()
	if (!IsValid(self.entity)) then
		return
	end

	for i = 0, self.entity:GetBoneCount() do
		self.entity:ManipulateBoneScale(i, Vector(1, 1, 1))
		self.entity:ManipulateBonePosition(i, vector_origin)
		self.entity:ManipulateBoneAngles(i, angle_zero)
	end

	local head

	for _, name in ipairs(HEAD_BONES) do
		head = self.entity:LookupBone(name)

		if (head) then
			break
		end
	end

	if (!head) then
		for index = 0, self.entity:GetBoneCount() - 1 do
			local name = self.entity:GetBoneName(index)

			if (name and string.find(string.lower(name), "head", 1, true)) then
				head = index

				break
			end
		end
	end

	if (head) then
		self.entity:ManipulateBoneScale(head, vector_origin)
	end

	if (self:ShouldHideArms()) then

		local roots = {}

		for _, name in ipairs(ARM_BONES) do
			local bone = self.entity:LookupBone(name)

			if (bone) then
				roots[#roots + 1] = bone
			end
		end

		if (#roots == 0) then
			for _, name in ipairs(ARM_BONES_FALLBACK) do
				local bone = self.entity:LookupBone(name)

				if (bone) then
					roots[#roots + 1] = bone
				end
			end
		end

		for _, bone in ipairs(roots) do
			self.entity:ManipulateBoneScale(bone, vector_origin)
			self.entity:ManipulateBonePosition(bone, HIDE_OFFSET)
		end

		if (#roots > 0) then
			local lookup = {}

			for _, bone in ipairs(roots) do
				lookup[bone] = true
			end

			for index = 0, self.entity:GetBoneCount() - 1 do
				local parent = self.entity:GetBoneParent(index)
				local guard = 0

				while (parent and parent >= 0 and guard < 24) do
					if (lookup[parent]) then
						self.entity:ManipulateBoneScale(index, vector_origin)

						break
					end

					parent = self.entity:GetBoneParent(parent)
					guard = guard + 1
				end
			end
		end
	end

	if (!showBody:GetBool()) then
		for _, name in ipairs(BODY_BONES) do
			local bone = self.entity:LookupBone(name)

			if (bone) then
				self.entity:ManipulateBoneScale(bone, vector_origin)
				self.entity:ManipulateBonePosition(bone, HIDE_OFFSET)
			end
		end
	end

	self.armState = self:ShouldHideArms()
end

function Legs:Update(maxSeqGroundSpeed)
	local client = LocalPlayer()

	if (!IsValid(self.entity) or !IsValid(client)) then
		return
	end

	if (!self:ShouldDraw()) then
		self:Park()

		self.sequence = nil
		self.lastTick = CurTime()

		return
	end

	local velocity = client:GetVelocity():Length2D()

	self.playback = 1

	if (velocity > 0.5) then
		if (maxSeqGroundSpeed < 0.001) then
			self.playback = 0.01
		else
			self.playback = math.Clamp(velocity / maxSeqGroundSpeed, 0.01, 10)
		end
	end

	self.entity:SetPlaybackRate(self.playback)

	local sequence = client:GetSequence()

	if (self.sequence != sequence) then
		self.sequence = sequence

		self.entity:ResetSequence(sequence)
	end

	self.entity:FrameAdvance(CurTime() - self.lastTick)
	self.lastTick = CurTime()

	self.entity:SetPoseParameter("move_x", client:GetPoseParameter("move_x") * 2 - 1)
	self.entity:SetPoseParameter("move_y", client:GetPoseParameter("move_y") * 2 - 1)
	self.entity:SetPoseParameter("move_yaw", client:GetPoseParameter("move_yaw") * 360 - 180)
	self.entity:SetPoseParameter("body_yaw", client:GetPoseParameter("body_yaw") * 180 - 90)
	self.entity:SetPoseParameter("spine_yaw", client:GetPoseParameter("spine_yaw") * 180 - 90)

	if (self.armState != self:ShouldHideArms()) then
		self:FixBones()
	end

	self:UpdateTransform()
end

function Legs:UpdateTransform()
	local client = LocalPlayer()
	local position = client:GetPos()
	local angles = client:EyeAngles()
	local radians = math.rad(angles.y)

	position.x = position.x + math.cos(radians) * self.forwardOffset
	position.y = position.y + math.sin(radians) * self.forwardOffset

	if (client:GetGroundEntity() == NULL) then
		position.z = position.z + 8

		if (client:KeyDown(IN_DUCK)) then
			position.z = position.z - 28
		end
	end

	self.entity:SetPos(position)
	self.entity:SetAngles(Angle(0, angles.y, 0))
	self.entity:SetupBones()
end

function Legs:CheckModel()
	local client = LocalPlayer()
	local model = client:GetCharacterModel()

	if (IsValid(self.entity) and self.model != model) then
		self.entity:Remove()

		self.entity = nil
		self.model = nil
	end

	if (IsValid(self.entity)) then
		NETWORK.util.ApplyAppearance(self.entity, client)
	end
end

function Legs:Park()
	if (!IsValid(self.entity)) then
		return
	end

	self.entity:SetNoDraw(true)
	self.entity:SetPos(Vector(0, 0, -16384))
end

function Legs:Render()
	if (!self:ShouldDraw()) then
		self:Park()

		return
	end

	local color = LocalPlayer():GetColor()

	self:CheckModel()

	if (!IsValid(self.entity)) then
		return
	end

	cam.Start3D(EyePos(), EyeAngles())
		local bClipping = render.EnableClipping(true)

		render.PushCustomClipPlane(CLIP_VECTOR, CLIP_VECTOR:Dot(EyePos()) + self.clipDown)
			render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
			render.SetBlend(color.a / 255)

			self.entity:SetupBones()
			self.entity:DrawModel()

			render.SetBlend(1)
			render.SetColorModulation(1, 1, 1)
		render.PopCustomClipPlane()

		render.EnableClipping(bClipping)
	cam.End3D()
end

hook.Add("UpdateAnimation", "nwLegs", function(client, velocity, maxSeqGroundSpeed)
	if (client != LocalPlayer()) then
		return
	end

	if (IsValid(Legs.entity)) then
		Legs:Update(maxSeqGroundSpeed)
	else
		Legs:Setup()
	end
end)

concommand.Add("network_legs_debug", function()
	local entity = Legs.entity

	NETWORK.util.Print("Подставное тело: " ..
		(IsValid(entity) and "существует" or "нет"))

	if (IsValid(entity)) then
		NETWORK.util.Print("  позиция: " .. tostring(entity:GetPos()))
		NETWORK.util.Print("  скрыта: " .. tostring(entity:GetNoDraw()))
	end

	NETWORK.util.Print("  надо рисовать: " .. tostring(Legs:ShouldDraw()))
	NETWORK.util.Print("  третье лицо: " ..
		tostring(NETWORK.thirdperson and NETWORK.thirdperson.IsEnabled()))
	NETWORK.util.Print("  иммерсивная: " ..
		tostring(NETWORK.immersive and NETWORK.immersive.IsEnabled()))
end)

hook.Add("EntityEmitSound", "nwLegsMute", function(data)
	if (IsValid(Legs.entity) and data.Entity == Legs.entity) then
		return false
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwLegs", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	Legs:Render()
end)

hook.Add("NetworkWeaponRaised", "nwLegs", function()
	Legs:FixBones()
end)

hook.Add("OnReloaded", "nwLegs", function()
	if (IsValid(Legs.entity)) then
		Legs.entity:Remove()
	end

	if (IsValid(Legs.weapon)) then
		Legs.weapon:Remove()
	end

	Legs.entity = nil
	Legs.weapon = nil
	Legs.weaponClass = ""
end)

concommand.Add("network_legs_refresh", function()
	if (IsValid(Legs.entity)) then
		Legs.entity:Remove()
	end

	Legs.entity = nil

	Legs:Setup()
end)

hook.Add("NetworkAppearanceChanged", "nwLegs", function()
	if (IsValid(Legs.entity)) then
		Legs.entity:Remove()
	end

	Legs.entity = nil
	Legs.model = nil
end)

function Legs:Gesture(slot, sequence)
	if (!IsValid(self.entity) or !enabled:GetBool()) then
		return
	end

	if (!self.entity.AddVCDSequenceToGestureSlot) then
		return
	end

	if (isstring(sequence)) then
		sequence = self.entity:LookupSequence(sequence)
	end

	if (sequence and sequence >= 0) then
		self.entity:AddVCDSequenceToGestureSlot(slot, sequence, 0, true)
	end
end

function Legs:GestureActivity(slot, activity)
	if (!IsValid(self.entity) or !enabled:GetBool()) then
		return
	end

	if (self.entity.AnimRestartGesture) then
		self.entity:AnimRestartGesture(slot, activity, true)

		return
	end

	if (!self.entity.AddVCDSequenceToGestureSlot or !self.entity.SelectWeightedSequence) then
		return
	end

	local sequence = self.entity:SelectWeightedSequence(activity)

	if (sequence and sequence >= 0) then
		self.entity:AddVCDSequenceToGestureSlot(slot, sequence, 0, true)
	end
end
