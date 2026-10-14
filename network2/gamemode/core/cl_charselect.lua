-- Character selection over the main menu camera: one dark glass card per character slot (the
-- model in a dim light, the name top left, the faction under it), an empty slot creates a new
-- character. Under the cards: "Выбрать" and "Удалить" (asks once more), "Назад" bottom left.
-- "Выбрать": a sound, the screen goes black and the player enters the world as that character,
-- on the spot where that character was last.

NW.charSelect = NW.charSelect or {}

local CS = NW.charSelect
local U = NW.ui
local C = NW.char

C.list = C.list or {}

-- ----------------------------------------------------------------- network --
net.Receive("nwCharList", function()
	C.list = {}

	for _ = 1, net.ReadUInt(4) do
		table.insert(C.list, {
			id = net.ReadUInt(32),
			name = net.ReadString(),
			faction = net.ReadString(),
			gender = net.ReadString(),
			model = net.ReadString(),
			skin = net.ReadUInt(8),
			height = net.ReadFloat()
		})
	end

	if (IsValid(CS.frame)) then
		CS.Build()
	end
end)

net.Receive("nwCharResult", function()
	local ok, text = net.ReadBool(), net.ReadString()

	if (NW.charCreate.OnResult) then
		NW.charCreate.OnResult(ok, text)
	end

	if (!ok and IsValid(CS.frame)) then
		CS.error = text
	end
end)

-- ------------------------------------------------------------------ layout --
local function Lerp2(current, target, speed)
	return Lerp(math.Clamp(FrameTime() * speed, 0, 1), current, target)
end

local function Button(parent, text, icon, callback)
	local button = parent:Add("DButton")

	button:SetText("")
	button.hover = 0
	button.Paint = function(self, w, h)
		self.hover = Lerp2(self.hover, self:IsHovered() and self:IsEnabled() and 1 or 0, 10)

		local alpha = self:IsEnabled() and 1 or 0.45
		local label = self.label or text
		local color = self.color or U.color.text

		U.Button(0, 0, w, h, alpha, false, self.hover)

		local size = h * 0.42
		surface.SetFont("nwButton")
		local tw = surface.GetTextSize(label)
		local total = size + h * 0.25 + tw
		local x = (w - total) / 2

		U.DrawIcon(icon, x, (h - size) / 2, size, color, alpha)
		draw.SimpleText(label, "nwButton", x + size + h * 0.25, h / 2, ColorAlpha(color, 255 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
	button.DoClick = function()
		U.Tick()
		callback(button)
	end

	return button
end

function CS.Close()
	if (IsValid(CS.frame)) then
		CS.frame:Remove()
	end
end

-- the model's plain standing idle (stock HL2 activity)
local IDLES = {}

local function Card(parent, index, character, x, y, w, h)
	local card = parent:Add("DButton")

	card:SetText("")
	card:SetPos(x, y)
	card:SetSize(w, h)
	card.hover = 0
	card.appear = 0
	card.delay = RealTime() + index * 0.12

	if (character) then
		local model = card:Add("DModelPanel")

		model:SetMouseInputEnabled(false)
		local inset = math.Round(h * 0.03)

		model:SetPos(inset, inset)
		model:SetSize(w - inset * 2, h - inset * 2)
		model:SetModel(NW.models.Resolve(character.model))
		model:SetFOV(30)
		model:SetCamPos(Vector(68, 0, 60))
		model:SetLookAt(Vector(0, 0, 54))
		model:SetAmbientLight(Color(36, 38, 44))
		model:SetDirectionalLight(BOX_TOP, Color(150, 154, 162))
		model:SetDirectionalLight(BOX_FRONT, Color(70, 74, 82))
		model:SetDirectionalLight(BOX_LEFT, Color(40, 60, 80))

		local entity = model:GetEntity()

		if (IsValid(entity)) then
			entity:SetSkin(character.skin or 0)

			local sequence

			for _, name in ipairs(IDLES) do
				local id = entity:LookupSequence(name)

				if (id and id > 0) then
					sequence = id

					break
				end
			end

			entity:ResetSequence(sequence or math.max(entity:SelectWeightedSequence(ACT_IDLE), 0))
			entity:SetCycle(math.Rand(0, 1))
		end

		model.LayoutEntity = function(self, ent)
			ent:SetAngles(Angle(0, 8, 0))
			self:RunAnimation()
		end

		card.model = model
	end

	card.Paint = function(self, cw, ch)
		local a = self.appear

		U.Panel(0, 0, cw, ch, a, self)
	end
	card.PaintOver = function(self, cw, ch)
		local a = self.appear
		local selected = CS.selected == index

		self.hover = Lerp2(self.hover, self:IsHovered() and 1 or 0, 10)

		-- shade over the model, darker at the bottom
		surface.SetMaterial(U.Material("network2/ui/card_shade.png"))
		surface.SetDrawColor(255, 255, 255, 255 * a)
		surface.DrawTexturedRect(0, 0, cw, ch)
		surface.SetDrawColor(8, 10, 12, (selected and 40 or 110 - self.hover * 40) * a)
		surface.DrawRect(6, 6, cw - 12, ch - 12)

		local pad = ch * 0.045

		if (character) then
			-- name top left, the faction under it
			draw.SimpleText(character.name, "nwHeader", pad, pad, ColorAlpha(U.color.text, 255 * a))

			local faction = C.factions[character.faction] or {name = character.faction}
			local size = ch * 0.042
			local fy = pad + ch * 0.056

			if (faction.logo) then
				surface.SetMaterial(U.Material("network2/factions/" .. faction.logo .. ".png"))
				surface.SetDrawColor(255, 255, 255, 230 * a)
				surface.DrawTexturedRect(pad, fy, size, size)
			else
				U.DrawIcon("faction", pad, fy, size, U.color.dim, a)
			end

			draw.SimpleText(faction.name, "nwText", pad + size + 10, fy + size / 2,
				ColorAlpha(U.color.dim, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			local size = ch * 0.1

			U.DrawIcon("plus", (cw - size) / 2, ch * 0.42 - size / 2, size, ColorAlpha(U.color.text, 200), a)
			draw.SimpleText("Создать персонажа", "nwButton", cw / 2, ch * 0.42 + size * 0.8,
				ColorAlpha(U.color.dim, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		if (selected) then
			U.Slice(U.Material("network2/ui/outline.png"), 0, 0, cw, ch, 22, 255, 255, 255, 230 * a)
		end
	end
	card.Think = function(self)
		if (RealTime() > self.delay) then
			self.appear = Lerp2(self.appear, 1, 5)
		end

		self:SetAlpha(255 * self.appear)
	end
	card.DoClick = function()
		U.Tick()

		if (character) then
			CS.selected = index
			CS.confirmDelete = nil
		else
			-- empty slot: create
			U.Transition(function()
				CS.Close()
				NW.charCreate.Open()
			end, 0.45, 0.7)
		end
	end
	card.DoDoubleClick = function()
		if (character) then
			CS.selected = index
			CS.Play()
		end
	end

	return card
end

function CS.Build()
	local frame = CS.frame

	for _, child in ipairs(frame:GetChildren()) do
		child:Remove()
	end

	local w, h = ScrW(), ScrH()
	local slots = C.maxCharacters
	local cardH = h * 0.64
	local cardW = math.min(w * 0.3, cardH * 0.78)
	local gap = w * 0.02
	local total = slots * cardW + (slots - 1) * gap
	local x0 = (w - total) / 2
	local y0 = h * 0.15

	if (!C.list[CS.selected or 0]) then
		CS.selected = C.list[1] and 1 or nil
	end

	for index = 1, slots do
		Card(frame, index, C.list[index], x0 + (index - 1) * (cardW + gap), y0, cardW, cardH)
	end

	local bh, bw = h * 0.062, math.min(w * 0.17, cardW * 0.9)
	local by = y0 + cardH + h * 0.05

	local play = Button(frame, "Выбрать", "play", function()
		CS.Play()
	end)
	play:SetPos(w / 2 - bw - gap / 2, by)
	play:SetSize(bw, bh)
	play.Think = function(self)
		self:SetEnabled(C.list[CS.selected or 0] != nil)
	end

	local delete = Button(frame, "Удалить", "trash", function(self)
		local character = C.list[CS.selected or 0]

		if (!character) then
			return
		end

		if (CS.confirmDelete == character.id and RealTime() < (CS.confirmUntil or 0)) then
			net.Start("nwCharDelete")
				net.WriteUInt(character.id, 32)
			net.SendToServer()

			CS.confirmDelete = nil
			CS.selected = nil
		else
			CS.confirmDelete = character.id
			CS.confirmUntil = RealTime() + 3
		end
	end)
	delete:SetPos(w / 2 + gap / 2, by)
	delete:SetSize(bw, bh)
	delete.Think = function(self)
		local character = C.list[CS.selected or 0]

		self:SetEnabled(character != nil)

		if (character and CS.confirmDelete == character.id and RealTime() < (CS.confirmUntil or 0)) then
			self.label = "Точно удалить?"
			self.color = U.color.error
		else
			self.label = nil
			self.color = nil
		end
	end

	local back = Button(frame, "Назад", "back", function()
		U.Transition(function()
			CS.Close()
			NW.menu.ShowMain(true)
		end, 0.4, 0.6)
	end)
	back:SetPos(w * 0.03, h - bh - h * 0.03)
	back:SetSize(bw * 0.7, bh)
end

function CS.Play()
	local character = C.list[CS.selected or 0]

	if (!character or CS.loading) then
		return
	end

	CS.loading = true
	U.Play("affirm")
	NW.menu.PlayConfirm()
	U.FadeTo(255, 0.6)

	timer.Simple(0.65, function()
		CS.loading = false

		net.Start("nwCharLoad")
			net.WriteUInt(character.id, 32)
		net.SendToServer()

		NW.menu.EnterWorld()
	end)
end

function CS.Open()
	CS.Close()

	NW.menu.SetCamera("main")

	local frame = vgui.Create("EditablePanel")
	frame:SetSize(ScrW(), ScrH())
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.Paint = function(self, w, h)
		surface.SetMaterial(U.Material("network2/menu/vignette.png"))
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(0, 0, w, h)

		-- a darker veil than the main menu, the cards stay readable
		surface.SetDrawColor(6, 8, 10, 110)
		surface.DrawRect(0, 0, w, h)

		draw.SimpleText("ВЫБЕРИТЕ ПЕРСОНАЖА", "nwTitle", w / 2, h * 0.05, ColorAlpha(U.color.text, 230), TEXT_ALIGN_CENTER)

		if (CS.error) then
			draw.SimpleText(CS.error, "nwSmall", w / 2, h * 0.115, U.color.error, TEXT_ALIGN_CENTER)
		end
	end

	CS.frame = frame
	CS.error = nil
	CS.Build()
	U.Play("appear")
end
