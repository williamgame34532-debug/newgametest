AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Коробка снабжения"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.PhysgunDisabled = true

ENT.bNoPersist = true

ENT.Contents = {"factory_water", "factory_dryration", "factory_dryration",
	"factory_components"}

if (SERVER) then
	util.AddNetworkString("nwFactoryUnpack")
	util.AddNetworkString("nwFactoryTake")

	function ENT:Initialize()
		local model = "models/props_junk/cardboard_box004a.mdl"

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:SetMass(8)
		end

		self.left = table.Copy(self.Contents)
	end

	function ENT:PhysgunPickup()
		return false
	end

	function ENT:OnTakeDamage()
		return 0
	end

	NETWORK.factory = NETWORK.factory or {}

	function NETWORK.factory.OpenBox(client, entity)
		entity.left = entity.left or
			{"factory_water", "factory_dryration", "factory_dryration",
			"factory_components"}
		entity.opener = client

		net.Start("nwFactoryUnpack")
			net.WriteEntity(entity)
			net.WriteUInt(#entity.left, 4)
		net.Send(client)
	end

	function ENT:OpenFor(client)
		self.opener = client

		net.Start("nwFactoryUnpack")
			net.WriteEntity(self)
			net.WriteUInt(#self.left, 4)
		net.Send(client)
	end

	net.Receive("nwFactoryTake", function(_, client)
		local box = net.ReadEntity()
		local bValid = IsValid(box) and (box:GetClass() == "nw_factory_box" or
			box:GetClass() == "nw_item")

		if (!bValid or box.opener != client or
			client:GetPos():Distance(box:GetPos()) > 140) then
			return
		end

		if ((box.nextTake or 0) > CurTime()) then
			return
		end

		if (NETWORK.schedule and NETWORK.schedule.IsFactoryShift and
			!NETWORK.schedule.IsFactoryShift()) then
			return NETWORK.chat.Notice(client, "factoryClosedShift")
		end

		box.nextTake = CurTime() + 0.35

		box.left = box.left or table.Copy(box.Contents)

		local name = table.remove(box.left, 1)

		if (!name) then
			return
		end

		box:EmitSound("framework/inv/inv_move" .. math.random(3) .. ".wav",
			55, math.random(96, 104))

		if (true) then
			local top = box:GetPos() + Vector(0, 0, box:OBBMaxs().z + 10)
			local scatter = Angle(0, math.Rand(0, 360), 0):Forward() *
				math.Rand(6, 12)

			NETWORK.item.Spawn(name, top + scatter)

			box:EmitSound("framework/inv/inv_move" .. math.random(3) .. ".wav",
				55, math.random(96, 104))

			if (#box.left == 0) then
				box:EmitSound("physics/cardboard/cardboard_box_break1.wav", 60)
				box:Remove()
			end

			return
		end

		local part = ents.Create("nw_factory_part")

		if (IsValid(part)) then

			local top = box:GetPos() + Vector(0, 0, box:OBBMaxs().z + 10)
			local scatter = Angle(0, math.Rand(0, 360), 0):Forward() *
				math.Rand(4, 10)

			part:SetPos(top + scatter)
			part:Spawn()
			part:Activate()
			part:Setup(name)

			local physics = part:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:Wake()
				physics:SetVelocity(scatter * 6 + Vector(0, 0, 40))
			end
		end

		if (#box.left == 0) then
			box:EmitSound("physics/cardboard/cardboard_box_break1.wav", 60)
			box:Remove()
		end
	end)
else
	function ENT:Draw()
		self:DrawModel()
	end

	local SHADE = Color(0, 0, 0, 170)

	net.Receive("nwFactoryUnpack", function()
		local box = net.ReadEntity()
		local count = net.ReadUInt(4)

		if (IsValid(NETWORK.factoryUnpack)) then
			NETWORK.factoryUnpack:Remove()
		end

		local Sc = NETWORK.util.Scale
		local theme = NETWORK.theme

		local panel = vgui.Create("DPanel")
		panel:SetSize(ScrW(), ScrH())
		panel:MakePopup()
		panel.left = count
		panel.total = math.max(count, 1)
		panel.born = RealTime()

		NETWORK.factoryUnpack = panel

		panel.Paint = function(_, width, height)
			local S = NETWORK.style
			local accent = theme.combine
			local appear = math.Clamp((RealTime() - panel.born) / 0.2, 0, 1)

			surface.SetDrawColor(SHADE.r, SHADE.g, SHADE.b, SHADE.a * appear)
			surface.DrawRect(0, 0, width, height)

			local cardWidth = Sc(460)
			local cardHeight = Sc(118)
			local cardX = math.Round((width - cardWidth) * 0.5)
			local cardY = Sc(56)
			local pad = Sc(20)

			S.Card(cardX, cardY, cardWidth, cardHeight, appear,
				{radius = S.Radius("panel"), accent = accent, panel = panel})

			draw.SimpleText(NETWORK.util.Upper(L("factoryUnpackTitle")), "nwInvTitle",
				cardX + pad, cardY + Sc(30), ColorAlpha(theme.text, 250 * appear),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			S.Chip(L("factoryUnpackLeft", panel.left), "nwInvKey", cardX + cardWidth - pad,
				cardY + Sc(21), panel.left > 0 and accent or theme.positive, appear,
				{alignRight = true})

			draw.SimpleText(L("factoryUnpackNext"), "nwInvBody", cardX + pad, cardY + Sc(62),
				ColorAlpha(theme.textDim, 240 * appear), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local barWidth = cardWidth - pad * 2
			local barHeight = math.max(Sc(4), 3)
			local barY = cardY + cardHeight - pad - barHeight + Sc(4)
			local fraction = 1 - panel.left / panel.total

			draw.RoundedBox(math.floor(barHeight * 0.5), cardX + pad, barY, barWidth, barHeight,
				ColorAlpha(accent, 34 * appear))
			draw.RoundedBox(math.floor(barHeight * 0.5), cardX + pad, barY,
				math.max(math.Round(barWidth * fraction), barHeight), barHeight,
				ColorAlpha(panel.left > 0 and accent or theme.positive, 240 * appear))

			local controls = L("factoryUnpackControls")

			surface.SetFont("nwInvBody")

			local controlsWidth = surface.GetTextSize(controls) + Sc(40)
			local pillHeight = Sc(40)
			local pillX = math.Round((width - controlsWidth) * 0.5)
			local pillY = height - Sc(92)

			S.Card(pillX, pillY, controlsWidth, pillHeight, appear,
				{radius = math.floor(pillHeight * 0.5), accent = false, blur = false})

			draw.SimpleText(controls, "nwInvBody", width * 0.5, pillY + math.Round(pillHeight * 0.5),
				ColorAlpha(theme.textDim, 240 * appear), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local model = panel:Add("DModelPanel")
		model:SetSize(Sc(520), Sc(520))
		model:SetPos(ScrW() * 0.5 - Sc(260), ScrH() * 0.5 - Sc(260))
		model:SetModel("models/props_junk/cardboard_box004a.mdl")
		model:SetFOV(34)
		model:SetCamPos(Vector(46, 46, 32))
		model:SetLookAt(Vector(0, 0, 6))

		model.LayoutEntity = function(_, entity)
			entity:SetAngles(Angle(0, model.rotation or 30, 0))
		end

		model.OnMousePressed = function(_, code)
			if (code == MOUSE_RIGHT) then
				panel:Remove()

				return
			end

			if (code == MOUSE_LEFT) then
				model.dragging = true
				model.dragX = gui.MouseX()
				model.dragStart = model.rotation or 30
				model.moved = false
			end
		end

		model.OnMouseReleased = function(_, code)
			if (code != MOUSE_LEFT) then
				return
			end

			model.dragging = false

			if (!model.moved and IsValid(box)) then
				net.Start("nwFactoryTake")
					net.WriteEntity(box)
				net.SendToServer()

				panel.left = math.max(0, panel.left - 1)

				if (panel.left == 0) then
					timer.Simple(0.3, function()
						if (IsValid(panel)) then
							panel:Remove()
						end
					end)
				end
			end
		end

		model.Think = function()
			if (model.dragging) then
				local delta = gui.MouseX() - model.dragX

				if (math.abs(delta) > 4) then
					model.moved = true
				end

				model.rotation = model.dragStart + delta * 0.6
			end

			if (!IsValid(box) or
				LocalPlayer():GetPos():Distance(box:GetPos()) > 150) then
				panel:Remove()

				return
			end

			if (gui.IsGameUIVisible()) then
				gui.HideGameUI()
				panel:Remove()
			end
		end

		panel.OnMousePressed = function(_, code)
			if (code == MOUSE_RIGHT) then
				panel:Remove()
			end
		end

		panel.OnKeyCodePressed = function(_, key)
			if (key == KEY_ESCAPE) then
				panel:Remove()
			end
		end
	end)
end
