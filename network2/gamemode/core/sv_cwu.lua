-- The CWU and the factory, server (sh_cwu.lua): the classes, the breakdowns and the outbreaks that
-- happen by themselves, the repair and the disinfection, the stations of the factory, the personnel
-- office, the CWU terminal, /menufactory, /entmodel.

util.AddNetworkString("nwFactoryHelp")
util.AddNetworkString("nwFactoryOffice")
util.AddNetworkString("nwFactoryHire")

local CW = NW.cwu
local INV = NW.inventory
local I = NW.items

local breakEvery = CreateConVar("nw_breakdown_interval", "300", FCVAR_ARCHIVE, "Как часто что-то ломается в городе (секунды)")
local infestEvery = CreateConVar("nw_infestation_interval", "480", FCVAR_ARCHIVE,
	"Как часто появляется очаг заражения (секунды)")
local maxBroken = CreateConVar("nw_breakdown_max", "3", FCVAR_ARCHIVE, "Сколько поломок может висеть одновременно")

local function Notify(client, text)
	NW.Notify(client, text)
end

local function Data(client)
	local character = client.nwCharacter

	if (!character) then
		return
	end

	character.data = character.data or {}

	return character.data
end

local function CWUMembers()
	local out = {}

	for _, client in ipairs(player.GetAll()) do
		if (CW.IsCWU(client)) then
			out[#out + 1] = client
		end
	end

	return out
end

local function Pay(client, amount)
	if (amount > 0) then
		NW.social.SetTokens(client, NW.social.GetTokens(client) + amount)
	end
end

local function Count(client, id)
	local inventory = INV.Get(client)
	local count = 0

	for index = 1, I.maxSize do
		if (inventory.grid[index] and inventory.grid[index].id == id) then
			count = count + 1
		end
	end

	return count
end

local function Take(client, id, count)
	local inventory = INV.Get(client)

	for index = 1, I.maxSize do
		if (count <= 0) then
			break
		end

		if (inventory.grid[index] and inventory.grid[index].id == id) then
			inventory.grid[index] = nil
			count = count - 1
		end
	end
end

local function ZoneName(entity)
	local zone = NW.zones.At(NW.zones.Point(entity))

	return zone and zone.name or "вне зон"
end

-- ---------------------------------------------------------------- the classes --
function CW.SetClass(client, id)
	local data = Data(client)

	if (!data or !CW.IsCWU(client) or !CW.classByID[id]) then
		return false
	end

	data.cwuClass = id
	client:SetNW2String("nwCwuClass", id)
	NW.char.SaveData(client)

	return true
end

hook.Add("NWCharacterLoaded", "nwCwu", function(client, character)
	local data = character.data or {}

	client:SetNW2String("nwCwuClass", CW.IsCWU(client) and (data.cwuClass or "worker") or "")
	client:SetNW2Int("nwFactoryXP", data.factory and data.factory.xp or 0)
	client:SetNW2Bool("nwFactoryHired", data.factory != nil and data.factory.hired == true)
end)

hook.Add("NWFactionChanged", "nwCwu", function(client, faction)
	local data = Data(client)

	if (faction == "cwu") then
		data.cwuClass = data.cwuClass or "worker"
		client:SetNW2String("nwCwuClass", data.cwuClass)
	else
		client:SetNW2String("nwCwuClass", "")
	end
end)

-- ------------------------------------------------------ breakdowns, outbreaks --
local function Breakdowns(bBroken)
	local out = {}

	for _, entity in ipairs(ents.FindByClass("nw_breakdown")) do
		if (entity:GetBroken() == bBroken) then
			out[#out + 1] = entity
		end
	end

	return out
end

timer.Create("nwCwuBreakdowns", 15, 0, function()
	local now = CurTime()

	-- a breakdown
	if (now >= (CW.nextBreak or now + 60)) then
		CW.nextBreak = now + breakEvery:GetFloat() * math.Rand(0.6, 1.4)

		local intact = Breakdowns(false)

		if (#intact > 0 and #Breakdowns(true) < maxBroken:GetInt()) then
			local entity = intact[math.random(#intact)]

			entity:SetState(true)

			for _, member in ipairs(CWUMembers()) do
				Notify(member, "Поломка: " .. entity:KindData().name .. " · " .. ZoneName(entity))
			end
		end
	end

	CW.nextBreak = CW.nextBreak or now + breakEvery:GetFloat()

	-- an outbreak
	if (now >= (CW.nextInfest or now + 60)) then
		CW.nextInfest = now + infestEvery:GetFloat() * math.Rand(0.6, 1.4)

		local clean = {}
		local active = 0

		for _, entity in ipairs(ents.FindByClass("nw_infestation")) do
			if (entity:GetActive()) then
				active = active + 1
			else
				clean[#clean + 1] = entity
			end
		end

		if (#clean > 0 and active < 2) then
			local entity = clean[math.random(#clean)]

			entity:SetState(true)

			for _, member in ipairs(CWUMembers()) do
				Notify(member, "Очаг заражения · " .. ZoneName(entity))
			end
		end
	end

	CW.nextInfest = CW.nextInfest or now + infestEvery:GetFloat()
end)

local function Near(client, entity, range)
	return IsValid(client) and IsValid(entity) and client:Alive() and
		client:GetPos():DistToSqr(entity:GetPos()) < (range or 140) ^ 2
end

function CW.Repair(client, entity)
	if (!entity:GetBroken()) then
		return Notify(client, "Здесь всё работает")
	end

	-- the settings of the point (the C menu, sh_entsettings.lua)
	local conf = entity.Conf and entity:Conf() or {tool = "toolkit", time = 10, reward = 0, cwuOnly = true}
	local tool = I.Get(conf.tool)

	if (conf.cwuOnly and !CW.IsCWU(client)) then
		return Notify(client, "Ремонтом занимаются рабочие ГСР")
	end

	if (tool and !INV.Has(client, conf.tool)) then
		return Notify(client, "Нужно: " .. tool.name)
	end

	local seconds = conf.time * NW.skills.Factor(client, "engineering", -0.06)

	NW.SayMe(client, "чинит " .. string.lower(entity:KindData().name))

	if (NW.progress.Start(client, "Ремонт", seconds, function()
		if (!IsValid(entity) or !entity:GetBroken()) then
			return
		end

		if (tool and conf.consume) then
			if (!INV.Has(client, conf.tool)) then
				return Notify(client, "Нужно: " .. tool.name)
			end

			Take(client, conf.tool, 1)
			INV.Changed(client)
		end

		entity:SetState(false)
		entity:EmitSound("buttons/button9.wav", 60)

		local reward = conf.reward > 0 and conf.reward or (CW.Class(client) == "worker" and 18 or 12)

		Pay(client, reward)
		NW.skills.Add(client, "engineering", 12)
		Notify(client, "Поломка устранена: +" .. reward .. " ток.")
	end, function()
		return Near(client, entity)
	end)) then
		client:EmitSound("npc/dog/dog_servo" .. math.random(1, 3) .. ".wav", 55)
	end
end

function CW.Disinfect(client, entity)
	if (!CW.IsCWU(client)) then
		return Notify(client, "Очагами занимается дезинфекционный контроль ГСР")
	end

	if (!INV.Has(client, "disinfectant")) then
		return Notify(client, "Нужен дезинфектор")
	end

	NW.SayMe(client, "выжигает очаг заражения дезинфектором")

	local seconds = 8 * NW.skills.Factor(client, "medicine", -0.04)

	if (NW.progress.Start(client, "Дезинфекция", seconds, function()
		if (!IsValid(entity) or !entity:GetActive()) then
			return
		end

		entity:SetState(false)
		entity:EmitSound("ambient/fire/mtov_flame2.wav", 65)

		local reward = CW.Class(client) == "icu" and 22 or 14

		Pay(client, reward)
		NW.skills.Add(client, "medicine", 10)
		Notify(client, "Очаг уничтожен: +" .. reward .. " ток.")
	end, function()
		return Near(client, entity, 170)
	end)) then
		client:EmitSound("ambient/gas/steam_loop1.wav", 55, 140)

		timer.Simple(seconds, function()
			if (IsValid(client)) then
				client:StopSound("ambient/gas/steam_loop1.wav")
			end
		end)
	end
end

-- ---------------------------------------------------------------- the factory --
local function Factory(client)
	local data = Data(client)

	return data and data.factory
end

function CW.Hire(client, bHire)
	local data = Data(client)

	if (!data) then
		return
	end

	data.factory = data.factory or {xp = 0, made = 0}
	data.factory.hired = bHire
	client:SetNW2Bool("nwFactoryHired", bHire)
	client:SetNW2Int("nwFactoryXP", data.factory.xp or 0)
	NW.char.SaveData(client)
	Notify(client, bHire and "Вы оформлены на завод" or "Вы уволились с завода")
end

-- where an ingredient comes from (the hint when it is missing)
function CW.SourceOf(id)
	for _, stationID in ipairs(CW.order) do
		if (CW.stations[stationID].give == id) then
			return "делают на станции «" .. CW.stations[stationID].name .. "»"
		end
	end

	return "нет на линии"
end

function CW.Work(client, entity)
	local station = CW.stations[entity.Station]
	local factory = Factory(client)

	if (!station) then
		return
	end

	if (!factory or !factory.hired) then
		return Notify(client, "Вы не оформлены на заводе: отдел кадров")
	end

	local rank = CW.Rank(factory.xp)

	if (rank < station.rank) then
		return Notify(client, "Эта станция — с ранга «" .. CW.ranks[station.rank].name .. "»")
	end

	-- the city schedule: the stations work in the work shift only (sh_schedule.lua)
	if (NW.schedule and !NW.schedule.Allows("factory")) then
		return Notify(client, "Завод закрыт: сейчас " .. string.lower(NW.schedule.Current().name) ..
			". Ждите рабочей смены")
	end

	for id, count in pairs(station.take) do
		if (Count(client, id) < count) then
			return Notify(client, "Нужно: " .. (I.Get(id) and I.Get(id).name or id) .. " ×" .. count ..
				" (" .. CW.SourceOf(id) .. ")")
		end
	end

	-- the shipping: the most valuable product you carry
	local sold

	if (station.buys) then
		local best = 0

		for id, deal in pairs(station.buys) do
			if (deal[1] > best and Count(client, id) > 0) then
				sold, best = id, deal[1]
			end
		end

		if (!sold) then
			return Notify(client, "Нечего сдавать: принесите лом, детали, блок или груз")
		end
	end

	if (IsValid(entity:GetWorker()) and entity:GetWorker() != client and Near(entity:GetWorker(), entity)) then
		return Notify(client, "Станция занята")
	end

	local seconds = station.time * (station.skill == "engineering" and NW.skills.Factor(client, "engineering", -0.06) or 1)

	entity:SetWorker(client)

	local started = NW.progress.Start(client, station.verb, seconds, function()
		entity:SetWorker(NULL)

		for id, count in pairs(station.take) do
			if (Count(client, id) < count) then
				return Notify(client, "Не хватает сырья")
			end
		end

		for id, count in pairs(station.take) do
			Take(client, id, count)
		end

		local pay = station.pay
		local xp = station.xp

		if (sold) then
			if (Count(client, sold) < 1) then
				return Notify(client, "Продукция пропала из рук")
			end

			Take(client, sold, 1)
			pay, xp = station.buys[sold][1], station.buys[sold][2]
		end

		local made = station.give

		-- the control: a defect now and then (less with the rank); the block goes back as parts
		if (station.defect and math.random() < math.max(0.03, station.defect - (rank - station.rank) * 0.05)) then
			made = "parts"
			Notify(client, "Брак: блок разобран на детали")
			entity:EmitSound("buttons/button10.wav", 60)
		end

		if (made and !INV.Add(client, made)) then
			-- no room: it lands at the feet
			INV.SpawnWorldItem(client, {id = made, data = {}})
		end

		INV.Changed(client)

		if (rank >= #CW.ranks) then
			pay = pay * 1.25
		end

		if (CW.Class(client) == "factory") then
			pay = pay * 1.2
		end

		pay = math.Round(pay)
		Pay(client, pay)

		factory.xp = (factory.xp or 0) + xp
		factory.made = (factory.made or 0) + 1
		client:SetNW2Int("nwFactoryXP", factory.xp)

		local newRank = CW.Rank(factory.xp)

		if (newRank > rank) then
			Notify(client, "Новый ранг на заводе: " .. CW.ranks[newRank].name)
			client:EmitSound("buttons/button3.wav", 60)
		end

		NW.char.SaveData(client)
		NW.skills.Add(client, station.skill, 3)
		CW.shift = (CW.shift or 0) + (entity.Station == "shipping" and 1 or 0)

		-- what came of it and how far the next rank is
		local nextRank = CW.ranks[newRank + 1]
		local progress = nextRank and ("  ·  +" .. xp .. " опыта, до «" .. nextRank.name .. "» ещё " ..
			(nextRank.xp - factory.xp)) or ("  ·  +" .. xp .. " опыта")

		Notify(client, (made and ((I.Get(made) and I.Get(made).name or made) .. "  ·  ") or "") .. "+" .. pay .. " ток." ..
			progress)
	end, function()
		return Near(client, entity)
	end)

	if (started) then
		entity:EmitSound(entity.Station == "press" and "ambient/machines/machine1_hit1.wav" or
			"physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 62)
	else
		entity:SetWorker(NULL)
	end
end

-- the stations stay with the map (the model too, /entmodel)
for _, id in ipairs(CW.order) do
	NW.persist.Register("nw_factory_" .. id, {
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
end

-- the personnel office: an NPC with the answer "factory" (sh_npc.lua)
function CW.OpenOffice(client, npc)
	local factory = Factory(client) or {}

	net.Start("nwFactoryOffice")
		net.WriteEntity(npc)
		net.WriteBool(factory.hired == true)
		net.WriteUInt(factory.xp or 0, 20)
		net.WriteUInt(factory.made or 0, 20)
	net.Send(client)
end

net.Receive("nwFactoryHire", function(_, client)
	local npc = net.ReadEntity()
	local bHire = net.ReadBool()

	if (!IsValid(npc) or npc:GetClass() != "nw_npc" or !NW.npc.HasAction(npc.nwConfig, "factory") or
		client:GetPos():DistToSqr(npc:GetPos()) > 200 * 200 or client:GetCharacterID() == 0) then
		return
	end

	CW.Hire(client, bHire)
	CW.OpenOffice(client, npc)
end)

function CW.OpenInstruction(client)
	net.Start("nwFactoryHelp")
	net.Send(client)
end

NW.AddChatCommand("menufactory", {run = function(client)
	CW.OpenInstruction(client)
end})

-- /entmodel <model>: the model of the entity of the map looked at (stations, breakdown points...)
NW.AddChatCommand("entmodel", {admin = true, run = function(client, rest)
	local entity = client:GetEyeTrace().Entity
	local model = string.Trim(rest or "")

	if (!IsValid(entity) or !NW.persist.classes[entity:GetClass()]) then
		return Notify(client, "Посмотрите на энтити сервера (станцию, точку поломки, почтовый ящик)")
	end

	if (!util.IsValidModel(model)) then
		return Notify(client, "Нет такой модели: " .. model)
	end

	entity.nwModel = model
	entity:SetModel(model)
	entity:PhysicsInit(SOLID_VPHYSICS)

	local physics = entity:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:EnableMotion(false)
	end

	NW.persist.Save(entity:GetClass())
	Notify(client, "Модель: " .. model)
end})

-- -------------------------------------------------------------- the CWU terminal --
local ACTIONS = NW.cmbTerminalActions

function ACTIONS.cwu_class(client, terminal, arg)
	if (terminal:GetClass() != "nw_cwu_terminal") then
		return
	end

	if (!CW.IsCWU(client)) then
		return Notify(client, "Назначение — только для членов ГСР")
	end

	if (CW.SetClass(client, arg)) then
		Notify(client, "Назначение: " .. CW.classByID[arg].name)
	end
end

function ACTIONS.cwu_gear(client, terminal)
	local data = Data(client)

	if (terminal:GetClass() != "nw_cwu_terminal" or !CW.IsCWU(client) or !data) then
		return
	end

	if ((data.cwuGear or 0) > os.time()) then
		return Notify(client, "Снаряжение уже выдано. Снова — через " .. math.ceil((data.cwuGear - os.time()) / 60) .. " мин.")
	end

	local class = CW.Class(client)
	local kit = class == "icu" and {"disinfectant", "gasmask"} or (class == "worker" and {"toolkit"} or {})

	if (#kit == 0) then
		return Notify(client, "Заводу снаряжение не положено")
	end

	for _, id in ipairs(kit) do
		if (!INV.Has(client, id)) then
			if (!INV.Add(client, id)) then
				INV.SpawnWorldItem(client, {id = id, data = {}})
			end
		end
	end

	data.cwuGear = os.time() + 600
	INV.Changed(client)
	Notify(client, "Снаряжение выдано")
end
