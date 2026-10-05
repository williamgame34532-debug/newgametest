AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "LED-панель"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Text")
	self:NetworkVar("String", 1, "Subtext")
	self:NetworkVar("Int", 0, "Style")
	self:NetworkVar("Float", 0, "TextScale")
end

if (SERVER) then

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_led")
		local angles = trace.HitNormal:Angle()

		angles:RotateAroundAxis(angles:Forward(), client:EyeAngles().y + 90)

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		self:SetRenderMode(RENDERMODE_TRANSALPHA)
		self:SetColor(Color(255, 255, 255, 0))
		self:DrawShadow(false)

		if (self:GetText() == "") then
			self:SetText("NETWORK")
		end

		if (self:GetTextScale() <= 0) then
			self:SetTextScale(1)
		end

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
		end
	end
else
	local COLORS = {
		Color(120, 220, 255),
		Color(255, 190, 70),
		Color(255, 90, 80),
		Color(120, 230, 150)
	}

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

		local client = LocalPlayer()

		if (!IsValid(client) or
			client:GetPos():DistToSqr(self:GetPos()) > 1600 * 1600) then
			return
		end

		local angles = self:GetAngles()

		angles:RotateAroundAxis(angles:Up(), 90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local color = COLORS[math.Clamp(self:GetStyle() + 1, 1, #COLORS)]
		local scale = 0.16 * math.Clamp(self:GetTextScale(), 0.2, 4)
		local sub = self:GetSubtext()

		local flicker = 0.94 + math.sin(CurTime() * 3.2 + self:EntIndex()) * 0.06

		surface.SetFont("nwBrand")

		local width = surface.GetTextSize(text)
		local height = 74

		if (sub != "") then
			surface.SetFont("nwSchema")

			width = math.max(width, surface.GetTextSize(sub))
			height = 122
		end

		width = width + 60

		cam.Start3D2D(self:GetPos() + self:GetUp() * 1.2, angles, scale)
			local x = -width * 0.5
			local y = -height * 0.5

			surface.SetDrawColor(6, 9, 13, 190)
			surface.DrawRect(x, y, width, height)

			surface.SetDrawColor(color.r, color.g, color.b, 30 * flicker)
			surface.DrawRect(x, y, width, height)

			surface.SetDrawColor(color.r, color.g, color.b, 200 * flicker)
			surface.DrawRect(x, y, width, 2)
			surface.DrawRect(x, y + height - 2, width, 2)

			local textY = sub != "" and -18 or 0

			draw.SimpleText(text, "nwBrand", 0, textY,
				ColorAlpha(color, 40 * flicker), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(text, "nwBrand", 0, textY,
				ColorAlpha(color, 255 * flicker), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			if (sub != "") then
				draw.SimpleText(sub, "nwSchema", 0, 32,
					ColorAlpha(color, 210 * flicker), TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)
			end
		cam.End3D2D()
	end
end
