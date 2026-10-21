-- The injuries and what heals them.
--   Кровотечение   a bullet, a blade, a blast (a harder hit - a better chance): the health runs out a point
--                  every 3 seconds (not below 5), drops of blood on the ground; stops by itself after
--                  nw_med_bleed_time seconds (240)
--   Перелом        a fall from a height, a heavy blast or crush, a bullet in the leg now and then: no running,
--                  no jumping, a slower step; never heals by itself
--   Боль           any hard hit (20+): the picture swims and smears; passes after nw_med_pain_time (120)
--   Отравление     poison, nerve gas, acid (the headcrabs, the toxic water): a point every 3 seconds (not
--                  below 1) while the poison lasts, the picture goes green
-- Every medical item has «Лечит» (the field cure, chosen from the list in /itemedit): Здоровье (only the
-- health), one of the four, or Всё. «Здоровье +» heals on top of that. Used with nothing to do - refused.
-- The conditions stay with the character (data.med) and go with death.

NW.medical = NW.medical or {}

local MD = NW.medical

MD.conditions = {
	{id = "bleed", name = "Кровотечение", icon = "st_bleed", color = Color(232, 70, 60),
		text = "Вы теряете кровь. Нужен бинт, жгут или аптечка."},
	{id = "fracture", name = "Перелом", icon = "st_fracture", color = Color(226, 214, 190),
		text = "Нельзя бежать и прыгать. Нужна шина или аптечка."},
	{id = "pain", name = "Боль", icon = "st_pain", color = Color(236, 150, 70),
		text = "В глазах плывёт. Поможет обезболивающее или морфин."},
	{id = "poison", name = "Отравление", icon = "st_sick", color = Color(140, 214, 90),
		text = "Яд в крови: здоровье тает. Нужен антидот или аптечка."}
}

MD.byID = {}

for _, condition in ipairs(MD.conditions) do
	MD.byID[condition.id] = condition
end

-- what an item may heal (the list of /itemedit)
MD.cures = {
	{"health", "Только здоровье"},
	{"bleed", "Кровотечение"},
	{"fracture", "Перелом"},
	{"pain", "Боль"},
	{"poison", "Отравление"},
	{"all", "Всё (аптечка)"}
}

MD.cureNames = {}

for _, entry in ipairs(MD.cures) do
	MD.cureNames[entry[1]] = entry[2]
end

function MD.IsMedical(item)
	return item != nil and (item.heal != nil or (item.cure != nil and item.cure != "health"))
end

-- whether the item heals that condition
function MD.Cures(item, id)
	return item.cure == "all" or item.cure == id
end

function MD.Has(client, id)
	if (id == "fracture") then
		return client:GetNW2Bool("nwFracture", false)
	end

	return client:GetNW2Float("nwMed_" .. id, 0) > 0
end

-- a broken leg: no running, no jumping (both sides, for the prediction)
hook.Add("SetupMove", "nwMedical", function(client, move)
	if (!client:GetNW2Bool("nwFracture", false)) then
		return
	end

	move:SetMaxClientSpeed(math.min(move:GetMaxClientSpeed(), client:GetWalkSpeed() * 0.8))

	if (move:KeyDown(IN_JUMP) and client:OnGround()) then
		move:SetButtons(bit.band(move:GetButtons(), bit.bnot(IN_JUMP)))
	end
end)

if (SERVER) then
	local bleedTime = CreateConVar("nw_med_bleed_time", "240", FCVAR_ARCHIVE, "Сколько секунд длится кровотечение")
	local painTime = CreateConVar("nw_med_pain_time", "120", FCVAR_ARCHIVE, "Сколько секунд длится боль")

	local function Data(client)
		local character = client.nwCharacter

		if (!character) then
			return
		end

		character.data = character.data or {}
		character.data.med = character.data.med or {}

		return character.data.med
	end

	-- value: seconds left (bleed, pain), the amount (poison), true / nil (fracture)
	function MD.Set(client, id, value)
		local data = Data(client)

		if (!data) then
			return
		end

		if (id == "fracture") then
			value = value and true or nil
			client:SetNW2Bool("nwFracture", value == true)
		else
			value = (value and value > 0) and math.Round(value) or nil
			client:SetNW2Float("nwMed_" .. id, value or 0)
		end

		local changed = (data[id] == nil) != (value == nil)

		data[id] = value

		if (changed) then
			NW.char.SaveData(client)

			if (value != nil) then
				NW.Notify(client, MD.byID[id].name .. ": " .. MD.byID[id].text)
			end
		end
	end

	function MD.Clear(client)
		for _, condition in ipairs(MD.conditions) do
			if (MD.Has(client, condition.id)) then
				MD.Set(client, condition.id, nil)
			end
		end
	end

	-- what the item would do to the one treated now
	function MD.Needs(target, item)
		if (item.heal and target:Health() < target:GetMaxHealth()) then
			return true
		end

		for _, condition in ipairs(MD.conditions) do
			if (MD.Cures(item, condition.id) and MD.Has(target, condition.id)) then
				return true
			end
		end

		return false
	end

	-- the treatment (by oneself or by a medic): false - nothing to do
	function MD.Treat(target, item, medic)
		if (!MD.Needs(target, item)) then
			return false
		end

		medic = IsValid(medic) and medic or target

		if (item.heal) then
			-- Медицина: +8% a level (sh_skills.lua)
			local heal = math.Round(item.heal * NW.skills.Factor(medic, "medicine", 0.08))

			target:SetHealth(math.min(target:GetMaxHealth(), target:Health() + heal))
		end

		local cured = {}

		for _, condition in ipairs(MD.conditions) do
			if (MD.Cures(item, condition.id) and MD.Has(target, condition.id)) then
				MD.Set(target, condition.id, nil)
				cured[#cured + 1] = string.lower(condition.name)
			end
		end

		if (#cured > 0) then
			NW.Notify(target, "Вылечено: " .. table.concat(cured, ", "))
		end

		NW.skills.Add(medic, "medicine", #cured > 0 and 6 or 4)

		return true
	end

	-- -------------------------------------------------------------- the causes --
	local CUT = bit.bor(DMG_BULLET, DMG_SLASH, DMG_BUCKSHOT, DMG_BLAST, DMG_SNIPER, DMG_AIRBOAT)
	local POISON = bit.bor(DMG_POISON, DMG_NERVEGAS, DMG_ACID, DMG_PARALYZE)
	local HEAVY = bit.bor(DMG_BLAST, DMG_CRUSH, DMG_VEHICLE)

	hook.Add("PostEntityTakeDamage", "nwMedical", function(target, damage, bTook)
		if (!bTook or !IsValid(target) or !target:IsPlayer() or !target:Alive() or target:GetCharacterID() == 0) then
			return
		end

		local amount = damage:GetDamage()
		local kind = damage:GetDamageType()
		local group = target:LastHitGroup()

		if (amount <= 0) then
			return
		end

		if (bit.band(kind, POISON) != 0) then
			MD.Set(target, "poison", math.min(60, target:GetNW2Float("nwMed_poison", 0) + amount * 1.5))

			return
		end

		if (bit.band(kind, CUT) != 0 and amount >= 8 and math.random() < math.min(0.25 + amount / 60, 0.9)) then
			MD.Set(target, "bleed", bleedTime:GetFloat())
		end

		if (!MD.Has(target, "fracture")) then
			local chance = 0

			if (bit.band(kind, DMG_FALL) != 0 and amount >= 15) then
				chance = 0.5 + amount / 100
			elseif (bit.band(kind, HEAVY) != 0 and amount >= 30) then
				chance = 0.3
			elseif (bit.band(kind, CUT) != 0 and amount >= 20 and (group == HITGROUP_LEFTLEG or
				group == HITGROUP_RIGHTLEG)) then
				chance = 0.25
			end

			if (math.random() < chance) then
				MD.Set(target, "fracture", true)
				target:EmitSound("physics/body/body_medium_break" .. math.random(2, 4) .. ".wav", 65)
			end
		end

		if (amount >= 20) then
			MD.Set(target, "pain", math.max(target:GetNW2Float("nwMed_pain", 0), painTime:GetFloat()))
		end
	end)

	-- -------------------------------------------------------------- the course --
	timer.Create("nwMedical", 3, 0, function()
		for _, client in ipairs(player.GetAll()) do
			if (!client:Alive() or client:GetCharacterID() == 0) then
				continue
			end

			local bleed = client:GetNW2Float("nwMed_bleed", 0)

			if (bleed > 0) then
				if (client:Health() > 5) then
					client:SetHealth(client:Health() - 1)
				end

				local pos = client:GetPos() + Vector(math.Rand(-8, 8), math.Rand(-8, 8), 4)

				util.Decal("Blood", pos, pos - Vector(0, 0, 32), client)
				MD.Set(client, "bleed", bleed - 3)
			end

			local poison = client:GetNW2Float("nwMed_poison", 0)

			if (poison > 0) then
				if (client:Health() > 1) then
					client:SetHealth(client:Health() - 1)
				end

				MD.Set(client, "poison", poison - 1)
			end

			local pain = client:GetNW2Float("nwMed_pain", 0)

			if (pain > 0) then
				MD.Set(client, "pain", pain - 3)
			end
		end
	end)

	hook.Add("NWCharacterLoaded", "nwMedical", function(client, character)
		local med = character.data and character.data.med or {}

		client:SetNW2Bool("nwFracture", med.fracture == true)

		for _, id in ipairs({"bleed", "pain", "poison"}) do
			client:SetNW2Float("nwMed_" .. id, tonumber(med[id]) or 0)
		end
	end)

	hook.Add("PlayerDeath", "nwMedical", MD.Clear)

	NW.AddChatCommand("heal", {admin = true, run = function(client, rest)
		local target = string.Trim(rest or "") != "" and NW.FindPlayer(rest) or client

		if (!IsValid(target)) then
			return NW.Notify(client, "Игрок не найден")
		end

		MD.Clear(target)
		target:SetHealth(target:GetMaxHealth())
		NW.Notify(client, target:Nick() .. ": здоров")
	end})

	return
end

-- ------------------------------------------------------------------ client --
-- the statuses (cl_status.lua): the icons, the cards, the page «Состояние»
local ST = NW.status

if (ST and ST.list) then
	for _, condition in ipairs(MD.conditions) do
		local id = condition.id

		ST.list[#ST.list + 1] = {id = "med_" .. id, icon = condition.icon, color = condition.color, title = condition.name,
			text = condition.text, Active = function(c)
				return MD.Has(c, id)
			end}
	end
end

-- the pain swims and smears, the poison greens
local GREEN = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0.02,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 0.75,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0.25,
	["$pp_colour_mulb"] = 0
}

hook.Add("RenderScreenspaceEffects", "nwMedical", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or client:GetCharacterID() == 0) then
		return
	end

	if (MD.Has(client, "pain")) then
		local wave = 0.5 + 0.5 * math.sin(CurTime() * 1.3)

		DrawMotionBlur(0.25 + wave * 0.2, 0.5 + wave * 0.3, 0.01)
	end

	if (MD.Has(client, "poison")) then
		DrawColorModify(GREEN)
	end
end)
