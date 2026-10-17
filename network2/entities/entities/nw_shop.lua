AddCSLuaFile()

-- A trading stand of a licensed business (sh_business.lua): put down from the item «Торговая стойка»
-- inside one's own premises. Over it the sign: the name, the owner, open or closed. E - the window of
-- the stand (the owner manages it, the others buy). The model: the C menu → «Настройки».

ENT.Type = "anim"
ENT.PrintName = "Торговая стойка"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/props_c17/FurnitureTable002a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Title")
	self:NetworkVar("String", 1, "OwnerName")
	self:NetworkVar("String", 2, "Kind")
	self:NetworkVar("Int", 0, "OwnerChar")
	self:NetworkVar("Bool", 0, "Open")
end

if (SERVER) then
	function ENT:Initialize()
		local model = self.nwModel or self.Model

		self:SetModel(util.IsValidModel(model) and model or "models/props_wasteland/controlroom_desk001b.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self.stock = self.stock or {}
		self.till = self.till or 0

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(client)
		if (IsValid(client) and client:IsPlayer() and client:GetCharacterID() != 0) then
			NW.business.OpenShop(client, self)
		end
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_shop", {
			Save = function(entity)
				return {owner = entity:GetOwnerChar(), ownerName = entity:GetOwnerName(), title = entity:GetTitle(),
					kind = entity:GetKind(), open = entity:GetOpen(), stock = entity.stock or {}, till = entity.till or 0,
					model = entity.nwModel}
			end,
			Load = function(entity, data)
				entity:SetOwnerChar(tonumber(data.owner) or 0)
				entity:SetOwnerName(tostring(data.ownerName or ""))
				entity:SetTitle(tostring(data.title or "Лавка"))
				entity:SetKind(tostring(data.kind or "general"))
				entity:SetOpen(data.open == true)
				entity.stock = istable(data.stock) and data.stock or {}
				entity.till = tonumber(data.till) or 0

				if (isstring(data.model) and util.IsValidModel(data.model)) then
					entity.nwModel = data.model
					entity:SetModel(data.model)
					entity:PhysicsInit(SOLID_VPHYSICS)

					local physics = entity:GetPhysicsObject()

					if (IsValid(physics)) then
						physics:EnableMotion(false)
					end
				end
			end
		})
	end)

	return
end

surface.CreateFont("nwShopTitle", {font = "Montserrat SemiBold", size = 44, weight = 600, extended = true, antialias = true})
surface.CreateFont("nwShopText", {font = "Exo 2", size = 30, weight = 500, extended = true, antialias = true})

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local distance = EyePos():DistToSqr(self:GetPos())

	if (distance > 500 * 500) then
		return
	end

	local alpha = math.Clamp((500 - math.sqrt(distance)) / 120, 0, 1)
	local top = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 22))
	local angle = Angle(0, EyeAngles().y - 90, 90)
	local open = self:GetOpen()
	local color = open and Color(130, 214, 120) or Color(232, 96, 80)

	cam.Start3D2D(top, angle, 0.08)
		draw.RoundedBox(10, -250, -66, 500, 124, Color(14, 16, 20, 215 * alpha))
		draw.RoundedBox(2, -250, -66, 500, 4, Color(232, 170, 64, 255 * alpha))
		draw.SimpleText(self:GetTitle(), "nwShopTitle", 0, -26, Color(240, 236, 228, 255 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
		draw.SimpleText((open and "ОТКРЫТО" or "ЗАКРЫТО") .. "  ·  " .. self:GetOwnerName(), "nwShopText", 0, 22,
			ColorAlpha(color, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
