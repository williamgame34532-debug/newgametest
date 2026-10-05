AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Граффити"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.bNoPersist = true

ENT.Scale = 0.22
ENT.Half = 210

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Slogan")
	self:NetworkVar("Int", 1, "Tint")
	self:NetworkVar("String", 0, "OwnerChar")
end

if (SERVER) then
	function ENT:Initialize()

		local model = "models/props_junk/PopCan01a.mdl"

		if (!util.IsValidModel(model)) then
			model = "models/props_junk/garbage_metalcan001a.mdl"
		end

		self:SetModel(model)
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		self:DrawShadow(false)
	end

	function ENT:CanProperty()
		return false
	end

	function ENT:CanTool(client)
		return IsValid(client) and client:IsAdmin()
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end
else
	local function Font()
		if (NETWORK.rebels and NETWORK.rebels.graffitiFont) then
			return NETWORK.rebels.graffitiFont
		end

		return "DermaLarge"
	end

	local function Stroke(x1, y1, x2, y2, width)
		local dx, dy = x2 - x1, y2 - y1
		local length = math.sqrt(dx * dx + dy * dy)

		surface.DrawTexturedRectRotated((x1 + x2) * 0.5, (y1 + y2) * 0.5, length + width * 0.5,
			width, math.deg(math.atan2(-dy, dx)))
	end

	local function Ring(x, y, radius, width, segments)
		local step = 360 / segments
		local chord = 2 * radius * math.sin(math.rad(step * 0.5)) + 2

		for index = 0, segments - 1 do
			local angle = math.rad(index * step)

			surface.DrawTexturedRectRotated(x + math.cos(angle) * radius,
				y - math.sin(angle) * radius, width, chord, math.deg(angle))
		end
	end

	local function Lambda(x, y, radius, color, alpha)
		local width = radius * 0.2

		draw.NoTexture()

		for pass = 1, 2 do
			local offset = pass == 1 and 3 or 0

			if (pass == 1) then
				surface.SetDrawColor(0, 0, 0, 70 * alpha)
			else
				surface.SetDrawColor(color.r, color.g, color.b, 225 * alpha)
			end

			local ox, oy = x + offset, y + offset

			Ring(ox, oy, radius, width * 0.7, 40)
			Stroke(ox - radius * 0.48, oy - radius * 0.58, ox - radius * 0.24, oy - radius * 0.58, width)
			Stroke(ox - radius * 0.28, oy - radius * 0.58, ox + radius * 0.46, oy + radius * 0.56, width)
			Stroke(ox + radius * 0.06, oy - radius * 0.02, ox - radius * 0.44, oy + radius * 0.56, width)
		end
	end

	function ENT:Initialize()
		local half = self.Half * self.Scale

		self:SetRenderBounds(Vector(-half, -half, -8), Vector(half, half, 8))
	end

	function ENT:Draw()
	end

	local LAMBDA_SIZE = 62 / 0.36
	local SLOGAN_WIDTH, SLOGAN_HEIGHT = 360, 90

	local function Art(name)
		if (!NETWORK.util or !NETWORK.util.GetTexture) then
			return
		end

		return NETWORK.util.GetTexture("framework/graffiti/" .. name .. ".png", "smooth mips")
	end

	local function SloganArt(index, text)
		local art = NETWORK.rebels and NETWORK.rebels.graffitiArt
		local language = NETWORK.lang and NETWORK.lang.GetCurrent and NETWORK.lang.GetCurrent()
		local baked = art and language and art[language]

		if (!baked or baked[index] != text) then
			return
		end

		return Art("slogan" .. index .. "_" .. language)
	end

	local function DrawArt(material, x, y, width, height, color, alpha, shadow)
		surface.SetMaterial(material)
		surface.SetDrawColor(0, 0, 0, shadow)
		surface.DrawTexturedRect(x + 3, y + 3, width, height)
		surface.SetDrawColor(color.r, color.g, color.b, alpha)
		surface.DrawTexturedRect(x, y, width, height)
	end

	function ENT:DrawTranslucent()
		local client = LocalPlayer()

		if (!IsValid(client) or client:GetPos():DistToSqr(self:GetPos()) > 2200 * 2200) then
			return
		end

		local rebels = NETWORK.rebels or {}
		local tints = rebels.tints or {Color(226, 128, 52)}
		local slogans = rebels.slogans or {}
		local color = tints[self:GetTint()] or tints[1]
		local key = slogans[self:GetSlogan()]
		local text = key and NETWORK.util.Upper(L(key)) or ""
		local lambda = Art("lambda")
		local sloganArt = text != "" and SloganArt(self:GetSlogan(), text)

		local seed = self:EntIndex()

		cam.Start3D2D(self:GetPos(), self:GetAngles(), self.Scale)
			if (lambda) then
				DrawArt(lambda, -LAMBDA_SIZE * 0.5, -34 - LAMBDA_SIZE * 0.5, LAMBDA_SIZE,
					LAMBDA_SIZE, color, 225, 70)
			else
				Lambda(0, -34, 62, color, 1)
			end

			if (sloganArt) then
				DrawArt(sloganArt, -SLOGAN_WIDTH * 0.5, 80 - SLOGAN_HEIGHT * 0.4, SLOGAN_WIDTH,
					SLOGAN_HEIGHT, color, 230, 80)
				draw.NoTexture()
			elseif (text != "") then
				draw.NoTexture()
				draw.SimpleText(text, Font(), 3, 83, Color(0, 0, 0, 80), TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)
				draw.SimpleText(text, Font(), 0, 80, ColorAlpha(color, 230), TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)

				draw.NoTexture()
				surface.SetDrawColor(color.r, color.g, color.b, 150)

				for index = 1, 5 do
					local x = ((seed * 37 + index * 53) % 180) - 90
					local length = 10 + (seed * 13 + index * 29) % 26

					surface.DrawRect(x, 96, 3, length)
				end
			end
		cam.End3D2D()
	end
end
