local CHECK = {
	"idle01", "idle02", "walk_all", "run_all", "crouchidle",
	"tcidle", "tc_aim_all", "tcfire", "run_all_tc", "tc_run_aim_all",
	"walk_all_tc", "walk_all_holdgun", "sweep", "sweep_idle",
	"gest_chant", "gest_heal", "heal_start", "meleehigh1", "stomp"
}

concommand.Add("network_vortanim", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local function Line(text)
		print("[vortanim] " .. text)
	end

	Line("------------------------------------------")
	Line("Модель: " .. tostring(client:GetModel()))
	Line("Кадров на модели: " .. tostring(client:GetSequenceCount()))
	Line("Класс анимаций: " .. tostring(client.nwAnimClass))
	Line("Тип удержания: " .. tostring(client.nwAnimHoldType) ..
		" (оружие: " .. tostring(client.nwAnimWeapon) .. ")")
	Line("Класс персонажа: " .. tostring(client:GetNWString("nwClass", "—")))

	if ((client:GetSequenceCount() or 0) < 2) then
		Line("!! У модели нет кадров. Скорее всего она не установлена " ..
			"на клиенте — проверьте ресурсы сервера и FastDL.")
	end

	local missing = {}

	for _, name in ipairs(CHECK) do
		if (client:LookupSequence(name) < 1) then
			missing[#missing + 1] = name
		end
	end

	if (#missing == 0) then
		Line("Все ожидаемые кадры на месте.")
	else
		Line("Нет этих кадров: " .. table.concat(missing, ", "))
		Line("Их заменит подбор по смыслу (sh_animhooks.lua). Если " ..
			"движение выглядит не так, пришлите эту строку — впишу " ..
			"точные имена.")
	end

	Line("Текущая таблица кадров: " ..
		(istable(client.nwAnimTable) and "есть" or "ПУСТО — это Т-поза"))
	Line("Принудительный кадр: " ..
		tostring(client:GetNWInt("nwForcedSequence", -1)))
end)
