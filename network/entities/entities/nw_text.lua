AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Табло"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Text")
	self:NetworkVar("Int", 0, "TextSize")
	self:NetworkVar("Vector", 0, "TextColor")
end

if (SERVER) then

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_text")
		local angles = trace.HitNormal:Angle()

		angles:RotateAroundAxis(angles:Forward(), client:EyeAngles().y + 90)

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/hunter/plates/plate1x1.mdl")

		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:SetNotSolid(true)
		self:DrawShadow(false)
		self:SetRenderMode(RENDERMODE_TRANSALPHA)
		self:SetColor(Color(255, 255, 255, 0))

		if (self:GetText() == "") then
			self:SetText("СЕКТОР 2")
		end

		if (self:GetTextSize() <= 0) then
			self:SetTextSize(30)
		end

		if (self:GetTextColor():Length() <= 0) then
			self:SetTextColor(Vector(0.35, 0.84, 1))
		end

	end
else

	function ENT:Draw()
		self:DrawText()
	end

	function ENT:DrawTranslucent()
		self:DrawText()
	end

	function ENT:DrawText()
		local text = self:GetText()

		if (text == "") then
			return
		end

		self.nwSeen = self.nwSeen or CurTime()

		local reveal = math.Clamp((CurTime() - self.nwSeen) / 0.5, 0, 1)

		reveal = 1 - (1 - reveal) * (1 - reveal)

		local position = self:GetPos() + self:GetUp() * 1
		local angles = self:GetAngles()

		angles:RotateAroundAxis(angles:Right(), 90)
		angles:RotateAroundAxis(angles:Up(), 90)

		local color = self:GetTextColor()
		local scale = math.max(self:GetTextSize(), 4) * 0.01 * (0.85 + reveal * 0.15)
		local tint = Color(color.x * 255, color.y * 255, color.z * 255)
		local pulse = 0.85 + math.sin(CurTime() * 2) * 0.15

		cam.Start3D2D(position, angles, scale)
			local lines = string.Explode("\\n", text)
			local y = -(#lines - 1) * 26

			for i = 1, #lines do
				draw.SimpleText(lines[i], "nwBrand", 2, y + 2,
					Color(0, 0, 0, 180 * reveal), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(lines[i], "nwBrand", 0, y,
					ColorAlpha(tint, 255 * pulse * reveal), TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)

				y = y + 52
			end
		cam.End3D2D()
	end
end
