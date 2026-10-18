-- The look of a character set by an admin, over everything (the faction, the class, the clothes):
--   /setskin <игрок> <номер>                       the skin of the model
--   /setbodygroup <игрок> <группа> <вариант>       a bodygroup by its name or number
--   /bodygroups [игрок]                            what groups the model has (names, numbers, variants)
--   /resetlook <игрок>                             the skin and the bodygroups as the game sets them
-- Saved with the character (data.lookSkin, data.lookGroups), put on again after every change of the clothes
-- and every spawn.

local INV = NW.inventory
local C = NW.char

local function Data(client)
	local character = client.nwCharacter

	if (!character) then
		return
	end

	character.data = character.data or {}

	return character.data
end

local function ApplyLook(client)
	local data = Data(client)

	if (!data or !client:Alive()) then
		return
	end

	if (data.lookSkin) then
		client:SetSkin(math.Clamp(data.lookSkin, 0, math.max(client:SkinCount() - 1, 0)))
	end

	for group, value in pairs(data.lookGroups or {}) do
		local index = tonumber(group) or client:FindBodygroupByName(group)

		if (index and index >= 0) then
			client:SetBodygroup(index, math.Clamp(value, 0, math.max(client:GetBodygroupCount(index) - 1, 0)))
		end
	end
end

-- after the clothes are put on (they reset the groups first)
local dress = INV.Dress

function INV.Dress(client, ...)
	dress(client, ...)
	ApplyLook(client)
end

hook.Add("NWModelApplied", "nwAppearance", function(client)
	timer.Simple(0, function()
		if (IsValid(client)) then
			ApplyLook(client)
		end
	end)
end)

local function Target(client, who)
	local target = NW.FindPlayer(who)

	if (!target or target:GetCharacterID() == 0) then
		NW.Notify(client, "Игрок не найден")

		return
	end

	return target
end

NW.AddChatCommand("setskin", {admin = true, run = function(client, rest)
	local who, skin = string.match(rest or "", "^(%S+)%s+(%d+)")
	local target = who and Target(client, who)

	if (!target) then
		return NW.Notify(client, "/setskin <имя> <номер>")
	end

	local data = Data(target)

	data.lookSkin = math.Clamp(tonumber(skin), 0, math.max(target:SkinCount() - 1, 0))
	C.SaveData(target)
	ApplyLook(target)
	NW.Notify(client, target:Nick() .. ": скин " .. data.lookSkin .. " (всего " .. target:SkinCount() .. ")")
end})

NW.AddChatCommand("setbodygroup", {admin = true, run = function(client, rest)
	local who, group, value = string.match(rest or "", "^(%S+)%s+(%S+)%s+(%d+)")
	local target = who and Target(client, who)

	if (!target) then
		return NW.Notify(client, "/setbodygroup <имя> <группа> <вариант>  ·  группы: /bodygroups <имя>")
	end

	local index = tonumber(group) or target:FindBodygroupByName(group)

	if (!index or index < 0 or index >= target:GetNumBodyGroups()) then
		return NW.Notify(client, "Нет такой группы у модели: " .. group)
	end

	local data = Data(target)

	data.lookGroups = data.lookGroups or {}
	data.lookGroups[target:GetBodygroupName(index)] = tonumber(value)
	C.SaveData(target)
	ApplyLook(target)
	NW.Notify(client, target:Nick() .. ": " .. target:GetBodygroupName(index) .. " = " .. value .. " (вариантов " ..
		target:GetBodygroupCount(index) .. ")")
end})

NW.AddChatCommand("bodygroups", {admin = true, run = function(client, rest)
	local target = string.Trim(rest or "") != "" and Target(client, rest) or client

	if (!target) then
		return
	end

	local parts = {}

	for index = 0, target:GetNumBodyGroups() - 1 do
		parts[#parts + 1] = index .. " " .. target:GetBodygroupName(index) .. " (" .. target:GetBodygroupCount(index) ..
			", сейчас " .. target:GetBodygroup(index) .. ")"
	end

	NW.Notify(client, target:GetModel() .. " · скинов " .. target:SkinCount())

	for start = 1, #parts, 4 do
		NW.Notify(client, table.concat(parts, "  ·  ", start, math.min(start + 3, #parts)))
	end
end})

NW.AddChatCommand("resetlook", {admin = true, run = function(client, rest)
	local target = Target(client, rest)

	if (!target) then
		return
	end

	local data = Data(target)

	data.lookSkin, data.lookGroups = nil, nil
	C.SaveData(target)

	if (target:Alive()) then
		NW.models.Apply(target)
	end

	NW.Notify(client, target:Nick() .. ": вид по умолчанию")
end})
