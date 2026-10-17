-- The requests of the citizens to the Civil Administration: made at the civic terminal, decided by the
-- Alliance at its terminal (the page ЗАЯВКИ). Kept in data/network2/requests.json.
--   kinds (NW.requests.kinds[kind] = {name, auto, Approved(entry, client), Revoked(entry, client)})
--     license        a license to trade (sh_business.lua)
--     registration   the registration of a refugee as a citizen (sh_rebels.lua)
--   the statuses     pending → approved / denied; an approved license can be revoked
--   no one to decide nw_request_auto seconds (180) after it was made, with no unit of the Alliance in
--                    the city, the administration decides by itself (kind.auto: true - approve)
--   Approved runs when the decision is made and the citizen is in the game, or when that character
--   comes into the game later (entry.applied).

NW.requests = NW.requests or {}

local RQ = NW.requests

RQ.kinds = RQ.kinds or {}
RQ.statuses = {pending = "НА РАССМОТРЕНИИ", approved = "ОДОБРЕНО", denied = "ОТКАЗАНО", revoked = "ОТОЗВАНО"}

if (SERVER) then
	util.AddNetworkString("nwRequests")

	local PATH = "network2/requests.json"
	local auto = CreateConVar("nw_request_auto", "180", FCVAR_ARCHIVE,
		"Через сколько секунд заявку решает администрация, если Альянса нет в городе (0 - никогда)")

	RQ.list = RQ.list or util.JSONToTable(file.Read(PATH, "DATA") or "") or {}

	local function Save()
		file.CreateDir("network2")
		file.Write(PATH, util.TableToJSON(RQ.list, true))
	end

	RQ.Save = Save

	local function Online(charID)
		for _, client in ipairs(player.GetAll()) do
			if (client:GetCharacterID() == charID) then
				return client
			end
		end
	end

	-- the newest request of this kind of a character (any status)
	function RQ.Of(charID, kind)
		for index = #RQ.list, 1, -1 do
			local entry = RQ.list[index]

			if (entry.char == charID and entry.kind == kind) then
				return entry
			end
		end
	end

	function RQ.Get(id)
		for _, entry in ipairs(RQ.list) do
			if (entry.id == id) then
				return entry
			end
		end
	end

	function RQ.Submit(client, kind, fields)
		local current = RQ.Of(client:GetCharacterID(), kind)

		if (current and current.status == "pending") then
			return false, "ЗАЯВКА УЖЕ НА РАССМОТРЕНИИ"
		end

		local entry = {id = (RQ.list[#RQ.list] and RQ.list[#RQ.list].id or 0) + 1, kind = kind,
			char = client:GetCharacterID(), name = client:Nick(), steam = client:SteamID64(), fields = fields or {},
			status = "pending", time = os.time()}

		RQ.list[#RQ.list + 1] = entry

		-- the old ones go (the last 200 are kept)
		while (#RQ.list > 200) do
			table.remove(RQ.list, 1)
		end

		Save()

		for _, unit in ipairs(player.GetAll()) do
			if (unit:GetCharacterID() != 0 and NW.zones.IsAlliance(unit)) then
				NW.Notify(unit, "Новая заявка: " .. RQ.kinds[kind].name .. " · " .. client:Nick())
			end
		end

		MsgN(string.format("[REQUEST] %s (%s): %s #%d", client:Nick(), client:SteamName(), kind, entry.id))

		return entry
	end

	local function Apply(entry)
		local client = Online(entry.char)
		local kind = RQ.kinds[entry.kind]

		if (IsValid(client) and !entry.applied and kind and kind.Approved) then
			entry.applied = true
			kind.Approved(entry, client)
		end

		return client
	end

	function RQ.Decide(entry, bApprove, reason, by)
		if (!entry or entry.status != "pending") then
			return false
		end

		entry.status = bApprove and "approved" or "denied"
		entry.reason = string.sub(string.Trim(reason or ""), 1, 160)
		entry.by = by
		entry.decided = os.time()

		local client = bApprove and Apply(entry) or Online(entry.char)

		if (IsValid(client)) then
			NW.Notify(client, RQ.kinds[entry.kind].name .. ": " .. (bApprove and "заявка одобрена" or "отказ") ..
				(entry.reason != "" and (" — " .. entry.reason) or ""))
			client:EmitSound(bApprove and "buttons/combine_button1.wav" or "buttons/combine_button2.wav", 60)
		end

		Save()

		return true
	end

	function RQ.Revoke(entry, reason, by)
		if (!entry or entry.status != "approved") then
			return false
		end

		entry.status = "revoked"
		entry.reason = string.sub(string.Trim(reason or ""), 1, 160)
		entry.by = by
		entry.decided = os.time()

		local client = Online(entry.char)
		local kind = RQ.kinds[entry.kind]

		if (kind and kind.Revoked) then
			kind.Revoked(entry, client)
		end

		if (IsValid(client)) then
			NW.Notify(client, RQ.kinds[entry.kind].name .. ": отозвано" .. (entry.reason != "" and (" — " .. entry.reason) or ""))
		end

		Save()

		return true
	end

	-- decided while away: now
	hook.Add("NWCharacterLoaded", "nwRequests", function(client)
		timer.Simple(1, function()
			if (!IsValid(client)) then
				return
			end

			for _, entry in ipairs(RQ.list) do
				if (entry.char == client:GetCharacterID() and entry.status == "approved" and !entry.applied) then
					Apply(entry)
					Save()
				end
			end
		end)
	end)

	-- no one of the Alliance: the administration decides
	timer.Create("nwRequestsAuto", 15, 0, function()
		local wait = auto:GetFloat()

		if (wait <= 0) then
			return
		end

		for _, unit in ipairs(player.GetAll()) do
			if (unit:GetCharacterID() != 0 and NW.zones.IsAlliance(unit)) then
				return
			end
		end

		for _, entry in ipairs(RQ.list) do
			local kind = RQ.kinds[entry.kind]

			if (entry.status == "pending" and os.time() - entry.time >= wait and kind) then
				local ok, why = true, "решение администрации"

				if (kind.Check) then
					ok, why = kind.Check(entry)
				end

				RQ.Decide(entry, ok and kind.auto == true, why or (ok and "решение администрации" or "отказ администрации"),
					"Администрация")
			end
		end
	end)

	-- the page of the Alliance terminal: what is pending, what was decided lately
	function RQ.SendList(client)
		local out = {}

		for index = #RQ.list, 1, -1 do
			local entry = RQ.list[index]

			if (entry.status == "pending" or entry.status == "approved" or #out < 40) then
				out[#out + 1] = {id = entry.id, kind = entry.kind, name = entry.name, fields = entry.fields,
					status = entry.status, reason = entry.reason, by = entry.by, time = entry.time}
			end

			if (#out >= 80) then
				break
			end
		end

		net.Start("nwRequests")
			net.WriteString(util.TableToJSON(out))
		net.Send(client)
	end

	local ACTIONS = NW.cmbTerminalActions

	function ACTIONS.req_list(client)
		RQ.SendList(client)
	end

	function ACTIONS.req_decide(client, _, arg)
		local data = util.JSONToTable(arg or "") or {}
		local entry = RQ.Get(tonumber(data.id) or 0)

		if (!entry) then
			return
		end

		if (data.action == "revoke") then
			RQ.Revoke(entry, data.reason, client:Nick())
		else
			RQ.Decide(entry, data.action == "approve", data.reason, client:Nick())
		end

		MsgN(string.format("[REQUEST] %s (%s): %s #%d", client:Nick(), client:SteamName(), tostring(data.action), entry.id))
		RQ.SendList(client)
	end

	return
end

-- ------------------------------------------------------------------ client --
local CT = NW.cmbTerminal
local C = CT.colors

RQ.list = RQ.list or {}

net.Receive("nwRequests", function()
	RQ.list = util.JSONToTable(net.ReadString() or "") or {}

	if (CT.page == "requests") then
		CT.Refresh()
	end
end)

local function Up(text)
	return NW.terminal.Upper(tostring(text or ""))
end

local CMB = CT.screens.cmb

table.insert(CMB.order, {"requests", "Заявки"})

CMB.pages.requests = {
	title = "Заявки",
	subtitle = "Лицензии на торговлю / регистрация беженцев",
	Build = function(area, w, h)
		local gap = math.Round(h * 0.02)

		if (!RQ.asked or RQ.asked < RealTime() - 3) then
			RQ.asked = RealTime()
			CT.Send("req_list")
		end

		local reason = CT.Entry(area, 0, 0, w * 0.7, h * 0.07, "Причина решения (необязательно)")

		CT.Button(area, "Обновить", w * 0.72, 0, w * 0.28, h * 0.07, function()
			RQ.asked = nil
			CT.Send("req_list")
		end)

		local scroll = CT.Scroll(area, 0, h * 0.07 + gap, w, h - h * 0.07 - gap)

		if (#RQ.list == 0) then
			CT.Label(scroll, "Заявок нет", 0, 0, "nwCmtText", C.dim)
		end

		for _, entry in ipairs(RQ.list) do
			local kind = RQ.kinds[entry.kind] or {name = entry.kind}
			local fields = entry.fields or {}
			local rowH = math.Round(h * 0.15)
			local row = scroll:Add("DPanel")
			local status = entry.status

			row:Dock(TOP)
			row:DockMargin(0, 0, 8, gap * 0.6)
			row:SetTall(rowH)
			row.Paint = function(_, rw, rh)
				local color = status == "pending" and C.cyan or (status == "approved" and Color(130, 214, 120) or C.red)

				surface.SetDrawColor(C.dark.r, C.dark.g, C.dark.b, 190)
				surface.DrawRect(0, 0, rw, rh)
				surface.SetDrawColor(color.r, color.g, color.b, 220)
				surface.DrawRect(0, 0, 3, rh)
				draw.SimpleText(Up(kind.name) .. "  ·  " .. Up(entry.name) .. "  ·  " .. os.date("%d.%m %H:%M", entry.time or 0),
					"nwCmtText", rh * 0.12, rh * 0.2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(kind.Describe and kind.Describe(fields) or "", "nwCmtSmall", rh * 0.12, rh * 0.48, C.dim,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(RQ.statuses[status] .. ((entry.by or "") != "" and ("  ·  " .. Up(entry.by)) or "") ..
					((entry.reason or "") != "" and ("  ·  " .. entry.reason) or ""), "nwCmtSmall", rh * 0.12, rh * 0.76, color,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			local function Decide(action)
				CT.Send("req_decide", util.TableToJSON({id = entry.id, action = action, reason = reason:GetValue()}))
			end

			local bw, bh = w * 0.15, rowH * 0.36

			if (status == "pending") then
				CT.Button(row, "Одобрить", w - 8 - bw * 2 - 12, rowH * 0.1, bw, bh, function()
					Decide("approve")
				end, true)
				CT.Button(row, "Отказать", w - 8 - bw - 6, rowH * 0.1, bw, bh, function()
					Decide("deny")
				end, false, true)
			elseif (status == "approved" and kind.revocable) then
				CT.Button(row, "Отозвать", w - 8 - bw - 6, rowH * 0.1, bw, bh, function()
					Decide("revoke")
				end, false, true)
			end
		end
	end
}
