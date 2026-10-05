AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Бочка с огнём"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Models = {
	"models/props_c17/oildrum001.mdl",
	"models/props_junk/metalbucket01a.mdl",
	"models/props_wasteland/controlroom_filecabinet001a.mdl"
}

ENT.fuelPerItem = 240
ENT.fuelMax = 1800

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Lit")
	self:NetworkVar("Float", 0, "Fuel")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_campfire")

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = self.Models[1]

		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
		end

		if (self:GetFuel() <= 0) then
			self:SetFuel(self.fuelPerItem * 2)
		end
	end

	function ENT:SetLitState(bState)
		if (bState and self:GetFuel() <= 0) then
			return false
		end

		self:SetLit(bState and true or false)

		if (bState) then
			self:EmitSound("ambient/fire/ignite.wav", 70, 100)
			self:StartFireSound("ambient/fire/fire_small_loop1.wav")
		else
			self:EmitSound("ambient/fire/mtov_flame2.wav", 60, 90)
			self:StopFireSound()
		end

		return true
	end

	function ENT:StartFireSound(path)
		self:StopFireSound()

		self.loop = CreateSound(self, path)
		self.loop:SetSoundLevel(72)
		self.loop:Play()
	end

	function ENT:StopFireSound()
		if (self.loop) then
			self.loop:Stop()

			self.loop = nil
		end
	end

	function ENT:OnRemove()
		self:StopFireSound()
	end

	function ENT:Think()
		if (self:GetLit()) then
			local fuel = self:GetFuel() - 1

			self:SetFuel(math.max(fuel, 0))

			if (fuel <= 0) then
				self:SetLitState(false)
			end
		end

		self:NextThink(CurTime() + 1)

		return true
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
			return
		end

		if ((self.nwNextUse or 0) > CurTime()) then
			return
		end

		self.nwNextUse = CurTime() + 0.6

		if (NETWORK.campfire and NETWORK.campfire.TryFuel(client, self)) then
			return
		end

		if (self:GetLit()) then
			self:SetLitState(false)

			return NETWORK.notice.Send(client, "campfireOut", "info")
		end

		if (!self:SetLitState(true)) then
			return NETWORK.notice.Send(client, "campfireNoFuel", "warn")
		end

		NETWORK.notice.Send(client, "campfireLit", "good")
	end
end

if (CLIENT) then
	local fire = Material("particle/fire")

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
		if (!self:GetLit()) then
			return
		end

		local position = self:LocalToWorld(self:OBBCenter()) +
			Vector(0, 0, self:OBBMaxs().z * 0.55)
		local time = CurTime()

		render.SetMaterial(fire)

		for index = 1, 3 do
			local phase = time * (2.2 + index * 0.35) + index
			local size = 22 + math.sin(phase) * 6 + index * 4
			local offset = Vector(math.sin(phase * 0.7) * 3,
				math.cos(phase * 0.6) * 3, index * 5 + math.sin(phase) * 2)

			render.DrawSprite(position + offset, size, size * 1.4,
				Color(255, 150 + index * 18, 60, 190))
		end

		local light = DynamicLight(self:EntIndex())

		if (light) then
			light.Pos = position
			light.r = 255
			light.g = 150
			light.b = 70
			light.Brightness = 2.4 + math.sin(time * 6) * 0.3
			light.Decay = 700
			light.Size = 420
			light.DieTime = time + 0.2
		end
	end
end
