-- The voice of the city (sound/network2/overwatch): the announcements of the Overwatch. Played by
-- the announcers in the world (nw_announcer, every 5..15 minutes, from where it stands) and by the
-- Alliance from its terminal (to the whole city, sv_cmbterminal.lua). The text goes to the chat as
-- the dispatcher. ambient = true - for the announcers (the calm, everyday ones).

NW.overwatch = NW.overwatch or {}

local OW = NW.overwatch

OW.list = {
	{id = "announcement_ration_intake", ambient = true,
		text = "Внимание, жители: начинается выдача рациона. Пройдите к пункту распределения."},
	{id = "announcement_one_ration_deducted", ambient = true,
		text = "Внимание: за нарушения рацион вашего блока сокращён на одну единицу."},
	{id = "announcement_two_rations_deducted",
		text = "Внимание: за нарушения рацион вашего блока сокращён на две единицы."},
	{id = "announcement_three_rations_deducted",
		text = "Внимание: за нарушения рацион вашего блока сокращён на три единицы."},
	{id = "announcement_four_rations_deducted",
		text = "Внимание: за нарушения рацион вашего блока сокращён на четыре единицы."},
	{id = "announcement_freed_biotic", ambient = true,
		text = "Внимание: замечен освобождённый биотик. Сообщите о нём Гражданской Обороне."},
	{id = "announcement_necrotic_presence",
		text = "Внимание: в секторе некротическое присутствие. Оставайтесь в жилых блоках."},
	{id = "overwatch_citizenreminder", ambient = true,
		text = "Гражданин, напоминаем: неучастие в программе считается нарушением."},
	{id = "overwatch_anticitizenscavenging", ambient = true,
		text = "Внимание: замечено антигражданское мародёрство. Нарушители будут наказаны."},
	{id = "overwatch_accessblockcivilcodeviolation",
		text = "Нарушение гражданского кодекса: доступ в блок закрыт."},
	{id = "overwatch_accessblocklocalsecurity", ambient = true,
		text = "Доступ ограничен местной службой безопасности."},
	{id = "overwatch_interior_acknowledgesactivity", ambient = true,
		text = "Надзор подтверждает активность в секторе."},
	{id = "overwatch_readministratoninprogress", ambient = true,
		text = "Идёт повторное администрирование сектора."},
	{id = "overwatch_chargedwithmultiplelevel5",
		text = "Вы обвиняетесь в многочисленных нарушениях пятого уровня."},
	{id = "overwatch_convergestation1", text = "Всем подразделениям: сходитесь к станции один."},
	{id = "overwatch_criticalbreach", text = "Критическое нарушение периметра."},
	{id = "overwatch_criticalinsurrection", text = "Внимание: в секторе критическое восстание."},
	{id = "overwatch_emergencycodevoid", text = "Чрезвычайный код: пустота."},
	{id = "overwatch_incidentsresponsedeployment", text = "Развёртывание сил реагирования на инцидент."},
	{id = "overwatch_invasiveoperation", text = "Начинается инвазивная операция."},
	{id = "overwatch_missionfailure", text = "Провал задания. Будет назначено взыскание."},
	{id = "overwatch_operationengagement", text = "Операция начата."},
	{id = "overwatch_responsecodeshieldkeymigrate", text = "Код реагирования: щит, ключ, миграция."},
	{id = "overwatch_responseteams", text = "Группы реагирования, выдвигайтесь."},
	{id = "overwatch_updatecodeflush", text = "Обновление кода: зачистка."}
}

OW.byID = {}

for _, entry in ipairs(OW.list) do
	entry.sound = "network2/overwatch/" .. entry.id .. ".mp3"
	OW.byID[entry.id] = entry
end

if (CLIENT) then
	net.Receive("nwOverwatchCity", function()
		local entry = OW.byID[net.ReadString()]

		if (entry) then
			surface.PlaySound(entry.sound)
		end
	end)

	return
end

util.AddNetworkString("nwOverwatchCity")

-- to the whole city: the voice for everyone, the words in the chat
function OW.City(id)
	local entry = OW.byID[id]

	if (!entry) then
		return false
	end

	net.Start("nwOverwatchCity")
		net.WriteString(id)
	net.Broadcast()

	NW.Dispatch(entry.text)

	return true
end
