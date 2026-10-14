-- Legs: in first person the player sees their own legs and body below the view (after the Helix
-- "Legs" plugin by Valkyrie & blackops7799, public domain - the same behaviour, made for Network).
-- A copy of the player's model (skin, bodygroups, materials, colour) plays the player's own
-- sequence and pose parameters; the head, arms and upper spine are hidden, and everything above
-- the eyes is clipped away. Drawn in first person only: not in third person, not in a pose seen
-- through the eyes, not when the player is hidden (unconscious), dead or watching something else.
-- Settings (Q → Настройки → Камера): nw_legs - on / off, nw_legs_vehicle - also in vehicles.
-- Other systems can hide them: hook ShouldDisableLegs returning true, or client.ShouldDisableLegs.

local enabled = CreateClientConVar("nw_legs", "1", true, false, "Ноги от первого лица")
local inVehicle = CreateClientConVar("nw_legs_vehicle", "1", true, false, "Ноги в транспорте")

NW.legs = NW.legs or {}

local Legs = NW.legs

Legs.PlaybackRate = 1
Legs.Sequence = nil
Legs.Velocity = 0
Legs.BonesToRemove = {}
Legs.BreathScale = 0.5
Legs.NextBreath = 0
Legs.RenderAngle = nil
Legs.BiaisAngles = nil
Legs.RadAngle = nil
Legs.RenderPos = nil
Legs.RenderColor = {}
Legs.ClipVector = vector_up * -1
Legs.ForwardOffset = -24

local REMOVE = {
	"ValveBiped.Bip01_Head1",
	"ValveBiped.Bip01_L_Hand",
	"ValveBiped.Bip01_L_Forearm",
	"ValveBiped.Bip01_L_Upperarm",
	"ValveBiped.Bip01_L_Clavicle",
	"ValveBiped.Bip01_R_Hand",
	"ValveBiped.Bip01_R_Forearm",
	"ValveBiped.Bip01_R_Upperarm",
	"ValveBiped.Bip01_R_Clavicle",
	"ValveBiped.Bip01_L_Finger4",
	"ValveBiped.Bip01_L_Finger41",
	"ValveBiped.Bip01_L_Finger42",
	"ValveBiped.Bip01_L_Finger3",
	"ValveBiped.Bip01_L_Finger31",
	"ValveBiped.Bip01_L_Finger32",
	"ValveBiped.Bip01_L_Finger2",
	"ValveBiped.Bip01_L_Finger21",
	"ValveBiped.Bip01_L_Finger22",
	"ValveBiped.Bip01_L_Finger1",
	"ValveBiped.Bip01_L_Finger11",
	"ValveBiped.Bip01_L_Finger12",
	"ValveBiped.Bip01_L_Finger0",
	"ValveBiped.Bip01_L_Finger01",
	"ValveBiped.Bip01_L_Finger02",
	"ValveBiped.Bip01_R_Finger4",
	"ValveBiped.Bip01_R_Finger41",
	"ValveBiped.Bip01_R_Finger42",
	"ValveBiped.Bip01_R_Finger3",
	"ValveBiped.Bip01_R_Finger31",
	"ValveBiped.Bip01_R_Finger32",
	"ValveBiped.Bip01_R_Finger2",
	"ValveBiped.Bip01_R_Finger21",
	"ValveBiped.Bip01_R_Finger22",
	"ValveBiped.Bip01_R_Finger1",
	"ValveBiped.Bip01_R_Finger11",
	"ValveBiped.Bip01_R_Finger12",
	"ValveBiped.Bip01_R_Finger0",
	"ValveBiped.Bip01_R_Finger01",
	"ValveBiped.Bip01_R_Finger02",
	"ValveBiped.Bip01_Spine4",
	"ValveBiped.Bip01_Spine2"
}

function Legs:CheckDrawVehicle()
	if (LocalPlayer():InVehicle()) then
		if (enabled:GetBool() and !inVehicle:GetBool()) then
			return true
		end

		return false
	end
end

local function ShouldDrawLegs()
	if (hook.Run("ShouldDisableLegs") == true) then
		return false
	end

	if (enabled:GetBool()) then
		local client = LocalPlayer()

		return IsValid(Legs.LegEnt) and
			client:Alive() and
			!Legs:CheckDrawVehicle() and GetViewEntity() == client and
			!client:ShouldDrawLocalPlayer() and !IsValid(client:GetObserverTarget()) and
			!client:GetNoDraw() and !client.ShouldDisableLegs and
			!client:GetNW2Bool("nwKnocked", false) and !client:GetNW2Bool("nwInMenu", false)
	end
end

-- what the copy must match: the model and everything that changes its look
local function Signature(client)
	local parts = {client:GetModel(), client:GetSkin(), client:GetMaterial(), client:GetModelScale()}

	for _, group in ipairs(client:GetBodyGroups() or {}) do
		parts[#parts + 1] = client:GetBodygroup(group.id)
	end

	for index = 0, #(client:GetMaterials() or {}) - 1 do
		parts[#parts + 1] = client:GetSubMaterial(index)
	end

	return table.concat(parts, "|")
end

function Legs:Setup(model)
	local client = LocalPlayer()

	model = model or client:GetModel()

	if (!model or model == "") then
		return
	end

	if (!IsValid(self.LegEnt)) then
		self.LegEnt = ClientsideModel(model, RENDERGROUP_OPAQUE)

		if (!IsValid(self.LegEnt)) then
			return
		end
	else
		self.LegEnt:SetModel(model)
	end

	self.LegEnt:SetNoDraw(true)

	for _, v in pairs(client:GetBodyGroups() or {}) do
		self.LegEnt:SetBodygroup(v.id, client:GetBodygroup(v.id))
	end

	for k, _ in ipairs(client:GetMaterials() or {}) do
		self.LegEnt:SetSubMaterial(k - 1, client:GetSubMaterial(k - 1))
	end

	self.LegEnt:SetSkin(client:GetSkin())
	self.LegEnt:SetMaterial(client:GetMaterial())
	self.LegEnt:SetColor(client:GetColor())
	self.LegEnt:SetModelScale(client:GetModelScale(), 0)
	self.LegEnt.GetPlayerColor = function()
		return LocalPlayer():GetPlayerColor()
	end

	self.LegEnt.Anim = nil
	self.PlaybackRate = 1
	self.Sequence = nil
	self.Velocity = 0
	self.BonesToRemove = {}
	self.LegEnt.LastTick = 0
	self.Signature = Signature(client)

	self:Update(0)
	self:FixBones()
end

function Legs:Think(maxSeqGroundSpeed)
	if (!LocalPlayer():Alive()) then
		self:Setup()

		return
	end

	self:Update(maxSeqGroundSpeed)
end

function Legs:Update(maxSeqGroundSpeed)
	if (!IsValid(self.LegEnt)) then
		return
	end

	local client = LocalPlayer()

	self.Velocity = client:GetVelocity():Length2D()
	self.PlaybackRate = 1

	if (self.Velocity > 0.5) then
		if (maxSeqGroundSpeed < 0.001) then
			self.PlaybackRate = 0.01
		else
			self.PlaybackRate = math.Clamp(self.Velocity / maxSeqGroundSpeed, 0.01, 10)
		end
	end

	self.LegEnt:SetPlaybackRate(self.PlaybackRate)

	self.Sequence = client:GetSequence()

	if (self.LegEnt.Anim != self.Sequence) then
		self.LegEnt.Anim = self.Sequence
		self.LegEnt:ResetSequence(self.Sequence)
	end

	self.LegEnt:FrameAdvance(CurTime() - self.LegEnt.LastTick)
	self.LegEnt.LastTick = CurTime()

	-- breathing: faster when the character is out of breath (sh_needs.lua stamina)
	local stamina = client.GetStamina and client:GetStamina()

	self.BreathScale = stamina and math.Clamp(math.floor((1 - stamina / 100) * 5 * 10) / 10, 0.5, 5) or 0.5

	if (self.NextBreath <= CurTime()) then
		self.NextBreath = CurTime() + 1.95 / self.BreathScale
		self.LegEnt:SetPoseParameter("breathing", self.BreathScale)
	end

	self.LegEnt:SetPoseParameter("move_x", (client:GetPoseParameter("move_x") * 2) - 1)
	self.LegEnt:SetPoseParameter("move_y", (client:GetPoseParameter("move_y") * 2) - 1)
	self.LegEnt:SetPoseParameter("move_yaw", (client:GetPoseParameter("move_yaw") * 360) - 180)
	self.LegEnt:SetPoseParameter("body_yaw", (client:GetPoseParameter("body_yaw") * 180) - 90)
	self.LegEnt:SetPoseParameter("spine_yaw", (client:GetPoseParameter("spine_yaw") * 180) - 90)

	if (client:InVehicle()) then
		self.LegEnt:SetPoseParameter("vehicle_steer", (client:GetVehicle():GetPoseParameter("vehicle_steer") * 2) - 1)
	end
end

function Legs:DoFinalRender()
	cam.Start3D(EyePos(), EyeAngles())
		if (ShouldDrawLegs()) then
			local client = LocalPlayer()

			self.RenderPos = client:GetPos()

			if (client:InVehicle()) then
				self.RenderAngle = client:GetVehicle():GetAngles()
				self.RenderAngle:RotateAroundAxis(self.RenderAngle:Up(), 90)
			else
				self.BiaisAngles = client:EyeAngles()
				self.RenderAngle = Angle(0, self.BiaisAngles.y, 0)
				self.RadAngle = math.rad(self.BiaisAngles.y)
				self.ForwardOffset = -22
				self.RenderPos.x = self.RenderPos.x + math.cos(self.RadAngle) * self.ForwardOffset
				self.RenderPos.y = self.RenderPos.y + math.sin(self.RadAngle) * self.ForwardOffset

				if (client:GetGroundEntity() == NULL) then
					self.RenderPos.z = self.RenderPos.z + 8

					if (client:KeyDown(IN_DUCK)) then
						self.RenderPos.z = self.RenderPos.z - 28
					end
				end
			end

			self.RenderColor = client:GetColor()

			local bEnabled = render.EnableClipping(true)
				render.PushCustomClipPlane(self.ClipVector, self.ClipVector:Dot(EyePos()))
					render.SetColorModulation(self.RenderColor.r / 255, self.RenderColor.g / 255, self.RenderColor.b / 255)
						render.SetBlend(self.RenderColor.a / 255)
							self.LegEnt:SetRenderOrigin(self.RenderPos)
							self.LegEnt:SetRenderAngles(self.RenderAngle)
							self.LegEnt:SetupBones()
							self.LegEnt:DrawModel()
							self.LegEnt:SetRenderOrigin()
							self.LegEnt:SetRenderAngles()
						render.SetBlend(1)
					render.SetColorModulation(1, 1, 1)
				render.PopCustomClipPlane()
			render.EnableClipping(bEnabled)
		end
	cam.End3D()
end

function Legs:FixBones()
	if (!IsValid(self.LegEnt)) then
		return
	end

	for i = 0, self.LegEnt:GetBoneCount() do
		self.LegEnt:ManipulateBoneScale(i, Vector(1, 1, 1))
		self.LegEnt:ManipulateBonePosition(i, vector_origin)
	end

	self.BonesToRemove = LocalPlayer():InVehicle() and {"ValveBiped.Bip01_Head1"} or REMOVE

	for _, v in pairs(self.BonesToRemove) do
		local bone = self.LegEnt:LookupBone(v)

		if (bone) then
			self.LegEnt:ManipulateBoneScale(bone, vector_origin)

			if (!LocalPlayer():InVehicle()) then
				self.LegEnt:ManipulateBonePosition(bone, Vector(0, -100, 0))
				self.LegEnt:ManipulateBoneAngles(bone, angle_zero)
			end
		end
	end
end

-- -------------------------------------------------------------------- hooks --
-- the weapon changed (Helix: PlayerWeaponChanged), getting in / out of a vehicle
local lastWeapon, lastVehicle

hook.Add("Think", "nwLegsWatch", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !IsValid(Legs.LegEnt)) then
		return
	end

	local weapon = client:GetActiveWeapon()
	local vehicle = client:InVehicle()

	if (weapon != lastWeapon or vehicle != lastVehicle) then
		lastWeapon, lastVehicle = weapon, vehicle
		Legs:FixBones()
	end
end)

hook.Add("UpdateAnimation", "nwLegs", function(client, velocity, maxSeqGroundSpeed)
	if (client != LocalPlayer()) then
		return
	end

	-- the model or its look changed (Helix: PlayerModelChanged)
	if (!IsValid(Legs.LegEnt) or Legs.Signature != Signature(client)) then
		Legs:Setup()
	else
		Legs:Think(maxSeqGroundSpeed)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwLegs", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	local client = LocalPlayer()

	if (IsValid(client) and !client:InVehicle()) then
		Legs:DoFinalRender()
	end
end)

hook.Add("RenderScreenspaceEffects", "nwLegs", function()
	local client = LocalPlayer()

	if (IsValid(client) and client:InVehicle()) then
		Legs:DoFinalRender()
	end
end)
