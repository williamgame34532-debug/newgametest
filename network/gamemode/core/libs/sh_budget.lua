NETWORK.budget = NETWORK.budget or {}

local B = NETWORK.budget

B.interval = 900
B.maxSalary = 200
B.historyMax = 12
B.logMax = 30

B.groups = {
	{id = "citizen", label = "Граждане (пособие)"},
	{id = "loyalist", label = "Лоялисты"},
	{id = "worker", label = "Сотрудники ГСР"},
	{id = "administration", label = "Городская Администрация"},
	{id = "council", label = "Совет Лоялистов"},
	{id = "alliance", label = "Гражданская оборона"}
}

function B.GetGroup(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local class = client:GetNWString("nwClass", "")

	if (class == "administration") then
		return "administration"
	end

	if (class == "council") then
		return "council"
	end

	if (class == "loyalist") then
		return "loyalist"
	end

	if (NETWORK.factions.IsCWU(client)) then
		return "worker"
	end

	if (NETWORK.factions.IsAlliance(client)) then
		return "alliance"
	end

	if (client:GetCharacterFaction() == "citizen") then
		return "citizen"
	end
end

if (CLIENT) then
	return
end

local dataPath = "network/budget.txt"

B.state = B.state or {
	balance = 5000,
	income = 400,
	salaries = {citizen = 5, loyalist = 10, worker = 15, administration = 25, council = 25, alliance = 0},
	history = {},
	log = {}
}

function B.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(B.state))
end

function B.Load()
	local data = util.JSONToTable(file.Read(dataPath, "DATA") or "")

	if (!istable(data)) then
		return
	end

	B.state.balance = tonumber(data.balance) or B.state.balance
	B.state.income = tonumber(data.income) or B.state.income
	B.state.history = istable(data.history) and data.history or {}
	B.state.log = istable(data.log) and data.log or {}

	for _, group in ipairs(B.groups) do
		local value = istable(data.salaries) and tonumber(data.salaries[group.id])

		if (value) then
			B.state.salaries[group.id] = value
		end
	end
end

function B.Log(text)
	local log = B.state.log

	table.insert(log, 1, {time = os.date("%d.%m %H:%M"), text = text})

	while (#log > B.logMax) do
		table.remove(log)
	end
end

function B.SetSalary(client, group, amount)
	local bKnown = false

	for _, entry in ipairs(B.groups) do
		if (entry.id == group) then
			bKnown = true
		end
	end

	if (!bKnown) then
		return false
	end

	amount = math.Clamp(math.floor(tonumber(amount) or 0), 0, B.maxSalary)

	if (B.state.salaries[group] == amount) then
		return true
	end

	B.state.salaries[group] = amount

	for _, entry in ipairs(B.groups) do
		if (entry.id == group) then
			B.Log(string.format("%s: зарплата «%s» — %d т.", client:GetCharacterName(),
				entry.label, amount))
		end
	end

	B.Save()

	return true
end

function B.Payday()
	local state = B.state

	state.balance = state.balance + state.income

	local paid, unpaid, total = 0, 0, 0

	for _, client in ipairs(player.GetAll()) do
		local group = B.GetGroup(client)
		local amount = group and state.salaries[group] or 0

		if (amount <= 0) then
			continue
		end

		if (state.balance < amount) then
			unpaid = unpaid + 1

			NETWORK.notice.Send(client, "budgetNoMoney", "warn")

			continue
		end

		state.balance = state.balance - amount
		total = total + amount
		paid = paid + 1

		NETWORK.currency.Add(client, amount)
		NETWORK.notice.Send(client, "budgetPaid", "good", amount)
	end

	B.Log(string.format("Выплата: %d чел., %d т.%s Субсидия +%d т.", paid, total,
		unpaid > 0 and (" Не хватило на " .. unpaid .. ".") or "", state.income))

	table.insert(state.history, state.balance)

	while (#state.history > B.historyMax) do
		table.remove(state.history, 1)
	end

	B.Save()
end

function B.GetNextPay()
	return math.max(math.floor((B.nextPay or CurTime()) - CurTime()), 0)
end

hook.Add("Initialize", "nwBudget", function()
	B.Load()
	B.nextPay = CurTime() + B.interval
end)

timer.Create("nwBudgetPayday", 5, 0, function()
	if (!B.nextPay or CurTime() < B.nextPay) then
		return
	end

	B.nextPay = CurTime() + B.interval
	B.Payday()
end)

hook.Add("ShutDown", "nwBudget", function()
	B.Save()
end)

NETWORK.command.Register("budgetadd", {
	adminOnly = true,
	description = "cmdBudgetAdd",
	usage = "/budgetadd <сумма>",
	OnRun = function(command, client, arguments)
		local amount = math.floor(tonumber(arguments[1]) or 0)

		B.state.balance = math.max(B.state.balance + amount, 0)
		B.Log(string.format("Админ %s: счёт %+d т.", client:Nick(), amount))
		B.Save()

		NETWORK.notice.Send(client, "budgetChanged", "good", B.state.balance)
	end
})

NETWORK.command.Register("budgetincome", {
	adminOnly = true,
	description = "cmdBudgetIncome",
	usage = "/budgetincome <сумма>",
	OnRun = function(command, client, arguments)
		B.state.income = math.max(math.floor(tonumber(arguments[1]) or 0), 0)
		B.Log(string.format("Админ %s: субсидия Альянса %d т.", client:Nick(), B.state.income))
		B.Save()

		NETWORK.notice.Send(client, "budgetChanged", "good", B.state.balance)
	end
})
