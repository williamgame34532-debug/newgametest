AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Пункт утилизации"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.Models = {
	"models/props_junk/TrashDumpster01a.mdl",
	"models/props_junk/TrashDumpster02.mdl",
	"models/props_c17/FurnitureDresser001a.mdl"
}

function ENT:PickModel()
	for _, path in ipairs(self.Models) do
		if (util.IsValidModel(path)) then
			return path
		end
	end

	return self.Models[1]
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_trash_dump")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:EnforceModel()
		local want = self:PickModel()

		if (string.lower(self:GetModel() or "") == string.lower(want)) then
			return
		end

		self:SetModel(want)
		self:SetSkin(0)
		self:SetBodyGroups("")
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Initialize()
		self:SetModel(self:PickModel())
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		timer.Simple(0, function()
			if (IsValid(self)) then
				self:EnforceModel()
			end
		end)

		timer.Simple(1, function()
			if (IsValid(self)) then
				self:EnforceModel()
			end
		end)
	end

	function ENT:Think()
		self:EnforceModel()
		self:NextThink(CurTime() + 5)

		return true
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		if ((activator.nwNextRecycle or 0) > CurTime()) then
			return
		end

		activator.nwNextRecycle = CurTime() + 1

		NETWORK.trash.Recycle(activator, self)
	end

	return
end

local FALLBACKS = {
	"models/props_junk/TrashDumpster01a.mdl",
	"models/props_c17/oildrum001.mdl"
}

local modelOK = {}

local function ModelOK(model)
	if (!isstring(model) or model == "") then
		return false
	end

	local cached = modelOK[model]

	if (cached == nil) then
		local lower = string.lower(model)

		cached = !string.find(lower, "error", 1, true) and util.IsValidModel(model) and
			(file.Exists(model, "GAME") or file.Exists(lower, "GAME"))

		modelOK[model] = cached == true
	end

	return cached
end

function ENT:GetFallback()
	if (IsValid(self.nwFallback)) then
		return self.nwFallback
	end

	if (self.nwFallbackFailed) then
		return nil
	end

	for _, path in ipairs(FALLBACKS) do
		if (util.IsValidModel(path)) then
			local prop = ClientsideModel(path, RENDERGROUP_OPAQUE)

			if (IsValid(prop)) then
				prop:SetNoDraw(true)
				self.nwFallback = prop

				local mins, maxs = prop:GetRenderBounds()

				if (mins and maxs) then
					self:SetRenderBounds(mins, maxs)
				end

				return prop
			end
		end
	end

	self.nwFallbackFailed = true

	return nil
end

function ENT:OnRemove()
	if (IsValid(self.nwFallback)) then
		self.nwFallback:Remove()
	end

	self.nwFallback = nil
end

function ENT:Draw()
	if (ModelOK(self:GetModel())) then
		if (IsValid(self.nwFallback)) then
			self.nwFallback:Remove()
			self.nwFallback = nil
		end

		self:DrawModel()
	else
		local prop = self:GetFallback()

		if (IsValid(prop)) then
			prop:SetPos(self:GetPos())
			prop:SetAngles(self:GetAngles())
			prop:SetupBones()
			prop:DrawModel()
		end
	end

	local client = LocalPlayer()

	if (client:GetPos():DistToSqr(self:GetPos()) > 400 * 400) then
		return
	end

	local position = self:GetPos() + self:OBBCenter() + Vector(0, 0, self:OBBMaxs().z + 6)
	local angles = (client:EyePos() - position):Angle()

	angles:RotateAroundAxis(angles:Up(), -90)
	angles:RotateAroundAxis(angles:Forward(), 90)

	cam.Start3D2D(position, angles, 0.08)
		NETWORK.label.Frame(-120, -20, 240, 40, NETWORK.theme.combine, 1)
		draw.SimpleText(NETWORK.util.Upper(L("trashDumpTitle")), "nwInvKey", 0, -8,
			NETWORK.theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(L("trashDumpHint"), "nwInvKey", 0, 10, NETWORK.theme.combine,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
