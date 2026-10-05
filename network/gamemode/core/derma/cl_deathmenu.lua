local PANEL = {}

function PANEL:Init()
	NETWORK.gui.death = self

	self.alpha = 0
	self.scale = 0
	self.bClosing = false
	self.startTime = CurTime()

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:OnRemove()
	if (NETWORK.gui.death == self) then
		NETWORK.gui.death = nil
	end
end

function PANEL:Close()
	self.bClosing = true
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 2.2)
	self.scale = NETWORK.util.Approach(self.scale or 0, self.bClosing and 0 or 1, 3)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

local HITGROUPS = {

	[HITGROUP_HEAD] = {x = 0.50, y = 0.07, name = "woundHead"},
	[HITGROUP_CHEST] = {x = 0.50, y = 0.25, name = "woundChest"},
	[HITGROUP_STOMACH] = {x = 0.50, y = 0.40, name = "woundStomach"},
	[HITGROUP_LEFTARM] = {x = 0.17, y = 0.42, name = "woundArmLeft"},
	[HITGROUP_RIGHTARM] = {x = 0.83, y = 0.42, name = "woundArmRight"},
	[HITGROUP_LEFTLEG] = {x = 0.38, y = 0.72, name = "woundLegLeft"},
	[HITGROUP_RIGHTLEG] = {x = 0.62, y = 0.72, name = "woundLegRight"}
}

local BODY = {
	{0.0000, 0.0091, 0.4317, 0.1367},
	{0.0091, 0.0091, 0.4100, 0.1800},
	{0.0182, 0.0091, 0.3948, 0.2082},
	{0.0273, 0.0091, 0.3883, 0.2234},
	{0.0364, 0.0091, 0.3839, 0.2321},
	{0.0455, 0.0091, 0.3818, 0.2343},
	{0.0545, 0.0091, 0.3818, 0.2343},
	{0.0636, 0.0091, 0.3774, 0.2430},
	{0.0727, 0.0091, 0.3774, 0.2430},
	{0.0818, 0.0091, 0.3796, 0.2386},
	{0.0909, 0.0091, 0.3883, 0.2213},
	{0.1000, 0.0091, 0.4035, 0.1909},
	{0.1091, 0.0091, 0.4121, 0.1757},
	{0.1182, 0.0091, 0.4187, 0.1627},
	{0.1273, 0.0091, 0.4165, 0.1670},
	{0.1364, 0.0091, 0.4056, 0.1909},
	{0.1455, 0.0091, 0.3774, 0.2495},
	{0.1545, 0.0091, 0.3362, 0.3319},
	{0.1636, 0.0091, 0.2907, 0.4273},
	{0.1727, 0.0091, 0.2473, 0.5119},
	{0.1818, 0.0091, 0.2191, 0.5662},
	{0.1909, 0.0091, 0.2017, 0.6009},
	{0.2000, 0.0091, 0.1887, 0.6269},
	{0.2091, 0.0091, 0.1779, 0.6464},
	{0.2182, 0.0091, 0.1714, 0.6594},
	{0.2273, 0.0091, 0.1649, 0.6725},
	{0.2364, 0.0091, 0.1627, 0.6790},
	{0.2455, 0.0091, 0.1584, 0.6855},
	{0.2545, 0.0091, 0.1518, 0.6963},
	{0.2636, 0.0091, 0.1475, 0.7072},
	{0.2727, 0.0091, 0.1410, 0.7180},
	{0.2818, 0.0091, 0.1367, 0.7267},
	{0.2909, 0.0091, 0.1323, 0.1453},
	{0.2909, 0.0091, 0.2820, 0.4382},
	{0.2909, 0.0091, 0.7267, 0.1410},
	{0.3000, 0.0091, 0.1280, 0.1410},
	{0.3000, 0.0091, 0.2907, 0.4208},
	{0.3000, 0.0091, 0.7332, 0.1410},
	{0.3091, 0.0091, 0.1236, 0.1388},
	{0.3091, 0.0091, 0.2993, 0.4056},
	{0.3091, 0.0091, 0.7419, 0.1367},
	{0.3182, 0.0091, 0.1193, 0.1345},
	{0.3182, 0.0091, 0.3059, 0.3905},
	{0.3182, 0.0091, 0.7505, 0.1323},
	{0.3273, 0.0091, 0.1150, 0.1302},
	{0.3273, 0.0091, 0.3145, 0.3753},
	{0.3273, 0.0091, 0.7592, 0.1280},
	{0.3364, 0.0091, 0.1085, 0.1280},
	{0.3364, 0.0091, 0.3210, 0.3644},
	{0.3364, 0.0091, 0.7679, 0.1258},
	{0.3455, 0.0091, 0.0976, 0.1280},
	{0.3455, 0.0091, 0.3254, 0.3536},
	{0.3455, 0.0091, 0.7766, 0.1280},
	{0.3545, 0.0091, 0.0868, 0.1302},
	{0.3545, 0.0091, 0.3275, 0.3492},
	{0.3545, 0.0091, 0.7831, 0.1323},
	{0.3636, 0.0091, 0.0781, 0.1323},
	{0.3636, 0.0091, 0.3319, 0.3406},
	{0.3636, 0.0091, 0.7918, 0.1323},
	{0.3727, 0.0091, 0.0694, 0.1345},
	{0.3727, 0.0091, 0.3319, 0.3406},
	{0.3727, 0.0091, 0.7961, 0.1367},
	{0.3818, 0.0091, 0.0629, 0.1345},
	{0.3818, 0.0091, 0.3319, 0.3406},
	{0.3818, 0.0091, 0.8026, 0.1367},
	{0.3909, 0.0091, 0.0564, 0.1345},
	{0.3909, 0.0091, 0.3297, 0.3449},
	{0.3909, 0.0091, 0.8091, 0.1345},
	{0.4000, 0.0091, 0.0521, 0.1323},
	{0.4000, 0.0091, 0.3275, 0.3514},
	{0.4000, 0.0091, 0.8178, 0.1323},
	{0.4091, 0.0091, 0.0477, 0.1258},
	{0.4091, 0.0091, 0.3232, 0.3601},
	{0.4091, 0.0091, 0.8286, 0.1258},
	{0.4182, 0.0091, 0.0412, 0.1215},
	{0.4182, 0.0091, 0.3189, 0.3688},
	{0.4182, 0.0091, 0.8395, 0.1193},
	{0.4273, 0.0091, 0.0369, 0.1128},
	{0.4273, 0.0091, 0.3145, 0.3774},
	{0.4273, 0.0091, 0.8525, 0.1106},
	{0.4364, 0.0091, 0.0325, 0.1041},
	{0.4364, 0.0091, 0.3080, 0.3905},
	{0.4364, 0.0091, 0.8655, 0.1041},
	{0.4455, 0.0091, 0.0282, 0.0954},
	{0.4455, 0.0091, 0.3015, 0.4035},
	{0.4455, 0.0091, 0.8785, 0.0954},
	{0.4545, 0.0091, 0.0217, 0.0889},
	{0.4545, 0.0091, 0.2950, 0.4165},
	{0.4545, 0.0091, 0.8894, 0.0889},
	{0.4636, 0.0091, 0.0174, 0.0846},
	{0.4636, 0.0091, 0.2863, 0.4317},
	{0.4636, 0.0091, 0.9002, 0.0824},
	{0.4727, 0.0091, 0.0130, 0.0803},
	{0.4727, 0.0091, 0.2798, 0.4447},
	{0.4727, 0.0091, 0.9089, 0.0781},
	{0.4818, 0.0091, 0.0087, 0.0868},
	{0.4818, 0.0091, 0.2733, 0.4577},
	{0.4818, 0.0091, 0.9089, 0.0824},
	{0.4909, 0.0091, 0.0043, 0.0998},
	{0.4909, 0.0091, 0.2668, 0.4707},
	{0.4909, 0.0091, 0.8980, 0.0976},
	{0.5000, 0.0091, 0.0022, 0.1106},
	{0.5000, 0.0091, 0.2603, 0.4837},
	{0.5000, 0.0091, 0.8915, 0.1063},
	{0.5091, 0.0091, 0.0000, 0.1150},
	{0.5091, 0.0091, 0.2560, 0.4924},
	{0.5091, 0.0091, 0.8894, 0.1106},
	{0.5182, 0.0091, 0.0000, 0.1171},
	{0.5182, 0.0091, 0.2516, 0.5011},
	{0.5182, 0.0091, 0.8850, 0.1150},
	{0.5273, 0.0091, 0.0022, 0.0607},
	{0.5273, 0.0091, 0.0846, 0.0369},
	{0.5273, 0.0091, 0.2495, 0.5076},
	{0.5273, 0.0091, 0.8807, 0.0369},
	{0.5273, 0.0091, 0.9393, 0.0586},
	{0.5364, 0.0091, 0.0065, 0.0586},
	{0.5364, 0.0091, 0.0889, 0.0325},
	{0.5364, 0.0091, 0.2451, 0.5141},
	{0.5364, 0.0091, 0.8807, 0.0325},
	{0.5364, 0.0091, 0.9371, 0.0564},
	{0.5455, 0.0091, 0.0130, 0.0629},
	{0.5455, 0.0091, 0.0976, 0.0217},
	{0.5455, 0.0091, 0.2430, 0.2560},
	{0.5455, 0.0091, 0.5054, 0.2560},
	{0.5455, 0.0091, 0.8850, 0.0195},
	{0.5455, 0.0091, 0.9262, 0.0607},
	{0.5545, 0.0091, 0.0239, 0.0651},
	{0.5545, 0.0091, 0.2408, 0.2473},
	{0.5545, 0.0091, 0.5163, 0.2473},
	{0.5545, 0.0091, 0.9111, 0.0651},
	{0.5636, 0.0091, 0.0412, 0.0521},
	{0.5636, 0.0091, 0.2386, 0.2430},
	{0.5636, 0.0091, 0.5228, 0.2430},
	{0.5636, 0.0091, 0.9089, 0.0521},
	{0.5727, 0.0091, 0.0759, 0.0108},
	{0.5727, 0.0091, 0.2386, 0.2386},
	{0.5727, 0.0091, 0.5271, 0.2386},
	{0.5727, 0.0091, 0.9154, 0.0130},
	{0.5818, 0.0091, 0.2386, 0.2321},
	{0.5818, 0.0091, 0.5336, 0.2321},
	{0.5909, 0.0091, 0.2386, 0.2256},
	{0.5909, 0.0091, 0.5380, 0.2278},
	{0.6000, 0.0091, 0.2386, 0.2191},
	{0.6000, 0.0091, 0.5445, 0.2213},
	{0.6091, 0.0091, 0.2408, 0.2126},
	{0.6091, 0.0091, 0.5510, 0.2126},
	{0.6182, 0.0091, 0.2430, 0.2039},
	{0.6182, 0.0091, 0.5575, 0.2039},
	{0.6273, 0.0091, 0.2451, 0.1952},
	{0.6273, 0.0091, 0.5640, 0.1952},
	{0.6364, 0.0091, 0.2473, 0.1866},
	{0.6364, 0.0091, 0.5705, 0.1866},
	{0.6455, 0.0091, 0.2495, 0.1779},
	{0.6455, 0.0091, 0.5770, 0.1779},
	{0.6545, 0.0091, 0.2516, 0.1692},
	{0.6545, 0.0091, 0.5835, 0.1692},
	{0.6636, 0.0091, 0.2538, 0.1605},
	{0.6636, 0.0091, 0.5900, 0.1605},
	{0.6727, 0.0091, 0.2538, 0.1562},
	{0.6727, 0.0091, 0.5965, 0.1540},
	{0.6818, 0.0091, 0.2516, 0.1540},
	{0.6818, 0.0091, 0.6009, 0.1518},
	{0.6909, 0.0091, 0.2473, 0.1540},
	{0.6909, 0.0091, 0.6052, 0.1518},
	{0.7000, 0.0091, 0.2408, 0.1540},
	{0.7000, 0.0091, 0.6095, 0.1540},
	{0.7091, 0.0091, 0.2364, 0.1540},
	{0.7091, 0.0091, 0.6161, 0.1518},
	{0.7182, 0.0091, 0.2299, 0.1540},
	{0.7182, 0.0091, 0.6226, 0.1518},
	{0.7273, 0.0091, 0.2234, 0.1518},
	{0.7273, 0.0091, 0.6312, 0.1497},
	{0.7364, 0.0091, 0.2148, 0.1540},
	{0.7364, 0.0091, 0.6377, 0.1497},
	{0.7455, 0.0091, 0.2082, 0.1562},
	{0.7455, 0.0091, 0.6399, 0.1540},
	{0.7545, 0.0091, 0.2017, 0.1627},
	{0.7545, 0.0091, 0.6377, 0.1627},
	{0.7636, 0.0091, 0.1974, 0.1670},
	{0.7636, 0.0091, 0.6377, 0.1670},
	{0.7727, 0.0091, 0.1952, 0.1692},
	{0.7727, 0.0091, 0.6377, 0.1714},
	{0.7818, 0.0091, 0.1931, 0.1714},
	{0.7818, 0.0091, 0.6377, 0.1735},
	{0.7909, 0.0091, 0.1931, 0.1714},
	{0.7909, 0.0091, 0.6399, 0.1714},
	{0.8000, 0.0091, 0.1931, 0.1692},
	{0.8000, 0.0091, 0.6421, 0.1692},
	{0.8091, 0.0091, 0.1931, 0.1649},
	{0.8091, 0.0091, 0.6464, 0.1649},
	{0.8182, 0.0091, 0.1931, 0.1584},
	{0.8182, 0.0091, 0.6529, 0.1562},
	{0.8273, 0.0091, 0.1952, 0.1497},
	{0.8273, 0.0091, 0.6594, 0.1475},
	{0.8364, 0.0091, 0.1974, 0.1410},
	{0.8364, 0.0091, 0.6659, 0.1388},
	{0.8455, 0.0091, 0.1996, 0.1302},
	{0.8455, 0.0091, 0.6746, 0.1280},
	{0.8545, 0.0091, 0.2017, 0.1215},
	{0.8545, 0.0091, 0.6811, 0.1193},
	{0.8636, 0.0091, 0.2039, 0.1128},
	{0.8636, 0.0091, 0.6876, 0.1106},
	{0.8727, 0.0091, 0.2061, 0.1041},
	{0.8727, 0.0091, 0.6941, 0.1041},
	{0.8818, 0.0091, 0.2082, 0.0954},
	{0.8818, 0.0091, 0.7007, 0.0954},
	{0.8909, 0.0091, 0.2082, 0.0911},
	{0.8909, 0.0091, 0.7050, 0.0911},
	{0.9000, 0.0091, 0.2061, 0.0889},
	{0.9000, 0.0091, 0.7093, 0.0889},
	{0.9091, 0.0091, 0.2061, 0.0868},
	{0.9091, 0.0091, 0.7093, 0.0911},
	{0.9182, 0.0091, 0.2039, 0.0889},
	{0.9182, 0.0091, 0.7115, 0.0911},
	{0.9273, 0.0091, 0.1952, 0.0911},
	{0.9273, 0.0091, 0.7180, 0.0911},
	{0.9364, 0.0091, 0.1822, 0.1063},
	{0.9364, 0.0091, 0.7158, 0.1041},
	{0.9455, 0.0091, 0.1692, 0.1236},
	{0.9455, 0.0091, 0.7115, 0.1215},
	{0.9545, 0.0091, 0.1540, 0.1410},
	{0.9545, 0.0091, 0.7115, 0.1367},
	{0.9636, 0.0091, 0.1388, 0.1540},
	{0.9636, 0.0091, 0.7115, 0.1540},
	{0.9727, 0.0091, 0.1258, 0.1605},
	{0.9727, 0.0091, 0.7180, 0.1605},
	{0.9818, 0.0091, 0.1236, 0.1345},
	{0.9818, 0.0091, 0.7462, 0.1367},
	{0.9909, 0.0091, 0.1258, 0.1193},
	{0.9909, 0.0091, 0.7592, 0.1193},
}

local BODY_RATIO = 0.419

local function DrawBody(x, y, width, height, color)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	for _, strip in ipairs(BODY) do
		surface.DrawRect(
			math.Round(x + strip[3] * width),
			math.Round(y + strip[1] * height),
			math.max(math.Round(strip[4] * width), 1),
			math.max(math.Round(strip[2] * height), 1))
	end
end

local function CenteredSpaced(text, font, x, y, color, spacing)
	local width = NETWORK.util.TextSpacedSize(text, font, spacing)

	NETWORK.util.DrawTextSpaced(text, font, math.Round(x - width * 0.5), y,
		color, spacing, TEXT_ALIGN_CENTER)
end

local function DrawIcon(path, x, y, size, color)
	local material = NETWORK.util.GetMaterial(path, "smooth")

	if (!material or material:IsError()) then
		return false
	end

	surface.SetMaterial(material)
	surface.SetDrawColor(0, 0, 0, (color.a or 255) * 0.5)
	surface.DrawTexturedRect(x + 1, y + 1, size, size)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawTexturedRect(x, y, size, size)

	return true
end

local HIT_PARTS = {
	[HITGROUP_HEAD] = "head",
	[HITGROUP_CHEST] = "chest",
	[HITGROUP_STOMACH] = "stomach",
	[HITGROUP_LEFTARM] = "armLeft",
	[HITGROUP_RIGHTARM] = "armRight",
	[HITGROUP_LEFTLEG] = "legLeft",
	[HITGROUP_RIGHTLEG] = "legRight"
}

local ASH = {}

for index = 1, 36 do
	ASH[index] = {
		x = (index * 0.618034) % 1,
		y = (index * 0.414214) % 1,
		speed = 0.012 + (index % 7) * 0.003,
		size = 1 + index % 3,
		phase = index * 1.7
	}
end

local function DrawTile(x, y, tileWidth, tileHeight, tile, fade)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local pad = Sc(10)
	local icon = Sc(18)
	local line = math.max(Sc(1), 1)

	surface.SetDrawColor(0, 0, 0, 140 * fade)
	surface.DrawRect(x, y, tileWidth, tileHeight)

	surface.SetDrawColor(255, 255, 255, 22 * fade)
	surface.DrawOutlinedRect(x, y, tileWidth, tileHeight, line)

	local labelX = x + pad
	local iconColor = ColorAlpha(tile[4] or theme.textDim, 200 * fade)

	if (DrawIcon("framework/icons/" .. tile[1] .. ".png", x + pad, y + pad, icon, iconColor)) then
		labelX = labelX + icon + Sc(8)
	else
		NETWORK.gui.DrawGlyph("dot", x + pad, y + pad, icon, iconColor)
		labelX = labelX + icon + Sc(8)
	end

	draw.SimpleText(NETWORK.util.Upper(tile[2]), "nwInvKey", labelX, y + pad + math.floor(icon * 0.5),
		ColorAlpha(theme.textFaint, 230 * fade), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(NETWORK.util.TruncateWidth(tile[3], "nwField", tileWidth - pad * 2), "nwField",
		x + pad, y + tileHeight - Sc(15), ColorAlpha(tile[4] or theme.text, 250 * fade),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local client = LocalPlayer()
	local alpha = util.EaseOut(self.alpha)
	local centerX = math.Round(width * 0.5)
	local report = NETWORK.death and NETWORK.death.report or {}
	local red = Color(214, 72, 66)
	local age = CurTime() - self.startTime
	local line = math.max(Sc(1), 1)

	local function Stage(from, length)
		return util.EaseOut(math.Clamp((age - from) / length, 0, 1)) * alpha
	end

	local dim = util.EaseInOut(math.Clamp(age / 1.5, 0, 1))

	surface.SetDrawColor(0, 0, 0, 245 * alpha * dim)
	surface.DrawRect(0, 0, width, height)

	if (dim < 0.999) then
		util.DrawVignette(0, 0, width, height,
			math.Round(math.max(width, height) * 0.6 * (1 - dim)), 255 * alpha)
	end

	util.DrawVignette(0, 0, width, height, math.Round(math.min(width, height) * 0.5),
		110 * alpha * dim, Color(16, 20, 30))

	local bandIn = Stage(0.4, 1.2)

	if (bandIn > 0.01) then
		local breath = 0.82 + math.sin(RealTime() * 0.6) * 0.18
		local bandAlpha = 120 * bandIn * breath
		local bandY = math.Round(height / 3)
		local bandHeight = math.Round(height / 3)
		local feather = math.Round(bandHeight * 0.3)
		local solid = Color(4, 5, 8, bandAlpha)
		local clear = Color(4, 5, 8, 0)

		util.DrawVGradient(0, bandY - feather, width, feather, clear, solid)
		surface.SetDrawColor(4, 5, 8, bandAlpha)
		surface.DrawRect(0, bandY, width, bandHeight)
		util.DrawVGradient(0, bandY + bandHeight, width, feather, solid, clear)
	end

	local ashIn = Stage(0.8, 1.5)

	for _, particle in ipairs(ASH) do
		local fall = (particle.y + (RealTime() * particle.speed)) % 1
		local ashX = (particle.x + math.sin(RealTime() * 0.4 + particle.phase) * 0.01) * width
		local fade = math.sin(fall * math.pi)
		local size = math.max(Sc(particle.size), 1)

		surface.SetDrawColor(170, 150, 150, 50 * fade * ashIn)
		surface.DrawRect(ashX, fall * height, size, size)
	end

	local titleIn = Stage(0.9, 0.8)
	local lineIn = Stage(1.3, 0.8)
	local subIn = Stage(1.5, 0.6)
	local titleY = math.Round(height * 0.38) + math.Round((1 - titleIn) * Sc(10))
	local lineY = math.Round(height * 0.38) + Sc(48)

	if (titleIn > 0.01) then
		CenteredSpaced(util.Upper(L("deathTitle")), "nwDeathTitle", centerX, titleY,
			ColorAlpha(theme.text, 250 * titleIn), Sc(8))
	end

	if (lineIn > 0.01) then
		local lineWidth = math.Round(Sc(360) * lineIn)

		surface.SetDrawColor(255, 255, 255, 90 * lineIn)
		surface.DrawRect(centerX - math.floor(lineWidth * 0.5), lineY, lineWidth, line)
	end

	if (subIn > 0.01) then
		CenteredSpaced(util.Upper(L("deathSubtitle")), "nwLabel", centerX, lineY + Sc(20),
			ColorAlpha(theme.textDim, 220 * subIn), Sc(4))
	end

	local partID = HIT_PARTS[report.group or 0]
	local lifetime = report.lifetime or 0
	local tiles = {}

	if (report.weapon and report.weapon != "") then
		tiles[#tiles + 1] = {"bolt", L("deathWeapon"), report.weapon}
	end

	if (report.attacker and report.attacker != "") then
		tiles[#tiles + 1] = {"person", L("deathKiller"), report.attacker}
	end

	if (report.distance) then
		tiles[#tiles + 1] = {"map", L("deathDistance"), report.distance .. " " .. L("questMetres")}
	end

	if (partID) then
		tiles[#tiles + 1] = {"visibility", L("deathCause"), L(NETWORK.wound.GetPart(partID).name), red}
	end

	if (report.lifetime) then
		tiles[#tiles + 1] = {"timer", L("deathLifetime"), string.format("%d:%02d",
			math.floor(lifetime / 60), lifetime % 60)}
	end

	local tileWidth = Sc(150)
	local tileHeight = Sc(56)
	local tileGap = Sc(10)
	local tileY = lineY + Sc(72)
	local tileMiddle = tileY + math.Round(tileHeight * 0.5)
	local body = NETWORK.medical and NETWORK.medical.body
	local bodyHeight = Sc(120)
	local bodyWidth = math.Round(bodyHeight * BODY_RATIO)
	local bodyGap = Sc(28)
	local bShowBody = partID != nil
	local rowWidth = #tiles * tileWidth + math.max(#tiles - 1, 0) * tileGap

	if (bShowBody) then
		rowWidth = rowWidth + bodyWidth + bodyGap
	end

	local cursor = centerX - math.Round(rowWidth * 0.5)

	if (bShowBody) then
		local bodyIn = Stage(1.8, 0.5)
		local bodyY = tileMiddle - math.Round(bodyHeight * 0.5) + math.Round((1 - bodyIn) * Sc(12))
		local pulse = 0.65 + math.abs(math.sin(RealTime() * 2.4)) * 0.35

		if (bodyIn > 0.01) then
			if (body and body.IsAvailable()) then
				body.Draw(cursor, bodyY, bodyWidth, bodyHeight,
					{[partID] = ColorAlpha(red, 255 * pulse * bodyIn)}, bodyIn, Color(58, 60, 66))

				local anchorX, anchorY = body.GetAnchor(partID, cursor, bodyY, bodyWidth, bodyHeight)
				local wave = (CurTime() % 1.6) / 1.6

				util.DrawSoftLight(anchorX, anchorY, Sc(40), Sc(40), red, 60 * bodyIn)
				util.DrawRing(anchorX, anchorY, Sc(3) + wave * Sc(12), math.max(Sc(1), 1),
					ColorAlpha(red, 170 * (1 - wave) * bodyIn), 24, 1)
			else
				DrawBody(cursor, bodyY, bodyWidth, bodyHeight, Color(236, 240, 245, 220 * bodyIn))

				local mark = HITGROUPS[report.group or 0]

				if (mark) then
					util.DrawSoftLight(cursor + math.Round(mark.x * bodyWidth),
						bodyY + math.Round(mark.y * bodyHeight), Sc(40), Sc(40), red,
						90 * pulse * bodyIn)
				end
			end
		end

		cursor = cursor + bodyWidth + bodyGap
	end

	for index, tile in ipairs(tiles) do
		local tileIn = Stage(1.8 + index * 0.08, 0.5)

		if (tileIn > 0.01) then
			DrawTile(cursor, tileY + math.Round((1 - tileIn) * Sc(12)), tileWidth, tileHeight,
				tile, tileIn)
		end

		cursor = cursor + tileWidth + tileGap
	end

	local barIn = Stage(2.0 + (#tiles + 1) * 0.08, 0.6)

	if (barIn > 0.01) then
		local respawn = client:GetNWFloat("nwRespawn", 0)
		local left = math.max(respawn - CurTime(), 0)
		local total = math.max(NETWORK.config.Get("respawnTime") or 12, 1)
		local fraction = 1 - math.Clamp(left / total, 0, 1)
		local barWidth = Sc(420)
		local barHeight = math.max(Sc(2), 2)
		local barX = centerX - math.Round(barWidth * 0.5)
		local barY = tileY + tileHeight + Sc(58) + math.Round((1 - barIn) * Sc(8))
		local bReady = left <= 0
		local accent = bReady and theme.positive or theme.combine
		local fill = math.Round(barWidth * fraction)

		surface.SetDrawColor(255, 255, 255, 22 * barIn)
		surface.DrawRect(barX, barY, barWidth, barHeight)

		if (fill > 0) then
			surface.SetDrawColor(accent.r, accent.g, accent.b, 240 * barIn)
			surface.DrawRect(barX, barY, fill, barHeight)
		end

		local textY = barY - Sc(14)
		local textX = barX
		local icon = Sc(16)
		local textColor = bReady and theme.positive or theme.text

		if (DrawIcon("framework/icons/" .. (bReady and "check_circle" or "timer") .. ".png", textX,
			textY - math.floor(icon * 0.5), icon, ColorAlpha(textColor, 240 * barIn))) then
			textX = textX + icon + Sc(8)
		end

		draw.SimpleText(bReady and L("deathRespawnReady") or (L("deathRespawn") .. " " ..
			string.format("%.0f", math.ceil(left))), "nwField", textX, textY,
			ColorAlpha(textColor, 245 * barIn), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local hint = L("deathHint")
		local hintIcon = Sc(12)
		local hintY = barY + barHeight + Sc(16)

		surface.SetFont("nwHudSmall")

		local hintWidth = surface.GetTextSize(hint)
		local hintX = centerX - math.floor((hintWidth + hintIcon + Sc(6)) * 0.5)

		if (DrawIcon("framework/icons/info.png", hintX, hintY - math.floor(hintIcon * 0.5), hintIcon,
			ColorAlpha(theme.textFaint, 220 * barIn))) then
			hintX = hintX + hintIcon + Sc(6)
		end

		draw.SimpleText(hint, "nwHudSmall", hintX, hintY, ColorAlpha(theme.textFaint, 220 * barIn),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwDeathMenu", PANEL, "EditablePanel")

NETWORK.death = NETWORK.death or {}

net.Receive("nwDeathReport", function()
	NETWORK.death.report = {
		group = net.ReadUInt(4),
		distance = net.ReadUInt(12),
		weapon = net.ReadString(),
		attacker = net.ReadString(),
		lifetime = net.ReadUInt(18)
	}
end)

local function IsDead()
	local client = LocalPlayer()

	return IsValid(client) and client:HasCharacter() and !client:Alive()
end

hook.Add("Think", "nwDeath", function()
	if (IsDead()) then
		if (!IsValid(NETWORK.gui.death)) then
			vgui.Create("nwDeathMenu")
		end

		return
	end

	if (IsValid(NETWORK.gui.death)) then
		NETWORK.gui.death:Close()
	end
end)

NETWORK.view.Register("death", 5, function(client, view)
	if (!IsDead()) then
		return
	end

	local ragdoll = client:GetNWEntity("nwRagdoll")

	if (!IsValid(ragdoll)) then
		return
	end

	local attachment = ragdoll:LookupAttachment("eyes")
	local data = attachment and attachment > 0 and ragdoll:GetAttachment(attachment)

	if (!data) then
		local bone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")

		if (!bone) then
			return
		end

		local position, boneAngles = ragdoll:GetBonePosition(bone)

		data = {Pos = position, Ang = boneAngles}
	end

	view.origin = data.Pos
	view.angles = data.Ang
	view.drawviewer = true

	return "stop"
end)

hook.Add("GetGameplaySoundVolume", "nwDeathSilence", function()
	local target = IsDead() and 0.04 or 1
	local current = NETWORK.death.volume or 1

	current = math.Approach(current, target, FrameTime() * 2)

	NETWORK.death.volume = current

	if (current >= 0.999) then
		return
	end

	return current
end)

hook.Add("HUDShouldDraw", "nwDeath", function(element)
	if (IsDead() and element != "CHudChat") then
		return false
	end
end)
