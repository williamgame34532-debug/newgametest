-- The time of the city: the phases go round by themselves, short, so the day does not drag.
--   Рабочая смена        the factory works (nw_schedule_work minutes, 12)
--   Свободное время      the factory is closed (nw_schedule_free, 10)
--   Комендантский час    the factory and the ration dispensers are closed; the citizens go home
--                        (nw_schedule_curfew, 6)
-- Every change: in the chat for everyone, yellow, «[ОПОВЕЩЕНИЕ] Наступает время: ...» with its sound
-- (sound/network2/schedule/reminder.mp3). The phase and the time left - a small line at the top of the
-- screen. Admins: /schedule <смена|свободное|комендантский|авто>; nw_schedule 0 - no schedule (always
-- the free time, the factory open).

NW.schedule = NW.schedule or {}

local SC = NW.schedule

SC.phases = {
	{id = "work", name = "Рабочая смена", convar = "nw_schedule_work", minutes = 12, allows = {factory = true, rations = true},
		text = "Граждане обязаны явиться на рабочие места. Завод открыт."},
	{id = "free", name = "Свободное время", convar = "nw_schedule_free", minutes = 10, allows = {rations = true},
		text = "Рабочая смена окончена. Завод закрыт."},
	{id = "curfew", name = "Комендантский час", convar = "nw_schedule_curfew", minutes = 6, allows = {},
		text = "Гражданам вернуться в жилые помещения. Нахождение на улице — нарушение."}
}

SC.byID = {}

for index, phase in ipairs(SC.phases) do
	phase.index = index
	SC.byID[phase.id] = phase
	phase.cvar = CreateConVar(phase.convar, tostring(phase.minutes), {FCVAR_ARCHIVE, FCVAR_REPLICATED},
		"Длительность фазы «" .. phase.name .. "» (минуты)")
end

local enabled = CreateConVar("nw_schedule", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Расписание города: смена, " ..
	"свободное время, комендантский час")

-- the phase now and the seconds left
function SC.Current()
	if (!enabled:GetBool()) then
		return SC.byID.free, 0
	end

	local phase = SC.byID[GetGlobal2String("nwPhase", "free")] or SC.byID.free

	return phase, math.max(0, GetGlobal2Float("nwPhaseEnds", 0) - CurTime())
end

-- what the phase allows: "factory", "rations"
function SC.Allows(what)
	if (!enabled:GetBool()) then
		return true
	end

	return SC.Current().allows[what] == true
end

if (SERVER) then
	util.AddNetworkString("nwSchedule")

	local manual = false

	function SC.Set(id, bManual)
		local phase = SC.byID[id]

		if (!phase) then
			return
		end

		SetGlobal2String("nwPhase", id)
		SetGlobal2Float("nwPhaseEnds", CurTime() + math.max(1, phase.cvar:GetFloat()) * 60)
		manual = bManual == true

		net.Start("nwSchedule")
			net.WriteString(id)
		net.Broadcast()

		MsgN("[SCHEDULE] " .. phase.name)
		hook.Run("NWScheduleChanged", phase)
	end

	timer.Create("nwSchedule", 1, 0, function()
		if (!enabled:GetBool()) then
			return
		end

		local phase, left = SC.Current()

		if (GetGlobal2String("nwPhase", "") == "") then
			return SC.Set("work")
		end

		if (left <= 0) then
			SC.Set(SC.phases[phase.index % #SC.phases + 1].id, manual)
		end
	end)

	local WORDS = {["смена"] = "work", ["работа"] = "work", ["свободное"] = "free", ["комендантский"] = "curfew",
		work = "work", free = "free", curfew = "curfew"}

	NW.AddChatCommand("schedule", {admin = true, run = function(client, rest)
		local word = string.lower(string.Trim(rest or ""))

		if (word == "авто" or word == "auto") then
			manual = false

			return NW.Notify(client, "Расписание идёт само")
		end

		local id = WORDS[word]

		if (!id) then
			return NW.Notify(client, "/schedule <смена|свободное|комендантский|авто>")
		end

		SC.Set(id, true)
	end})

	return
end

-- ------------------------------------------------------------------ client --
local YELLOW = Color(240, 208, 70)

net.Receive("nwSchedule", function()
	local phase = SC.byID[net.ReadString()]

	if (!phase) then
		return
	end

	NW.chat.AddStyled("nwChat", YELLOW, "[ОПОВЕЩЕНИЕ] Наступает время: " .. phase.name .. ". " .. phase.text)
	surface.PlaySound("network2/schedule/reminder.mp3")
end)

surface.CreateFont("nwSchedule", {font = "Montserrat SemiBold", size = math.max(11, math.Round(ScrH() * 0.015)),
	weight = 600, extended = true, antialias = true})

-- the phase at the top of the screen
hook.Add("HUDPaint", "nwSchedule", function()
	local client = LocalPlayer()

	if (!enabled:GetBool() or !IsValid(client) or client:GetCharacterID() == 0 or (NW.cameras and NW.cameras.full)) then
		return
	end

	local phase, left = SC.Current()
	local text = string.upper(phase.name) .. "  ·  " .. string.format("%02d:%02d", math.floor(left / 60), math.floor(left % 60))
	local color = phase.id == "curfew" and Color(236, 96, 80) or (phase.id == "work" and YELLOW or Color(200, 210, 220))

	draw.SimpleTextOutlined(text, "nwSchedule", ScrW() / 2, ScrH() * 0.012, ColorAlpha(color, 220), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 160))
end)
