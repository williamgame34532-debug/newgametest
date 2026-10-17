-- The Resistance and the refugees.
-- The refugees (framework/gamefactions/refugee.lua): came from beyond the walls - no CID card, no rations,
-- no housing. The civic terminal → «Регистрация беженца» (in place of the housing): the story, then
-- Civil Protection decides at the Alliance terminal (ЗАЯВКИ; nobody in the city - the administration).
-- Approved: a citizen, with a CID card.
-- The Resistance (rebel.lua): to everyone else they look like citizens (cl_overhead.lua).
--   /rr <text>       the hidden frequency (with a radio): only the Resistance hears it; who stands
--                    right next to the speaker hears a whisper
--   recruiting       the wheel over a citizen → «Завербовать»: when they agree they are of the
--                    Resistance (not the Alliance, not refugees)
--   the Lambda       «Баллончик с краской» (3 uses): the sign on a wall close by (6 s, faster with
--                    Скрытность); half a minute later the dispatcher tells the Alliance where. The
--                    Alliance and the CWU wash it off: E (5 s; the CWU is paid)
--   lockpicks        «Отмычки»: a locked door close by, 10 s (faster with Скрытность); the chance grows
--                    with Скрытность; a failure may break a pick and makes noise - the Alliance may hear
--   contraband       the lockpicks and the paint are contraband (the tooltip says so); a search shows them
-- The graffiti stays with the map (sv_persist.lua).

NW.rebels = NW.rebels or {}

local RB = NW.rebels

NW.requests.kinds.registration = {
	name = "Регистрация беженца",
	auto = true,
	Describe = function(fields)
		return tostring(fields.story or "")
	end
}

if (SERVER) then
	local RQ = NW.requests
	local T = NW.terminal
	local D = NW.doors
	local SO = NW.social
	local INV = NW.inventory
	local I = NW.items

	local function Notify(client, text)
		NW.Notify(client, text)
	end

	local function Units()
		local out = {}

		for _, unit in ipairs(player.GetAll()) do
			if (unit:GetCharacterID() != 0 and NW.zones.IsAlliance(unit)) then
				out[#out + 1] = unit
			end
		end

		return out
	end

	local function ZoneName(pos)
		local zone = NW.zones.At(pos)

		return zone and zone.name or "вне зон"
	end

	-- one item of this id out of the grid (a broken pick)
	local function TakeOne(client, id)
		local inventory = INV.Get(client)

		for index = 1, I.maxSize do
			if (inventory.grid[index] and inventory.grid[index].id == id) then
				inventory.grid[index] = nil
				INV.Changed(client)

				return true
			end
		end
	end

	-- ---------------------------------------------------------- refugees --
	RQ.kinds.registration.Approved = function(entry, client)
		if (client:GetFaction() != "refugee") then
			return
		end

		NW.char.SetFaction(client, "citizen")

		if (!INV.Has(client, "cid")) then
			local character = client.nwCharacter
			local card = SO.MakeCard(character, client:GetCharacterDescription())

			character.data = character.data or {}
			character.data.cid = card.number

			if (!INV.Add(client, "cid", card)) then
				INV.SpawnWorldItem(client, {id = "cid", data = card})
			end

			INV.Changed(client)
			NW.char.SaveData(client)
		end

		Notify(client, "Вы зарегистрированы как гражданин. Получите жильё на терминале.")
	end

	RQ.kinds.registration.Check = function(entry)
		return (entry.fields.story or "") != "", "решение администрации"
	end

	hook.Add("NWTerminalProfile", "nwRebels", function(client, extra)
		local entry = RQ.Of(client:GetCharacterID(), "registration")

		extra.registration = entry and {status = entry.status, reason = entry.reason or ""} or nil
	end)

	T.actions.refugee_apply = function(client, terminal, input)
		if (client:GetFaction() != "refugee") then
			return T.Result(client, terminal, "ВЫ УЖЕ ЗАРЕГИСТРИРОВАНЫ")
		end

		local story = string.Trim(tostring(input.story or ""))

		if ((utf8.len(story) or 0) < 5) then
			return T.Result(client, terminal, "РАССКАЖИТЕ, ОТКУДА ВЫ ПРИШЛИ")
		end

		local entry, why = RQ.Submit(client, "registration", {story = string.sub(story, 1, 200)})

		T.Result(client, terminal, entry and "ЗАЯВКА ПРИНЯТА: ОЖИДАЙТЕ РЕШЕНИЯ" or why)
		T.Send(client, "profile", terminal, T.Profile(client))
	end

	T.actions.refugee_cancel = function(client, terminal)
		local entry = RQ.Of(client:GetCharacterID(), "registration")

		if (entry and entry.status == "pending") then
			RQ.Decide(entry, false, "отозвана заявителем", client:Nick())
		end

		T.Send(client, "profile", terminal, T.Profile(client))
	end

	-- ------------------------------------------------------- recruiting --
	function SO.actions.recruit(client, target)
		if (client:GetFaction() != "rebel" or !target:IsPlayer() or target:GetCharacterID() == 0) then
			return
		end

		if (NW.zones.IsAlliance(target) or target:GetFaction() == "rebel" or target:GetFaction() == "refugee") then
			return Notify(client, "Этого человека не завербовать")
		end

		SO.Request(client, target, "recruit", 0, function()
			NW.char.SetFaction(target, "rebel")
			Notify(target, "Вы в Сопротивлении. Частота: /rr (нужна рация). Для всех остальных вы — гражданин.")
			Notify(client, target:Nick() .. " теперь с нами")
			NW.skills.Add(client, "speech", 15)
		end)
	end

	-- ---------------------------------------------------------- graffiti --
	function RB.Graffiti(client, cell)
		if (NW.zones.IsAlliance(client)) then
			return Notify(client, "Не по уставу")
		end

		local trace = client:GetEyeTrace()

		if (!trace.HitWorld or trace.HitPos:DistToSqr(client:GetShootPos()) > 90 * 90 or math.abs(trace.HitNormal.z) > 0.4) then
			return Notify(client, "Подойдите к стене и посмотрите на неё")
		end

		local pos, normal = trace.HitPos, trace.HitNormal
		local seconds = 6 * NW.skills.Factor(client, "stealth", -0.05)

		NW.SayMe(client, "быстро рисует что-то баллончиком на стене")

		if (!NW.progress.Start(client, "Рисую", seconds, function()
			local inventory = INV.Get(client)
			local uses = 3

			-- the can: three uses, then empty
			for index = 1, I.maxSize do
				local own = inventory.grid[index]

				if (own and own.id == "spray_paint") then
					own.data = own.data or {}
					own.data.uses = (own.data.uses or 3) - 1
					uses = own.data.uses

					if (uses <= 0) then
						inventory.grid[index] = nil
					end

					break
				end
			end

			INV.Changed(client)

			local graffiti = ents.Create("nw_graffiti")

			graffiti:SetPos(pos + normal * 0.6)
			graffiti:SetAngles(normal:Angle())
			graffiti:Spawn()
			graffiti:Activate()
			NW.persist.Save("nw_graffiti")
			NW.skills.Add(client, "stealth", 6)
			Notify(client, uses > 0 and ("Краски осталось на " .. uses) or "Баллончик пуст")

			-- the Alliance learns of it a little later
			timer.Simple(30, function()
				if (IsValid(graffiti)) then
					NW.Dispatch("Антигражданская символика обнаружена. Зона: " .. ZoneName(pos) .. ". Очистить.", Units())
				end
			end)
		end, function()
			return client:GetShootPos():DistToSqr(pos) < 110 * 110
		end)) then
			return
		end

		client:EmitSound("player/sprayer.wav", 60)
	end

	function RB.Clean(client, graffiti)
		local cwu = client:GetFaction() == "cwu"

		if (!NW.zones.IsAlliance(client) and !cwu) then
			return
		end

		NW.SayMe(client, "оттирает рисунок со стены")

		NW.progress.Start(client, "Очищаю", 5, function()
			if (!IsValid(graffiti)) then
				return
			end

			graffiti:Remove()

			if (cwu) then
				SO.SetTokens(client, SO.GetTokens(client) + 6)
				Notify(client, "Стена очищена: +6 ток.")
			else
				Notify(client, "Стена очищена")
			end
		end, function()
			return IsValid(graffiti) and client:GetPos():DistToSqr(graffiti:GetPos()) < 130 * 130
		end)
	end

	-- --------------------------------------------------------- lockpicks --
	local function Locked(door)
		return door.nwLocked == true or door:GetInternalVariable("m_bLocked") == true
	end

	function RB.Lockpick(client)
		local door = client:GetEyeTrace().Entity

		if (!D.IsDoor(door) or door:GetPos():DistToSqr(client:GetPos()) > 120 * 120) then
			return Notify(client, "Посмотрите на дверь рядом")
		elseif (!Locked(door)) then
			return Notify(client, "Дверь не заперта")
		elseif (door:GetNW2String("nwDoorKind", "") == "alliance") then
			return Notify(client, "Замок Альянса отмычкой не взять")
		end

		local level = NW.skills.Level(client, "stealth")
		local seconds = 10 * NW.skills.Factor(client, "stealth", -0.06)

		NW.SayMe(client, "возится с замком двери")

		NW.progress.Start(client, "Вскрываю замок", seconds, function()
			if (!IsValid(door) or !Locked(door)) then
				return
			end

			if (math.random() < 0.45 + level * 0.05) then
				for _, member in ipairs(D.Group(door)) do
					member:Fire("Unlock")
					member.nwLocked = false
				end

				door:EmitSound("doors/latchunlocked1.wav", 55)
				NW.skills.Add(client, "stealth", 8)
				Notify(client, "Замок поддался")

				return
			end

			door:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 70)

			if (math.random() < 0.35 - level * 0.02) then
				TakeOne(client, "lockpick")
				Notify(client, "Отмычка сломалась")
			else
				Notify(client, "Не вышло")
			end

			NW.skills.Add(client, "stealth", 2)

			-- the noise: a unit close by, or the dispatcher sometimes
			if (math.random() < 0.5) then
				NW.Dispatch("Попытка взлома двери. Зона: " .. ZoneName(door:GetPos()) .. ".", Units())
			end
		end, function()
			return IsValid(door) and client:GetPos():DistToSqr(door:GetPos()) < 140 * 140
		end)
	end

	return
end

-- ------------------------------------------------------------------ client --
local SO = NW.social

SO.requestTexts.recruit = "предлагает вам присоединиться к Сопротивлению"

hook.Add("NWSocialItems", "nwRebels", function(target, items)
	local me = LocalPlayer()

	if (me:GetFaction() != "rebel" or !target:IsPlayer()) then
		return
	end

	local can = target:GetFaction() != "rebel" and !NW.zones.IsAlliance(target) and target:GetFaction() != "refugee"

	items[#items + 1] = {name = "Завербовать", icon = "flag", disabled = !can,
		hint = can and "Предложить вступить в Сопротивление" or "Этого человека не завербовать",
		run = function()
			SO.Send("recruit", target)
		end}
end)
