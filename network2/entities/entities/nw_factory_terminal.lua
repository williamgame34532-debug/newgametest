AddCSLuaFile()

-- The terminal of the factory (sh_cwu.lua): a screen in the look of the civic terminal, only text - how
-- to work at the factory and how to rise.
--   the first page   your file: hired or not, the rank, the experience and how far the next rank is,
--                    the stations open to you, the next step, the time of the city (sh_schedule.lua)
--   then             the sections of the instruction (CW.instruction): the steps, the line, the ranks,
--                    the pay - from the settings of the server
--   E                the next page;  Alt + E - the previous;  Shift + E - get hired / quit right here
-- The model: the C menu → «Настройки».

ENT.Type = "anim"
ENT.PrintName = "Терминал завода"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/props_combine/combine_interface001.mdl"

if (SERVER) then
	util.AddNetworkString("nwFactoryTerminal")

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create(self.ClassName)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0
		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = self.nwModel or self.Model

		self:SetModel(util.IsValidModel(model) and model or "models/props_lab/monitor01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer() or client:GetCharacterID() == 0) then
			return
		end

		if (client:KeyDown(IN_SPEED)) then
			local hired = client:GetNW2Bool("nwFactoryHired", false)

			if (!hired and NW.zones.IsAlliance(client)) then
				return NW.Notify(client, "Служащие Альянса на заводе не работают")
			end

			NW.cwu.Hire(client, !hired)
		end

		net.Start("nwFactoryTerminal")
			net.WriteEntity(self)
			net.WriteInt(client:KeyDown(IN_SPEED) and 0 or (client:KeyDown(IN_WALK) and -1 or 1), 3)
		net.Send(client)

		self:EmitSound("buttons/combine_button" .. math.random(1, 3) .. ".wav", 55)
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_factory_terminal", {
			Save = function(entity)
				return {model = entity.nwModel}
			end,
			Load = function(entity, data)
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

local CW = NW.cwu
local I = NW.items

surface.CreateFont("nwFTermTitle", {font = "Montserrat SemiBold", size = 40, weight = 600, extended = true,
	antialias = true})
surface.CreateFont("nwFTermHead", {font = "Montserrat SemiBold", size = 28, weight = 600, extended = true,
	antialias = true})
surface.CreateFont("nwFTermText", {font = "Exo 2", size = 25, weight = 500, extended = true, antialias = true})
surface.CreateFont("nwFTermSmall", {font = "Exo 2", size = 20, weight = 500, extended = true, antialias = true})

local W, H = 720, 440
local AMBER = Color(232, 170, 64)
local TEXT = Color(236, 232, 222)
local DIM = Color(170, 164, 150)
local GREEN = Color(130, 214, 120)
local RED = Color(232, 100, 80)

net.Receive("nwFactoryTerminal", function()
	local entity = net.ReadEntity()
	local step = net.ReadInt(3)

	if (IsValid(entity)) then
		local count = #CW.instruction + 1

		entity.page = ((entity.page or 0) + step) % count
		entity.flip = RealTime()
	end
end)

local function ItemName(id)
	local item = id and I.Get(id)

	return item and item.name or tostring(id)
end

-- the lines of a page: {text, font, color}
local function Personal()
	local client = LocalPlayer()
	local hired = client:GetNW2Bool("nwFactoryHired", false)
	local xp = client:GetNW2Int("nwFactoryXP", 0)
	local rank = CW.Rank(xp)
	local nextRank = CW.ranks[rank + 1]
	local out = {}

	out[#out + 1] = {client:Nick() .. "  ·  " .. (hired and "оформлен на заводе" or "не оформлен"), "nwFTermHead",
		hired and GREEN or RED}
	out[#out + 1] = {"Ранг: " .. CW.ranks[rank].name .. "   ·   опыт " .. xp .. (nextRank and (" / " .. nextRank.xp) or ""),
		"nwFTermText", TEXT, bar = nextRank and math.Clamp((xp - CW.ranks[rank].xp) / (nextRank.xp - CW.ranks[rank].xp), 0, 1)}

	local open, best, bestXP = {}, nil, 0

	for _, id in ipairs(CW.order) do
		local station = CW.stations[id]

		if (station.rank <= rank) then
			open[#open + 1] = station.name

			local gain = station.buys and 2 or station.xp

			if (gain > bestXP and !station.buys) then
				best, bestXP = station, gain
			end
		end
	end

	out[#out + 1] = {"Вам открыто: " .. table.concat(open, ", "), "nwFTermText", TEXT}

	if (!hired) then
		out[#out + 1] = {"Следующий шаг: Shift + E — оформиться прямо здесь.", "nwFTermText", AMBER}
	elseif (nextRank) then
		local left = nextRank.xp - xp

		out[#out + 1] = {"До ранга «" .. nextRank.name .. "»: " .. left .. " опыта — примерно " ..
			math.ceil(left / math.max(bestXP, 1)) .. " операций на станции «" .. (best and best.name or "?") ..
			"» (продукцию — на «Отгрузку»).", "nwFTermText", AMBER}
	else
		out[#out + 1] = {"Высший ранг: все станции открыты, оплата +25%.", "nwFTermText", GREEN}
	end

	if (NW.schedule) then
		local phase, left = NW.schedule.Current()

		out[#out + 1] = {"Сейчас: " .. phase.name .. " (ещё " .. math.ceil(left / 60) .. " мин)" ..
			(NW.schedule.Allows("factory") and " — завод работает" or " — завод закрыт"), "nwFTermText",
			NW.schedule.Allows("factory") and GREEN or RED}
	end

	return "Ваше дело", out
end

local function Section(section)
	local out = {}

	if (section.steps) then
		for index, step in ipairs(section.steps) do
			out[#out + 1] = {index .. ". " .. step[1], "nwFTermHead", AMBER}
			out[#out + 1] = {step[2], "nwFTermSmall", TEXT}
		end
	elseif (section.id == "line") then
		for index, id in ipairs(CW.order) do
			local station = CW.stations[id]
			local take = {}

			for item, amount in pairs(station.take) do
				take[#take + 1] = amount .. "× " .. ItemName(item)
			end

			out[#out + 1] = {index .. ". " .. station.name .. ":  " .. (#take > 0 and table.concat(take, ", ") or
				(station.buys and "любая продукция" or "ничего")) .. "  →  " .. (station.give and ItemName(station.give) or
				"токены") .. "  (" .. station.time .. " с, «" .. CW.ranks[station.rank].name .. "»)", "nwFTermSmall", TEXT}
		end

		out[#out + 1] = {section.text, "nwFTermSmall", DIM}
	elseif (section.id == "ranks") then
		for _, rank in ipairs(CW.ranks) do
			out[#out + 1] = {rank.name .. "  —  " .. rank.xp .. " опыта", "nwFTermText", TEXT}
		end

		out[#out + 1] = {section.text, "nwFTermSmall", DIM}
	elseif (section.id == "pay") then
		for _, id in ipairs(CW.order) do
			local station = CW.stations[id]

			out[#out + 1] = {station.name .. ":  " .. (station.buys and "1–14 ток., +1–8 опыта" or (station.pay ..
				" ток., +" .. station.xp .. " опыта")), "nwFTermText", TEXT}
		end

		out[#out + 1] = {section.text, "nwFTermSmall", DIM}
	else
		out[#out + 1] = {section.text or "", "nwFTermSmall", TEXT}
	end

	return section.title, out
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local distance = EyePos():DistToSqr(self:GetPos())

	if (distance > 400 * 400) then
		return
	end

	local alpha = math.Clamp((400 - math.sqrt(distance)) / 100, 0, 1)
	local page = self.page or 0
	local title, lines

	if (page == 0) then
		title, lines = Personal()
	else
		title, lines = Section(CW.instruction[page])
	end

	-- the screen: in front of the model, upright, facing where the model faces
	local maxs = self:OBBMaxs()
	local pos = self:LocalToWorld(Vector(maxs.x + 3, 0, maxs.z * 0.55 + 12))
	local angle = self:GetAngles()

	angle:RotateAroundAxis(angle:Up(), 90)
	angle:RotateAroundAxis(angle:Forward(), 90)

	local flip = math.Clamp((RealTime() - (self.flip or 0)) / 0.25, 0, 1)

	cam.Start3D2D(pos, angle, 0.045)
		local x0, y0 = -W / 2, -H / 2

		draw.RoundedBox(8, x0, y0, W, H, Color(12, 14, 10, 225 * alpha))
		surface.SetDrawColor(AMBER.r, AMBER.g, AMBER.b, 200 * alpha)
		surface.DrawOutlinedRect(x0, y0, W, H, 2)
		surface.DrawRect(x0, y0 + 56, W, 2)
		draw.SimpleText("ЗАВОД  ::  " .. string.upper(title), "nwFTermTitle", x0 + 20, y0 + 28,
			ColorAlpha(TEXT, 255 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText((page + 1) .. " / " .. (#CW.instruction + 1), "nwFTermSmall", x0 + W - 20, y0 + 28,
			ColorAlpha(DIM, 255 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local y = y0 + 72

		for _, line in ipairs(lines) do
			for _, part in ipairs(NW.inventory.WrapText(line[1], line[2], W - 40)) do
				if (y > y0 + H - 60) then
					break
				end

				draw.SimpleText(part, line[2], x0 + 20, y, ColorAlpha(line[3], 255 * alpha * flip), TEXT_ALIGN_LEFT,
					TEXT_ALIGN_TOP)
				y = y + (line[2] == "nwFTermHead" and 32 or (line[2] == "nwFTermSmall" and 24 or 29))
			end

			if (line.bar) then
				draw.RoundedBox(3, x0 + 20, y + 2, W - 40, 8, Color(255, 255, 255, 20 * alpha))
				draw.RoundedBox(3, x0 + 20, y + 2, (W - 40) * line.bar, 8, ColorAlpha(AMBER, 255 * alpha))
				y = y + 18
			end

			y = y + 4
		end

		surface.SetDrawColor(AMBER.r, AMBER.g, AMBER.b, 120 * alpha)
		surface.DrawRect(x0, y0 + H - 40, W, 1)
		draw.SimpleText("E — дальше   ·   ALT + E — назад   ·   SHIFT + E — оформиться / уволиться", "nwFTermSmall", 0,
			y0 + H - 20, ColorAlpha(DIM, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
