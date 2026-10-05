AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Шкафчик"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.Range = 110

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Busy")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_locker")
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p = 0
		angles.r = 0

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(angles:SnapTo("y", 45))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = "models/props_c17/Lockers001a.mdl"

		if (!util.IsValidModel(model)) then
			model = "models/props_c17/furnitureDrawer001a.mdl"
		end

		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.nextUse = 0
	end

	function ENT:Use(client)
		if (self.nextUse > CurTime() or !IsValid(client) or !client:HasCharacter()) then
			return
		end

		self.nextUse = CurTime() + 1

		if (client:GetPos():Distance(self:GetPos()) > self.Range) then
			return
		end

		client.nwLocker = self
		client.nwLockerUntil = CurTime() + 120

		self:EmitSound("items/ammocrate_open.wav", 65, 105)

		net.Start("nwBodygroupEdit")
			NETWORK.util.WriteTable({bOpen = true})
		net.Send(client)
	end

	hook.Add("Think", "nwLockerRange", function()
		for _, client in ipairs(player.GetAll()) do
			local locker = client.nwLocker

			if (!locker) then
				continue
			end

			if (!IsValid(locker) or !client:Alive() or
				client:GetPos():Distance(locker:GetPos()) > locker.Range) then
				client.nwLocker = nil
				client.nwLockerUntil = nil
			end
		end
	end)
else
	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (!IsValid(client) or client:GetPos():DistToSqr(self:GetPos()) > 200 * 200) then
			return
		end

		local theme = NETWORK.theme
		local mins, maxs = self:GetRotatedAABB(self:OBBMins(), self:OBBMaxs())
		local position = self:GetPos() + Vector(0, 0, maxs.z + 8)
		local direction = position - EyePos()

		direction.z = 0

		if (direction:LengthSqr() < 0.01) then
			return
		end

		local angles = direction:Angle()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(position, angles, 0.1)
			local text = NETWORK.util.Upper(L("lockerTitle"))
			local hint = L("lockerHint")

			surface.SetFont("nwChat")

			local width = math.max(surface.GetTextSize(text), 150) + 40

			NETWORK.label.Frame(-width * 0.5, -26, width, 52,
				theme.accent, 1)

			draw.SimpleText(text, "nwChat", 0, -10, theme.text, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(hint, "nwHudSmall", 0, 12, theme.textDim, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
