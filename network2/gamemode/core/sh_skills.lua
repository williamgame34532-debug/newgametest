-- Skills that grow. The character starts with the points of the creation (0..5 each, sh_character.lua);
-- from then on every skill grows with what the character does, up to NW.skills.max (10). Experience
-- of a level: NW.skills.Need(level). A skill gets at most nw_skill_xp_minute experience a minute
-- (no farming). The levels are kept in the skills of the character, the experience in its data
-- (skillXP). TAB → Навыки (cl_skills.lua) shows each skill: the level, the bar, what it gives now
-- and how it grows.
-- What a skill gives (the code that uses NW.skills.Level / NW.skills.Factor):
--   Сила          +4% to the damage of fists and melee (sv here), the push and the knock with the hands
--                 and the baton are stronger (nw_hands, nw_stunstick)
--   Выносливость  -5% stamina spent running a level (sv_needs.lua)
--   Медицина      +8% healed by bandages, kits and pills a level (sv_inventory / sv_body)
--   Инженерия     -6% time of the work at the factory and of the repairs a level (sv_cwu.lua)
--   Скрытность    from level 3 the steps are silent when walking (Alt) or crouching; from 7 always
--                 when not running
--   Убеждение     -2% to the prices of NPC traders a level (sv_npc.lua)

NW.skills = NW.skills or {}

local SK = NW.skills

SK.max = 10

-- how each grows (shown in the TAB) and what it gives (shown with the level)
SK.info = {
	strength = {
		gain = {"Удары кулаками и оружием ближнего боя", "Толчки и отбрасывание", "Работа грузчиком на заводе"},
		Effect = function(level)
			return string.format("+%d%% урона в ближнем бою, сильнее толчок", level * 4)
		end
	},
	endurance = {
		gain = {"Бег (каждые 10 секунд)", "Работа до изнеможения: стамина на нуле", "Смены на заводе"},
		Effect = function(level)
			return string.format("-%d%% расхода стамины на беге", level * 5)
		end
	},
	medicine = {
		gain = {"Лечение себя бинтами, аптечками и таблетками", "Помощь лежащим: пульс, перевязка, подъём",
			"Дезинфекция (ДК ГСР)"},
		Effect = function(level)
			return string.format("+%d%% к лечению предметами", level * 8)
		end
	},
	engineering = {
		gain = {"Работа на станках и сборке завода", "Ремонт поломок (рабочие ГСР)"},
		Effect = function(level)
			return string.format("-%d%% времени работы и ремонта", level * 6)
		end
	},
	stealth = {
		gain = {"Тихий шаг и ходьба вприсядку (каждые 10 секунд)", "Обыск со спины"},
		Effect = function(level)
			if (level >= 7) then
				return "Шаги не слышны, пока вы не бежите"
			elseif (level >= 3) then
				return "Шаги не слышны шагом (Alt) и вприсядку"
			end

			return "С 3 уровня шаги станут тише"
		end
	},
	speech = {
		gain = {"Сделки с торговцами", "Знакомства с людьми", "Разговор (в меру)"},
		Effect = function(level)
			return string.format("-%d%% к ценам торговцев", level * 2)
		end
	}
}

-- the experience for the next level after `level`
function SK.Need(level)
	return math.Round(60 * (level + 1) ^ 1.45)
end

-- the level of a skill (a player: the own levels come with nwSkills; the others - not known)
function SK.Level(client, id)
	if (SERVER) then
		local character = client.nwCharacter

		return math.Clamp(tonumber(character and character.skills and character.skills[id]) or 0, 0, SK.max)
	end

	if (client == LocalPlayer()) then
		return math.Clamp(tonumber(SK.mine and SK.mine.levels[id]) or 0, 0, SK.max)
	end

	return 0
end

-- 1 + perLevel * level (or 1 - ... for a negative perLevel), never under 0.1
function SK.Factor(client, id, perLevel)
	return math.max(0.1, 1 + perLevel * SK.Level(client, id))
end

-- --------------------------------------------------------------- server --
if (SERVER) then
	util.AddNetworkString("nwSkills")
	util.AddNetworkString("nwSkillUp")

	local perMinute = CreateConVar("nw_skill_xp_minute", "40", FCVAR_ARCHIVE,
		"Сколько опыта навык может получить за минуту")

	function SK.Send(client)
		local character = client.nwCharacter

		if (!character) then
			return
		end

		local data = character.data or {}

		net.Start("nwSkills")
			net.WriteString(util.TableToJSON({levels = character.skills or {}, xp = data.skillXP or {}}))
		net.Send(client)
	end

	local function SaveSkills(client)
		local character = client.nwCharacter

		if (character and !character.test and client:GetCharacterID() != 0) then
			sql.Query("UPDATE nw_characters SET skills = " .. sql.SQLStr(util.TableToJSON(character.skills or {})) ..
				" WHERE id = " .. client:GetCharacterID())
		end
	end

	-- experience: amount points to the skill (the minute limit applies)
	function SK.Add(client, id, amount)
		local character = IsValid(client) and client.nwCharacter

		if (!character or client:GetCharacterID() == 0 or !SK.info[id] or amount <= 0) then
			return
		end

		character.skills = character.skills or {}
		character.data = character.data or {}
		character.data.skillXP = character.data.skillXP or {}

		local level = SK.Level(client, id)

		if (level >= SK.max) then
			return
		end

		-- the limit of a minute
		client.nwSkillMinute = client.nwSkillMinute or {}

		local window = client.nwSkillMinute[id]

		if (!window or CurTime() - window.start > 60) then
			window = {start = CurTime(), got = 0}
			client.nwSkillMinute[id] = window
		end

		amount = math.min(amount, perMinute:GetFloat() - window.got)

		if (amount <= 0) then
			return
		end

		window.got = window.got + amount

		local xp = (tonumber(character.data.skillXP[id]) or 0) + amount

		while (level < SK.max and xp >= SK.Need(level)) do
			xp = xp - SK.Need(level)
			level = level + 1
			character.skills[id] = level

			net.Start("nwSkillUp")
				net.WriteString(id)
				net.WriteUInt(level, 5)
			net.Send(client)
		end

		character.data.skillXP[id] = level >= SK.max and 0 or math.Round(xp, 2)

		-- saved now and then (and with every level)
		if (character.skills[id] != client.nwSkillSaved) then
			client.nwSkillSaved = character.skills[id]
			SaveSkills(client)
		end

		if ((client.nwSkillDataSave or 0) < CurTime()) then
			client.nwSkillDataSave = CurTime() + 20
			NW.char.SaveData(client)
		end

		-- the TAB refreshes at most twice a second
		if ((client.nwSkillSend or 0) < CurTime()) then
			client.nwSkillSend = CurTime() + 0.5

			timer.Simple(0.5, function()
				if (IsValid(client)) then
					SK.Send(client)
				end
			end)
		end
	end

	hook.Add("NWCharacterLoaded", "nwSkills", function(client)
		timer.Simple(0.5, function()
			if (IsValid(client)) then
				SK.Send(client)
			end
		end)
	end)

	-- strength: the damage of the hands and the melee weapons
	hook.Add("EntityTakeDamage", "nwSkillStrength", function(target, damage)
		local attacker = damage:GetAttacker()

		if (!IsValid(attacker) or !attacker:IsPlayer() or attacker == target or !damage:IsDamageType(DMG_CLUB)) then
			return
		end

		damage:ScaleDamage(SK.Factor(attacker, "strength", 0.04))

		if (target:IsPlayer() or target:IsNPC() or target:IsNextBot()) then
			SK.Add(attacker, "strength", 2)
		end
	end)

	-- endurance and stealth: running, walking quietly and crouching, every 10 seconds
	timer.Create("nwSkillMoves", 10, 0, function()
		for _, client in ipairs(player.GetAll()) do
			if (client:Alive() and client:GetCharacterID() != 0 and client:GetMoveType() == MOVETYPE_WALK and
				client:OnGround()) then
				local speed = client:GetVelocity():Length2D()

				if (client:KeyDown(IN_SPEED) and speed > client:GetWalkSpeed() + 15) then
					SK.Add(client, "endurance", 3)
				elseif (speed > 20 and (client:Crouching() or client:KeyDown(IN_WALK))) then
					SK.Add(client, "stealth", 3)
				end

				if (client.GetStamina and client:GetStamina() <= 1) then
					SK.Add(client, "endurance", 4)
				end
			end
		end
	end)

	-- speech: a little for talking in character (once in 20 seconds)
	hook.Add("PlayerSay", "nwSkillSpeech", function(client, text)
		if ((client.nwSkillTalk or 0) < CurTime() and string.sub(string.Trim(text), 1, 1) != "/" and
			#string.Trim(text) > 12) then
			client.nwSkillTalk = CurTime() + 20
			SK.Add(client, "speech", 1)
		end
	end)
end

-- stealth: silent steps (shared - the steps are predicted)
hook.Add("PlayerFootstep", "nwSkillStealth", function(client)
	if (client:KeyDown(IN_SPEED)) then
		return
	end

	local level = SK.Level(client, "stealth")

	if (level >= 7 or (level >= 3 and (client:Crouching() or client:KeyDown(IN_WALK)))) then
		return true
	end
end)

if (SERVER) then
	return
end

-- ------------------------------------------------------------------ client --
SK.mine = SK.mine or {levels = {}, xp = {}}

net.Receive("nwSkills", function()
	local data = util.JSONToTable(net.ReadString() or "") or {}

	SK.mine = {levels = data.levels or {}, xp = data.xp or {}}
end)

net.Receive("nwSkillUp", function()
	local id = net.ReadString()
	local level = net.ReadUInt(5)

	SK.mine.levels[id] = level

	for _, skill in ipairs(NW.char.skills) do
		if (skill.id == id) then
			NW.notify.Add("Навык «" .. skill.name .. "» вырос: уровень " .. level)
		end
	end

	surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
end)
