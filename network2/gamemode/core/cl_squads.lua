-- Squads, client (sh_squads.lua): the list, the block in the HUD of the Alliance, the outline of the
-- members through the walls and the squad mark over their heads.
--   the outline   thin and sharp (not a soft halo): the members and their weapons are drawn white
--                 into a texture, the texture is laid around them shifted by a pixel or two in eight
--                 directions where they themselves are not (the stencil) - a line around the body,
--                 seen through the walls; blue for Civil Protection, red for the Combine
--   the mark      materials/network2/squad/icon_combine_squad1.png in the colour of the side, the
--                 leader's yellow; over the head, a little smaller with the distance
-- nw_squad_outline 0 - no outline.

local SQ = NW.squads
local outline = CreateClientConVar("nw_squad_outline", "1", true, false, "Контур отряда сквозь стены")

local MARK = Material("network2/squad/icon_combine_squad1.png", "smooth mips")
local EMBLEM = Material("network2/squad/icon_combine_squad2.png", "smooth mips")

-- ------------------------------------------------------------------- sync --
net.Receive("nwSquads", function()
	local list = util.JSONToTable(net.ReadString() or "") or {}
	local out = {}

	for _, data in ipairs(list) do
		local squad = {id = data.id, name = data.name, side = data.side, succession = data.succession,
			created = data.created, leader = Entity(data.leader or 0), members = {}}

		for _, index in ipairs(data.members or {}) do
			squad.members[#squad.members + 1] = Entity(index)
		end

		out[data.id] = squad
	end

	SQ.list = out
end)

function SQ.Action(action, arg)
	net.Start("nwSquadAction")
		net.WriteString(action)
		net.WriteString(tostring(arg or ""))
	net.SendToServer()
end

-- the other members of my squad close enough to matter
function SQ.Mates()
	local me = LocalPlayer()
	local squad = SQ.Of(me)
	local out = {}

	for _, member in ipairs(SQ.Members(squad)) do
		if (member != me and member:Alive() and !member:IsDormant() and !(NW.Hidden and NW.Hidden(member))) then
			out[#out + 1] = member
		end
	end

	return out, squad
end

-- ---------------------------------------------------------------- the HUD --
-- called by the HUD of the Alliance (cl_combinehud.lua) under the system lines, with its own
-- text and bar functions (the curve and the sway come with them)
function SQ.DrawHud(x, y, Text, Bar)
	local me = LocalPlayer()
	local squad = SQ.Of(me)

	if (!squad) then
		return y
	end

	local sw, sh = ScrW(), ScrH()
	local color = SQ.colors[squad.side] or SQ.colors.cp

	y = y + sh * 0.02
	Text("ОТРЯД :: " .. NW.terminal.Upper(squad.name), "nwCmbHead", x, y, color, TEXT_ALIGN_LEFT)
	y = y + sh * 0.032
	Bar(x, y, sw * 0.12, 2, ColorAlpha(color, 210))
	y = y + sh * 0.01

	for _, member in ipairs(SQ.Members(squad)) do
		local leader = member == squad.leader
		local tint = leader and SQ.colors.leader or color
		local hp = member:Alive() and math.Clamp(member:Health() / math.max(member:GetMaxHealth(), 1), 0, 1) or 0
		local name = NW.terminal.Upper(member:Nick()) .. (leader and "  [Л]" or "") .. (member == me and "  ◂" or "")

		Text(name, "nwCmbSmall", x + sh * 0.006, y, member:Alive() and tint or Color(150, 60, 56), TEXT_ALIGN_LEFT, false)
		Bar(x + sh * 0.006, y + sh * 0.02, sw * 0.08, 1, ColorAlpha(color, 50))
		Bar(x + sh * 0.006, y + sh * 0.02, sw * 0.08 * hp, 1, ColorAlpha(tint, 200))
		y = y + sh * 0.028
	end

	return y
end

-- ------------------------------------------------------------ the outline --
local W, H = ScrW(), ScrH()
local mask, maskMaterial
local WHITE = CreateMaterial("nwSquadWhite", "UnlitGeneric", {["$basetexture"] = "color/white", ["$model"] = 1})

local function Targets()
	if (!outline:GetBool() or !NW.zones.IsAlliance(LocalPlayer())) then
		return {}
	end

	return (SQ.Mates())
end

local function Mask()
	if (!mask or W != ScrW() or H != ScrH()) then
		W, H = ScrW(), ScrH()
		mask = GetRenderTargetEx("nwSquadMask" .. W .. "x" .. H, W, H, RT_SIZE_FULL_FRAME_BUFFER, MATERIAL_RT_DEPTH_SEPARATE,
			bit.bor(1, 256), 0, IMAGE_FORMAT_RGBA8888)
		maskMaterial = CreateMaterial("nwSquadMask" .. W .. "x" .. H, "UnlitGeneric", {
			["$basetexture"] = mask:GetName(),
			["$additive"] = 1,
			["$vertexcolor"] = 1,
			["$vertexalpha"] = 1,
			["$ignorez"] = 1
		})
	end

	return mask, maskMaterial
end

local function DrawBodies(list)
	for _, member in ipairs(list) do
		member:DrawModel()

		local weapon = member:GetActiveWeapon()

		if (IsValid(weapon)) then
			weapon:DrawModel()
		end
	end
end

local OFFSETS = {{-2, 0}, {2, 0}, {0, -2}, {0, 2}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}}

hook.Add("PostDrawEffects", "nwSquadOutline", function()
	local list = Targets()

	if (#list == 0) then
		return
	end

	local squad = SQ.Of(LocalPlayer())
	local color = SQ.colors[squad and squad.side or "cp"]
	local rt, material = Mask()

	-- the bodies, white, into the texture
	render.PushRenderTarget(rt)
		render.Clear(0, 0, 0, 0, true, true)
		cam.Start3D()
			render.SuppressEngineLighting(true)
			render.MaterialOverride(WHITE)
			render.SetColorModulation(1, 1, 1)
			DrawBodies(list)
			render.MaterialOverride()
			render.SuppressEngineLighting(false)
		cam.End3D()
	render.PopRenderTarget()

	-- where the bodies are on the screen (through the walls) - not to be painted over
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_REPLACE)

	cam.Start3D()
		cam.IgnoreZ(true)
		render.SetBlend(0)
		render.MaterialOverride(WHITE)
		DrawBodies(list)
		render.MaterialOverride()
		render.SetBlend(1)
		cam.IgnoreZ(false)
	cam.End3D()

	-- the shifted silhouettes around them: the line
	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	cam.Start2D()
		surface.SetMaterial(material)
		surface.SetDrawColor(color.r, color.g, color.b, 255)

		for _, offset in ipairs(OFFSETS) do
			surface.DrawTexturedRect(offset[1], offset[2], W, H)
		end
	cam.End2D()

	render.SetStencilEnable(false)
end)

-- --------------------------------------------------------------- the marks --
surface.CreateFont("nwSquadMark", {font = "JetBrains Mono ExtraBold", size = math.max(11, math.Round(ScrH() * 0.013)),
	weight = 800, extended = true, antialias = true})

hook.Add("HUDPaint", "nwSquadMarks", function()
	if (!NW.zones.IsAlliance(LocalPlayer())) then
		return
	end

	local list, squad = SQ.Mates()

	if (!squad) then
		return
	end

	local eye = EyePos()
	local sh = ScrH()

	for _, member in ipairs(list) do
		local head = member:EyePos() + Vector(0, 0, 14)
		local screen = head:ToScreen()

		if (screen.visible) then
			local distance = eye:Distance(head)
			local size = math.Clamp(sh * 0.028 * (600 / math.max(distance, 300)), sh * 0.014, sh * 0.03)
			local color = member == squad.leader and SQ.colors.leader or SQ.colors[squad.side]

			surface.SetMaterial(MARK)
			surface.SetDrawColor(0, 0, 0, 160)
			surface.DrawTexturedRect(screen.x - size / 2 + 1, screen.y - size + 1, size, size)
			surface.SetDrawColor(color)
			surface.DrawTexturedRect(screen.x - size / 2, screen.y - size, size, size)

			draw.SimpleTextOutlined(math.Round(distance / 52.5) .. " м", "nwSquadMark", screen.x, screen.y + 2,
				ColorAlpha(color, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 160))
		end
	end
end)

SQ.emblem = EMBLEM
