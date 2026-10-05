local PANEL = {}

local appearSpeed = 6
local hoverSpeed = 12

local materials = {}

local function GetMaterial(path)
	local material = materials[path]

	if (!material) then
		material = Material(path, "smooth")
		materials[path] = material
	end

	return material
end

local ACTION_ICONS = {
	gesture = "framework/interact/gesture.png",
	act = "framework/interact/act.png",
	mood = "framework/interact/mood.png",
	walk = "framework/interact/walk.png",
	voice = "framework/voice/speak.png",
	radio = "framework/voice/radio.png"
}

local ACTION_ORDER = {"gesture", "act", "mood", "walk", "voice", "radio"}

local MENU_ICONS = {
	anim = "framework/interact/anim.png",
	gestures = "framework/interact/gesture.png",
	acts = "framework/interact/act.png",
	moods = "framework/interact/mood.png",
	walks = "framework/interact/walk.png",
	mic = "framework/voice/mic.png",
	voices = "framework/voice/speak.png",
	squad = "framework/interact/squad.png"
}

local ICON_FALLBACK = {
	["framework/interact/anim.png"] = "framework/icons/directions_run.png",
	["framework/interact/gesture.png"] = "framework/icons/directions_run.png",
	["framework/interact/act.png"] = "framework/icons/person.png",
	["framework/interact/mood.png"] = "framework/icons/favorite.png",
	["framework/interact/walk.png"] = "framework/status/accessibility.png",
	["framework/interact/squad.png"] = "framework/icons/group.png",
	["framework/interact/breach.png"] = "framework/icons/key.png",
	["framework/interact/knockout.png"] = "framework/icons/bolt.png",
	["framework/interact/order.png"] = "framework/icons/flag.png",
	["framework/interact/marker.png"] = "framework/icons/map.png",
	["framework/voice/mic.png"] = "framework/icons/record_voice_over.png",
	["framework/voice/speak.png"] = "framework/icons/record_voice_over.png",
	["framework/voice/whisper.png"] = "framework/icons/volume_down.png",
	["framework/voice/yell.png"] = "framework/icons/record_voice_over.png",
	["framework/voice/radio.png"] = "framework/status/radio.png"
}

local VOICE_MODE_ICONS = {
	"framework/voice/whisper.png",
	"framework/voice/speak.png",
	"framework/voice/yell.png"
}

local function ResolveIcon(item)
	if (isstring(item.iconWhite) and item.iconWhite != "") then
		return item.iconWhite, true
	end

	if (item.bBack) then
		return "framework/chat/ui_close.png", true
	end

	if (item.menu == "voices" and NETWORK.act and NETWORK.act.GetVoiceMode) then
		local _, index = NETWORK.act.GetVoiceMode(LocalPlayer())

		return VOICE_MODE_ICONS[index or 2] or MENU_ICONS.voices, true
	end

	if (item.menu) then
		return MENU_ICONS[item.menu] or "framework/icons/list.png", true
	end

	for _, key in ipairs(ACTION_ORDER) do
		if (item[key] != nil) then
			return ACTION_ICONS[key], true
		end
	end

	if (isstring(item.icon) and item.icon != "") then
		return item.icon, false
	end
end

local function DrawIcon(path, bWhite, x, y, size, color)
	local material = bWhite and NETWORK.util.GetMaterial(path, "smooth") or GetMaterial(path)

	if ((!material or material:IsError()) and bWhite and ICON_FALLBACK[path]) then
		material = NETWORK.util.GetMaterial(ICON_FALLBACK[path], "smooth")
	end

	if (!material or material:IsError()) then
		return false
	end

	surface.SetMaterial(material)

	if (bWhite) then

		surface.SetDrawColor(0, 0, 0, (color.a or 255) * 0.5)
		surface.DrawTexturedRect(x + 1, y + 1, size, size)
		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	else
		surface.SetDrawColor(255, 255, 255, color.a or 255)
	end

	surface.DrawTexturedRect(x, y, size, size)

	return true
end

local function DrawSegment(x, y, inner, outer, startAngle, length, color)
	if (length <= 0 or outer <= inner) then
		return
	end

	local segments = math.max(math.ceil(length / 4), 2)

	draw.NoTexture()
	surface.SetDrawColor(color)

	for i = 0, segments - 1 do
		local first = math.rad(startAngle + length * (i / segments))
		local second = math.rad(startAngle + length * ((i + 1) / segments))
		local cos1, sin1 = math.cos(first), math.sin(first)
		local cos2, sin2 = math.cos(second), math.sin(second)

		surface.DrawPoly({
			{x = x + cos1 * inner, y = y + sin1 * inner},
			{x = x + cos1 * outer, y = y + sin1 * outer},
			{x = x + cos2 * outer, y = y + sin2 * outer},
			{x = x + cos2 * inner, y = y + sin2 * inner}
		})
	end
end

local function DrawSegmentOutline(x, y, inner, outer, startAngle, length, thickness, color)
	if (length <= 0 or outer <= inner) then
		return
	end

	DrawSegment(x, y, outer - thickness, outer, startAngle, length, color)
	DrawSegment(x, y, inner, inner + thickness, startAngle, length, color)

	for _, degrees in ipairs({startAngle, startAngle + length}) do
		local radians = math.rad(degrees)
		local cos, sin = math.cos(radians), math.sin(radians)

		NETWORK.util.DrawThickLine(x + cos * inner, y + sin * inner,
			x + cos * outer, y + sin * outer, thickness, color)
	end
end

local function DrawCircle(x, y, radius, color)
	if (radius <= 0) then
		return
	end

	local vertices = {}

	for i = 0, 64 do
		local angle = math.rad((i / 64) * 360)

		vertices[#vertices + 1] = {
			x = x + math.cos(angle) * radius,
			y = y + math.sin(angle) * radius
		}
	end

	draw.NoTexture()
	surface.SetDrawColor(color)
	surface.DrawPoly(vertices)
end

function NETWORK.gui.GetRadialMenus()
	local client = LocalPlayer()
	local act = NETWORK.act
	local gestures, acts, moods, walks, voices = {}, {}, {}, {}, {}
	local voiceMode, voiceIndex = act.GetVoiceMode(client)
	local mood = client:GetNWInt("nwMood", 1)
	local walk = client:GetNWInt("nwWalk", 1)
	local bRadio = act.CanUseRadio(client)
	local bRadioOn = act.IsRadioOn(client)

	for i, data in ipairs(act.voiceModes) do
		voices[i] = {
			label = L(data.name),
			hint = L("radialRange") .. ": " .. data.range,
			voice = i,
			bText = true,
			bActive = i == voiceIndex
		}
	end

	for i, data in ipairs(act.moods) do
		moods[i] = {
			label = L(data.name),
			mood = i,
			sequence = data.idle and data.idle[1],
			bText = true,
			bActive = i == mood
		}
	end

	for i, data in ipairs(act.walks) do
		walks[i] = {
			label = L(data.name),
			walk = i,
			sequence = data.sequence,
			bText = true,
			bActive = i == walk
		}
	end

	for i, data in ipairs(act.GetActs(client)) do
		local bPlayable = act.HasSequence(client, data)

		acts[#acts + 1] = {
			label = L(data.name),
			hint = bPlayable and (data.hint and L(data.hint) or nil) or
				L("actNoSequence"),
			act = bPlayable and i or nil,
			bStub = !bPlayable or nil,
			sequence = data.sequence,
			bText = true
		}
	end

	for i, data in ipairs(act.GetGestures(client)) do
		local bPlayable = act.HasSequence(client, data)

		gestures[#gestures + 1] = {
			label = L(data.name),
			hint = !bPlayable and L("actNoSequence") or nil,
			gesture = bPlayable and i or nil,
			bStub = !bPlayable or nil,
			sequence = data.sequence,
			bText = true
		}
	end

	local animItems = {
		{label = L("radialGestures"), icon = "icon16/hand_point.png", menu = "gestures"},
		{label = L("radialActs"), icon = "icon16/user_go.png", menu = "acts"}
	}

	if (act.HasMood(client)) then
		animItems[#animItems + 1] = {
			label = L("radialMood"), icon = "icon16/emoticon_smile.png", menu = "moods"
		}
	end

	if (act.HasWalk(client)) then
		animItems[#animItems + 1] = {
			label = L("radialWalk"), icon = "icon16/foot.png", menu = "walks"
		}
	end

	local rootItems = {
		{label = L("radialAnimations"), icon = "icon16/film.png", menu = "anim"},
		{label = L("radialVoice"), icon = "icon16/sound.png", menu = "mic"}
	}

	if (NETWORK.breach.GetDoor(client)) then
		rootItems[#rootItems + 1] = {
			label = L("radialBreach"),
			icon = "icon16/door_open.png",
			iconWhite = "framework/interact/breach.png",
			hint = L("radialBreachHint"),
			callback = function()
				net.Start("nwDoorKick")
				net.SendToServer()
			end
		}
	end

	if (NETWORK.shield and NETWORK.shield.IsUser and NETWORK.shield.IsUser(client)) then
		local trace = client:GetEyeTrace()
		local target = trace.Entity

		if (IsValid(target) and target:IsPlayer() and target:Alive() and
			client:GetPos():Distance(target:GetPos()) <= 100) then
			rootItems[#rootItems + 1] = {
				label = L("radialKnockout"),
				icon = "icon16/user_delete.png",
				iconWhite = "framework/interact/knockout.png",
				hint = L("radialKnockoutHint"),
				callback = function()
					net.Start("nwWallhammerKnock")
					net.SendToServer()
				end
			}
		end
	end

	local squadItems = {}

	if (client.IsSquadLeader and client:IsSquadLeader()) then
		for _, data in ipairs(NETWORK.squad.orders) do
			squadItems[#squadItems + 1] = {
				label = L(data.name),
				icon = "icon16/flag_red.png",
				iconWhite = "framework/interact/order.png",
				hint = L("radialOrderHint"),
				callback = function()
					net.Start("nwSquadOrder")
						net.WriteString(data.id)
					net.SendToServer()
				end
			}
		end

		squadItems[#squadItems + 1] = {
			label = L("radialMarker"),
			icon = "icon16/map.png",
			iconWhite = "framework/interact/marker.png",
			hint = L("radialMarkerHint"),
			callback = function()
				net.Start("nwWaypointQuick")
				net.SendToServer()
			end
		}

		rootItems[#rootItems + 1] = {
			label = L("radialSquad"),
			icon = "icon16/group.png",
			menu = "squad"
		}
	end

	local menus = {

		root = {
			title = L("radialActions"),
			items = rootItems
		},
		squad = {title = L("radialSquad"), items = squadItems},
		anim = {title = L("radialAnimations"), items = animItems},
		gestures = {title = L("radialGestures"), items = gestures},
		acts = {title = L("radialActs"), items = acts},
		moods = {title = L("radialMood"), items = moods},
		walks = {title = L("radialWalk"), items = walks},
		mic = {
			title = L("radialVoice"),
			items = {
				{
					label = L("radialVolume"),
					icon = "icon16/sound_add.png",
					hint = L("radialCurrent") .. ": " .. L(voiceMode.name),
					menu = "voices"
				},
				{
					label = L("radialRadio"),
					icon = "icon16/transmit.png",

					iconWhite = "framework/voice/radio.png",
					hint = bRadio and L(bRadioOn and "radialOn" or "radialOff") or
						L("radialNoRadio"),
					radio = bRadio and true or nil,
					bStub = !bRadio,
					bActive = bRadioOn
				}
			}
		},
		voices = {title = L("radialVolume"), items = voices}
	}

	hook.Run("NetworkRadialMenus", client, menus, rootItems)

	return menus
end

function PANEL:Init()
	NETWORK.gui.radial = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetKeyboardInputEnabled(false)

	self.menus = NETWORK.gui.GetRadialMenus()
	self.level = "root"
	self.stack = {}
	self.frac = 0
	self.levelFrac = 0
	self.hover = 0

	self.modelYaw = 35
	self.modelPitch = 0
	self.modelZoom = 1
	self.modelShift = 0

	self.centerX = ScrW() * 0.5
	self.centerY = ScrH() * 0.5
	self.outer = ScrH() * 0.235
	self.inner = ScrH() * 0.118

	self:SetupModel()

	gui.SetMousePos(self.centerX, self.centerY)

	NETWORK.sound.Soft()
end

function PANEL:SetupModel()
	local client = LocalPlayer()
	local size = math.Round(self.inner * 1.9)

	self.model = self:Add("DModelPanel")
	self.model:SetSize(size, size)
	self.model:SetPos(self.centerX - size * 0.5, self.centerY - size * 0.5)
	self.model:SetModel(client:GetModel())
	self.model:SetFOV(32)
	self.model:SetAnimated(true)
	self.model:SetMouseInputEnabled(false)
	self.model.LayoutEntity = function(panel, entity)
		entity:SetAngles(Angle(0, self.modelYaw, 0))

		panel:RunAnimation()
	end

	local entity = self.model.Entity

	if (IsValid(entity)) then
		entity:SetSkin(client:GetSkin())

		for _, data in pairs(client:GetBodyGroups() or {}) do
			entity:SetBodygroup(data.id, client:GetBodygroup(data.id))
		end

		local idle = entity:LookupSequence("idle_all_01")

		if (!idle or idle < 1) then
			idle = entity:SelectWeightedSequence(ACT_IDLE)
		end

		self.idleSequence = idle

		if (idle and idle > 0) then
			entity:ResetSequence(idle)
		end
	end

	self:UpdateCamera()
end

function PANEL:UpdateCamera()
	if (!IsValid(self.model)) then
		return
	end

	local zoom = self.modelZoom

	self.model:SetCamPos(Vector(64 * zoom, 26 * zoom, 62 * zoom + self.modelPitch))
	self.model:SetLookAt(Vector(0, self.modelShift, 46 + self.modelPitch * 0.4))
end

function PANEL:IsModelHovered()
	local mouseX, mouseY = gui.MousePos()
	local deltaX, deltaY = mouseX - self.centerX, mouseY - self.centerY

	return (deltaX * deltaX + deltaY * deltaY) < (self.inner * 0.94) ^ 2
end

function PANEL:PreviewSequence(sequence)
	local entity = IsValid(self.model) and self.model.Entity

	if (!IsValid(entity) or !isstring(sequence)) then
		return
	end

	local index = entity:LookupSequence(sequence)

	if (!index or index < 1) then
		return
	end

	entity:ResetSequence(index)
	entity:SetCycle(0)
	entity:SetPlaybackRate(1)

	self.previewEnd = CurTime() + entity:SequenceDuration(index)
end

function PANEL:GetItems()
	local menu = self.menus[self.level]

	if (!menu) then
		return {}, ""
	end

	if (#self.stack > 0) then
		if (!menu.bBackAdded) then
			table.insert(menu.items, 1, {
				label = L("radialBack"),
				icon = "icon16/arrow_undo.png",
				bBack = true
			})

			menu.bBackAdded = true
		end
	elseif (menu.bBackAdded) then
		table.remove(menu.items, 1)

		menu.bBackAdded = nil
	end

	return menu.items, menu.title or ""
end

function PANEL:BeginTransition()
	self.exitItems = self:GetItems()
	self.exitFrac = 1
	self.levelFrac = -0.35
	self.hovered = nil
end

function PANEL:SetLevel(id)
	if (!self.menus[id]) then
		return
	end

	self:BeginTransition()

	self.stack[#self.stack + 1] = self.level
	self.level = id

	NETWORK.sound.Click()
end

function PANEL:Back()
	local previous = table.remove(self.stack)

	if (!previous) then
		return self:Close()
	end

	self:BeginTransition()

	self.level = previous

	NETWORK.sound.Soft()
end

function PANEL:Send(name, value, bits)
	net.Start(name)
		net.WriteUInt(value, bits or 8)
	net.SendToServer()
end

function PANEL:Activate(item)
	if (!item) then
		return
	end

	if (item.menu) then
		return self:SetLevel(item.menu)
	end

	if (item.bStub) then
		NETWORK.sound.Play("hover3", 92, 0.5)

		return
	end

	if (item.gesture) then
		self:Send("nwActGesture", item.gesture)
	elseif (item.act) then
		self:Send("nwActRun", item.act)
	elseif (item.mood) then
		self:Send("nwActMood", item.mood, 4)
	elseif (item.walk) then
		self:Send("nwActWalk", item.walk, 4)
	elseif (item.voice) then
		self:Send("nwActVoice", item.voice, 4)
	elseif (item.radio) then
		net.Start("nwActRadio")
		net.SendToServer()
	elseif (item.bBack) then
		return self:Back()
	elseif (item.callback) then
		item.callback()
	else
		return
	end

	NETWORK.sound.Soft()

	self:Close()
end

function PANEL:Think()
	local frameTime = FrameTime()

	self.frac = math.Approach(self.frac, self.bClosing and 0 or 1,
		frameTime * appearSpeed)
	self.levelFrac = math.Approach(self.levelFrac, 1, frameTime * appearSpeed)
	self.exitFrac = math.Approach(self.exitFrac or 0, 0, frameTime * appearSpeed * 1.6)

	if (self.exitFrac <= 0.001) then
		self.exitItems = nil
	end

	if (self.bClosing and self.frac <= 0.001) then
		return self:Remove()
	end

	local items = self:GetItems()
	local mouseX, mouseY = gui.MousePos()
	local deltaX, deltaY = mouseX - self.centerX, mouseY - self.centerY
	local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
	local hovered

	if (#items > 0 and distance > self.inner * 0.9 and distance < self.outer * 1.35) then
		local angle = math.deg(math.atan2(deltaY, deltaX)) % 360
		local step = 360 / #items
		local index = math.floor(((angle + step * 0.5) % 360) / step) + 1

		hovered = math.Clamp(index, 1, #items)
	end

	if (hovered != self.hovered) then
		self.hovered = hovered

		self.scrollStart = RealTime()

		local item = hovered and items[hovered]

		if (item and item.sequence) then
			self:PreviewSequence(item.sequence)
		end
	end

	self.hover = math.Approach(self.hover, hovered and 1 or 0, frameTime * hoverSpeed)

	if (self.bDragging) then
		local currentX, currentY = gui.MousePos()

		self.modelYaw = (self.modelYaw - (currentX - (self.dragX or currentX)) * 0.6) % 360
		self.modelPitch = math.Clamp(self.modelPitch +
			(currentY - (self.dragY or currentY)) * 0.35, -34, 44)
		self.dragX, self.dragY = currentX, currentY

		if (!input.IsMouseDown(MOUSE_LEFT)) then
			self.bDragging = false
		end
	end

	self:UpdateCamera()

	local entity = IsValid(self.model) and self.model.Entity

	if (IsValid(entity) and self.previewEnd and self.previewEnd < CurTime()) then
		self.previewEnd = nil

		if (self.idleSequence and self.idleSequence > 0) then
			entity:ResetSequence(self.idleSequence)
		end
	end
end

function PANEL:OnMousePressed(key)
	if (key == MOUSE_RIGHT) then
		return self:Back()
	end

	if (key != MOUSE_LEFT) then
		return
	end

	if (self:IsModelHovered()) then
		self.bDragging = true
		self.dragX, self.dragY = gui.MousePos()

		return
	end

	self:Activate(self:GetItems()[self.hovered or 0])
end

function PANEL:OnMouseReleased()
	self.bDragging = false
end

function PANEL:OnMouseWheeled(delta)
	if (!self:IsModelHovered()) then
		return
	end

	local mouseX = gui.MousePos()

	self.modelZoom = math.Clamp(self.modelZoom - delta * 0.09, 0.5, 1.9)
	self.modelShift = math.Clamp(self.modelShift +
		((mouseX - self.centerX) / math.max(self.inner, 1)) * delta * 2.5, -18, 18)

	self:UpdateCamera()
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)

	gui.EnableScreenClicker(false)
end

function PANEL:OnRemove()
	gui.EnableScreenClicker(false)

	if (NETWORK.gui.radial == self) then
		NETWORK.gui.radial = nil
	end
end

function PANEL:PaintItems(items, progress, alpha, bActive)
	local theme = NETWORK.theme
	local frac = 1 - math.pow(1 - math.Clamp(progress, 0, 1), 3)

	if (frac <= 0.005 or #items == 0) then
		return
	end

	local x, y = self.centerX, self.centerY
	local outer = self.outer * Lerp(frac, 0.72, 1)
	local inner = self.inner * Lerp(frac, 0.86, 1)
	local step = 360 / #items

	for i, item in ipairs(items) do
		local reveal = math.Clamp((frac - (i - 1) * 0.04) / 0.62, 0, 1)

		if (reveal <= 0.01) then
			continue
		end

		local bHovered = bActive and self.hovered == i
		local start = -step * 0.5 + step * (i - 1)
		local length = (step - 2.2) * reveal

		local bVort = (self.menus[self.level] or {}).bScroll
		local accent = bVort and Color(96, 200, 120) or theme.combine
		local segmentAlpha = (item.bStub and 0.6 or 1) * alpha
		local fillColor, edgeColor

		if (bHovered) then
			fillColor = ColorAlpha(accent, 60 * segmentAlpha)
			edgeColor = ColorAlpha(accent, 255 * segmentAlpha)
		elseif (item.bActive) then
			fillColor = ColorAlpha(accent, 24 * segmentAlpha)
			edgeColor = ColorAlpha(accent, 110 * segmentAlpha)
		else
			fillColor = Color(255, 255, 255, 8 * segmentAlpha)
			edgeColor = Color(255, 255, 255, 18 * segmentAlpha)
		end

		DrawSegment(x, y, inner + 4, outer, start, length, fillColor)
		DrawSegmentOutline(x, y, inner + 4, outer, start, length,
			math.max(NETWORK.util.Scale(1), 1), edgeColor)

		local middle = math.rad(start + length * 0.5)
		local radius = (inner + outer) * 0.5
		local pointX = x + math.cos(middle) * radius
		local pointY = y + math.sin(middle) * radius
		local textColor = bHovered and theme.combine or
			(item.bStub and theme.textFaint or theme.textDim)

		if (item.bText) then
			draw.SimpleText(item.label, bHovered and "nwField" or "nwHudSmall",
				pointX, pointY, ColorAlpha(textColor, 255 * alpha * reveal),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			local path, bWhite = ResolveIcon(item)

			if (path) then
				local size = math.Round(ScrH() * (bHovered and 0.036 or 0.03))

				DrawIcon(path, bWhite, math.Round(pointX - size * 0.5),
					math.Round(pointY - size * 0.5), size,
					ColorAlpha(textColor, 255 * alpha * reveal))
			end
		end
	end
end

function PANEL:PaintScroll(x, y, inner, item, alpha, index, count)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme

	local since = RealTime() - (self.scrollStart or 0)
	local unfold = math.Clamp(since / 0.25, 0, 1)

	local eased = util.EaseOutBack and util.EaseOutBack(unfold) or
		util.EaseOut(unfold)

	local width = inner * 1.55
	local full = inner * 1.05
	local height = full * eased

	local step = 360 / math.max(count or 1, 1)
	local angle = math.rad(-step * 0.5 + step * ((index or 1) - 1) - 90 +
		step * 0.5)

	local distance = self.outer + width * 0.42 + Sc(26)

	local anchorX = x + math.cos(angle) * distance
	local anchorY = y + math.sin(angle) * distance

	anchorX = math.Clamp(anchorX, width * 0.5 + Sc(12),
		ScrW() - width * 0.5 - Sc(12))
	anchorY = math.Clamp(anchorY, full * 0.5 + Sc(24),
		ScrH() - full * 0.5 - Sc(24))

	local left = anchorX - width * 0.5
	local top = anchorY - height * 0.5

	if (eased > 0.2) then
		surface.SetDrawColor(150, 112, 60, 120 * alpha * eased)
		surface.DrawLine(x + math.cos(angle) * (self.outer + Sc(4)),
			y + math.sin(angle) * (self.outer + Sc(4)),
			anchorX - math.cos(angle) * (width * 0.42),
			anchorY - math.sin(angle) * (full * 0.42))
	end

	surface.SetDrawColor(30, 27, 22, 244 * alpha)
	surface.DrawRect(left, top, width, height)

	surface.SetDrawColor(16, 14, 11, 220 * alpha)
	surface.DrawRect(left, top, width, math.max(Sc(2), 2))
	surface.DrawRect(left, top + height - math.max(Sc(2), 2), width,
		math.max(Sc(2), 2))

	local rollHeight = math.max(Sc(9), 6)

	local function Roll(rollY)
		surface.SetDrawColor(74, 58, 38, 250 * alpha)
		surface.DrawRect(left - Sc(6), rollY - rollHeight * 0.5,
			width + Sc(12), rollHeight)

		surface.SetDrawColor(126, 100, 64, 250 * alpha)
		surface.DrawRect(left - Sc(6), rollY - rollHeight * 0.5 + 1,
			width + Sc(12), math.max(rollHeight * 0.35, 1))

		surface.SetDrawColor(48, 38, 25, 250 * alpha)
		surface.DrawRect(left - Sc(6), rollY - rollHeight * 0.5,
			math.max(Sc(4), 3), rollHeight)
		surface.DrawRect(left + width + Sc(6) - math.max(Sc(4), 3),
			rollY - rollHeight * 0.5, math.max(Sc(4), 3), rollHeight)
	end

	Roll(top)
	Roll(top + height)

	local textAlpha = math.Clamp((unfold - 0.45) / 0.55, 0, 1) * alpha

	if (textAlpha <= 0.01) then
		return
	end

	local label = util.Upper(item.label or "")

	surface.SetFont("nwField")

	local limit = width - Sc(26)
	local labelFont = surface.GetTextSize(label) > limit and "nwHudSmall" or
		"nwField"

	draw.SimpleText(label, labelFont, x, top + Sc(20),
		Color(232, 214, 176, 252 * textAlpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	surface.SetDrawColor(150, 112, 60, 200 * textAlpha)
	surface.DrawRect(x - width * 0.22, top + Sc(31), width * 0.44,
		math.max(Sc(1), 1))

	if (!item.hint or item.hint == "") then
		return
	end

	surface.SetFont("nwHudSmall")

	local words = string.Explode(" ", item.hint)
	local line = ""
	local lines = {}

	for _, word in ipairs(words) do
		local try = line == "" and word or (line .. " " .. word)

		if (surface.GetTextSize(try) > limit and line != "") then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end

	if (line != "") then
		lines[#lines + 1] = line
	end

	for index = 1, math.min(#lines, 4) do
		draw.SimpleText(lines[index], "nwHudSmall", x,
			top + Sc(46) + (index - 1) * Sc(13),
			Color(196, 180, 150, 240 * textAlpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end

function PANEL:PaintFooter(x, y, outer, alpha, title)
	local Sc = NETWORK.util.Scale

	NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(title), "nwHudSmall", x,
		y + outer + Sc(44), Color(130, 168, 136, 190 * alpha),
		Sc(4), TEXT_ALIGN_CENTER)
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local frac = 1 - math.pow(1 - math.Clamp(self.frac, 0, 1), 3)
	local alpha = frac

	if (alpha <= 0.005) then
		return
	end

	local items, title = self:GetItems()
	local x, y = self.centerX, self.centerY
	local outer = self.outer * Lerp(frac, 0.86, 1)
	local inner = self.inner * Lerp(frac, 0.86, 1)

	util.DrawBlur(self, 4 * alpha, 0.25)

	surface.SetDrawColor(3, 4, 6, 140 * alpha)
	surface.DrawRect(0, 0, width, height)

	util.DrawVignette(0, 0, width, height,
		math.Round(math.min(width, height) * 0.5), 140 * alpha)

	DrawCircle(x, y, inner, Color(8, 9, 11, 240 * alpha))

	util.DrawArc(x, y, inner, math.max(Sc(1), 1), 1, Color(255, 255, 255, 30 * alpha), 96)

	if (self.exitItems and (self.exitFrac or 0) > 0.005) then
		self:PaintItems(self.exitItems, self.exitFrac, alpha * self.exitFrac, false)
	end

	if ((self.levelFrac or 0) > 0) then
		self:PaintItems(items, self.levelFrac, alpha, true)
	end

	local titleText = util.Upper(title)
	local titleWidth = util.TextSpacedSize(titleText, "nwSkillName", Sc(3))

	util.DrawTextSpaced(titleText, "nwSkillName", math.Round(x - titleWidth * 0.5),
		y - outer - Sc(44), ColorAlpha(theme.textDim, 235 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	local item = items[self.hovered or 0]

	if (!item and (self.levelFrac or 0) > 0.4) then
		draw.SimpleText("· · ·", "nwHudSmall", x, y, ColorAlpha(theme.textFaint,
			200 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if (item and (self.levelFrac or 0) > 0.4 and
		(self.menus[self.level] or {}).bScroll) then
		self:PaintScroll(x, y, inner, item, alpha, self.hovered, #items)

		return self:PaintFooter(x, y, outer, alpha, title)
	end

	if (item and (self.levelFrac or 0) > 0.4) then
		local centerLabel = util.Upper(item.label)
		local centerHint = item.hint

		surface.SetFont("nwField")

		local labelWidth = surface.GetTextSize(centerLabel)
		local limit = inner * 1.55

		local labelFont = labelWidth > limit and "nwHudSmall" or "nwField"
		local hintY = y + Sc(4)

		draw.SimpleText(centerLabel, labelFont, x,
			centerHint and (y - Sc(14)) or y,
			ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		if (centerHint) then
			surface.SetFont("nwHudSmall")

			local words = string.Explode(" ", centerHint)
			local line = ""
			local lines = {}

			for _, word in ipairs(words) do
				local try = line == "" and word or (line .. " " .. word)

				if (surface.GetTextSize(try) > limit and line != "") then
					lines[#lines + 1] = line
					line = word
				else
					line = try
				end
			end

			if (line != "") then
				lines[#lines + 1] = line
			end

			for index = 1, math.min(#lines, 4) do
				draw.SimpleText(lines[index], "nwHudSmall", x,
					hintY + (index - 1) * Sc(13),
					ColorAlpha(theme.textDim, 235 * alpha),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end

	if ((self.levelFrac or 0) > 0.4) then
		local label = item and util.Upper(item.label) or util.Upper(title)
		local labelY = y + outer + Sc(48)
		local line = math.max(Sc(1), 1)

		local hint = item and isstring(item.hint) and item.hint != "" and
			util.TruncateWidth(item.hint, "nwLabel", outer * 2.4) or nil

		surface.SetFont("nwInvName")

		local plateWidth = surface.GetTextSize(label) + Sc(56)
		local plateHeight = hint and Sc(52) or Sc(36)

		if (hint) then
			surface.SetFont("nwLabel")

			plateWidth = math.max(plateWidth, surface.GetTextSize(hint) + Sc(56))
		end

		local plateX = x - math.Round(plateWidth * 0.5)
		local plateY = labelY - math.Round(plateHeight * 0.5)

		surface.SetDrawColor(8, 9, 11, 235 * alpha)
		surface.DrawRect(plateX, plateY, plateWidth, plateHeight)

		surface.SetDrawColor(item and ColorAlpha(theme.combine, 200 * alpha) or
			Color(255, 255, 255, 26 * alpha))
		surface.DrawOutlinedRect(plateX, plateY, plateWidth, plateHeight, line)

		draw.SimpleText(label, "nwInvName", x,
			hint and (plateY + Sc(15)) or (plateY +
			math.Round(plateHeight * 0.5)),
			ColorAlpha(item and theme.text or theme.textDim, 252 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (hint) then
			draw.SimpleText(hint, "nwLabel", x, plateY + Sc(36),
				ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end
	end

	if (#self.stack > 0) then
		local backX = x + outer + Sc(46)

		DrawIcon("framework/chat/ui_close.png", true, backX - Sc(8), y - Sc(8), Sc(16),
			ColorAlpha(theme.combine, 235 * alpha))

		draw.SimpleText(util.Upper(L("radialBack")), "nwHudSmall", backX + Sc(20), y,
			ColorAlpha(theme.accent, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwRadial", PANEL, "EditablePanel")

local function IsBusy()
	if (gui.IsGameUIVisible()) then
		return true
	end

	local focus = vgui.GetKeyboardFocus()

	if (IsValid(focus) and focus:IsVisible()) then
		return true
	end

	if (IsValid(NETWORK.gui.chat) and NETWORK.gui.chat.bActive) then
		return true
	end

	if (IsValid(NETWORK.gui.tabMenu) or IsValid(NETWORK.gui.menu)) then
		return true
	end

	return NETWORK.hud.IsHidden()
end

function NETWORK.gui.OpenRadial()
	local client = LocalPlayer()

	if (IsValid(NETWORK.gui.radial)) then
		return nil, "уже открыто"
	end

	if (!IsValid(client) or !client:HasCharacter()) then
		return nil, "нет персонажа"
	end

	if (!client:Alive()) then
		return nil, "персонаж мёртв"
	end

	if (IsBusy()) then
		return nil, "открыто другое окно или скрыт интерфейс"
	end

	return vgui.Create("nwRadial")
end

local keyConVar = CreateClientConVar("network_radial_key", tostring(KEY_G), true,
	false, "Клавиша кругового меню")

local bHeld = false

hook.Add("Think", "nwRadialKey", function()
	local key = keyConVar:GetInt()

	if (key <= 0 or !input.IsKeyDown(key)) then
		bHeld = false

		return
	end

	if (bHeld) then
		return
	end

	bHeld = true

	if (vgui.CursorVisible() and !IsValid(NETWORK.gui.radial)) then
		return
	end

	NETWORK.gui.OpenRadial()
end)

hook.Add("PlayerBindPress", "nwRadial", function(client, bind, bPressed)
	if (!bPressed or string.lower(bind) != "gm_showspare2") then
		return
	end

	NETWORK.gui.OpenRadial()

	return true
end)

concommand.Add("network_radial", function()
	local panel, reason = NETWORK.gui.OpenRadial()

	if (!IsValid(panel)) then
		NETWORK.util.PrintWarning("Меню не открылось: " .. tostring(reason))
	end
end)

concommand.Add("network_radial_bind", function(_, _, arguments)
	local name = arguments[1]

	if (!name) then
		NETWORK.util.Print("Использование: network_radial_bind <клавиша>")
		NETWORK.util.Print("Например: network_radial_bind g")

		return
	end

	local key = _G["KEY_" .. string.upper(name)]

	if (!key) then
		NETWORK.util.PrintWarning("Клавиша не найдена: " .. name)

		return
	end

	RunConsoleCommand("network_radial_key", tostring(key))

	NETWORK.util.Print("Круговое меню теперь на клавише " .. string.upper(name))
end)

net.Receive("nwActPlay", function()
	local client = net.ReadEntity()
	local index = net.ReadUInt(8)

	if (!IsValid(client)) then
		return
	end

	local data = NETWORK.act.GetGestures(client)[index]

	if (!data) then
		return
	end

	local sequence = client:LookupSequence(data.sequence)

	if (sequence and sequence > 0) then
		client:AnimRestartGesture(GESTURE_SLOT_CUSTOM, sequence, true)
	end
end)

net.Receive("nwActReset", function()
	local client = net.ReadEntity()

	if (IsValid(client)) then
		client:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
	end
end)
