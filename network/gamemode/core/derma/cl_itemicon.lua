local PANEL = {}

NETWORK.icon.panels = NETWORK.icon.panels or {}

local function ModelOf(item)
	if (item and isstring(item.model) and item.model != "") then
		return item.model
	end

	return NETWORK.item.GetModel(item)
end

function PANEL:Init()
	NETWORK.icon.panels[self] = true

	self.alphaValue = 255

	self:SetPaintBackground(false)
end

function PANEL:Paint()
end

function PANEL:OnRemove()
	NETWORK.icon.panels[self] = nil
end

function PANEL:Clear()
	if (IsValid(self.inner)) then
		self.inner:Remove()
	end

	self.inner = nil
end

function PANEL:SetItem(item)
	self.item = item

	self:Build()
end

function PANEL:SetModel(model)
	if (!isstring(model)) then
		return
	end

	self.item = {id = self.item and self.item.id or nil, model = model}

	self:Build()
end

function PANEL:Build()
	self:Clear()

	self.bFramed = false
	self.bFallback = false
	self.attempts = 0

	if (!self.item) then
		return
	end

	self.inner = self:Add("DModelPanel")
	self.inner:SetModel(ModelOf(self.item))
	self.inner:SetMouseInputEnabled(false)
	self.inner:SetPaintBackground(false)
	self.inner:SetAnimated(false)
	self.inner:SetAlpha(self.alphaValue)
	self.inner.LayoutEntity = function() end

	self.bCustom = NETWORK.icon.Get(self.item.id) != nil

	self:InvalidateLayout(true)
end

function PANEL:Fallback()
	self:Clear()

	self.bFramed = true
	self.bFallback = true

	self.inner = self:Add("SpawnIcon")
	self.inner:SetModel(ModelOf(self.item))
	self.inner:SetMouseInputEnabled(false)
	self.inner:SetPaintBackground(false)
	self.inner:SetAlpha(self.alphaValue)
	self.inner.PaintOver = function() end

	self:InvalidateLayout(true)
end

function PANEL:Frame()
	if (self.bFramed or !self.item or !IsValid(self.inner)) then
		return
	end

	self.attempts = (self.attempts or 0) + 1

	local entity = self.inner:GetEntity()

	if (!IsValid(entity)) then
		if (self.attempts > 60) then
			self:Fallback()
		end

		return
	end

	local custom = NETWORK.icon.Get(self.item.id)
	local data = custom

	if (!data) then
		local mins, maxs = entity:GetRenderBounds()
		local size = math.max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z)

		if (size <= 0.01) then
			if (self.attempts > 60) then
				self:Fallback()
			end

			return
		end

		local center = (mins + maxs) * 0.5
		local distance = math.max(size * 1.5, 10)

		data = {
			pos = {center.x + distance * 0.7, center.y + distance * 0.7,
				center.z + distance * 0.4},
			ang = {0, 0, 0},
			fov = 38,
			center = {center.x, center.y, center.z}
		}
	end

	local center = data.center and
		Vector(data.center[1], data.center[2], data.center[3]) or vector_origin

	entity:SetAngles(Angle(data.ang[1], data.ang[2], data.ang[3]))

	self.baseAngles = Angle(data.ang[1], data.ang[2], data.ang[3])
	self.spin = 0

	self.baseFov = data.fov or 38
	self.inner:SetCamPos(Vector(data.pos[1], data.pos[2], data.pos[3]))
	self.inner:SetLookAt(center)

	self.baseLook = self.inner:GetLookAng()
	self.bFramed = true

	self:ApplyRotation()
end

function PANEL:IsRotated()
	return istable(self.item) and self.item.rotated == true
end

function PANEL:ApplyRotation()
	if (self.bFallback or !IsValid(self.inner) or !self.baseLook) then
		return
	end

	local fov = self.baseFov or 38

	if (!self:IsRotated()) then
		self.inner:SetLookAng(self.baseLook)
		self.inner:SetFOV(fov)

		return
	end

	local width, height = self:GetSize()

	if (width <= 0 or height <= 0) then
		return
	end

	local look = Angle(self.baseLook.p, self.baseLook.y, self.baseLook.r + 90)
	local ratio = math.min(width, height) / math.max(width, height)
	local rotatedFov = math.deg(2 * math.atan(math.tan(math.rad(fov * 0.5)) * ratio))

	self.inner:SetLookAng(look)
	self.inner:SetFOV(math.Clamp(rotatedFov, 5, 120))
end

NETWORK.icon.spinSpeed = 70
NETWORK.icon.bSpin = true

function PANEL:IsHoveredDeep()
	if (!NETWORK.icon.bSpin or self.bFallback) then
		return false
	end

	local hovered = vgui.GetHoveredPanel()

	if (!IsValid(hovered)) then
		return false
	end

	local parent = self:GetParent()

	if (hovered == self or hovered == parent) then
		return true
	end

	return IsValid(parent) and hovered:HasParent(parent)
end

function PANEL:Think()
	if (!self.bFramed) then
		self:Frame()

		return
	end

	if (!self.baseAngles or !IsValid(self.inner)) then
		return
	end

	local entity = self.inner:GetEntity()

	if (!IsValid(entity)) then
		return
	end

	local frame = math.min(FrameTime(), 0.05)
	local bHover = self:IsHoveredDeep()

	if (bHover) then
		self.spin = ((self.spin or 0) + NETWORK.icon.spinSpeed * frame) % 360
	elseif ((self.spin or 0) != 0) then

		local remaining = self.spin > 180 and (360 - self.spin) or -self.spin
		local step = math.min(math.abs(remaining), NETWORK.icon.spinSpeed * 3 * frame)

		self.spin = (self.spin + (remaining > 0 and step or -step)) % 360

		if (math.abs(remaining) <= step + 0.01) then
			self.spin = 0
		end
	else
		return
	end

	entity:SetAngles(Angle(self.baseAngles.p, self.baseAngles.y + self.spin, self.baseAngles.r))
end

function PANEL:Refresh()
	if (!self.item) then
		return
	end

	local bCustom = NETWORK.icon.Get(self.item.id) != nil

	if (bCustom != self.bCustom or bCustom) then
		self:Build()
	end
end

function PANEL:PerformLayout(width, height)
	if (!IsValid(self.inner)) then
		return
	end

	if (self.bFallback) then
		local size = math.min(width, height)

		self.inner:SetSize(size, size)
		self.inner:SetPos(math.Round((width - size) * 0.5),
			math.Round((height - size) * 0.5))

		return
	end

	self.inner:SetSize(width, height)
	self.inner:SetPos(0, 0)

	self:ApplyRotation()
end

function PANEL:SetAlphaValue(alpha)
	self.alphaValue = alpha

	if (IsValid(self.inner)) then
		self.inner:SetAlpha(alpha)
	end
end

vgui.Register("nwItemIcon", PANEL, "DPanel")

hook.Add("NetworkIconsUpdated", "nwItemIcon", function()
	for panel in pairs(NETWORK.icon.panels) do
		if (IsValid(panel)) then
			panel:Refresh()
		else
			NETWORK.icon.panels[panel] = nil
		end
	end
end)
